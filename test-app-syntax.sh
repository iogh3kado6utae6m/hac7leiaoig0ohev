#!/bin/bash
# Test application syntax and dependencies locally
# This helps identify issues without Docker

set -euo pipefail

echo "🔍 Testing Monitus Application Components"
echo "=========================================="

# Check if we have the required tools
echo "🔧 Checking prerequisites..."
for tool in ruby jruby bundle; do
    if command -v "$tool" >/dev/null 2>&1; then
        echo "   ✅ $tool: $(which $tool)"
    else
        echo "   ❌ $tool: not found"
    fi
done
echo

# Try to test with regular Ruby first (simpler)
if command -v ruby >/dev/null 2>&1; then
    echo "🔴 Testing with Ruby $(ruby -v):"
    
    echo -n "   Syntax check prometheus_exporter.rb... "
    if ruby -c src/prometheus_exporter.rb >/dev/null 2>&1; then
        echo "✅"
    else
        echo "❌"
        echo "   Error details:"
        ruby -c src/prometheus_exporter.rb 2>&1 | sed 's/^/      /'
    fi
    
    # Test various config.ru files
    for config in src/config.ru.jruby-passenger src/config.ru.jruby-passenger-simple; do
        if [[ -f "$config" ]]; then
            echo -n "   Syntax check $(basename $config)... "
            if ruby -c "$config" >/dev/null 2>&1; then
                echo "✅"
            else
                echo "❌"
                echo "   Error details:"
                ruby -c "$config" 2>&1 | sed 's/^/      /'
            fi
        fi
    done
    echo
fi

# Try with JRuby if available
if command -v jruby >/dev/null 2>&1; then
    echo "♦️ Testing with JRuby $(jruby --version 2>/dev/null | head -1):"
    
    echo -n "   Syntax check prometheus_exporter.rb... "
    if jruby -c src/prometheus_exporter.rb >/dev/null 2>&1; then
        echo "✅"
    else
        echo "❌"
        echo "   Error details:"
        jruby -c src/prometheus_exporter.rb 2>&1 | sed 's/^/      /'
    fi
    
    # Test config.ru files with JRuby
    for config in src/config.ru.jruby-passenger src/config.ru.jruby-passenger-simple; do
        if [[ -f "$config" ]]; then
            echo -n "   Syntax check $(basename $config)... "
            if jruby -c "$config" >/dev/null 2>&1; then
                echo "✅"
            else
                echo "❌"
                echo "   Error details:"
                jruby -c "$config" 2>&1 | sed 's/^/      /'
            fi
        fi
    done
    echo
fi

# Test dependency loading
echo "📦 Testing dependency loading:"
for ruby_cmd in ruby jruby; do
    if command -v "$ruby_cmd" >/dev/null 2>&1; then
        echo "   With $ruby_cmd:"
        
        # Test each required gem
        for gem in json nokogiri sinatra; do
            echo -n "      $gem... "
            if "$ruby_cmd" -e "require '$gem'; puts 'OK'" >/dev/null 2>&1; then
                echo "✅"
            else
                echo "❌"
            fi
        done
        echo
    fi
done

# Test bundle configurations
if [[ -d src ]]; then
    echo "📦 Testing bundle configurations:"
    cd src
    
    for gemfile in Gemfile.jruby-passenger; do
        if [[ -f "$gemfile" ]]; then
            echo "   $gemfile:"
            echo -n "      Syntax... "
            if ruby -c "$gemfile" >/dev/null 2>&1; then
                echo "✅"
            else
                echo "❌"
            fi
            
            echo "      Contents:"
            cat "$gemfile" | sed 's/^/         /'
            echo
        fi
    done
    cd ..
fi

echo "📋 Summary:"
echo "   If all syntax checks pass, the issue is likely:"
echo "   1. Missing gems in the Docker environment"
echo "   2. JRuby-specific compatibility issues"
echo "   3. Passenger configuration problems"
echo "   4. File permissions in the container"
echo
echo "   Next steps:"
echo "   - Try: ./deploy-full-monitus.sh working 8082"
echo "   - Check container logs with Docker access"
echo "   - Use debug variant with friendly error pages"
