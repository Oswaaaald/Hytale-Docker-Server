#!/bin/bash

# Hytale server startup script (optimized)
# With AOT cache and optimized JVM parameters

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SERVER_JAR="$SERVER_DIR/Server/HytaleServer.jar"
ASSETS_ZIP="$SERVER_DIR/Assets.zip"
AOT_CACHE="$SERVER_DIR/Server/HytaleServer.aot"

cd "$SERVER_DIR"

echo "=========================================="
echo "Starting Hytale Server (Optimized)"
echo "=========================================="

# Check Java 25
JAVA_VERSION=$(java -version 2>&1 | head -n 1 | awk -F '"' '{print $2}' | cut -d'.' -f1)
if [ "$JAVA_VERSION" != "25" ]; then
    echo "⚠️  WARNING: Java 25 is required!"
    echo "   Current version: Java $JAVA_VERSION"
    echo ""
    echo "   Install Java 25 from: https://adoptium.net/"
    exit 1
fi

# Check that files exist
if [ ! -f "$SERVER_JAR" ]; then
    echo "❌ Error: $SERVER_JAR not found"
    echo "   Run first: ./download-server.sh"
    exit 1
fi

if [ ! -f "$ASSETS_ZIP" ]; then
    echo "❌ Error: $ASSETS_ZIP not found"
    echo "   Run first: ./download-server.sh"
    exit 1
fi

# Create necessary directories
mkdir -p logs
mkdir -p mods
mkdir -p universe/worlds
mkdir -p backups

# Fix permissions if folders belong to root
if [ ! -w logs ]; then
    echo "⚠️  Fixing permissions (requires sudo)..."
    sudo chown -R $USER:$USER logs universe mods backups config.json permissions.json whitelist.json bans.json auth.enc 2>/dev/null || true
fi

echo "✅ Checks complete"
echo ""

# Extract memory values from JVM_ARGS for display
CURRENT_SCRIPT="$SCRIPT_DIR/start-server-optimized.sh"
CURRENT_XMS=$(grep -oP 'Xms\K[0-9]+[GM]' "$CURRENT_SCRIPT" | head -1)
CURRENT_XMX=$(grep -oP 'Xmx\K[0-9]+[GM]' "$CURRENT_SCRIPT" | head -1)

echo "🚀 Starting server with optimizations..."
echo "   Port: 5520 (UDP)"
echo "   Memory: ${CURRENT_XMX} (${CURRENT_XMS} initial)"
echo "   AOT Cache: $([ -f "$AOT_CACHE" ] && echo "Enabled" || echo "Not available")"
echo "   Sentry: Disabled (development)"
echo "   GC: ZGC (ultra-low latency)"
echo ""
echo "📝 After first launch, authenticate the server with:"
echo "   /auth login device"
echo ""

# Optimized JVM arguments
JVM_ARGS=(
    # Memory (auto-configured by download-server.sh based on system RAM)
    -Xms3G
    -Xmx6G
    
    # Garbage Collector (ZGC for ultra-low latency)
    -XX:+UseZGC
    -XX:ZCollectionInterval=5
    -XX:ZAllocationSpikeTolerance=2
    
    # Performance
    -XX:+AlwaysPreTouch
    -XX:+ParallelRefProcEnabled
    -XX:+DisableExplicitGC
    
    # Réduire les pauses
    -XX:-UseCompressedOops
    -XX:+UseLargePages
    
    # Cache AOT (si disponible)
    $([ -f "$AOT_CACHE" ] && echo "-XX:AOTCache=$AOT_CACHE" || echo "")
)

# Démarrer le serveur
java \
    "${JVM_ARGS[@]}" \
    -jar "$SERVER_JAR" \
    --assets "$ASSETS_ZIP" \
    --disable-sentry
