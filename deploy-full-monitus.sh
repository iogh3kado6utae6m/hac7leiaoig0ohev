#!/bin/bash
# Deploy full Monitus application with all passenger-status endpoints

set -euo pipefail

DOCKER_VARIANT="${1:-minimal}"
CONTAINER_NAME="monitus"
PORT="${2:-8080}"

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
curl -s "http://localhost:$PORT/health" || echo "❌ Health endpoint failed"

echo "\nMetrics: http://localhost:$PORT/monitus/metrics"
curl -s "http://localhost:$PORT/monitus/metrics" | head -5 || echo "❌ Metrics endpoint failed"

echo "\nPassenger Status: http://localhost:$PORT/monitus/passenger-status"
curl -s "http://localhost:$PORT/monitus/passenger-status" | head -5 || echo "❌ Passenger status endpoint failed"

echo "\n🎉 Deployment complete!"
echo "\n📋 Available endpoints:"
echo "   Health:           http://localhost:$PORT/health"
echo "   Metrics:          http://localhost:$PORT/monitus/metrics"
echo "   Passenger Status: http://localhost:$PORT/monitus/passenger-status"
echo "   System Metrics:   http://localhost:$PORT/monitus/passenger-config_system-metrics"
echo "   Pool JSON:        http://localhost:$PORT/monitus/passenger-config_pool-json"
echo "\n📊 Container status:"
docker ps --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
