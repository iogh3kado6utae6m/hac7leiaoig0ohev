#!/bin/bash
# Test all Monitus endpoints to verify full application is working

set -euo pipefail

BASE_URL="${1:-http://localhost:8080}"
echo "🧪 Testing all Monitus endpoints on $BASE_URL"
echo "======================================================"

# Function to test an endpoint
test_endpoint() {
    local path="$1"
    local description="$2"
    local expected_content="${3:-}"
    
    echo -n "🔍 $description... "
    
    if response=$(curl -s -w "\n%{http_code}" "$BASE_URL$path" 2>/dev/null); then
        http_code=$(echo "$response" | tail -n1)
        body=$(echo "$response" | head -n -1)
        
        if [[ "$http_code" == "200" ]]; then
            if [[ -n "$expected_content" ]] && [[ ! "$body" =~ $expected_content ]]; then
                echo "❌ (200 but unexpected content)"
                echo "   Expected: $expected_content"
                echo "   Got: $(echo "$body" | head -c 100)..."
            else
                echo "✅ (200 OK)"
                if [[ ${#body} -lt 200 ]]; then
                    echo "   Response: $body"
                else
                    echo "   Response: $(echo "$body" | head -c 100)..."
                fi
            fi
        else
            echo "❌ (HTTP $http_code)"
            echo "   Response: $body"
        fi
    else
        echo "❌ (Connection failed)"
    fi
    echo
}

# Test basic endpoints
echo "🏥 === BASIC ENDPOINTS ==="
test_endpoint "/health" "Health check" "healthy"
test_endpoint "/" "Root page"

# Test core Monitus endpoints  
echo "📋 === CORE MONITUS ENDPOINTS ==="
test_endpoint "/monitus/metrics" "Prometheus metrics" "# HELP\|# TYPE"

# Test passenger-status endpoints
echo "🏁 === PASSENGER STATUS ENDPOINTS ==="
test_endpoint "/monitus/passenger-status" "Raw passenger-status" "Version\|General information"
test_endpoint "/monitus/passenger-status-prometheus" "Passenger Prometheus metrics"
test_endpoint "/monitus/passenger-status-native_prometheus" "Native Passenger Prometheus"

# Test passenger-config endpoints
echo "⚙️ === PASSENGER CONFIG ENDPOINTS ==="
test_endpoint "/monitus/passenger-config_system-metrics" "System metrics"
test_endpoint "/monitus/passenger-config_system-properties" "System properties" "{"
test_endpoint "/monitus/passenger-config_pool-json" "Pool JSON" "{"
test_endpoint "/monitus/passenger-config_api-call_get_server" "Server JSON" "{"

# Test debug endpoints
echo "🔍 === DEBUG ENDPOINTS ==="
test_endpoint "/monitus/debug-passenger-status-json" "Debug passenger status JSON"

# Test passenger-status-node endpoints (if available)
echo "📊 === PASSENGER STATUS NODE ENDPOINTS ==="
test_endpoint "/monitus/passenger-status-node_json" "Passenger status node JSON"
test_endpoint "/monitus/passenger-status-node_prometheus" "Passenger status node Prometheus"

echo "======================================================"
echo "🏁 Testing complete!"
echo
echo "📋 Summary:"
echo "   ✅ Green checkmarks = Working endpoints"
echo "   ❌ Red X marks = Failed/missing endpoints"
echo
echo "💡 If you see many failures for passenger-status endpoints,"
echo "   you're likely running the test variant instead of the full app."
echo "   Run: ./deploy-full-monitus.sh minimal"
