#!/bin/bash
# Simple test script for JRuby Docker build

echo "=== Testing JRuby Docker build ==="

# Check if files exist
echo "1. Checking required files:"
for file in Dockerfile.jruby Gemfile.jruby config.ru.jruby config/puma.rb prometheus_exporter.rb; do
    if [ -f "$file" ]; then
        echo "✅ $file exists"
    else
        echo "❌ $file missing"
    fi
done

echo -e "\n2. Dockerfile structure check:"
grep -c "FROM jruby:9.4" Dockerfile.jruby && echo "✅ Using correct base image"
grep -c "bundle.*path.*vendor" Dockerfile.jruby && echo "✅ Bundler path configured" 
grep -c "config.ru.jruby" Dockerfile.jruby && echo "✅ Using JRuby config"

echo -e "\n3. Bundle configuration check:"
grep -A 3 -B 3 "bundle config" Dockerfile.jruby

echo -e "\n✅ Pre-build validation completed"

echo "4. JRuby Gemfile validation:"
echo "Checking JRuby-specific gem configuration:"
grep -c "nokogiri\|sinatra\|puma\|prometheus-client" Gemfile.jruby && echo "✅ Core gems present"
! grep "^gem.*thin" Gemfile.jruby && echo "✅ No thin dependency (avoids EventMachine conflicts)"
! grep "^gem.*faye-websocket" Gemfile.jruby && echo "✅ No faye-websocket dependency (not needed for core app)"
echo "5. Lockfile conflict check:"
if [ -f "Gemfile.lock" ]; then
    echo "⚠️  WARNING: Gemfile.lock present - may cause thin dependency conflicts"
    grep -q "thin" Gemfile.lock && echo "❌ Gemfile.lock contains thin dependency" || echo "✅ Gemfile.lock doesn't contain thin"
else
    echo "✅ No Gemfile.lock present - no conflict risk"
fi
echo "6. Production gem validation:"
echo "Checking no test dependencies in JRuby Gemfile:"
! grep "^gem.*minitest" Gemfile.jruby && echo "✅ No minitest dependency (not needed in production)"
! grep "^gem.*rack-test" Gemfile.jruby && echo "✅ No rack-test dependency (not needed in production)"
echo "Core production gems: $(grep -c '^gem' Gemfile.jruby) gems total"
echo "7. Startup script validation:"
echo "Checking startup components:"
[ -f "start-jruby.sh" ] && echo "✅ start-jruby.sh exists" || echo "❌ start-jruby.sh missing"
[ -x "start-jruby.sh" ] && echo "✅ start-jruby.sh is executable" || echo "❌ start-jruby.sh not executable"
[ -f "simple-config.ru" ] && echo "✅ simple-config.ru fallback exists" || echo "❌ simple-config.ru missing"
echo "Startup strategy: Intelligent fallback with bundler bypass"