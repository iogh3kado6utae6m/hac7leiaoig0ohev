#!/bin/bash
# Debug deployment issues for Monitus JRuby containers

set -euo pipefail

CONTAINER_NAME="${1:-monitus}"
VARIANT="${2:-minimal-debug}"

echo "🔍 Debugging deployment for container: $CONTAINER_NAME"
echo "======================================================"

# Function to run commands safely
run_cmd() {
    local description="$1"
    local cmd="$2"
    echo -n "📋 $description... "
    if output=$(eval "$cmd" 2>&1); then
        echo "✅"
        if [[ -n "$output" ]]; then
            echo "$output" | sed 's/^/   /'
        fi
    else
        echo "❌"
        echo "$output" | sed 's/^/   ERROR: /'
    fi
    echo
}

# Check if Docker is available
if ! command -v docker >/dev/null 2>&1; then
    echo "❌ Docker not available in this environment"
    echo "💡 This script is designed for environments with Docker access"
    echo "💡 Please run this on your local machine or deployment environment"
    exit 1
fi

echo "🏃 Container Status:"
run_cmd "Container running status" "docker ps --filter name=$CONTAINER_NAME --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"

echo "📜 Container Logs (last 50 lines):"
run_cmd "Application logs" "docker logs $CONTAINER_NAME --tail 50"

echo "🔎 Container Inspection:"
run_cmd "Container environment" "docker exec $CONTAINER_NAME env | grep -E '(RACK|PASSENGER|JRUBY|JAVA)'"

echo "📁 Application Files:"
run_cmd "App directory contents" "docker exec $CONTAINER_NAME ls -la /home/app/webapp/"

echo "🔧 JRuby Status:"
run_cmd "JRuby version" "docker exec $CONTAINER_NAME jruby --version"

echo "📝 Application Syntax Check:"
run_cmd "Main app syntax" "docker exec $CONTAINER_NAME su - app -c 'cd /home/app/webapp && timeout 10s jruby -c prometheus_exporter.rb'"
run_cmd "Config.ru syntax" "docker exec $CONTAINER_NAME su - app -c 'cd /home/app/webapp && timeout 10s jruby -c config.ru'"

echo "📦 Bundle Status:"
run_cmd "Bundle check" "docker exec $CONTAINER_NAME su - app -c 'cd /home/app/webapp && bundle check'"
run_cmd "Installed gems" "docker exec $CONTAINER_NAME su - app -c 'cd /home/app/webapp && bundle list'"

echo "🆔 Nginx Status:"
run_cmd "Nginx config test" "docker exec $CONTAINER_NAME nginx -t"
run_cmd "Nginx process" "docker exec $CONTAINER_NAME pgrep nginx || echo 'Not running'"

echo "🛠️ Manual Testing Commands:"
echo "   docker exec -it $CONTAINER_NAME bash"
echo "   docker logs -f $CONTAINER_NAME"
echo "   docker exec $CONTAINER_NAME su - app -c 'cd /home/app/webapp && bundle exec rackup -p 3000'"
echo
echo "📦 Deploy debug variant:"
echo "   ./deploy-full-monitus.sh $VARIANT 8081"
echo
echo "🔄 Restart container:"
echo "   docker restart $CONTAINER_NAME"
