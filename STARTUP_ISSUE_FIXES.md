# 🔧 Monitus Startup Issue Fixes

## 🚨 **Issue Identified**: Application Startup Failure

The container built successfully but the web application failed to start, showing Passenger error page "Web application could not be started".

## 🔍 **Root Cause Analysis**

### **Missing Dependencies**
- ❌ `json` gem was not included in `Gemfile.jruby-passenger`
- ❌ `config.ru.jruby-passenger` uses JSON but doesn't require it
- ❌ Complex middleware stack may have compatibility issues

## ✅ **Fixes Applied**

### 1. **Fixed Missing JSON Dependency**
```ruby
# Added to Gemfile.jruby-passenger:
gem 'json'

# Added to config.ru.jruby-passenger:
require 'json'
```

### 2. **Created Simplified Configuration**
- 📄 `config.ru.jruby-passenger-simple` - minimal config for troubleshooting
- ⚙️ Removed complex middleware that might cause startup issues
- 📊 Enabled error reporting for better diagnostics

### 3. **Added Debug Docker Variant**
- 📄 `Dockerfile.jruby-minimal-debug` - enhanced error reporting
- ⚙️ `passenger_friendly_error_pages on` - shows detailed error messages
- 📊 Comprehensive startup logging and syntax checking

### 4. **Enhanced Debugging Tools**
- 🛠️ `debug-deployment.sh` - container troubleshooting script
- 📊 Improved `deploy-full-monitus.sh` with better error handling
- 🔍 Automated syntax validation and health checks
- ✨ `test-app-syntax.sh` - test application syntax locally

### 5. **Working Variant Created**
- 📄 `Dockerfile.jruby-working` - based on proven test pattern
- ⚙️ Inline Gemfile creation (like successful test variant)
- 🐍 Simplified config.ru without complex middleware
- 📊 Same pattern as working test container but with full app

## 🚀 **Next Steps: Test Deployment**

### **Option 1: Deploy Working Variant (Recommended)**
```bash
# Stop current failing container
docker stop monitus && docker rm monitus

# Deploy working variant based on proven test pattern
./deploy-full-monitus.sh working 8080
```

### **Option 2: Re-deploy Fixed Minimal Variant**
```bash
# Deploy with fixes
./deploy-full-monitus.sh minimal 8081
```

### **Option 3: Deploy Debug Variant**
```bash
# Deploy debug variant with detailed error reporting
./deploy-full-monitus.sh minimal-debug 8082
```

### **Option 3: Manual Troubleshooting**
```bash
# Debug current container (if accessible)
./debug-deployment.sh monitus

# Or manually inspect
docker logs monitus
docker exec -it monitus bash
```

## 📋 **Expected Results After Fix**

### **Successful Startup Should Show:**
- ✅ `curl http://localhost:8080/health` → `"healthy"`
- ✅ `curl http://localhost:8080/monitus/metrics` → Prometheus metrics
- ✅ `curl http://localhost:8080/monitus/passenger-status` → Passenger status output

### **Debug Variant Benefits:**
- 🔍 Detailed error pages instead of generic Passenger error
- 📊 Comprehensive startup logging
- ⚙️ Syntax validation during container startup
- 🛠️ Bundle and gem verification

## 💡 **Key Learnings**

1. **Always check gem dependencies** - even basic ones like `json`
2. **Test application syntax** before deploying
3. **Use debug/development modes** for troubleshooting
4. **Enable Passenger friendly error pages** for better diagnostics
5. **Keep fallback configurations** simple and minimal

## 🔄 **Rollback Plan**

If issues persist:
```bash
# Deploy known-working test variant
./deploy-full-monitus.sh test 8082

# Compare working vs non-working configurations
curl http://localhost:8082/health  # Should work
curl http://localhost:8080/health  # May fail
```

The test variant has minimal dependencies and should always work, even without the full passenger-status endpoints.
