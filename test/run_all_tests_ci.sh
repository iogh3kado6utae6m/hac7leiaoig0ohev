#!/bin/bash
set -e

echo "Starting CI test suite..."
echo "Working directory: $(pwd)"

# Wait for services to become available
echo "Waiting for services to start..."
for service in passenger_with_app passenger_without_app passenger_with_visible_prometheus; do
    echo "Checking $service..."
    for i in {1..30}; do
        if curl -f "http://$service:80/monitus/metrics" >/dev/null 2>&1; then
            echo "$service is ready"
            break
        fi
        echo "Waiting for $service... ($i/30)"
        sleep 2
    done
done

cd /src/test

echo "Installing test dependencies..."
# Install curl if not available
which curl || (apt-get update && apt-get install -y curl)

# Install test dependencies
bundle config --global silence_root_warning 1
bundle install

echo "Running all tests..."
# Run all the tests with verbose output
bundle exec rake --verbose

echo "Tests completed successfully!"
