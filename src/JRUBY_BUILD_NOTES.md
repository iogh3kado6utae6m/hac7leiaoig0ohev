# JRuby Docker Build Notes

## Clean Build (No Cache)

To ensure no cached layers interfere with dependency resolution:

```bash
# Force rebuild without Docker cache
docker build --no-cache -f src/Dockerfile.jruby -t monitus-jruby src/

# Or clean specific images first  
docker rmi monitus-jruby jruby:9.4 2>/dev/null || true
docker build -f src/Dockerfile.jruby -t monitus-jruby src/
```

## Troubleshooting

### Gem Dependency Errors

#### "Could not find gem 'thin'" Error
**Cause:** MRI `Gemfile.lock` interfering with JRuby gem resolution.

**Solutions:**
1. Dockerfile automatically removes `Gemfile.lock` 
2. `.dockerignore` excludes MRI-specific files
3. Force clean build: `docker build --no-cache ...`

#### "Could not find gem 'minitest'" Error
**Cause:** Test dependencies included but excluded with `--without development test`.

**Solutions:**
1. Removed minitest/rack-test from production Gemfile.jruby
2. More aggressive bundler state cleanup (`.bundle/` directory)
3. Production build only includes essential gems (12 total)

### Validation

Run pre-build validation:
```bash
cd src && ./test-docker-jruby.sh
```

Look for:
- ✅ No thin dependency in Gemfile.jruby
- ⚠️ Gemfile.lock warnings (expected - will be removed during build)

## Startup Strategies

### Intelligent Startup Script

The `start-jruby.sh` script tries multiple approaches:

1. **Bundle exec (preferred)**: Normal bundler-managed startup
2. **Direct puma (fallback)**: Bypasses bundler using simple-config.ru

### Manual Troubleshooting

If container still fails to start:

```bash
# Connect to running container for debugging
docker run -it --entrypoint /bin/bash monitus-jruby

# Inside container:
./start-jruby.sh  # Run startup script manually
bundle list       # Check installed gems
bundle config     # Check bundler configuration
```

### Alternative Startup Methods

```bash
# Method 1: Use simple config (no bundler)
docker run -p 8080:8080 monitus-jruby puma -b tcp://0.0.0.0:8080 simple-config.ru

# Method 2: Override entrypoint for debugging
docker run -it --entrypoint /bin/bash monitus-jruby
```