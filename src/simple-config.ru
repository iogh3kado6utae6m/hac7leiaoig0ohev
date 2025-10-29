# Minimal JRuby config.ru - health check only
# This avoids loading complex applications that might have port conflicts

puts "Loading minimal JRuby configuration..."

# Simple health check application
class JRubyHealthApp
  def call(env)
    case env['PATH_INFO']
    when '/health'
      [200, {'Content-Type' => 'text/plain'}, ["OK - JRuby #{JRUBY_VERSION if defined?(JRUBY_VERSION)}\n"]]
    when '/'
      [200, {'Content-Type' => 'text/plain'}, ["JRuby Monitus Server Running\nVisit /health for health check\n"]]
    else
      [404, {'Content-Type' => 'text/plain'}, ['Not Found']]
    end
  end
end

puts "Starting minimal JRuby health application..."
run JRubyHealthApp.new