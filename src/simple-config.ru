# Simple config.ru without bundler requirements
# Load gems directly from vendor/bundle path

$LOAD_PATH.unshift('/app/vendor/bundle/jruby/3.1.0/gems/*/lib')

# Manual gem loading to avoid bundler
require 'sinatra/base'
require 'nokogiri'
require 'json'

# Load the main application
require_relative 'prometheus_exporter'

# Simple health check
class SimpleHealthCheck
  def self.call(env)
    if env['PATH_INFO'] == '/health'
      [200, {'Content-Type' => 'text/plain'}, ['OK - JRuby Direct Mode']]
    else
      PrometheusExporterApp.call(env)
    end
  end
end

run SimpleHealthCheck
