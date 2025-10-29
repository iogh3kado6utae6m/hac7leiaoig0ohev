# Puma configuration optimized for JRuby
# JRuby benefits from threading more than forking

# Use environment variables or defaults
port ENV.fetch('PORT', 8080)
environment ENV.fetch('RACK_ENV', 'production')

# JRuby-optimized thread configuration
# JRuby handles threads better than MRI Ruby
if defined?(JRUBY_VERSION)
  # More threads for JRuby since it has true threading
  threads_count = ENV.fetch('RAILS_MAX_THREADS', 16).to_i
  threads threads_count, threads_count * 2
  
  # JRuby doesn't benefit as much from workers (forking)
  # Use fewer workers and rely more on threading
  workers ENV.fetch('WEB_CONCURRENCY', 1).to_i
  
  # Preload application for better memory usage
  preload_app!
else
  # Standard configuration for MRI Ruby
  threads_count = ENV.fetch('RAILS_MAX_THREADS', 5).to_i
  threads threads_count, threads_count
  
  workers ENV.fetch('WEB_CONCURRENCY', 2).to_i
end

# Bind to all interfaces
bind "tcp://0.0.0.0:#{ENV.fetch('PORT', 8080)}"

# Logging
if ENV['RACK_ENV'] == 'production'
  stdout_redirect '/dev/stdout', '/dev/stderr', true
else
  # Development logging
  activate_control_app 'tcp://127.0.0.1:9293', { no_token: true }
end

# Worker and thread management (updated for Puma v7+)
before_worker_boot do
  # Code to run before forking workers
  puts "Preparing to fork workers"
end

on_worker_boot do
  # Code to run when a worker starts
  puts "Worker #{Process.pid} started"
end

# Graceful shutdown configuration
before_worker_shutdown do
  puts "Worker #{Process.pid} shutting down"
end

# JRuby-specific optimizations
if defined?(JRUBY_VERSION)
  # JRuby system properties should be set via environment variables or Java system properties
  # These are typically set via JRUBY_OPTS or JAVA_OPTS environment variables
  # rather than programmatically in Puma config
  
  puts "JRuby detected: #{JRUBY_VERSION}"
  puts "Java version: #{java.lang.System.getProperty('java.version')}" if defined?(java)
end

# Health check endpoint
app do |env|
  if env['PATH_INFO'] == '/health'
    [200, {'Content-Type' => 'text/plain'}, ['OK']]
  else
    [404, {'Content-Type' => 'text/plain'}, ['Not Found']]
  end
end
