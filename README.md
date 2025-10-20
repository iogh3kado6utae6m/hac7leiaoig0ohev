# Monitus

Small application that runs on the Phusion Passenger webserver and exposes Passenger metrics in a
Prometheus format.

## Metrics

Name                        | Description 
----------------------------|--------------------------------------------------
passenger_capacity          | Number of processes spawn
passenger_processes_active  | Number of processes currently working on requests
passenger_wait_list_size    | Requests in queue

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

This example will make the Passenger Metric available on `http://<ip-of-this-server>:10254/metrics`.

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
- **Syntax validation** - Ruby and Node.js code
- **Unit tests** - Core functionality without dependencies
- **Configuration validation** - Docker Compose, Rack configs
- **Integration readiness** - Component loading verification

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

**Primary Workflow** (`build`):
- ✅ Fast validation tests (< 2 minutes)
- ✅ Runs on every push/PR
- ✅ No Docker complexity
- ✅ Reliable results

**Integration Workflow** (`docker-integration`):
- 🐳 Full Docker integration tests
- 📅 Runs weekly or manually
- ⏱️ 30-minute timeout
- 🔍 Comprehensive validation

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
```

### Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for detailed guidance.

**Quick fixes:**
- **CI failures**: Usually pass with basic validation
- **Docker issues**: Use `make syntax-check unit-test`
- **Local problems**: Try `make clean && make build`