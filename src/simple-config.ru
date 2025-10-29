# Simple config.ru for JRuby fallback mode
# Minimal dependencies to ensure startup works

begin
  require "bundler/setup"
rescue LoadError
  # If bundler fails, try manual path setup
  $LOAD_PATH.unshift('/app/vendor/bundle/jruby/3.1.0/gems/*/lib')
end

# Try to load the main application
app_loaded = false
begin
  require_relative 'prometheus_exporter'
  main_app = PrometheusExporterApp
  app_loaded = true
  puts "Loaded PrometheusExporterApp in simple mode"
rescue LoadError => e
  puts "Could not load PrometheusExporterApp: #{e.message}"
  begin
    require_relative 'victima'
    main_app = TargetApp
    app_loaded = true
    puts "Loaded TargetApp in simple mode"
  rescue LoadError => e2
    puts "Could not load TargetApp either: #{e2.message}"
  end
end

# Simple health check with fallback
class SimpleHealthCheck
  def initialize(main_app = nil)
    @main_app = main_app
  end
  
  def call(env)
    if env['PATH_INFO'] == '/health'
      [200, {'Content-Type' => 'text/plain'}, ['OK - JRuby Simple Mode']]
    elsif @main_app
      @main_app.call(env)
    else
      [200, {'Content-Type' => 'text/plain'}, ['JRuby Server Running - No main app loaded']]
    end
  end
end

if app_loaded
  run SimpleHealthCheck.new(main_app)
else
  puts "Running in health-check-only mode"
  run SimpleHealthCheck.new
end
