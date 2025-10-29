#!/bin/bash
# Simple JRuby startup script - single attempt

echo "Starting JRuby Monitus with Puma..."
echo "JRuby version: $(jruby --version)"

# Set up environment
export BUNDLE_PATH="/app/vendor/bundle"
export BUNDLE_WITHOUT="development:test"
export RACK_ENV="production"

# Clean any bundler state
rm -rf .bundle/ Gemfile.lock 2>/dev/null || true

echo "Bundler configuration:"
bundle config list 2>/dev/null || echo "No bundler config"

echo "Available gems in vendor/bundle:"
ls -la vendor/bundle/jruby/*/gems/ 2>/dev/null | head -5 || echo "No gems directory found"

echo "Starting Puma server..."
# Start with the most likely to work configuration
exec bundle exec puma -C config/puma.rb simple-config.ru