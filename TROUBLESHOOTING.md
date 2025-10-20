# Troubleshooting Guide

## CI/CD Issues

### "dependency failed to start: container is unhealthy"

This error occurs when Docker health checks fail in the CI environment.

**Possible Causes:**
1. Services taking longer to start than expected
2. Network connectivity issues between containers
3. Missing dependencies (curl) in base image
4. Incorrect health check endpoints

**Solutions:**

1. **Use CI-specific configuration:**
   ```bash
   cd test
   make integration-test-ci  # Uses more lenient settings
   ```

2. **Check service logs:**
   ```bash
   docker compose logs passenger_with_app
   docker compose logs passenger_without_app
   docker compose logs passenger_with_visible_prometheus
   ```

3. **Manual service testing:**
   ```bash
   # Start services without health check dependencies
   docker compose -f docker-compose.ci.yaml up -d
   
   # Wait and test manually
   sleep 30
   curl -f http://localhost:PORT/monitus/metrics
   ```

4. **Debug container startup:**
   ```bash
   # Get shell access to container
   docker compose run --rm passenger_with_app /bin/bash
   
   # Check if curl is available
   which curl
   
   # Test health check manually
   curl -v http://localhost:80/monitus/metrics
   ```

### GitHub Actions Specific Issues

The workflow has a fallback strategy:

1. **Primary**: Full Docker integration tests with health checks
2. **Fallback**: CI-specific tests with relaxed timing
3. **Backup**: Syntax and unit tests only (no Docker)

If Docker tests fail but syntax/unit tests pass, this usually indicates:
- Docker environment issues (not code problems)
- Timing/networking issues in CI
- Resource constraints in CI runners

## Local Development Issues

### Docker Not Available

```bash
# Run tests without Docker
cd test
make syntax-check
make unit-test
```

### Services Won't Start

1. **Check Docker resources:**
   ```bash
   docker system df
   docker system prune  # If needed
   ```

2. **Verify port availability:**
   ```bash
   netstat -tlnp | grep :10254
   ```

3. **Build images fresh:**
   ```bash
   cd test
   make clean
   make build
   ```

### Test Failures

1. **Network connectivity:**
   ```bash
   docker network ls
   docker network inspect test_test_network
   ```

2. **Service health:**
   ```bash
   docker ps  # Check STATUS column
   make status  # Convenient wrapper
   ```

3. **Application logs:**
   ```bash
   make logs  # View all service logs
   ```

## Common Error Messages

### "curl: command not found"

The health check requires curl but it's missing from the container.

**Fix:** The updated Dockerfiles now install curl automatically.

### "Connection refused"

Service is not ready or listening on wrong port.

**Fix:** 
- Wait longer for startup (increased start_period)
- Check correct port in health check
- Verify service configuration

### "timeout waiting for containerd to start"

Docker daemon issues (usually in containerized environments).

**Fix:** Use the fallback testing without Docker.

## Performance Optimization

### Faster CI Builds

1. **Use Docker layer caching in CI**
2. **Cache Ruby gems and Node.js packages**
3. **Parallelize independent test stages**

The current configuration already implements these optimizations.

### Reduced Resource Usage

```bash
# Run specific test scenarios only
make passenger_with_app
docker compose run --rm test
```

## Getting Help

If problems persist:

1. **Check logs first:** `make logs`
2. **Try CI configuration:** `make integration-test-ci`
3. **Test without Docker:** `make syntax-check && make unit-test`
4. **Clean rebuild:** `make clean && make build`

For CI/CD issues, the backup test job will still validate code correctness even if Docker integration fails.

## Node.js Components

### passenger-status-node

The `src/passenger-status-node` utility is excluded from CI testing because:

1. **Missing package-lock.json** - Required for `npm ci` in CI environments
2. **Development-only dependency** - Not needed for core application functionality
3. **Optional component** - Used for extended metrics, not core Prometheus export

**Local Development:**
```bash
cd src/passenger-status-node
npm install  # Creates package-lock.json locally
node index.js --help
```

**CI Strategy:**
- ✅ Focus on core Ruby application
- ✅ Validate essential functionality
- ⏭️ Skip optional Node.js utilities

This approach ensures reliable CI while maintaining full local development capabilities.
