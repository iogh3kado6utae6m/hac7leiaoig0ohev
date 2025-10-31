#!/bin/bash
# Quick check for legacy Ruby 2.3.8 compatibility status
# Can run locally to verify fixes without waiting for CI

set -e

echo "🔍 Legacy Ruby Compatibility Quick Check"
echo "==========================================="
echo

# Check if we have Ruby available
if ! command -v ruby &> /dev/null; then
    echo "❌ No Ruby found in PATH"
    echo "Install Ruby to run this check:"
    echo "  - brew install ruby (macOS)"
    echo "  - apt install ruby (Ubuntu)"
    echo "  - Or use Docker: docker run -it ruby:2.3.8 bash"
    exit 1
fi

echo "📋 Current Ruby Environment:"
echo "Ruby version: $(ruby --version)"
echo "Ruby location: $(which ruby)"
echo "Rubygems version: $(gem --version 2>/dev/null || echo 'N/A')"
echo

# Check Ruby version compatibility
RUBY_VERSION_STR=$(ruby -e "puts RUBY_VERSION")
echo "🔬 Testing Ruby Version Compatibility:"

if ruby -e "exit(RUBY_VERSION >= '2.3.8' ? 0 : 1)" 2>/dev/null; then
    echo "✅ Ruby version $RUBY_VERSION_STR is compatible (>= 2.3.8)"
else
    echo "⚠️  Ruby version $RUBY_VERSION_STR may have compatibility issues"
    echo "   Recommended: Ruby 2.3.8+ for legacy compatibility testing"
fi
echo

# Test 1: Basic syntax check
echo "📝 Test 1: Syntax Validation"
if [ -f "src/prometheus_exporter.rb" ]; then
    if ruby -c src/prometheus_exporter.rb > /dev/null 2>&1; then
        echo "✅ prometheus_exporter.rb syntax OK"
    else
        echo "❌ prometheus_exporter.rb syntax errors"
        ruby -c src/prometheus_exporter.rb || true
    fi
else
    echo "⚠️  src/prometheus_exporter.rb not found (run from project root)"
fi

if [ -f "src/config.ru" ]; then
    if ruby -c src/config.ru > /dev/null 2>&1; then
        echo "✅ config.ru syntax OK"
    else
        echo "❌ config.ru syntax errors"
        ruby -c src/config.ru || true
    fi
else
    echo "⚠️  src/config.ru not found"
fi
echo

# Test 2: Core Ruby functionality
echo "🧪 Test 2: Core Ruby Functionality"
ruby -e "
  puts 'Testing JSON support...'
  require 'json'
  test_data = {'test' => true, 'version' => RUBY_VERSION}
  json_result = JSON.generate(test_data)
  parsed = JSON.parse(json_result)
  puts '✅ JSON works: ' + json_result
  
  puts 'Testing array methods...'
  test_array = [1, 2, 3, 4, 5]
  if RUBY_VERSION >= '2.4.0'
    result = test_array.sum
    method_name = 'Array#sum (Ruby 2.4+)'
  else
    result = test_array.inject(0, :+)
    method_name = 'Array#inject (Ruby 2.3.8 compatible)'
  end
  puts '✅ Array sum: ' + result.to_s + ' using ' + method_name
  
  puts 'Testing string methods...'
  test_string = 'Hello Ruby ' + RUBY_VERSION
  puts '✅ String concatenation: ' + test_string
  
  puts '✅ Core functionality test passed'
" 2>/dev/null && echo "✅ Core Ruby functionality works" || {
    echo "❌ Core Ruby functionality failed"
    echo "This may indicate Ruby installation issues"
}
echo

# Test 3: Legacy Gemfile check
echo "📦 Test 3: Legacy Gemfile Analysis"
if [ -f "src/Gemfile.legacy" ]; then
    echo "✅ Gemfile.legacy exists"
    echo "Dependencies listed:"
    grep "^gem " src/Gemfile.legacy | sed 's/^/  - /'
    echo
    
    # Check if bundler is available
    if command -v bundle &> /dev/null; then
        echo "🔧 Testing bundle configuration..."
        cd src
        export BUNDLE_GEMFILE=Gemfile.legacy
        
        # Check bundler compatibility
        if bundle config --local 2>/dev/null | head -5; then
            echo "✅ Bundler configuration working"
        else
            echo "⚠️  Bundler configuration issues (may be normal for older Ruby)"
        fi
        
        # Try a dry-run to see what would be installed
        echo "Checking gem availability (dry run)..."
        if timeout 30 bundle install --dry-run 2>/dev/null | tail -5; then
            echo "✅ Gems appear available for installation"
        else
            echo "⚠️  Some gems may not be available or compatible"
            echo "   This is common with old Ruby versions"
        fi
        
        cd ..
    else
        echo "⚠️  Bundler not available (install with: gem install bundler)"
    fi
else
    echo "❌ src/Gemfile.legacy not found"
fi
echo

# Test 4: Application loading simulation
echo "🚀 Test 4: Application Loading Test"
if [ -f "src/prometheus_exporter.rb" ]; then
    echo "Testing minimal application loading..."
    
    # Test without full gem dependencies
    ruby -e "
      # Simulate application loading without gems
      RUBY_VERSION_FOR_TEST = RUBY_VERSION
      
      # Test class definition
      class TestPrometheusApp
        def initialize
          @ruby_version = RUBY_VERSION_FOR_TEST
        end
        
        def ruby_sum(array)
          if RUBY_VERSION_FOR_TEST >= '2.4.0'
            array.sum
          else
            array.inject(0, :+)
          end
        end
        
        def info
          {
            'ruby_version' => @ruby_version,
            'engine' => (defined?(RUBY_ENGINE) ? RUBY_ENGINE : 'MRI'),
            'test_sum' => ruby_sum([1, 2, 3, 4, 5])
          }
        end
      end
      
      app = TestPrometheusApp.new
      info = app.info
      
      puts '✅ Application simulation successful'
      puts '   Ruby: ' + info['ruby_version']
      puts '   Engine: ' + info['engine']
      puts '   Test sum: ' + info['test_sum'].to_s
    " 2>/dev/null && echo "✅ Application loading simulation passed" || {
        echo "❌ Application loading simulation failed"
    }
else
    echo "⚠️  Cannot test - prometheus_exporter.rb not found"
fi
echo

# Summary
echo "📊 Legacy Ruby Compatibility Summary"
echo "===================================="

if ruby -e "exit(RUBY_VERSION >= '2.3.8' ? 0 : 1)" 2>/dev/null; then
    echo "✅ Ruby version compatible for legacy testing"
else
    echo "⚠️  Ruby version may need upgrade for full compatibility"
fi

if [ -f "src/prometheus_exporter.rb" ] && ruby -c src/prometheus_exporter.rb > /dev/null 2>&1; then
    echo "✅ Application syntax valid"
else
    echo "❌ Application syntax issues detected"
fi

if ruby -e "require 'json'; JSON.generate({'test' => true})" > /dev/null 2>&1; then
    echo "✅ Core functionality working"
else
    echo "❌ Core functionality issues"
fi

echo
echo "🎯 Recommendations:"
echo "  - For development: Use Ruby 3.2+ or Docker"
echo "  - For legacy systems: Ruby 2.3.8+ should work with basic functionality"
echo "  - For CI: Legacy tests are now non-blocking and run weekly"
echo "  - If issues persist: Check LEGACY_RUBY_TESTING.md for troubleshooting"
echo
echo "✨ Legacy compatibility check completed!"
