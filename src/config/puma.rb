# Puma configuration optimized for JRuby
# JRuby benefits from threading more than forking

# Use environment variables or defaults
environment ENV.fetch('RACK_ENV', 'production')

# JRuby-optimized thread configuration
# JRuby handles threads better than MRI Ruby
if defined?(JRUBY_VERSION)
  # More threads for JRuby since it has true threading
  threads_count = ENV.fetch('RAILS_MAX_THREADS', 16).to_i
  threads threads_count, threads_count * 2
  
  # JRuby doesn't support worker mode (forking) reliably
  # Run in single-process mode with high thread count instead
  # Note: Don't set workers() for JRuby - it defaults to 0 (single process)
  
  puts "JRuby detected: Running in single-process mode with #{threads_count}-#{threads_count * 2} threads"
else
  # Standard configuration for MRI Ruby
  threads_count = ENV.fetch('RAILS_MAX_THREADS', 5).to_i
  threads threads_count, threads_count
  
  workers ENV.fetch('WEB_CONCURRENCY', 2).to_i
  
  # Preload application for better memory usage with workers
  preload_app!
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

# Worker and thread management (for MRI Ruby only)
unless defined?(JRUBY_VERSION)
  # Only set worker callbacks for MRI Ruby that supports forking
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
else
  # JRuby runs in single-process mode, no worker callbacks needed
  puts "JRuby single-process mode: No worker callbacks configured"
end

# JRuby-specific optimizations
if defined?(JRUBY_VERSION)
  # JRuby system properties should be set via environment variables or Java system properties
  # These are typically set via JRUBY_OPTS or JAVA_OPTS environment variables
  # rather than programmatically in Puma config
  
  puts "JRuby detected: #{JRUBY_VERSION}"
  puts "Java version: #{java.lang.System.getProperty('java.version')}" if defined?(java)
end

# Health check endpoint will be handled by the config.ru application
