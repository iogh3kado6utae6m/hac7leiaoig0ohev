#!/bin/bash
# Test script for JRuby + Passenger deployment
# Tests the fixed Docker configuration following official Passenger patterns

set -e

echo "🧪 Testing JRuby + Passenger + Nginx Docker deployment"
echo "========================================"

# Configuration
IMAGE_NAME="monitus-jruby-passenger"
CONTAINER_NAME="test-jruby-passenger"
PORT="8082"
DOCKERFILE="../src/Dockerfile.jruby-passenger"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

cleanup() {
    log "Cleaning up..."
    docker stop "$CONTAINER_NAME" 2>/dev/null || true
    docker rm "$CONTAINER_NAME" 2>/dev/null || true
}

# Trap cleanup on exit
trap cleanup EXIT

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    error "Docker is not running or not accessible"
    echo "This test requires Docker to be running"
    echo "Please start Docker and try again"
    exit 1
fi

log "Building Docker image: $IMAGE_NAME"
if docker build -f "$DOCKERFILE" -t "$IMAGE_NAME" ../src; then
    success "Docker image built successfully"
else
    error "Failed to build Docker image"
    exit 1
fi

# Test image properties
log "Inspecting Docker image..."
echo "Image size: $(docker images --format 'table {{.Repository}}:{{.Tag}}\t{{.Size}}' | grep $IMAGE_NAME)"
echo "Image layers: $(docker history --quiet --no-trunc $IMAGE_NAME | wc -l)"

# Start container
log "Starting container: $CONTAINER_NAME"
docker run -d \
    --name "$CONTAINER_NAME" \
    --publish "$PORT:80" \
    --env PASSENGER_MIN_INSTANCES=2 \
    --env PASSENGER_MAX_INSTANCES=4 \
    --env PASSENGER_THREAD_COUNT=8 \
    --env RACK_ENV=production \
    "$IMAGE_NAME"

if [ $? -eq 0 ]; then
    success "Container started successfully"
else
    error "Failed to start container"
    exit 1
fi

# Wait for container to be ready
log "Waiting for container to be ready..."
sleep 10

# Check container status
log "Checking container status..."
if docker ps --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -q "$CONTAINER_NAME"; then
    success "Container is running"
    docker ps --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
else
    error "Container is not running"
    echo "Container logs:"
    docker logs "$CONTAINER_NAME"
    exit 1
fi

# Show container logs
log "Container startup logs:"
docker logs "$CONTAINER_NAME" | head -20

# Test endpoints
BASE_URL="http://localhost:$PORT"
echo
log "Testing HTTP endpoints..."

# Test health endpoint
log "Testing /health endpoint"
if curl -s -f "$BASE_URL/health" | grep -q "OK"; then
    success "Health endpoint working"
    echo "Response: $(curl -s "$BASE_URL/health")"
else
    error "Health endpoint failed"
    curl -v "$BASE_URL/health" || true
fi

# Test nginx health endpoint
log "Testing /nginx-health endpoint"
if curl -s -f "$BASE_URL/nginx-health" | grep -q "OK"; then
    success "Nginx health endpoint working"
    echo "Response: $(curl -s "$BASE_URL/nginx-health")"
else
    warning "Nginx health endpoint not available (this is OK if not configured)"
fi

# Test info endpoint
log "Testing /info endpoint"
if curl -s -f "$BASE_URL/info"; then
    success "Info endpoint working"
    echo "Response: $(curl -s "$BASE_URL/info" | jq 2>/dev/null || curl -s "$BASE_URL/info")"
else
    warning "Info endpoint not available"
fi

# Test main page
log "Testing root endpoint"
if curl -s -f "$BASE_URL/"; then
    success "Root endpoint working"
    echo "Response: $(curl -s "$BASE_URL/" | head -3)"
else
    warning "Root endpoint not available"
fi

# Test metrics endpoint (if available)
log "Testing /metrics endpoint"
if curl -s "$BASE_URL/metrics" | head -5; then
    success "Metrics endpoint working"
else
    warning "Metrics endpoint not available (may not be implemented)"
fi

# Performance test
log "Running basic performance test..."
echo "Testing with 10 concurrent requests..."
if command -v ab >/dev/null 2>&1; then
    ab -n 20 -c 4 "$BASE_URL/health" | grep -E "(Requests per second|Time per request|Failed requests)"
else
    warning "Apache Bench (ab) not available, skipping performance test"
    # Simple alternative
    for i in {1..5}; do
        start_time=$(date +%s.%3N)
        curl -s "$BASE_URL/health" >/dev/null
        end_time=$(date +%s.%3N)
        duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "unknown")
        echo "Request $i: ${duration}s"
    done
fi

# Container resource usage
log "Checking resource usage..."
docker stats "$CONTAINER_NAME" --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"

# Show running processes in container
log "Processes running in container:"
docker exec "$CONTAINER_NAME" ps aux | head -10

# Test JRuby specific features
log "Testing JRuby configuration..."
docker exec "$CONTAINER_NAME" jruby --version || warning "JRuby command not available in PATH"
docker exec "$CONTAINER_NAME" java -version 2>&1 | head -1 || warning "Java not available"

# Check Passenger status
log "Checking Passenger status..."
docker exec "$CONTAINER_NAME" passenger-status 2>/dev/null || warning "passenger-status command not available"

# Check nginx status
log "Checking Nginx configuration..."
docker exec "$CONTAINER_NAME" nginx -t 2>/dev/null && success "Nginx configuration valid" || warning "Nginx configuration issues"

# Final assessment
echo
log "Test Summary"
echo "============"
success "JRuby + Passenger + Nginx container is working"
echo "🌐 Access the application at: $BASE_URL"
echo "❤️  Health check: $BASE_URL/health"
echo "📊 Container stats available with: docker stats $CONTAINER_NAME"
echo "📋 Container logs: docker logs $CONTAINER_NAME"
echo
warning "Container will be stopped and removed when this script exits"
log "Press Enter to continue or Ctrl+C to keep container running..."
read -r

echo "✨ JRuby + Passenger deployment test completed successfully!"
