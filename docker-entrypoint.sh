#!/bin/bash
set -e

# Cleanup function to kill screen when container stops
cleanup() {
    echo "Stopping server..."
    screen -S hytale -X quit 2>/dev/null || true
    exit 0
}

# Trap SIGTERM to gracefully stop
trap cleanup SIGTERM SIGINT

# Start server in screen with Ctrl+C protection (workdir already /server/Server)
# Use bash -c wrapper to ensure container stops when Java exits
screen -DmS hytale bash -c '
    trap "" SIGINT && \
    java \
    -Xms${XMS} \
    -Xmx${XMX} \
    -XX:+UseZGC \
    -XX:ZCollectionInterval=5 \
    -XX:ZAllocationSpikeTolerance=2 \
    -XX:+AlwaysPreTouch \
    -XX:+ParallelRefProcEnabled \
    -XX:+DisableExplicitGC \
    -XX:-UseCompressedOops \
    $([ -f HytaleServer.aot ] && echo "-XX:AOTCache=HytaleServer.aot" || echo "") \
    -jar HytaleServer.jar \
    --assets Assets.zip \
    --disable-sentry 2>&1 | tee /proc/1/fd/1'

# Wait for screen session to end (server stopped)
while screen -list | grep -q "hytale"; do
    sleep 1
done

echo "Server stopped, container exiting..."
