#!/bin/bash

# Hytale server manual backup script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKUP_DIR="$SERVER_DIR/backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="hytale_backup_$TIMESTAMP.tar.gz"

cd "$SERVER_DIR"

echo "=========================================="
echo "Hytale Server Backup"
echo "=========================================="

# Check if server files exist
if [ ! -d "universe" ] && [ ! -f "config.json" ]; then
    echo ""
    echo "❌ Error: No server data found"
    echo "   The server must be installed and run at least once before creating backups."
    echo ""
    echo "   Run: ./download-server.sh"
    echo ""
    exit 1
fi

# Check if server is running - MUST stop it to avoid corruption
SERVER_WAS_RUNNING=false
if pgrep -f "HytaleServer.jar" > /dev/null; then
    echo ""
    echo "⚠️  Server is currently running"
    echo "   Automatically stopping server to create a safe backup..."
    echo ""
    
    # Use systemctl if service exists, otherwise pkill
    if systemctl is-active --quiet hytale-server 2>/dev/null; then
        sudo systemctl stop hytale-server
        echo "✅ Server stop command sent (systemctl)"
        SERVER_WAS_SYSTEMD=true
    else
        sudo pkill -f "HytaleServer.jar"
        echo "✅ Server stopped manually"
        SERVER_WAS_SYSTEMD=false
    fi
    
    # Wait for complete shutdown (up to 2 minutes)
    echo "⏳ Waiting for complete shutdown (may take up to 2 minutes)..."
    MAX_WAIT=120
    for i in $(seq 1 $MAX_WAIT); do
        if ! pgrep -f "HytaleServer.jar" > /dev/null; then
            echo "✅ Server stopped after ${i}s"
            break
        fi
        if [ $((i % 10)) -eq 0 ]; then
            echo "   Still waiting... (${i}s / ${MAX_WAIT}s)"
        fi
        sleep 1
    done
    
    if pgrep -f "HytaleServer.jar" > /dev/null; then
        echo "❌ Server did not stop properly after ${MAX_WAIT}s"
        exit 1
    fi
    
    # Additional safety pause
    echo "⏳ Waiting 5 more seconds for cleanup..."
    sleep 5
    SERVER_WAS_RUNNING=true
    echo ""
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"

echo "📦 Creating backup..."
echo "   File: $BACKUP_NAME"
echo "   Note: auth.enc excluded (tokens expire)"

# Create archive (with sudo since files belong to root)
sudo tar -czf "$BACKUP_DIR/$BACKUP_NAME" \
    --exclude='Server' \
    --exclude='Assets.zip' \
    --exclude='hytale-downloader' \
    --exclude='backups' \
    --exclude='logs/*.log' \
    --exclude='.cache' \
    --exclude='auth.enc' \
    universe/ \
    config.json \
    permissions.json \
    whitelist.json \
    bans.json \
    mods/ \
    2>/dev/null || true

# Change backup owner
sudo chown $USER:$USER "$BACKUP_DIR/$BACKUP_NAME"

BACKUP_SIZE=$(du -h "$BACKUP_DIR/$BACKUP_NAME" | cut -f1)

echo "✅ Backup created: $BACKUP_SIZE"
echo "   Location: $BACKUP_DIR/$BACKUP_NAME"

# List existing backups
echo ""
echo "📂 Available backups:"
ls -lh "$BACKUP_DIR" | grep -E "hytale_backup_.*\.tar\.gz" | awk '{print "   " $9 " (" $5 ")"}'

# Clean old backups (keep 10 most recent)
BACKUP_COUNT=$(ls -1 "$BACKUP_DIR"/hytale_backup_*.tar.gz 2>/dev/null | wc -l)
if [ "$BACKUP_COUNT" -gt 10 ]; then
    echo ""
    echo "🧹 Cleaning old backups (keeping 10 most recent)..."
    ls -1t "$BACKUP_DIR"/hytale_backup_*.tar.gz | tail -n +11 | xargs rm -f
    echo "✅ Cleanup complete"
fi

echo ""
echo "✅ Backup completed successfully!"

# Restart server if it was running
if [ "$SERVER_WAS_RUNNING" = true ]; then
    echo ""
    read -p "Restart the server? (yes/no): " RESTART_SERVER
    
    if [[ "$RESTART_SERVER" =~ ^[Yy] ]]; then
        echo "⏳ Waiting 5 seconds before restart..."
        sleep 5
        
        if [ "$SERVER_WAS_SYSTEMD" = true ]; then
            sudo systemctl start hytale-server
            echo "✅ Server restarted via systemctl"
        else
            echo "🚀 Start server manually with:"
            echo "   ./start-server-optimized.sh"
        fi
    else
        echo "🚀 To restart server:"
        if [ "$SERVER_WAS_SYSTEMD" = true ]; then
            echo "   sudo systemctl start hytale-server"
        else
            echo "   ./start-server-optimized.sh"
        fi
    fi
fi
