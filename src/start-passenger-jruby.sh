#!/bin/bash
# JRuby + Passenger startup script
# Based on official Passenger Docker patterns
# This script runs during container initialization

set -e

# Source RVM environment
source /usr/local/rvm/scripts/rvm

# Ensure we're using the correct JRuby version
rvm use jruby-9.4.14.0

echo "[$(date)] Starting JRuby + Passenger application initialization..."

# Change to application directory
cd /home/app/webapp

# Verify JRuby is working
echo "[$(date)] JRuby version:"
jruby --version

# Verify Passenger can see JRuby
echo "[$(date)] Passenger Ruby configuration:"
passenger-config validate-install --auto || true

# Precompile application if needed
if [ "$RACK_ENV" = "production" ] && [ -f "config/application.rb" ]; then
    echo "[$(date)] Precompiling Rails assets (if applicable)..."
    su - app -c "cd /home/app/webapp && RACK_ENV=production jruby -S bundle exec rake assets:precompile" || echo "No assets to precompile or not a Rails app"
fi

# Warm up the JRuby application
echo "[$(date)] Warming up JRuby application..."
su - app -c "cd /home/app/webapp && jruby --dev -e 'puts \"JRuby application warmed up\""

# Test basic application loading
echo "[$(date)] Testing application load..."
su - app -c "cd /home/app/webapp && jruby --dev -e 'require_relative \"prometheus_exporter\"; puts \"Application loads successfully\"'" || echo "Warning: Application test failed"

# Ensure proper ownership
chown -R app:app /home/app/webapp
chown -R app:app /var/log/webapp

# Create necessary directories
mkdir -p /var/run/passenger-instreg
chown -R app:app /var/run/passenger-instreg

# Test Nginx configuration
echo "[$(date)] Testing Nginx configuration..."
nginx -t

echo "[$(date)] JRuby + Passenger initialization completed successfully!"
echo "[$(date)] Application will be available on port 80"
echo "[$(date)] Health check: curl http://localhost/health"
echo "[$(date)] Metrics endpoint: curl http://localhost/monitus/metrics"
