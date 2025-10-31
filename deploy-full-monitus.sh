#!/bin/bash
# Deploy full Monitus application with all passenger-status endpoints

set -euo pipefail

DOCKER_VARIANT="${1:-minimal}"
PORT="${2:-8080}"
CONTAINER_NAME="${3:-monitus}"

# Use variant-specific container names to avoid conflicts
if [[ "$DOCKER_VARIANT" == "diagnostic" ]]; then
    CONTAINER_NAME="${3:-monitus-diagnostic}"
fi

echo "🚀 Deploying full Monitus application..."
echo "   Variant: $DOCKER_VARIANT"
echo "   Port: $PORT"
echo "   Container: $CONTAINER_NAME"

# Stop and remove existing container if it exists
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "📦 Stopping existing container..."
    docker stop $CONTAINER_NAME || true
    docker rm $CONTAINER_NAME || true
fi

# Build the image
echo "🔨 Building Docker image..."
cd src
docker build -f Dockerfile.jruby-${DOCKER_VARIANT} -t monitus-jruby-${DOCKER_VARIANT} .

# Run the container
echo "🏃 Starting container..."
docker run -d \
    --name $CONTAINER_NAME \
    --restart unless-stopped \
    -p $PORT:80 \
    monitus-jruby-${DOCKER_VARIANT}

# Wait for container to be ready
echo "⏳ Waiting for container to be ready..."
sleep 5

# Health check
echo "🏥 Running health checks..."
for i in {1..10}; do
    if curl -f -s "http://localhost:$PORT/health" > /dev/null; then
        echo "✅ Health check passed!"
        break
    fi
    echo "   Attempt $i/10 failed, retrying in 3 seconds..."
    sleep 3
done

# Test endpoints
echo "\n🔍 Testing endpoints:"
echo "Health: http://localhost:$PORT/health"
HEALTH_RESPONSE=$(curl -s "http://localhost:$PORT/health" 2>/dev/null || echo "CONNECTION_FAILED")
if [[ "$HEALTH_RESPONSE" == "healthy" ]]; then
    echo "✅ Health endpoint working!"
else
    echo "❌ Health endpoint failed!"
    echo "   Response: ${HEALTH_RESPONSE:0:200}..."
    echo "\n🔧 Troubleshooting steps:"
    echo "   1. Check container logs: docker logs $CONTAINER_NAME"
    echo "   2. Debug deployment: ./debug-deployment.sh $CONTAINER_NAME"
    echo "   3. Try debug variant: ./deploy-full-monitus.sh minimal-debug $PORT"
    exit 1
fi

echo "\nMetrics: http://localhost:$PORT/monitus/metrics"
METRICS_RESPONSE=$(curl -s "http://localhost:$PORT/monitus/metrics" 2>/dev/null | head -5 || echo "FAILED")
if [[ "$METRICS_RESPONSE" =~ "# HELP".*"# TYPE" ]]; then
    echo "✅ Metrics endpoint working!"
else
    echo "❌ Metrics endpoint failed (but container is healthy)"
fi

echo "\nPassenger Status: http://localhost:$PORT/monitus/passenger-status"
PASSENGER_RESPONSE=$(curl -s "http://localhost:$PORT/monitus/passenger-status" 2>/dev/null | head -5 || echo "FAILED")
if [[ "$PASSENGER_RESPONSE" =~ "Version".*"General information" ]]; then
    echo "✅ Passenger status endpoint working!"
else
    echo "❌ Passenger status endpoint failed (but container is healthy)"
fi

echo "\n🎉 Deployment complete!"
echo "\n📋 Available endpoints:"
echo "   Health:           http://localhost:$PORT/health"
echo "   Metrics:          http://localhost:$PORT/monitus/metrics"
echo "   Passenger Status: http://localhost:$PORT/monitus/passenger-status"
echo "   System Metrics:   http://localhost:$PORT/monitus/passenger-config_system-metrics"
echo "   Pool JSON:        http://localhost:$PORT/monitus/passenger-config_pool-json"
echo "\n📊 Container status:"
docker ps --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
