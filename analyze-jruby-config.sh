#!/bin/bash
# Static analysis of JRuby + Docker + Passenger configuration
# Can run without Docker to validate configurations

set -e

echo "🔍 JRuby + Docker + Passenger Configuration Analysis"
echo "================================================="
echo

# Function to check file and report findings
check_file() {
    local file="$1"
    local description="$2"
    
    if [ -f "$file" ]; then
        echo "✅ $description: $file"
        return 0
    else
        echo "❌ Missing $description: $file"
        return 1
    fi
}

# Function to analyze dockerfile
analyze_dockerfile() {
    local dockerfile="$1"
    echo "📋 Analyzing: $dockerfile"
    
    if [ ! -f "$dockerfile" ]; then
        echo "❌ File not found: $dockerfile"
        return 1
    fi
    
    # Base image analysis
    local base_image=$(grep '^FROM' "$dockerfile" | head -1 | awk '{print $2}')
    echo "  📦 Base image: $base_image"
    
    # JRuby-specific checks
    if grep -q 'jruby' "$dockerfile"; then
        echo "  ✅ JRuby references found"
    else
        echo "  ⚠️  No JRuby references found"
    fi
    
    if grep -q 'JRUBY_OPTS' "$dockerfile"; then
        local jruby_opts=$(grep 'JRUBY_OPTS' "$dockerfile" | head -1)
        echo "  ✅ JRuby optimization: $jruby_opts"
    else
        echo "  ⚠️  No JRUBY_OPTS found"
    fi
    
    if grep -q 'JAVA_OPTS' "$dockerfile"; then
        local java_opts=$(grep 'JAVA_OPTS' "$dockerfile" | head -1)
        echo "  ✅ Java optimization: $java_opts"
    else
        echo "  ⚠️  No JAVA_OPTS found"
    fi
    
    # Passenger-specific checks
    if grep -q 'passenger' "$dockerfile"; then
        echo "  ✅ Passenger references found"
    else
        echo "  ⚠️  No Passenger references found"
    fi
    
    if grep -q 'passenger_spawn_method.*direct' "$dockerfile"; then
        echo "  ✅ Correct spawn method for JRuby (direct)"
    elif grep -q 'nginx-jruby.conf' "$dockerfile" && [ -f "src/nginx-jruby.conf" ] && grep -q 'passenger_spawn_method direct' "src/nginx-jruby.conf"; then
        echo "  ✅ Correct spawn method for JRuby (via nginx-jruby.conf)"
    elif grep -q 'passenger' "$dockerfile"; then
        echo "  ⚠️  Should use 'direct' spawn method for JRuby"
    else
        echo "  ✅ No Passenger (standalone JRuby - spawn method not applicable)"
    fi
    
    # Health check
    if grep -q 'HEALTHCHECK' "$dockerfile"; then
        echo "  ✅ Health check configured"
    else
        echo "  ⚠️  No health check configured"
    fi
    
    # Package issues (ignore comments)
    if grep -v '^[[:space:]]*#' "$dockerfile" | grep -q 'libnginx-mod-http-passenger'; then
        echo "  ❌ ISSUE: Uses problematic libnginx-mod-http-passenger package"
        echo "     FIX: Install Passenger repository and use 'passenger' package"
    fi
    
    echo
}

# Main analysis
echo "🏗️  Dockerfile Analysis"
echo "===================="

# Analyze different JRuby Dockerfiles (avoid duplicates)
analyzed_files=()
for dockerfile in src/Dockerfile.jruby* src/Dockerfile.*jruby*; do
    if [ -f "$dockerfile" ]; then
        # Check if already analyzed
        skip=false
        for analyzed in "${analyzed_files[@]}"; do
            if [ "$dockerfile" = "$analyzed" ]; then
                skip=true
                break
            fi
        done
        
        if [ "$skip" = false ]; then
            analyze_dockerfile "$dockerfile"
            analyzed_files+=("$dockerfile")
        fi
    fi
done

echo "📄 Configuration Files Analysis"
echo "==============================="

# Check key configuration files
config_files_found=0

if check_file "src/Gemfile.jruby" "JRuby standalone Gemfile"; then
    echo "     Dependencies: $(grep '^gem' src/Gemfile.jruby | wc -l) gems"
    if grep -q 'jrjackson' src/Gemfile.jruby; then
        echo "     ✅ Uses JRuby-optimized JSON (jrjackson)"
    fi
    if grep -q 'jruby-openssl' src/Gemfile.jruby; then
        echo "     ✅ Uses JRuby-optimized SSL"
    fi
    config_files_found=$((config_files_found + 1))
fi

if check_file "src/Gemfile.jruby-passenger" "JRuby Passenger Gemfile"; then
    echo "     Dependencies: $(grep '^gem' src/Gemfile.jruby-passenger | wc -l) gems (minimal)"
    config_files_found=$((config_files_found + 1))
fi

if check_file "src/nginx-jruby.conf" "Nginx JRuby configuration"; then
    if grep -q 'passenger_ruby /usr/bin/jruby' src/nginx-jruby.conf; then
        echo "     ✅ Configured for JRuby runtime"
    fi
    if grep -q 'passenger_spawn_method direct' src/nginx-jruby.conf; then
        echo "     ✅ Uses correct spawn method"
    fi
    if grep -q 'passenger_concurrency_model thread' src/nginx-jruby.conf; then
        echo "     ✅ Uses thread concurrency model"
    fi
    config_files_found=$((config_files_found + 1))
fi

if check_file "src/passenger-jruby.conf" "Passenger JRuby configuration"; then
    if grep -q 'passenger_ruby /usr/bin/jruby' src/passenger-jruby.conf; then
        echo "     ✅ Configured for JRuby runtime"
    fi
    config_files_found=$((config_files_found + 1))
fi

if check_file "src/config/puma.rb" "Puma configuration"; then
    if grep -q 'defined?(JRUBY_VERSION)' src/config/puma.rb; then
        echo "     ✅ JRuby-specific configuration found"
    fi
    config_files_found=$((config_files_found + 1))
fi

if check_file "src/start-jruby.sh" "JRuby startup script"; then
    config_files_found=$((config_files_found + 1))
fi

if check_file "src/start-passenger-jruby.sh" "Passenger JRuby startup script"; then
    config_files_found=$((config_files_found + 1))
fi

echo
echo "📊 Testing Infrastructure Analysis"
echo "=================================="

test_files_found=0

if check_file "test/docker-compose-jruby.yaml" "JRuby Docker Compose"; then
    echo "     Services: $(grep -c '^  [a-zA-Z]' test/docker-compose-jruby.yaml) services"
    test_files_found=$((test_files_found + 1))
fi

if check_file "test/docker-compose-jruby-passenger.yml" "JRuby Passenger Docker Compose"; then
    test_files_found=$((test_files_found + 1))
fi

if check_file "test/tests/jruby_passenger_test.rb" "JRuby integration tests"; then
    echo "     Test methods: $(grep -c "def test_\|it " test/tests/jruby_passenger_test.rb) tests"
    test_files_found=$((test_files_found + 1))
fi

if check_file "test/Makefile" "Test automation"; then
    if grep -q 'jruby-test' test/Makefile; then
        echo "     ✅ JRuby test targets available"
    fi
    test_files_found=$((test_files_found + 1))
fi

echo
echo "📚 Documentation Analysis"
echo "========================="

docs_found=0

if check_file "JRUBY_SUPPORT.md" "JRuby support documentation"; then
    echo "     Size: $(wc -l < JRUBY_SUPPORT.md) lines"
    docs_found=$((docs_found + 1))
fi

if check_file "src/README-jruby-passenger.md" "JRuby Passenger documentation"; then
    echo "     Size: $(wc -l < src/README-jruby-passenger.md) lines"
    docs_found=$((docs_found + 1))
fi

if check_file "src/README-jruby-deployment-comparison.md" "JRuby deployment comparison"; then
    echo "     Size: $(wc -l < src/README-jruby-deployment-comparison.md) lines"
    docs_found=$((docs_found + 1))
fi

if check_file "src/JRUBY_BUILD_NOTES.md" "JRuby build notes"; then
    docs_found=$((docs_found + 1))
fi

echo
echo "📈 Summary Report"
echo "================="
echo "Configuration files found: $config_files_found"
echo "Test files found: $test_files_found"
echo "Documentation files found: $docs_found"

if [ $config_files_found -ge 5 ] && [ $test_files_found -ge 3 ] && [ $docs_found -ge 3 ]; then
    echo "✅ EXCELLENT: Comprehensive JRuby + Docker + Passenger setup"
elif [ $config_files_found -ge 3 ] && [ $test_files_found -ge 2 ] && [ $docs_found -ge 2 ]; then
    echo "✅ GOOD: Well-configured JRuby + Docker + Passenger setup"
else
    echo "⚠️  BASIC: Limited JRuby + Docker + Passenger configuration"
fi

echo
echo "💡 Recommendations"
echo "=================="
echo "1. Use 'passenger_spawn_method direct' for JRuby (no fork support)"
echo "2. Configure high thread counts (16-32) for JRuby concurrency"
echo "3. Use JRuby-optimized gems: jrjackson, jruby-openssl"
echo "4. Set appropriate JVM memory limits (JAVA_OPTS)"
echo "5. Use longer startup timeouts (JRuby slower to start)"
echo "6. Avoid libnginx-mod-http-passenger on Ubuntu Noble"
echo
echo "🚀 Next Steps"
echo "============="
echo "To test with Docker: docker build -f src/Dockerfile.jruby-test -t test ."
echo "To run tests: cd test && make jruby-test"
echo "To run standalone: docker build -f src/Dockerfile.jruby -t monitus-jruby . && docker run -p 8080:8080 monitus-jruby"
