#!/bin/bash
# Simple JRuby startup script to bypass bundler issues

echo "Starting JRuby Monitus with Puma..."
echo "JRuby version: $(jruby --version)"

# Set up paths
export BUNDLE_PATH="/app/vendor/bundle"
export BUNDLE_WITHOUT="development:test"

# Clean any bundler state that might interfere
rm -rf .bundle/ Gemfile.lock

# Print diagnostic info  
echo "Bundler configuration:"
bundle config list 2>/dev/null || echo "No bundler config"

echo "Available gems in vendor/bundle:"
ls -la vendor/bundle/jruby/*/gems/ 2>/dev/null | head -10 || echo "No gems directory found"

# Try to start puma with different approaches
echo "Attempting to start Puma..."

# Method 1: Try bundle exec (normal approach)
echo "Method 1: Trying bundle exec puma..."
bundle exec puma -C config/puma.rb -b tcp://0.0.0.0:8080 -e production -t 8:32 --preload config.ru.jruby &
PID1=$!
sleep 3

# Check if it started successfully
if kill -0 $PID1 2>/dev/null; then
    echo "Bundle exec puma started successfully!"
    wait $PID1
else
    echo "Bundle exec failed, trying simple config..."
    
    # Method 2: Direct puma with simple config (fallback)
    echo "Method 2: Trying direct puma with simple config..."
    puma -C config/puma.rb -b tcp://0.0.0.0:8080 -e production -t 8:32 --preload simple-config.ru
fi
