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

### "Could not find gem 'thin'" Error

**Cause:** MRI `Gemfile.lock` interfering with JRuby gem resolution.

**Solutions:**
1. Dockerfile automatically removes `Gemfile.lock` 
2. `.dockerignore` excludes MRI-specific files
3. Force clean build: `docker build --no-cache ...`

### Validation

Run pre-build validation:
```bash
cd src && ./test-docker-jruby.sh
```

Look for:
- ✅ No thin dependency in Gemfile.jruby
- ⚠️ Gemfile.lock warnings (expected - will be removed during build)
