SHELL := /usr/bin/bash

.PHONY: clean test build run check-docker syntax-check unit-test integration-test
.PHONY: passenger_with_app passenger_without_app passenger_with_visible_prometheus
.PHONY: jruby-build jruby-test jruby-clean jruby-all
.PHONY: passenger_jruby_with_app passenger_jruby_without_app monitus_jruby_standalone

all: check-docker clean build integration-test

jruby-all: check-docker jruby-clean jruby-build jruby-test

check-docker:
	@echo "Checking Docker availability..."
	@docker --version || (echo "ERROR: Docker is not available" && exit 1)
	@docker compose version || docker-compose --version || (echo "ERROR: Docker Compose is not available" && exit 1)

syntax-check:
	@echo "Running syntax checks..."
	@cd ../src && ruby -c prometheus_exporter.rb
	@find tests -name "*.rb" -exec ruby -c {} \;
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

# JRuby-specific targets
jruby-build: passenger_jruby_with_app passenger_jruby_without_app monitus_jruby_standalone

passenger_jruby_with_app passenger_jruby_without_app:
	@echo "Building JRuby Docker image: $@"
	docker compose -f docker-compose-jruby.yaml build $@
	@echo "Successfully built JRuby image: $@"

monitus_jruby_standalone:
	@echo "Building standalone JRuby Docker image: $@"
	docker compose -f docker-compose-jruby.yaml build $@
	@echo "Successfully built standalone JRuby image: $@"

jruby-test: jruby-build
	@echo "Running JRuby integration tests..."
	docker compose -f docker-compose-jruby.yaml run --rm test_jruby
	@echo "JRuby integration tests completed!"

jruby-test-ci: jruby-build
	@echo "Running JRuby CI tests..."
	docker compose -f docker-compose-jruby.ci.yaml up -d passenger_jruby_with_app passenger_jruby_without_app monitus_jruby_standalone
	sleep 15
	docker compose -f docker-compose-jruby.ci.yaml run --rm test_jruby
	docker compose -f docker-compose-jruby.ci.yaml down
	@echo "JRuby CI tests completed!"

jruby-clean:
	@echo "Cleaning up JRuby Docker resources..."
	docker compose -f docker-compose-jruby.yaml down --volumes --remove-orphans || true
	docker compose -f docker-compose-jruby.ci.yaml down --volumes --remove-orphans || true
	@echo "JRuby cleanup completed!"

clean:
	@echo "Cleaning up Docker resources..."
	docker compose down --volumes --remove-orphans || true
	docker compose -f docker-compose-jruby.yaml down --volumes --remove-orphans || true
	docker compose -f docker-compose-jruby.ci.yaml down --volumes --remove-orphans || true
	docker system prune -f || true
	@echo "Cleanup completed!"

run:
	@echo "Starting all services..."
	docker compose up passenger_with_app passenger_without_app passenger_with_visible_prometheus

jruby-run:
	@echo "Starting JRuby services..."
	docker compose -f docker-compose-jruby.yaml up passenger_jruby_with_app passenger_jruby_without_app monitus_jruby_standalone

# Development helpers
shell-test:
	docker compose run --rm test /bin/bash

shell-jruby-test:
	docker compose -f docker-compose-jruby.yaml run --rm test_jruby /bin/bash

logs:
	docker compose logs -f

jruby-logs:
	docker compose -f docker-compose-jruby.yaml logs -f

status:
	docker compose ps

jruby-status:
	docker compose -f docker-compose-jruby.yaml ps

# Combined targets for testing both MRI and JRuby
test-all: test jruby-test

run-all:
	@echo "Starting both MRI and JRuby services..."
	docker compose up -d passenger_with_app passenger_without_app passenger_with_visible_prometheus
	docker compose -f docker-compose-jruby.yaml up passenger_jruby_with_app passenger_jruby_without_app monitus_jruby_standalone
