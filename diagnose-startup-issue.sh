#!/bin/bash
# Step-by-step diagnosis of JRuby + Passenger startup issues

set -euo pipefail

echo "🔍 JRuby + Passenger Startup Diagnosis"
echo "=========================================="

# Step 1: Deploy ultra-minimal diagnostic version
echo "📋 Step 1: Deploy minimal diagnostic container..."
echo "This version has:"
echo "   - No external gems (no bundle install)"
echo "   - Pure Rack app (no Sinatra)"
echo "   - Minimal routes"
echo "   - Detailed startup logging"
echo "   - Friendly error pages enabled"
echo

echo "Deploying diagnostic variant..."
./deploy-full-monitus.sh diagnostic 8090

echo
echo "🔍 Step 2: Test diagnostic endpoints..."
echo "Testing basic functionality..."

# Test each endpoint
echo -n "Health check... "
if curl -f -s "http://localhost:8090/health" | grep -q "healthy"; then
    echo "✅ OK"
else
    echo "❌ FAILED"
    echo "   This means basic Passenger + JRuby integration is broken"
fi

echo -n "JRuby test... "
if curl -f -s "http://localhost:8090/test" | grep -q "JRuby"; then
    echo "✅ OK"
else
    echo "❌ FAILED"
    echo "   This means JRuby is not working properly"
fi

echo -n "Environment test... "
if curl -f -s "http://localhost:8090/env" | grep -q "REQUEST"; then
    echo "✅ OK"
else
    echo "❌ FAILED"
    echo "   This means Rack environment is not being passed correctly"
fi

echo
echo "📊 Analysis:"
echo "If the diagnostic container works:"
echo "   - Basic JRuby + Passenger integration is OK"
echo "   - Issue is in the application code or dependencies"
echo "   - Focus on prometheus_exporter.rb or gem loading"
echo
echo "If the diagnostic container fails:"
echo "   - Fundamental JRuby + Passenger issue"
echo "   - Container environment problem"
echo "   - Need to check base image or system configuration"
echo
echo "🛠️ Next steps based on results:"
echo "   ✅ If diagnostic works: Issue is in application complexity"
echo "   ❌ If diagnostic fails: Issue is in base JRuby/Passenger setup"
echo
echo "Manual inspection commands:"
echo "   docker logs monitus-diagnostic"
echo "   docker exec -it monitus-diagnostic bash"
echo "   ./debug-deployment.sh monitus-diagnostic"
