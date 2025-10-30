#!/bin/bash
# JRuby + Passenger startup script
# Compatible with both RVM and system JRuby installations

set -e

echo "[$(date)] Starting JRuby + Passenger application initialization..."

# Try to source RVM if available, otherwise use system JRuby
if [ -f /usr/local/rvm/scripts/rvm ]; then
    echo "[$(date)] Using RVM JRuby installation"
    source /usr/local/rvm/scripts/rvm
    rvm use jruby-9.4.14.0 || echo "Warning: Specific JRuby version not found, using default"
else
    echo "[$(date)] Using system JRuby installation"
fi

# Change to application directory
cd /home/app/webapp

# Verify JRuby is working
echo "[$(date)] JRuby version:"
jruby --version

# Verify Passenger can see JRuby
echo "[$(date)] Passenger Ruby configuration:"
passenger-config validate-install --auto || echo "Warning: Passenger validation failed but continuing"

# Test basic application loading
echo "[$(date)] Testing application load..."
if [ -f "prometheus_exporter.rb" ]; then
    su - app -c "cd /home/app/webapp && jruby -c prometheus_exporter.rb" && echo "Application syntax OK" || echo "Warning: Application syntax check failed"
fi

# Ensure proper ownership
chown -R app:app /home/app/webapp
if [ -d "/var/log/webapp" ]; then
    chown -R app:app /var/log/webapp
fi

# Create necessary directories
mkdir -p /var/run/passenger-instreg || true
chown -R app:app /var/run/passenger-instreg || true

# Test Nginx configuration
echo "[$(date)] Testing Nginx configuration..."
nginx -t || echo "Warning: Nginx config test failed"

echo "[$(date)] JRuby + Passenger initialization completed!"
echo "[$(date)] Application should be available on port 80"
echo "[$(date)] Health check: curl http://localhost/health"
echo "[$(date)] Metrics endpoint: curl http://localhost/monitus/metrics"
