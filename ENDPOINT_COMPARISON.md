# 🔗 Monitus Endpoint Comparison: Test vs Full Application

## 🚨 **ISSUE IDENTIFIED**: Wrong Docker Variant Deployed

You're getting "Not Found" for `/monitus/passenger-status` because you're running the **test variant** instead of the **full application variant**.

## 📋 **Endpoint Comparison**

### 🧪 **Currently Running: `jruby-test` variant**
**Container**: Simple test application (Dockerfile.jruby-test)

| Endpoint | Status | Response |
|----------|--------|---------|
| `GET /health` | ✅ Works | `"healthy"` |
| `GET /test` | ✅ Works | JRuby version info |
| `GET /monitus/metrics` | ✅ Works | Simple test metrics |
| `GET /monitus/passenger-status` | ❌ **Not Found** | **Endpoint doesn't exist** |
| `GET /monitus/passenger-config_*` | ❌ **Not Found** | **Endpoints don't exist** |

### 🎯 **Should Deploy: `jruby-minimal` variant**
**Container**: Full Monitus application (Dockerfile.jruby-minimal)

| Endpoint | Status | Description |
|----------|--------|--------------|
| `GET /health` | ✅ Available | Health check |
| `GET /monitus/metrics` | ✅ Available | Full Prometheus metrics |
| `GET /monitus/passenger-status` | ✅ **Available** | **Raw passenger-status output** |
| `GET /monitus/passenger-status-prometheus` | ✅ Available | Passenger metrics in Prometheus format |
| `GET /monitus/passenger-config_system-metrics` | ✅ Available | System metrics from passenger-config |
| `GET /monitus/passenger-config_system-properties` | ✅ Available | System properties JSON |
| `GET /monitus/passenger-config_pool-json` | ✅ Available | Pool status JSON |
| `GET /monitus/passenger-config_api-call_get_server` | ✅ Available | Server status JSON |
| `GET /monitus/debug-passenger-status-json` | ✅ Available | Debug passenger status |

## 🔧 **Solution: Deploy Full Application**

### ✅ **FIXED**: Nginx Configuration Issues Resolved
The minimal variant Dockerfile had problematic Passenger directives that caused build failures. This has been fixed!

### Option 1: Quick Deploy Script
```bash
# Deploy minimal variant with full application (now fixed!)
./deploy-full-monitus.sh minimal 8080

# Or deploy to different port to compare
./deploy-full-monitus.sh minimal 8081
```

### Option 2: Manual Docker Commands
```bash
# Stop current test container
docker stop monitus
docker rm monitus

# Build and run minimal variant
cd src
docker build -f Dockerfile.jruby-minimal -t monitus-jruby-minimal .
docker run -d --name monitus --restart unless-stopped -p 8080:80 monitus-jruby-minimal

# Test the passenger-status endpoint
curl http://localhost:8080/monitus/passenger-status
```

## 📊 **Variant Comparison Summary**

| Docker Variant | Application | passenger-status | Complexity | Status |
|----------------|-------------|------------------|------------|--------|
| `jruby-test` | 🧪 Simple test app | ❌ Missing | Minimal | Currently running |
| `jruby-minimal` | 🎯 Full Monitus | ✅ **Available** | Medium | ✅ **Recommended** |
| `jruby-passenger` | 🎯 Full Monitus | ✅ Available | High | Fixed, untested |
| `jruby-official-pattern` | 🎯 Full Monitus | ✅ Available | Complex | Module issues |

## 🔍 **After Deploying Full App, Test These Endpoints**

```bash
# Basic health
curl http://localhost:8080/health

# The missing endpoint that should now work:
curl http://localhost:8080/monitus/passenger-status

# Full metrics
curl http://localhost:8080/monitus/metrics

# Passenger-specific endpoints  
curl http://localhost:8080/monitus/passenger-status-prometheus
curl http://localhost:8080/monitus/passenger-config_system-metrics
curl http://localhost:8080/monitus/passenger-config_pool-json
```

## 💡 **Why This Happened**

The `jruby-test` variant was designed as a **minimal test container** to verify JRuby + Passenger integration works. It includes:
- Basic Sinatra app
- Simple health check
- Fake metrics
- **No passenger-status integration**

For **production use**, you need the full Monitus application that includes all the `/monitus/passenger-status*` endpoints.

## ⚙️ **Command Path Fixes Applied**

The passenger commands have been fixed to work across different Docker environments:
- ✅ Multiple path detection: `/usr/bin/`, `/usr/sbin/`, `/usr/local/bin/`, `PATH`
- ✅ Graceful error handling
- ✅ Proper error messages when commands are not found
- ✅ Timeout handling for command execution

These fixes are in the updated `prometheus_exporter.rb` file.
