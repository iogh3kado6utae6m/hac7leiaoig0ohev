#!/bin/bash
# Extract and validate nginx configuration from Dockerfile

set -euo pipefail

DOCKERFILE="${1:-src/Dockerfile.jruby-minimal}"
TEMP_CONFIG="/tmp/nginx-test.conf"

echo "🔍 Extracting nginx config from $DOCKERFILE..."

# Extract nginx server block from Dockerfile
awk '/cat > \/etc\/nginx\/sites-available\/webapp.conf/,/^EOF$/' "$DOCKERFILE" | \
    grep -v "cat >" | \
    grep -v "^EOF$" | \
    sed 's/^-//' > "$TEMP_CONFIG"

echo "📝 Extracted config:"
echo "==========================================="
cat "$TEMP_CONFIG"
echo "==========================================="

# Basic syntax validation
echo
echo "🔍 Basic nginx syntax validation:"

# Check for common issues
ERROR_COUNT=0

echo -n "  ✓ Checking server block... "
if grep -q "server {" "$TEMP_CONFIG" && grep -q "}" "$TEMP_CONFIG"; then
    echo "✅ OK"
else
    echo "❌ Missing server block"
    ((ERROR_COUNT++))
fi

echo -n "  ✓ Checking semicolons... "
if grep -E "(listen|server_name|root|passenger_)" "$TEMP_CONFIG" | grep -v ";$" | grep -q "."; then
    echo "❌ Missing semicolons found:"
    grep -E "(listen|server_name|root|passenger_)" "$TEMP_CONFIG" | grep -v ";$"
    ((ERROR_COUNT++))
else
    echo "✅ OK"
fi

echo -n "  ✓ Checking passenger directives... "
PROBLEMATIC_DIRECTIVES=("passenger_pool_idle_time" "passenger_startup_timeout" "passenger_thread_count" "passenger_max_instances")
for directive in "${PROBLEMATIC_DIRECTIVES[@]}"; do
    if grep -q "^[[:space:]]*$directive" "$TEMP_CONFIG"; then
        echo "❌ Found problematic directive: $directive"
        ((ERROR_COUNT++))
    fi
done
if [ $ERROR_COUNT -eq 0 ]; then
    echo "✅ OK - no problematic directives"
fi

echo -n "  ✓ Checking location blocks... "
if grep -q "location" "$TEMP_CONFIG"; then
    if grep -q "location.*{" "$TEMP_CONFIG" && grep -A5 "location.*{" "$TEMP_CONFIG" | grep -q "}"; then
        echo "✅ OK"
    else
        echo "❌ Malformed location blocks"
        ((ERROR_COUNT++))
    fi
else
    echo "⚠️  No location blocks found"
fi

echo
if [ $ERROR_COUNT -eq 0 ]; then
    echo "🎉 Configuration looks good!"
    echo "💡 To test with real nginx: docker run --rm -v $(pwd):/tmp nginx:alpine nginx -t -c /tmp/nginx-test.conf"
else
    echo "❌ Found $ERROR_COUNT issues that need to be fixed"
    exit 1
fi

# Clean up
rm -f "$TEMP_CONFIG"
