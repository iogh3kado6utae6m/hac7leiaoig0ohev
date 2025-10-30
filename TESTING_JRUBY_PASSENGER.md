# Testing JRuby + Passenger Docker Setup

Этот документ описывает тестирование исправленной интеграции JRuby с Passenger.

## 🚀 Quick Start

### Automated Testing
```bash
# Test the full custom build
./test-fixed-dockerfile.sh

# Test the simplified version (faster)
./test-fixed-dockerfile.sh simple
```

### Manual Testing
```bash
# Build full version (15+ minutes)
docker build -f src/Dockerfile.jruby-passenger -t monitus-jruby-passenger src/

# Build simplified version (5 minutes)
docker build -f src/Dockerfile.jruby-passenger-simple -t monitus-jruby-passenger-simple src/

# Run the container
docker run -p 8080:80 monitus-jruby-passenger-simple

# Test endpoints
curl http://localhost:8080/health
curl http://localhost:8080/monitus/metrics
```

## 📋 Available Dockerfiles

### 1. Dockerfile.jruby-passenger (Full Custom)
- **Base**: phusion/baseimage:noble-1.0.2
- **Build time**: 15+ minutes
- **Features**: Custom RVM + JRuby installation
- **Use case**: Maximum control, enterprise setup

### 2. Dockerfile.jruby-passenger-simple (Recommended)
- **Base**: phusion/passenger-jruby94:3.0.4
- **Build time**: 5 minutes
- **Features**: Pre-configured JRuby environment
- **Use case**: Faster builds, production ready

## 🔧 Fixes Applied

Based on analysis of official passenger-docker project:

### Fixed Issues:
1. ✅ **Shell compatibility**: Use `/bin/bash` instead of `/bin/sh`
2. ✅ **User management**: Create `app` user explicitly
3. ✅ **RVM integration**: Proper group assignment after RVM installation
4. ✅ **Wrapper scripts**: Simplified direct echo commands
5. ✅ **Base image**: Alternative using pre-built passenger-jruby image

### Key Changes:
```dockerfile
# Before (failed)
usermod -a -G rvm app  # app user didn't exist

# After (works)
groupadd -r app && \
useradd -r -g app -d /home/app -s /bin/bash -m app && \
# ... install RVM ... && \
usermod -a -G rvm app
```

## 🧪 Testing Results

The test script validates:
- ✅ Container builds successfully
- ✅ Application starts without errors
- ✅ Health endpoint responds
- ✅ Metrics endpoints return valid Prometheus format
- ✅ JRuby is properly integrated
- ✅ Passenger is running and accessible
- ✅ Concurrent requests work correctly

## 🐛 Troubleshooting

### Common Build Issues

**"user 'app' does not exist"**
```bash
# Fixed by creating app user explicitly
groupadd -r app && useradd -r -g app -d /home/app -s /bin/bash -m app
```

**"source: not found"**
```bash
# Fixed by using bash shell
SHELL ["/bin/bash", "-c"]
```

**GPG key import fails**
```bash
# Network issue - retry build or use simplified version
./test-fixed-dockerfile.sh simple
```

### Runtime Issues

**"502 Bad Gateway"**
- Check if JRuby process is running: `docker exec <container> ps aux | grep jruby`
- Check application logs: `docker logs <container>`
- Verify Passenger configuration: `docker exec <container> passenger-status`

**Application not responding**
- JRuby takes 30-60 seconds to fully start
- Check health endpoint: `curl http://localhost:8080/health`
- Monitor startup logs: `docker logs -f <container>`

## 📊 Performance Expectations

| Version | Build Time | Memory | Startup | Req/sec |
|---------|------------|--------|---------|----------|
| Simple  | 5 min      | 300MB  | 45s     | 1000+   |
| Full    | 15 min     | 400MB  | 60s     | 1000+   |

## 📚 Related Files

- `src/Dockerfile.jruby-passenger` - Full custom build
- `src/Dockerfile.jruby-passenger-simple` - Simplified build
- `src/nginx-jruby.conf` - Nginx virtual host configuration
- `src/config.ru.jruby-passenger` - JRuby-optimized Rack config
- `src/Gemfile.jruby-passenger` - Production gem dependencies
- `test-fixed-dockerfile.sh` - Automated test script
- `src/README-jruby-deployment-comparison.md` - Detailed comparison

---

*For detailed deployment comparison, see [README-jruby-deployment-comparison.md](src/README-jruby-deployment-comparison.md)*
