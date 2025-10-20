.PHONY: clean test build run check-docker syntax-check unit-test integration-test
.PHONY: passenger_with_app passenger_without_app passenger_with_visible_prometheus

all: check-docker clean build integration-test

check-docker:
	@echo "Checking Docker availability..."
	@docker --version || (echo "ERROR: Docker is not available" && exit 1)
	@docker compose version || docker-compose --version || (echo "ERROR: Docker Compose is not available" && exit 1)

syntax-check:
	@echo "Running syntax checks..."
	@cd ../src && ruby -c prometheus_exporter.rb
	@find tests -name "*.rb" -exec ruby -c {} \;
	@cd ../src/passenger-status-node && node -c index.js
	@echo "Syntax checks passed!"

unit-test:
	@echo "Running unit tests..."
	@cd ../src && bundle exec ruby -e "\
		require_relative 'prometheus_exporter'; \
		app = PrometheusExporterApp.new; \
		puts 'Application loads successfully'; \
		puts 'SELF_GROUP_NAME: ' + PrometheusExporterApp::SELF_GROUP_NAME.inspect; \
		puts 'COMMON_LABELS: ' + PrometheusExporterApp::COMMON_LABELS.inspect; \
		puts 'Unit tests passed!';\
	"

build: passenger_with_app passenger_without_app passenger_with_visible_prometheus

passenger_with_app passenger_without_app passenger_with_visible_prometheus:
	@echo "Building Docker image: $@"
	docker compose build $@
	@echo "Successfully built: $@"

integration-test: build
	@echo "Running integration tests..."
	docker compose run --rm test
	@echo "Integration tests completed!"

integration-test-ci: build
	@echo "Running CI integration tests..."
	docker compose -f docker-compose.ci.yaml up -d passenger_with_app passenger_without_app passenger_with_visible_prometheus
	sleep 10
	docker compose -f docker-compose.ci.yaml run --rm test
	docker compose -f docker-compose.ci.yaml down
	@echo "CI integration tests completed!"

test: syntax-check unit-test integration-test

clean:
	@echo "Cleaning up Docker resources..."
	docker compose down --volumes --remove-orphans || true
	docker system prune -f || true
	@echo "Cleanup completed!"

run:
	@echo "Starting all services..."
	docker compose up passenger_with_app passenger_without_app passenger_with_visible_prometheus

# Development helpers
shell-test:
	docker compose run --rm test /bin/bash

logs:
	docker compose logs -f

status:
	docker compose ps
