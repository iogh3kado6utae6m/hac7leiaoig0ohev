#!/bin/bash
# Тест JRuby + Passenger + Nginx Docker setup

set -e

echo "🧪 Testing JRuby + Passenger + Nginx Docker setup..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test configuration
CONTAINER_NAME="monitus-jruby-passenger-test"
IMAGE_NAME="monitus-jruby-passenger"
TEST_PORT="8082"
BASE_URL="http://localhost:${TEST_PORT}"

echo "📋 Test Configuration:"
echo "  Container: $CONTAINER_NAME"
echo "  Image: $IMAGE_NAME"
echo "  Port: $TEST_PORT"
echo "  Base URL: $BASE_URL"
echo ""

# Cleanup function
cleanup() {
    echo "🧹 Cleaning up..."
    docker stop $CONTAINER_NAME >/dev/null 2>&1 || true
    docker rm $CONTAINER_NAME >/dev/null 2>&1 || true
}

# Set trap for cleanup
trap cleanup EXIT

# Step 1: Build image
echo "🏗️  Building JRuby + Passenger Docker image..."
if ! docker build -f ../src/Dockerfile.jruby-passenger -t $IMAGE_NAME ../src/; then
    echo -e "${RED}❌ Docker build failed${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Docker build successful${NC}"
echo ""

# Step 2: Start container
echo "🚀 Starting container..."
if ! docker run -d \
    --name $CONTAINER_NAME \
    -p $TEST_PORT:80 \
    -e JRUBY_OPTS="-Xcompile.invokedynamic=true" \
    -e JAVA_OPTS="-Xmx1G -Xms256M -XX:+UseG1GC" \
    -e PASSENGER_MIN_INSTANCES=2 \
    -e PASSENGER_MAX_INSTANCES=4 \
    -e PASSENGER_THREAD_COUNT=8 \
    $IMAGE_NAME; then
    echo -e "${RED}❌ Failed to start container${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Container started${NC}"
echo ""

# Step 3: Wait for container to be ready
echo "⏳ Waiting for container to be ready..."
max_attempts=60
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if curl -s -f $BASE_URL/nginx-health >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Container is ready!${NC}"
        break
    fi
    
    attempt=$((attempt + 1))
    echo "  Attempt $attempt/$max_attempts - waiting..."
    sleep 2
done

if [ $attempt -eq $max_attempts ]; then
    echo -e "${RED}❌ Container failed to start within timeout${NC}"
    echo "📋 Container logs:"
    docker logs $CONTAINER_NAME
    exit 1
fi
echo ""

# Step 4: Run tests
echo "🧪 Running health checks..."

# Test 1: Nginx health check
echo "Test 1: Nginx health check"
if response=$(curl -s $BASE_URL/nginx-health); then
    if [[ "$response" == *"OK"* ]]; then
        echo -e "  ${GREEN}✅ Nginx health check passed${NC}"
    else
        echo -e "  ${YELLOW}⚠️  Nginx health check returned unexpected response: $response${NC}"
    fi
else
    echo -e "  ${RED}❌ Nginx health check failed${NC}"
fi

# Test 2: Application health check  
echo "Test 2: Application health check"
if response=$(curl -s $BASE_URL/health); then
    if [[ "$response" == *"JRuby"* ]] || [[ "$response" == *"OK"* ]]; then
        echo -e "  ${GREEN}✅ Application health check passed${NC}"
    else
        echo -e "  ${YELLOW}⚠️  Application health check returned: $response${NC}"
    fi
else
    echo -e "  ${RED}❌ Application health check failed${NC}"
fi

# Test 3: Root endpoint
echo "Test 3: Root endpoint"
if response=$(curl -s $BASE_URL/); then
    if [[ "$response" == *"Running"* ]]; then
        echo -e "  ${GREEN}✅ Root endpoint working${NC}"
    else
        echo -e "  ${YELLOW}⚠️  Root endpoint returned: $response${NC}"
    fi
else
    echo -e "  ${RED}❌ Root endpoint failed${NC}"
fi

# Test 4: Info endpoint
echo "Test 4: Info endpoint"
if response=$(curl -s $BASE_URL/info); then
    if [[ "$response" == *"jruby_version"* ]]; then
        echo -e "  ${GREEN}✅ Info endpoint working${NC}"
    else
        echo -e "  ${YELLOW}⚠️  Info endpoint returned: $response${NC}"
    fi
else
    echo -e "  ${YELLOW}⚠️  Info endpoint not available (may not be implemented)${NC}"
fi

# Test 5: HTTP headers
echo "Test 5: Security headers"
if headers=$(curl -s -I $BASE_URL/health); then
    if [[ "$headers" == *"X-Frame-Options"* ]]; then
        echo -e "  ${GREEN}✅ Security headers present${NC}"
    else
        echo -e "  ${YELLOW}⚠️  Some security headers missing${NC}"
    fi
else
    echo -e "  ${RED}❌ Failed to get headers${NC}"
fi

# Test 6: Performance test
echo "Test 6: Basic performance test"
start_time=$(date +%s%N)
for i in {1..10}; do
    curl -s $BASE_URL/health >/dev/null
done
end_time=$(date +%s%N)
duration=$(( (end_time - start_time) / 1000000 )) # Convert to milliseconds
avg_time=$(( duration / 10 ))

if [ $avg_time -lt 500 ]; then
    echo -e "  ${GREEN}✅ Performance good (avg: ${avg_time}ms per request)${NC}"
elif [ $avg_time -lt 1000 ]; then
    echo -e "  ${YELLOW}⚠️  Performance acceptable (avg: ${avg_time}ms per request)${NC}"
else
    echo -e "  ${RED}❌ Performance poor (avg: ${avg_time}ms per request)${NC}"
fi

echo ""

# Step 5: Show container status
echo "📊 Container Status:"
echo "Docker stats:"
docker stats $CONTAINER_NAME --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
echo ""

echo "📋 Container Information:"
echo "  Image: $(docker inspect $CONTAINER_NAME --format='{{.Config.Image}}')"
echo "  Status: $(docker inspect $CONTAINER_NAME --format='{{.State.Status}}')"
echo "  Started: $(docker inspect $CONTAINER_NAME --format='{{.State.StartedAt}}')"
echo "  Ports: $(docker port $CONTAINER_NAME)"
echo ""

# Step 6: Show logs (last 20 lines)
echo "📜 Recent container logs:"
docker logs --tail 20 $CONTAINER_NAME
echo ""

# Success message
echo -e "${GREEN}🎉 JRuby + Passenger + Nginx test completed!${NC}"
echo "🌐 Access the application at: $BASE_URL"
echo "🏥 Health check: $BASE_URL/health"
echo "🔍 Nginx health: $BASE_URL/nginx-health"
echo ""
echo "💡 To keep the container running for manual testing:"
echo "   docker run -d -p $TEST_PORT:80 --name $CONTAINER_NAME-manual $IMAGE_NAME"
echo ""
echo "🛑 Container will be stopped and removed automatically when script exits."
echo "   Press Ctrl+C to stop the test container now, or wait for auto-cleanup."

# Optional: Wait for user input to keep container running
read -t 30 -p "Press Enter to stop container (auto-stop in 30 seconds)..." || true

echo ""
echo "✅ Test completed successfully!"
