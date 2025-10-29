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

# Method 1: Try bundle exec with JRuby config (normal approach)
echo "Method 1: Trying bundle exec puma with JRuby config..."
if bundle exec puma -C config/puma.rb config.ru.jruby; then
    echo "Bundle exec puma started successfully with JRuby config!"
else
    echo "JRuby config failed, trying standard config..."
    
    # Method 2: Try standard config.ru
    echo "Method 2: Trying bundle exec with standard config..."
    if bundle exec puma -C config/puma.rb config.ru; then
        echo "Standard config worked!"
    else
        echo "Bundle exec failed, trying simple config..."
        
        # Method 3: Direct puma via bundle with simple config (fallback)
        echo "Method 3: Trying bundle exec puma with simple config..."
        bundle exec puma -C config/puma.rb simple-config.ru
    fi
fi
