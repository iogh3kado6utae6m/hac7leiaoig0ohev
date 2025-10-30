#!/bin/bash
# JRuby + Passenger + Nginx startup script

set -e

echo "🚀 Starting JRuby application with Passenger + Nginx..."
echo "JRuby version: $(jruby --version)"
echo "Java version: $(java -version 2>&1 | head -n 1)"

# Set JRuby environment variables
export JRUBY_OPTS="${JRUBY_OPTS:--Xcompile.invokedynamic=true -J-Djnr.ffi.asm.enabled=false}"
export JAVA_OPTS="${JAVA_OPTS:--Xmx1G -Xms256M -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -Djnr.netdb.provider=files}"
export RACK_ENV="${RACK_ENV:-production}"
export PASSENGER_APP_ENV="${PASSENGER_APP_ENV:-production}"

# Set Passenger environment variables with defaults
export PASSENGER_MIN_INSTANCES="${PASSENGER_MIN_INSTANCES:-2}"
export PASSENGER_MAX_INSTANCES="${PASSENGER_MAX_INSTANCES:-8}"
export PASSENGER_CONCURRENCY_MODEL="${PASSENGER_CONCURRENCY_MODEL:-thread}"
export PASSENGER_THREAD_COUNT="${PASSENGER_THREAD_COUNT:-16}"

echo "📋 Configuration:"
echo "  RACK_ENV: $RACK_ENV"
echo "  PASSENGER_MIN_INSTANCES: $PASSENGER_MIN_INSTANCES"
echo "  PASSENGER_MAX_INSTANCES: $PASSENGER_MAX_INSTANCES"
echo "  PASSENGER_CONCURRENCY_MODEL: $PASSENGER_CONCURRENCY_MODEL"
echo "  PASSENGER_THREAD_COUNT: $PASSENGER_THREAD_COUNT"

# Ensure application directory ownership
echo "🔧 Setting up application directory..."
chown -R app:app /home/app/webapp || true
chown -R app:app /var/log/webapp || true

# Switch to application directory
cd /home/app/webapp

# Check if Gemfile exists and install dependencies if needed
if [ -f "Gemfile" ]; then
    echo "📦 Checking gem dependencies..."
    
    # Use JRuby bundle command
    if ! jbundle check >/dev/null 2>&1; then
        echo "⚠️  Missing gems detected, running bundle install..."
        jbundle config set --local deployment true
        jbundle config set --local path 'vendor/bundle'
        jbundle config set --local without 'development test'
        jbundle install --jobs=4 --retry=3
    else
        echo "✅ Gem dependencies satisfied"
    fi
else
    echo "⚠️  No Gemfile found, proceeding without gem installation"
fi

# Verify critical files exist
if [ ! -f "config.ru" ]; then
    echo "❌ config.ru not found, creating minimal config..."
    cat > config.ru << 'EOF'
# Minimal config.ru for JRuby + Passenger
require_relative 'simple-config.ru' if File.exist?('simple-config.ru')

# Fallback minimal app if no other config found
class MinimalApp
  def call(env)
    case env['PATH_INFO']
    when '/health'
      [200, {'Content-Type' => 'text/plain'}, ["OK - JRuby Passenger #{Time.now.utc.iso8601}\n"]]
    when '/'
      [200, {'Content-Type' => 'text/plain'}, ["JRuby + Passenger Server Running\nVisit /health for health check\n"]]
    else
      [404, {'Content-Type' => 'text/plain'}, ['Not Found']]
    end
  end
end

run MinimalApp.new
EOF
fi

# Create public directory if it doesn't exist (required by Passenger)
if [ ! -d "public" ]; then
    echo "📁 Creating public directory..."
    mkdir -p public
    chown app:app public
fi

# Test JRuby configuration
echo "🧪 Testing JRuby configuration..."
jruby -e "puts 'JRuby working: ' + JRUBY_VERSION; require 'java'; puts 'Java integration: OK'"

# Test application syntax
echo "🔍 Validating application syntax..."
if [ -f "config.ru" ]; then
    jruby -c config.ru && echo "✅ config.ru syntax OK" || echo "⚠️  config.ru syntax issues detected"
fi

# Substitute environment variables in nginx config
echo "⚙️  Configuring Nginx with environment variables..."
envsubst '$PASSENGER_MIN_INSTANCES $PASSENGER_MAX_INSTANCES $PASSENGER_CONCURRENCY_MODEL $PASSENGER_THREAD_COUNT' \
    < /etc/nginx/sites-enabled/webapp.conf > /tmp/webapp.conf && \
    mv /tmp/webapp.conf /etc/nginx/sites-enabled/webapp.conf

# Test nginx configuration
echo "🔍 Testing Nginx configuration..."
nginx -t

# Pre-warm JRuby (optional optimization)
echo "🔥 Pre-warming JRuby JIT compiler..."
jruby -e "
  puts 'Warming up JRuby JIT...'
  3.times do
    (1..100).each { |i| i * 2 }
  end
  puts 'JIT warm-up complete'
" || echo "⚠️  JIT warm-up failed, continuing..."

# Start services
echo "🎬 Starting services..."

# Start nginx with passenger module
echo "🌐 Starting Nginx + Passenger..."
exec nginx -g 'daemon off;'