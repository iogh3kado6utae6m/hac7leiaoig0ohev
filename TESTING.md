# Testing Documentation

This document provides comprehensive information about the testing system in Monitus.

## Overview

Monitus uses a **multi-layered testing approach** designed for both speed and reliability:

- **Syntax validation** - Code syntax and configuration checks
- **Unit tests** - Core functionality without external dependencies
- **Integration tests** - Full Docker-based end-to-end testing
- **CI/CD validation** - Automated testing with fallback strategies

## Test Architecture

### Docker Test Environment

The testing system uses Docker Compose with three distinct scenarios:

```
├── passenger_with_app          # With dummy application
├── passenger_without_app       # Monitor only
├── passenger_with_visible_prometheus # Visible Prometheus metrics
└── test                        # Test runner container
```

### Test Scenarios

#### MRI Ruby Scenarios
| Scenario | Purpose | Configuration |
|----------|---------|---------------|
| **passenger_with_app** | Tests with a running Rails/Sinatra app | Uses dummy-app + monitor |
| **passenger_without_app** | Tests monitor-only deployment | Monitor application only |
| **passenger_with_visible_prometheus** | Tests with metrics visible | Monitor + visible prometheus metrics |

#### JRuby Scenarios  
| Scenario | Purpose | Configuration |
|----------|---------|---------------|
| **passenger_jruby_with_app** | JRuby with running application | JRuby + Passenger + dummy-app |
| **passenger_jruby_without_app** | JRuby monitor-only | JRuby + Passenger + monitor only |
| **monitus_jruby_standalone** | Standalone JRuby application | JRuby + Puma + Sinatra (no Passenger) |
| **passenger_with_visible_prometheus** | Tests when exporter metrics are visible | Modified nginx config |

## Running Tests

### Quick Commands

```bash
# Full test suite (recommended for development)
make test

# Fast validation only (no Docker required)
make syntax-check && make unit-test

# Docker integration tests only
make integration-test

# CI-style testing with relaxed timeouts
make integration-test-ci

# JRuby-specific testing
make jruby-test         # Full JRuby integration testing
make jruby-build        # Build JRuby Docker images only
make jruby-clean        # Clean JRuby resources

# Combined testing (MRI + JRuby)
make test-all           # Test both Ruby implementations
```

### Individual Components

```bash
# Build Docker images
make build

# Run specific scenario
make passenger_with_app
docker compose run --rm test

# Debug access
make shell-test

# View logs
make logs

# Check service status
make status
```

## Test Types

### 1. Syntax Validation

**Files checked:**
- `src/prometheus_exporter.rb` - Main application
- `tests/*.rb` - All test files

**Command:** `make syntax-check`

**Purpose:** Validates Ruby syntax without executing code.

### 2. Unit Tests

**Location:** `test/tests/passenger_native_prometheus_unit_test.rb`

**Features:**
- No external dependencies
- Tests core logic and data structures
- Validates Prometheus metric naming conventions
- Fast execution (< 10 seconds)

**Example:**
```ruby
it "should validate metric name patterns" do
  expected_metrics = [
    "passenger_process_count",
    "passenger_capacity_used",
    # ...
  ]
  expected_metrics.each do |metric|
    assert_match(/^passenger_[a-z_]+$/, metric)
  end
end
```

### 3. Integration Tests

**Test Files:**
- `passenger_with_app_test.rb` - Tests with dummy application
- `passenger_without_app_test.rb` - Tests monitor-only setup
- `passenger_visible_prometheus_test.rb` - Tests visible metrics
- `passenger_native_prometheus_test.rb` - Tests native endpoint

**Features:**
- Full HTTP endpoint testing
- Real Passenger metrics validation
- Label and value verification
- Cross-service communication

## Test Infrastructure

### Docker Configuration

**Base Image:** `phusion/passenger-ruby32:2.5.1`

**Health Checks:**
```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:80/monitus/metrics"]
  interval: 30s
  timeout: 15s
  retries: 5
  start_period: 45s
```

**Dependencies:**
```yaml
test:
  depends_on:
    passenger_with_app:
      condition: service_healthy
    # ... other services
```

### Test Runner

**Script:** `test/run_all_tests.sh`

**Process:**
1. Verify service availability via `nslookup`
2. Install test dependencies with `bundle install`
3. Execute `bundle exec rake --verbose`
4. Run all `tests/*_test.rb` files via Minitest

### Rake Configuration

**File:** `test/Rakefile`

```ruby
Rake::TestTask.new do |t|
  t.libs << "tests"
  t.test_files = FileList['tests/*_test.rb']
  t.verbose = true
  t.ruby_opts = %w(-W1)
end
```

## Test Data and Fixtures

### Dummy Application

**Location:** `test/dummy-app/`

**Purpose:**
- Generates realistic Passenger metrics
- Creates process load for testing
- Simulates production environment

**Structure:**
```
dummy-app/
├── Gemfile         # Dependencies
├── config.ru       # Rack configuration
└── dummy.rb        # Simple Sinatra app
```

### Nginx Configurations

**Standard:** `test/nginx-configurations/nginx.conf.erb`
- Hides Prometheus exporter from metrics (default behavior)

**Visible:** `test/nginx-configurations/nginx.conf-visible-prometheus.erb`
- Shows all metrics including the exporter itself

## Expected Test Output

### Successful Test Run

```bash
$ make test
Checking Docker availability...
Running syntax checks...
Syntax checks passed!
Running unit tests...
Unit tests passed!
Building Docker images...
Running integration tests...

# PASS: passenger_with_app_test.rb
# PASS: passenger_without_app_test.rb
# PASS: passenger_visible_prometheus_test.rb
# PASS: passenger_native_prometheus_test.rb

Integration tests completed!
```

### Typical Metrics in Tests

```prometheus
# HELP passenger_capacity Capacity used
# TYPE passenger_capacity gauge
passenger_capacity{supergroup_name="/app (development)",group_name="/app (development)",hostname="passenger_with_app"} 1

# HELP passenger_process_count Total number of processes in instance
# TYPE passenger_process_count gauge
passenger_process_count{instance="passenger_with_app"} 1

# HELP passenger_process_cpu CPU usage by process
# TYPE passenger_process_cpu gauge
passenger_process_cpu{instance="passenger_with_app",supergroup="/app (development)",pid="123"} 0.0
```

## CI/CD Integration

### Three-Tier Strategy

**GitHub Actions Workflows:**

1. **Primary** (`test`)
   - Modern dependencies
   - Fast execution (< 2 minutes)
   - Comprehensive validation

2. **Backup** (`test-without-docker`)
   - Reliable fallback
   - No Docker dependencies
   - Always runs regardless of primary result

3. **Integration** (`docker-integration`)
   - **Scheduled**: Every Sunday at 6:00 UTC (`cron: '0 6 * * 0'`)
   - **Manual**: Available via GitHub Actions "Run workflow" button
   - Full end-to-end validation
   - Extended timeout (30 minutes)

### Workflow Benefits

| Scenario | Primary | Backup | Result |
|----------|---------|--------|---------|
| Both pass | ✅ | ✅ | High confidence |
| Primary fails, backup passes | ❌ | ✅ | Likely infrastructure issue |
| Both fail | ❌ | ❌ | Code issue needs attention |

### Docker Integration Schedule

The `docker-integration` workflow may show "This workflow has no runs yet" for these reasons:

- **Weekly schedule**: Runs only on Sundays at 6:00 UTC
- **Recent addition**: Workflow was added October 20, 2025
- **Manual trigger available**: Go to GitHub Actions → docker-integration → "Run workflow"
- **Local testing**: Always available via `make test` in the `test/` directory

## Troubleshooting

### Common Issues

**"dependency failed to start: container is unhealthy"**
- Use CI configuration: `make integration-test-ci`
- Check service logs: `make logs`
- Verify port availability: `netstat -tlnp | grep :10254`

**"Connection refused"**
- Services not ready - wait longer
- Check correct ports in health checks
- Verify service configuration

**"curl: command not found"**
- Health check requires curl
- Fixed in updated Dockerfiles

### Debug Commands

```bash
# Get shell access to test environment
make shell-test

# View all service logs
make logs

# Check service status
make status

# Manual service testing
docker compose up -d
sleep 30
curl -f http://localhost:PORT/monitus/metrics

# Clean rebuild
make clean && make build
```

### Performance Optimization

**For faster CI builds:**
- Docker layer caching
- Gem and package caching
- Parallel test execution

**For reduced resource usage:**
```bash
# Run specific scenarios only
make passenger_with_app
docker compose run --rm test
```

## Development Workflow

### Adding New Tests

1. **Unit Tests:**
   ```ruby
   # Add to passenger_native_prometheus_unit_test.rb
   it "should handle new feature" do
     # Test logic without external dependencies
   end
   ```

2. **Integration Tests:**
   ```ruby
   # Create new *_test.rb file in tests/
   require_relative "test_helper"
   
   describe "new feature" do
     before do
       wait_to_be_ready("http://service:10254/")
     end
     
     it "should work correctly" do
       response = Net::HTTP.get(URI("http://service:10254/endpoint"))
       assert_includes(response, "expected_content")
     end
   end
   ```

### Test-Driven Development

```bash
# 1. Write failing test
make unit-test  # Should fail

# 2. Implement feature
# Edit src/prometheus_exporter.rb

# 3. Verify unit tests pass
make unit-test  # Should pass

# 4. Run full integration
make test       # Should pass
```

### Continuous Testing

```bash
# Watch for changes and re-run tests
while inotifywait -e modify src/ test/; do
  make syntax-check unit-test
done
```

## Best Practices

### Test Design

- **Unit tests** should be fast and isolated
- **Integration tests** should verify real HTTP endpoints
- Use **descriptive test names** that explain the scenario
- **Mock external dependencies** in unit tests only
- **Test both success and error cases**

### Test Data

- Use **realistic passenger-status output**
- Test with **multiple process scenarios**
- Verify **label correctness** in Prometheus format
- Check **metric value accuracy**

### Performance

- Keep **unit tests under 10 seconds total**
- Use **health checks** to ensure service readiness
- **Parallel test execution** where possible
- **Cache Docker layers** for faster builds

## Future Improvements

Potential enhancements:
- Matrix testing with different Ruby versions
- Performance benchmarking integration
- Security scanning in CI pipeline
- Code coverage reporting
- Automated dependency updates
- Load testing scenarios

---

*For additional troubleshooting information, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md)*
*For CI/CD improvements history, see [TESTING_IMPROVEMENTS.md](TESTING_IMPROVEMENTS.md)*
