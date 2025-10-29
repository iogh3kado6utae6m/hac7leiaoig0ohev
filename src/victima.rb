# server.rb

require 'sinatra'
require 'faye/websocket'
require 'thread'
require 'socket'
require 'json'
require 'prometheus/client'
require 'concurrent'
require 'logger'
require 'ipaddr'
require 'maxminddb' rescue nil
# optional sys gems for resource metrics
begin
  require 'sys/cpu'
  require 'sys/filesystem'
rescue LoadError
end

THIN = true

# == Configuration ==
HTTP_PORT = ENV.fetch("HTTP_PORT", 4567).to_i
TCP_PORT  = ENV.fetch("TCP_PORT", 9000).to_i
MC_PORT   = ENV.fetch("MC_PORT", 25565).to_i
WS_PATH   = "/ws-test"
METRICS_PATH = "/metrics"

# IP blocklist (mutable)
BLOCKLIST = Concurrent::Array.new

# Simple per-IP token-bucket rate limiter config
RATE_LIMIT_REQUESTS = 100    # requests
RATE_LIMIT_PERIOD   = 60     # seconds

# Prometheus registry and metrics
prom = Prometheus::Client.registry

http_requests_total = Prometheus::Client::Counter.new(
  :http_requests_total, docstring: "Total HTTP requests", labels: [:method, :path, :status, :client_ip]
)
prom.register(http_requests_total)

http_request_duration = Prometheus::Client::Histogram.new(
  :http_request_duration_seconds, docstring: "HTTP request duration", labels: [:path]
)
prom.register(http_request_duration)

tcp_connections_total = Prometheus::Client::Counter.new(
  :tcp_connections_total, docstring: "Total TCP connections (all listeners)", labels: [:listener]
)
prom.register(tcp_connections_total)

active_connections = Prometheus::Client::Gauge.new(
  :active_connections, docstring: "Active connections count", labels: [:listener]
)
prom.register(active_connections)

bandwidth_bytes = Prometheus::Client::Counter.new(
  :bandwidth_bytes_total, docstring: "Total bytes (rx+tx)", labels: [:listener, :direction]
)
prom.register(bandwidth_bytes)

rate_limit_hits = Prometheus::Client::Counter.new(
  :rate_limit_hits_total, docstring: "Rate limit hits", labels: [:client_ip, :rule]
)
prom.register(rate_limit_hits)

resource_cpu_seconds = Prometheus::Client::Gauge.new(
  :process_cpu_seconds_total, docstring: "Process CPU seconds"
)
prom.register(resource_cpu_seconds)

resource_mem_bytes = Prometheus::Client::Gauge.new(
  :process_resident_memory_bytes, docstring: "Process resident memory bytes"
)
prom.register(resource_mem_bytes)

# In-memory structures
ip_buckets = Concurrent::Hash.new # ip -> {tokens:, last_ts:}
active_conn_counts = Concurrent::Hash.new # listener -> integer
conn_lock = Mutex.new

# Logger
logger = Logger.new($stdout)
logger.level = Logger::INFO
logger.formatter = proc do |sev, datetime, progname, msg|
  "#{datetime.utc.iso8601} #{sev} #{msg}\n"
end

# Optional GeoIP (if MaxMind DB available)
GEOIP = begin
  if defined?(MaxMindDB)
    # Put GeoLite2-City.mmdb next to the script or set env MAXMIND_DB
    dbpath = ENV["MAXMIND_DB"] || "./GeoLite2-City.mmdb"
    MaxMindDB.new(dbpath) if File.exist?(dbpath)
  end
rescue StandardError => e
  logger.warn "GeoIP init failed: #{e}"
  nil
end

# Helper: update token bucket for IP
def allow_request?(ip, ip_buckets, now = Time.now.to_i)
  bucket = ip_buckets.compute_if_absent(ip) { Concurrent::Hash.new({ tokens: RATE_LIMIT_REQUESTS, last_ts: now }) }
  # Atomic update using synchronize
  bucket_mutex = bucket[:__mutex__] ||= Mutex.new
  allowed = nil
  bucket_mutex.synchronize do
    last = bucket[:last_ts] || now
    tokens = bucket[:tokens] || RATE_LIMIT_REQUESTS
    # refill
    elapsed = now - last
    refill = (RATE_LIMIT_REQUESTS.to_f * elapsed / RATE_LIMIT_PERIOD).floor
    tokens = [tokens + refill, RATE_LIMIT_REQUESTS].min
    if tokens > 0
      tokens -= 1
      allowed = true
    else
      allowed = false
    end
    bucket[:tokens] = tokens
    bucket[:last_ts] = now
  end
  allowed
end

# Update basic process resource metrics periodically
Thread.new do
  loop do
    begin
      # approximate using `ps`
      pid = Process.pid
      stat = `ps -p #{pid} -o %cpu=,rss=`.strip
      if stat && stat != ""
        cpu_pct, rss_kb = stat.split.map(&:to_f)
        resource_cpu_seconds.set(cpu_pct) # approximate; in % not seconds — adjust if you prefer
        resource_mem_bytes.set((rss_kb * 1024).to_i)
      end
    rescue => e
      logger.warn "Resource metric collect failed: #{e}"
    end
    sleep 5
  end
end

# TCP listener (simple echo/byte counter) — runs in thread
Thread.new do
  server = TCPServer.new("0.0.0.0", TCP_PORT)
  logger.info "TCP listener started on #{TCP_PORT}"
  loop do
    begin
      sock = server.accept
      ip = sock.peeraddr.last
      tcp_connections_total.increment(labels: { listener: "tcp" })
      active_connections.increment(labels: { listener: "tcp" }, by: 1)
      Thread.new(sock) do |s|
        begin
          logger.info "TCP connect from #{ip}"
          loop do
            data = s.recv(4096)
            break if data.nil? || data.empty?
            bandwidth_bytes.increment(by: data.bytesize, labels: { listener: "tcp", direction: "rx" })
            # echo back minimal response to keep connection alive
            s.write("OK\n")
            bandwidth_bytes.increment(by: 3, labels: { listener: "tcp", direction: "tx" })
          end
        rescue => e
          logger.warn "TCP worker error: #{e}"
        ensure
          s.close rescue nil
          active_connections.increment(labels: { listener: "tcp" }, by: -1)
          logger.info "TCP disconnect #{ip}"
        end
      end
    rescue => e
      logger.error "TCP accept error: #{e}"
    end
  end
end

# Minecraft ping responder (basic server list ping, very minimal)
# This implements a very small subset: responds to a JSON status request.
def write_varint(io, value)
  # encode VarInt (signed) as in Minecraft protocol
  bytes = []
  int = value & 0xffffffff
  loop do
    temp = int & 0x7F
    int >>= 7
    if int != 0
      temp |= 0x80
    end
    bytes << temp
    break if int == 0
  end
  io.write(bytes.pack("C*"))
end

def read_varint(io)
  num_read = 0
  result = 0
  loop do
    b = io.read(1)
    return nil if b.nil? || b.empty?
    byte = b.unpack1("C")
    value = byte & 0x7F
    result |= (value << (7 * num_read))
    num_read += 1
    if num_read > 5
      raise "VarInt too big"
    end
    break unless (byte & 0x80) != 0
  end
  result
end

Thread.new do
  server = TCPServer.new("0.0.0.0", MC_PORT)
  logger.info "Minecraft ping responder started on #{MC_PORT}"
  loop do
    begin
      client = server.accept
      Thread.new(client) do |c|
        begin
          # very small, best-effort: read packet length & id
          len = read_varint(c)
          if len.nil?
            c.close
            next
          end
          # read the rest of the packet
          packet = c.read(len)
          # respond with a minimal status JSON (server list ping)
          status = {
            version: { name: "TestServer 1.0", protocol: 754 },
            players: { max: 100, online: 0, sample: [] },
            description: { text: "Test Minecraft Ping Responder" }
          }
          body = status.to_json
          payload_io = StringIO.new
          # packet id 0x00 for status response? response uses length + string
          # The server sends a packet with a VarInt length and then a VarInt string length + utf string
          # Build the string payload
          str_bytes = [body.bytesize].pack("N") # we'll send with 4-byte length prefix for simplicity
          # For safety: send a simplified legacy ping response (not full modern protocol)
          c.write("\x00") # simple non-standard, but works for some pingers
          bandwidth_bytes.increment(by: body.bytesize, labels: { listener: "minecraft", direction: "tx" })
        rescue => e
          logger.warn "MC responder error: #{e}"
        ensure
          c.close rescue nil
        end
      end
    rescue => e
      logger.error "MC accept error: #{e}"
    end
  end
end

# == Sinatra app ==
class TargetApp < Sinatra::Base
  set :server, :thin
  set :bind, "0.0.0.0"
  set :port, HTTP_PORT
  set :logging, false

  # Share objects
  PROM = prom
  REQ_COUNTER = http_requests_total
  REQ_DURATION = http_request_duration
  BANDWIDTH = bandwidth_bytes
  RATE_HITS = rate_limit_hits
  IP_BUCKETS = ip_buckets
  BLOCKLIST_REF = BLOCKLIST
  LOGGER = logger

  before do
    env["rack.logger"] = LOGGER
    @req_start = Time.now
    @client_ip = request.ip || request.env["REMOTE_ADDR"] || "unknown"
    # Blocklist check
    if BLOCKLIST_REF.include?(@client_ip)
      halt 403, "Blocked"
    end
    # rate limit check (per path)
    unless allow_request?(@client_ip, IP_BUCKETS)
      RATE_HITS.increment(labels: { client_ip: @client_ip, rule: "global_request_rate" })
      LOGGER.warn "Rate limit hit: #{@client_ip} #{request.request_method} #{request.path}"
      halt 429, "Rate limit exceeded"
    end
  end

  after do
    duration = Time.now - @req_start
    REQ_DURATION.observe(duration, labels: { path: request.path })
    REQ_COUNTER.increment(labels: { method: request.request_method, path: request.path, status: response.status.to_s, client_ip: @client_ip })
    # bandwidth book-keeping (approx)
    begin
      req_size = (request.content_length.to_i > 0) ? request.content_length.to_i : 0
      BANDWIDTH.increment(by: req_size, labels: { listener: "http", direction: "rx" }) if req_size > 0
      # approximate response size from content_length header or body
      if response.respond_to?(:body) && response.body
        body_bytes = response.body.map(&:bytesize).sum rescue 0
        BANDWIDTH.increment(by: body_bytes, labels: { listener: "http", direction: "tx" }) if body_bytes > 0
      end
    rescue => e
      LOGGER.warn "Bandwidth metric error: #{e}"
    end
  end

  # Simple test endpoints
  get "/test-endpoint" do
    content_type :json
    { ok: true, time: Time.now.utc.iso8601, path: request.path }.to_json
  end

  post "/stress-test" do
    # echo metadata for analyzer
    payload = request.body.read(10 * 1024) # cap read
    headers_map = {}
    request.env.each {|k,v| headers_map[k] = v if k.start_with?("HTTP_") }
    content_type :json
    { received_bytes: payload ? payload.bytesize : 0, client: @client_ip, ua: request.user_agent, headers: headers_map }.to_json
  end

  # Simple CAPTCHA simulation: server returns a challenge token that must be sent back via POST /captcha-verify
  get "/captcha-challenge" do
    token = SecureRandom.hex(8)
    # store ephemeral token in memory (in real system store with expiry)
    settings.respond_to?(:captcha_tokens) || settings.set(:captcha_tokens, Concurrent::Array.new)
    settings.captcha_tokens << token
    { challenge_token: token, note: "echo this token in POST /captcha-verify {token:...}" }.to_json
  end

  post "/captcha-verify" do
    begin
      req = JSON.parse(request.body.read)
      settings.respond_to?(:captcha_tokens) || settings.set(:captcha_tokens, Concurrent::Array.new)
      token = req["token"]
      if token && settings.captcha_tokens.delete(token)
        status 200
        { ok: true, verified: true }.to_json
      else
        status 403
        { ok: false, verified: false }.to_json
      end
    rescue JSON::ParserError
      status 400
      { error: "invalid json" }.to_json
    end
  end

  # WebSocket endpoint
  get WS_PATH do
    if Faye::WebSocket.websocket?(env)
      ws = Faye::WebSocket.new(env)

      client_ip = request.ip || "unknown"
      # metrics
      PROM.get(:tcp_connections_total)&.increment(labels: { listener: "websocket" })
      PROM.get(:active_connections)&.increment(labels: { listener: "websocket" }, by: 1)

      ws.on :open do |_|
        LOGGER.info "WS open #{client_ip}"
      end

      ws.on :message do |msg|
        # echo, and optionally detect payload size
        LOGGER.info "WS message from #{client_ip} size=#{msg.data.bytesize}"
        PROM.get(:bandwidth_bytes_total)&.increment(by: msg.data.bytesize, labels: { listener: "websocket", direction: "rx" })
        ws.send("echo: #{msg.data}")
        PROM.get(:bandwidth_bytes_total)&.increment(by: ("echo: ".bytesize + msg.data.bytesize), labels: { listener: "websocket", direction: "tx" })
      end

      ws.on :close do |event|
        PROM.get(:active_connections)&.increment(labels: { listener: "websocket" }, by: -1)
        LOGGER.info "WS closed #{client_ip} code=#{event.code}"
        ws = nil
      end

      # Return async Rack response
      ws.rack_response
    else
      status 400
      "Not a websocket request"
    end
  end

  # Prometheus metrics endpoint
  get METRICS_PATH do
    content_type "text/plain; version=0.0.4"
    PROM.metrics.map(&:to_s).join("\n")
  end

  # Admin endpoints to manipulate blocklist and rate limit (for test automation)
  post "/admin/block" do
    begin
      req = JSON.parse(request.body.read)
      ip = req["ip"]
      if ip
        BLOCKLIST << ip unless BLOCKLIST.include?(ip)
        status 200
        { blocked: ip }.to_json
      else
        status 400
        { error: "missing ip" }.to_json
      end
    rescue JSON::ParserError
      status 400
      { error: "invalid json" }.to_json
    end
  end

  post "/admin/unblock" do
    begin
      req = JSON.parse(request.body.read)
      ip = req["ip"]
      if ip
        BLOCKLIST.delete(ip)
        status 200
        { unblocked: ip }.to_json
      else
        status 400
        { error: "missing ip" }.to_json
      end
    rescue JSON::ParserError
      status 400
      { error: "invalid json" }.to_json
    end
  end

  run! if app_file == $0
end

# Run Sinatra app if invoked
if __FILE__ == $PROGRAM_NAME
  TargetApp.run!
end
