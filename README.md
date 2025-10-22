# Monitus

Small application that runs on the Phusion Passenger webserver and exposes Passenger metrics in a
Prometheus format.

## Metrics

### Standard Passenger Metrics

Name                        | Description 
----------------------------|--------------------------------------------------
passenger_capacity          | Number of processes spawn
passenger_processes_active  | Number of processes currently working on requests
passenger_wait_list_size    | Requests in queue

### Extended Passenger Metrics (via `/monitus/passenger-status-native_prometheus`)

Name                             | Description 
---------------------------------|--------------------------------------------------
passenger_process_count          | Total number of processes in instance
passenger_capacity_used          | Capacity used by instance  
passenger_get_wait_list_size     | Size of get wait list in instance
passenger_supergroup_capacity_used | Capacity used by supergroup
passenger_supergroup_get_wait_list_size | Size of get wait list in supergroup
passenger_process_cpu            | CPU usage by individual process
passenger_process_memory         | Memory usage by individual process (RSS)
passenger_process_sessions       | Active sessions by individual process
passenger_process_processed      | Total requests processed by individual process

Example of output:
```
# HELP passenger_capacity Capacity used
# TYPE passenger_capacity gauge
passenger_capacity{supergroup_name="/app (development)",group_name="/app (development)",hostname="my-container"} 1
# HELP passenger_wait_list_size Requests in the queue
# TYPE passenger_wait_list_size gauge
passenger_wait_list_size{supergroup_name="/app (development)",group_name="/app (development)",hostname="my-container"} 0
# HELP passenger_processes_active Active processes
# TYPE passenger_processes_active gauge
passenger_processes_active{supergroup_name="/app (development)",group_name="/app (development)",hostname="my-container"} 0
```

## Requirements
* a Ruby interpreter in the path
* the Nokogiri gem (tested with 1.10.0)
* the Sinatra gem (tested with 2.0.5)


## Integration
Copy the content of `src` inside your container (or your server) and adapt the Nginx configuration
template to load the application:

Example with the application copied in `/monitor`:
```
# Modified nginx.conf.erb

    [...]
        ### END your own configuration options ###
    }

    <% end %>

    server {
        server_name _;
        listen 0.0.0.0:10254;
        root '/monitor/public';
        passenger_app_root '/monitor';
        passenger_app_group_name 'Prometheus exporter';
        passenger_spawn_method direct;
        passenger_enabled on;
        passenger_min_instances 1;
        passenger_load_shell_envvars off;
    }

    <%= include_passenger_internal_template('footer.erb', 4) %>
    [...]
```

This example will make the Passenger Metrics available on:

- `http://<ip-of-this-server>:10254/monitus/metrics` - Standard metrics
- `http://<ip-of-this-server>:10254/monitus/passenger-status-prometheus` - Extended metrics (native implementation, short name)
- `http://<ip-of-this-server>:10254/monitus/passenger-status-native_prometheus` - Extended metrics (native implementation)
- `http://<ip-of-this-server>:10254/monitus/passenger-status-node_prometheus` - Extended metrics (requires passenger-status-node)

### Filtering Extended Metrics

The `/monitus/passenger-status-prometheus` endpoint supports filtering to show metrics for specific components only. Only one filter parameter is allowed per request:

- `?instance=<name>` - Show metrics only for the specified Passenger instance
- `?supergroup=<name>` - Show metrics only for the specified application/supergroup across all instances
- `?pid=<process_id>` - Show metrics only for the specified process across all supergroups and instances

**Examples:**
```bash
# Get metrics for a specific instance
curl http://localhost:10254/monitus/passenger-status-prometheus?instance=default

# Get metrics for a specific application
curl http://localhost:10254/monitus/passenger-status-prometheus?supergroup=/app

# Get metrics for a specific process
curl http://localhost:10254/monitus/passenger-status-prometheus?pid=12345
```

**Note:** Multiple filter parameters in a single request will result in an error.

Note: If you want to have this application's metrics hidden from the metric endpoint, you have to name
its group `Prometheus exporter`.


## Development

This project uses Docker and Docker Compose for testing. `make test` will build a test container
with a dummy applicaton and the Prometheus Exporter and query the metric endpoint. If all goes
well, hack along and submit a pull request.

## Testing

### Testing Strategy

The project uses a **multi-layered testing approach** optimized for both speed and reliability:

#### 1. Fast CI Tests (Always Run)
- **Syntax validation** - Ruby code and configurations
- **Unit tests** - Core functionality without dependencies  
- **Configuration validation** - Docker Compose, Rack configs
- **Integration readiness** - Component loading verification
- **Note**: `passenger-status-node` requires local `npm install` (development-only)

#### 2. Docker Integration Tests (Local/Manual)
- **Full integration testing** with Docker Compose
- **End-to-end workflow** testing
- **Multi-scenario validation**

### Local Development Testing

```bash
# Quick validation (recommended for development)
make syntax-check && make unit-test

# Full integration tests (requires Docker)
make test

# CI-style integration tests
make integration-test-ci

# Individual components
make build              # Build Docker images
make logs              # View service logs
make clean             # Clean up resources
```

### CI/CD Workflows

**Three-Tier Strategy:**

1. **Primary** (`test`): Modern validation with latest dependencies
2. **Backup** (`test-without-docker`): Proven reliable validation  
3. **Integration** (`docker-integration`): Full end-to-end testing (weekly on Sundays, 6:00 UTC + manual)

**Benefits:**
- ✅ **Dual validation**: Two independent validation paths
- ✅ **High reliability**: Backup ensures validation even if primary fails
- ✅ **Fast feedback**: Both validation jobs complete quickly
- ✅ **Clear reporting**: Status shows which layer passed/failed

> **ℹ️ Note**: The `docker-integration` workflow runs weekly and may show "This workflow has no runs yet" if:
> - Recently added to the project (less than a week ago)
> - No Sunday has passed since the workflow was created
> - No manual runs have been triggered via GitHub Actions UI

### Test Scenarios

Three Docker test scenarios:
- `passenger_with_app` - With dummy application
- `passenger_without_app` - Monitor only
- `passenger_with_visible_prometheus` - Visible metrics

### Quick Start

```bash
# For rapid development feedback
cd test && make syntax-check unit-test

# For comprehensive local testing
cd test && make test

# For CI troubleshooting
cd test && make integration-test-ci

# Test native prometheus endpoint specifically
cd test && bundle exec ruby tests/passenger_native_prometheus_unit_test.rb
```

### Testing the Native Prometheus Endpoint

The new `/monitus/passenger-status-native_prometheus` endpoint has comprehensive test coverage:

- **Unit Tests**: Logic validation without Docker (`passenger_native_prometheus_unit_test.rb`)
- **Integration Tests**: Full HTTP endpoint testing (`passenger_native_prometheus_test.rb`) 
- **Format Compliance**: Prometheus exposition format validation

### Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for detailed guidance.

**Quick fixes:**
- **CI failures**: Usually pass with basic validation
- **Docker issues**: Use `make syntax-check unit-test`
- **Local problems**: Try `make clean && make build`