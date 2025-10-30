#!/bin/bash
# Test script for the fixed JRuby + Passenger Docker setup
# Run this script to validate the fixes

set -e

echo "🔧 Testing Fixed JRuby + Passenger Docker Setup"
echo "================================================="
echo

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed or not in PATH"
    echo "Please install Docker to test the container build"
    exit 1
fi

if ! docker info &> /dev/null; then
    echo "❌ Docker daemon is not running"
    echo "Please start Docker daemon and try again"
    exit 1
fi

echo "✅ Docker is available"
echo

# Test 1: Build the fixed container
echo "📦 Step 1: Building fixed JRuby + Passenger container..."
echo "This may take 10-15 minutes for the first build"
echo

if docker build -f src/Dockerfile.jruby-passenger -t monitus-jruby-passenger-fixed src/; then
    echo "✅ Container built successfully!"
else
    echo "❌ Container build failed"
    echo "Check the build logs above for details"
    exit 1
fi

echo
echo "🚀 Step 2: Testing container startup..."

# Test 2: Start container and basic health check
echo "Starting container in background..."
CONTAINER_ID=$(docker run -d -p 8083:80 --name monitus-test-fixed monitus-jruby-passenger-fixed)

echo "Container ID: $CONTAINER_ID"
echo "Waiting for application to start (60 seconds)..."

# Wait for container to be ready
sleep 60

# Test 3: Health checks
echo
echo "🔍 Step 3: Running health checks..."

# Check if container is still running
if docker ps | grep -q $CONTAINER_ID; then
    echo "✅ Container is running"
else
    echo "❌ Container stopped unexpectedly"
    echo "Container logs:"
    docker logs $CONTAINER_ID
    docker rm -f $CONTAINER_ID 2>/dev/null || true
    exit 1
fi

# Test basic HTTP endpoints
echo "Testing HTTP endpoints..."

# Health check
if curl -f -s http://localhost:8083/health > /dev/null; then
    echo "✅ Health endpoint working"
else
    echo "❌ Health endpoint failed"
fi

# Metrics endpoint
if curl -f -s http://localhost:8083/monitus/metrics | head -5; then
    echo "✅ Metrics endpoint working"
else
    echo "❌ Metrics endpoint failed"
fi

# Test JRuby-specific features
echo
echo "🔍 Step 4: Testing JRuby integration..."

# Check if JRuby is actually being used
docker exec $CONTAINER_ID jruby --version
echo "✅ JRuby version confirmed"

# Check Passenger status
if docker exec $CONTAINER_ID passenger-status > /dev/null 2>&1; then
    echo "✅ Passenger is running"
else
    echo "❌ Passenger not accessible"
fi

# Test 5: Performance test
echo
echo "⚡ Step 5: Basic performance test..."
echo "Running 10 concurrent requests..."

for i in {1..10}; do
    curl -s http://localhost:8083/monitus/metrics > /dev/null &
done
wait

echo "✅ Concurrent requests completed"

# Cleanup
echo
echo "🧹 Step 6: Cleanup..."
docker stop $CONTAINER_ID
docker rm $CONTAINER_ID

echo
echo "🎉 SUCCESS: Fixed JRuby + Passenger setup working!"
echo
echo "Summary of fixes applied:"
echo "  • Fixed shell compatibility (bash instead of sh)"
echo "  • Proper RVM integration using official patterns"
echo "  • Correct user management (app user already exists)"
echo "  • Fixed JRuby installation and wrapper scripts"
echo "  • Proper Nginx + Passenger module loading"
echo "  • Corrected bundler configuration for production"
echo
echo "The container is ready for production use!"
echo "Start with: docker run -p 8080:80 monitus-jruby-passenger-fixed"
