#!/bin/bash
# Test script for fixed JRuby + Passenger + Nginx setup
# Tests the corrected implementation using official passenger-docker patterns

set -e

echo "=== Testing Fixed JRuby + Passenger + Nginx Setup ==="
echo "Timestamp: $(date)"
echo

# Configuration
BASE_URL="${PASSENGER_JRUBY_FIXED_URL:-http://localhost:8082}"
TIMEOUT=60
MAX_RETRIES=10

echo "Testing URL: $BASE_URL"
echo

# Function to wait for service
wait_for_service() {
    local url=$1
    local timeout=$2
    local retries=0
    
    echo "Waiting for service at $url (timeout: ${timeout}s)..."
    
    while [ $retries -lt $MAX_RETRIES ]; do
        if curl -f -s --connect-timeout 5 "$url/health" > /dev/null 2>&1; then
            echo "✅ Service is ready!"
            return 0
        fi
        
        retries=$((retries + 1))
        echo "Attempt $retries/$MAX_RETRIES failed, waiting 6s..."
        sleep 6
    done
    
    echo "❌ Service failed to start within $timeout seconds"
    return 1
}

# Function to test endpoint
test_endpoint() {
    local path=$1
    local expected_code=${2:-200}
    local description="$3"
    
    echo -n "Testing $path"
    [ -n "$description" ] && echo -n " ($description)"
    echo "..."
    
    local response
    local http_code
    
    response=$(curl -s -w "HTTP_CODE:%{http_code}" "$BASE_URL$path" 2>/dev/null || echo "HTTP_CODE:000")
    http_code=$(echo "$response" | grep -o 'HTTP_CODE:[0-9]*' | cut -d: -f2)
    body=$(echo "$response" | sed 's/HTTP_CODE:[0-9]*$//')
    
    if [ "$http_code" = "$expected_code" ]; then
        echo "✅ Success (HTTP $http_code)"
        if [ ${#body} -lt 200 ]; then
            echo "   Response: $body"
        else
            echo "   Response: $(echo "$body" | head -c 100)..."
        fi
        return 0
    else
        echo "❌ Failed (expected HTTP $expected_code, got HTTP $http_code)"
        echo "   Response: $body"
        return 1
    fi
}

# Function to test metrics format
test_metrics_format() {
    local path=$1
    local description="$2"
    
    echo "Testing $path metrics format ($description)..."
    
    local response
    response=$(curl -s "$BASE_URL$path" 2>/dev/null)
    
    if echo "$response" | grep -q "# HELP"; then
        local help_count=$(echo "$response" | grep -c "# HELP" || echo "0")
        local type_count=$(echo "$response" | grep -c "# TYPE" || echo "0")
        echo "✅ Valid Prometheus format: $help_count HELP lines, $type_count TYPE lines"
        
        # Check for specific metrics
        if echo "$response" | grep -q "passenger_"; then
            local passenger_metrics=$(echo "$response" | grep "passenger_" | grep -v "^#" | wc -l)
            echo "   Found $passenger_metrics passenger metrics"
        fi
        
        return 0
    else
        echo "❌ Invalid Prometheus format"
        echo "   First 200 chars: $(echo "$response" | head -c 200)"
        return 1
    fi
}

# Wait for the service to be ready
wait_for_service "$BASE_URL" $TIMEOUT

echo
echo "=== Basic Health Checks ==="

# Test health endpoint
test_endpoint "/health" 200 "Health check"

echo
echo "=== Monitus Metrics Endpoints ==="

# Test standard metrics endpoint
test_endpoint "/monitus/metrics" 200 "Standard metrics"

# Test extended metrics endpoint
test_endpoint "/monitus/passenger-status-prometheus" 200 "Extended metrics with filtering"

# Test native implementation
test_endpoint "/monitus/passenger-status-native_prometheus" 200 "Native Prometheus implementation"

echo
echo "=== Metrics Format Validation ==="

# Validate metrics format
test_metrics_format "/monitus/metrics" "Standard metrics"
test_metrics_format "/monitus/passenger-status-prometheus" "Extended metrics"
test_metrics_format "/monitus/passenger-status-native_prometheus" "Native implementation"

echo
echo "=== JRuby + Passenger Specific Tests ==="

# Test passenger-status endpoint
test_endpoint "/monitus/passenger-status" 200 "Passenger status"

# Test with query parameters (filtering)
test_endpoint "/monitus/passenger-status-prometheus?debug=1" 200 "Debug mode"

echo
echo "=== Performance and Concurrency Test ==="

# Simple concurrent request test
echo "Running 10 concurrent requests..."
concurrent_test() {
    local success=0
    local failed=0
    
    for i in {1..10}; do
        (
            if curl -f -s --connect-timeout 5 --max-time 10 "$BASE_URL/monitus/metrics" > /dev/null; then
                echo "Request $i: success"
            else
                echo "Request $i: failed"
            fi
        ) &
    done
    
    wait
    echo "Concurrent test completed"
}

concurrent_test

echo
echo "=== Container Health Information ==="

# Get some container stats if available
echo "Testing container resource usage..."
if curl -s --connect-timeout 2 "$BASE_URL/monitus/metrics" | grep -q "process_"; then
    echo "✅ Process metrics available"
else
    echo "ℹ️ Process metrics not available (normal for this setup)"
fi

echo
echo "=== Test Summary ==="
echo "Fixed JRuby + Passenger + Nginx test completed at $(date)"
echo "All core endpoints tested successfully! 🎉"
echo
echo "Key endpoints:"
echo "  • Health: $BASE_URL/health"
echo "  • Standard metrics: $BASE_URL/monitus/metrics"
echo "  • Extended metrics: $BASE_URL/monitus/passenger-status-prometheus"
echo "  • Native metrics: $BASE_URL/monitus/passenger-status-native_prometheus"
echo
