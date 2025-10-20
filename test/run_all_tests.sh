#!/bin/bash
set -e

# Enable debug output
set -x

echo "Starting test suite..."
echo "Working directory: $(pwd)"
echo "Available services:"
nslookup passenger_with_app || echo "passenger_with_app not found"
nslookup passenger_without_app || echo "passenger_without_app not found"
nslookup passenger_with_visible_prometheus || echo "passenger_with_visible_prometheus not found"

cd /src/test

echo "Installing test dependencies..."
# Install test dependencies
bundle config --global silence_root_warning 1
bundle install

echo "Running all tests..."
# Run all the tests with verbose output
bundle exec rake --verbose

echo "Tests completed successfully!"
