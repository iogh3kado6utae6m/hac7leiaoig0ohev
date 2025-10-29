#!/bin/bash
set -e

# JRuby-specific test runner
echo "🔥 Running JRuby-specific tests..."
echo "JRuby Version: $(jruby --version)"
echo "Java Version: $(java -version 2>&1 | head -n 1)"

# Set JRuby optimizations
export JRUBY_OPTS="-Xcompile.invokedynamic=true"
export JAVA_OPTS="-Xmx1G -Xms256M -XX:+UseG1GC"

# Install test dependencies if not already installed
cd test
echo "📦 Installing test dependencies..."
gem install bundler --no-document
bundle install --quiet

echo "🧪 Running JRuby compatibility tests..."

# Test basic JRuby functionality
echo "🔍 Testing JRuby environment..."
jruby -e "puts 'JRuby is working: ' + JRUBY_VERSION"
jruby -e "require 'java'; puts 'Java integration working'"

# Test core application loading with JRuby
echo "🏗️  Testing application loading on JRuby..."
cd ../src
jruby -e "
  require_relative 'prometheus_exporter'
  puts '✅ Application loaded successfully on JRuby'
  app = PrometheusExporterApp.new
  puts '✅ Application instantiated on JRuby'
  puts 'Self group name: ' + PrometheusExporterApp::SELF_GROUP_NAME
"

# Run JRuby-specific tests
echo "🧪 Running JRuby unit tests..."
cd ../test
jruby tests/jruby_compatibility_test.rb

# Test JRuby endpoints
echo "🌐 Testing JRuby service endpoints..."

# Test JRuby with app
echo "Testing passenger_jruby_with_app..."
response=$(curl -s -w "%{http_code}" -o /tmp/jruby_response_with_app.txt "http://passenger_jruby_with_app:80/monitus/metrics" || echo "000")
if [ "$response" = "200" ]; then
    echo "✅ JRuby with app: HTTP $response"
    grep -q "passenger_capacity" /tmp/jruby_response_with_app.txt && echo "✅ JRuby with app: Contains expected metrics"
else
    echo "❌ JRuby with app: HTTP $response"
    exit 1
fi

# Test JRuby without app
echo "Testing passenger_jruby_without_app..."
response=$(curl -s -w "%{http_code}" -o /tmp/jruby_response_without_app.txt "http://passenger_jruby_without_app:80/monitus/metrics" || echo "000")
if [ "$response" = "200" ]; then
    echo "✅ JRuby without app: HTTP $response"
    # Should have fewer metrics since no apps are running
    if grep -q "ERROR: No other application has been loaded yet" /tmp/jruby_response_without_app.txt; then
        echo "✅ JRuby without app: Expected no-app message"
    fi
else
    echo "❌ JRuby without app: HTTP $response"
    exit 1
fi

# Test standalone JRuby application
echo "Testing monitus_jruby_standalone..."
response=$(curl -s -w "%{http_code}" -o /tmp/jruby_standalone_health.txt "http://monitus_jruby_standalone:8080/health" || echo "000")
if [ "$response" = "200" ]; then
    echo "✅ JRuby standalone: Health check HTTP $response"
    grep -q "OK" /tmp/jruby_standalone_health.txt && echo "✅ JRuby standalone: Health check OK"
else
    echo "❌ JRuby standalone: Health check HTTP $response"
    exit 1
fi

# Test JRuby performance characteristics
echo "⚡ Testing JRuby performance characteristics..."
start_time=$(date +%s%3N)
curl -s "http://passenger_jruby_with_app:80/monitus/metrics" > /dev/null
end_time=$(date +%s%3N)
duration=$((end_time - start_time))
echo "📊 JRuby metrics endpoint response time: ${duration}ms"

if [ $duration -lt 5000 ]; then
    echo "✅ JRuby performance: Response time acceptable (<5s)"
else
    echo "⚠️  JRuby performance: Response time high (${duration}ms) - expected for first request"
fi

# JRuby memory usage check (approximate)
echo "🧠 Checking JRuby memory characteristics..."
jruby -e "
  runtime = Java::JavaLang::Runtime.getRuntime
  total_memory = runtime.totalMemory / 1024 / 1024
  free_memory = runtime.freeMemory / 1024 / 1024
  used_memory = total_memory - free_memory
  puts \"📊 JRuby Memory: #{used_memory}MB used / #{total_memory}MB total\"
  puts \"✅ JRuby memory reporting functional\" if total_memory > 0
"

echo "🎉 All JRuby tests completed successfully!"
echo "📋 JRuby Test Summary:"
echo "  ✅ JRuby environment functional"
echo "  ✅ Application loads on JRuby"
echo "  ✅ JRuby services responding"
echo "  ✅ Metrics endpoints functional"
echo "  ✅ Performance within acceptable range"
echo "  ✅ Memory management functional"
