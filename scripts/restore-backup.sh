#!/bin/bash

# Backup restore script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKUP_DIR="$SERVER_DIR/backups"

cd "$SERVER_DIR"

echo "=========================================="
echo "Backup Restoration"
echo "=========================================="

# Check if server files exist (Server/ or Assets.zip from download-server.sh)
if [ ! -d "Server" ] && [ ! -f "Assets.zip" ]; then
    echo ""
    echo "❌ Error: Server files not found"
    echo "   You must download the server first before restoring backups."
    echo ""
    echo "   Run: ./download-server.sh"
    echo ""
    exit 1
fi

# List available backups
echo "📂 Available backups:"
echo ""
BACKUPS=($(ls -1t "$BACKUP_DIR"/hytale_backup_*.tar.gz 2>/dev/null))

if [ ${#BACKUPS[@]} -eq 0 ]; then
    echo "❌ No backups found in $BACKUP_DIR"
    exit 1
fi

for i in "${!BACKUPS[@]}"; do
    BACKUP_FILE="${BACKUPS[$i]}"
    BACKUP_NAME=$(basename "$BACKUP_FILE")
    BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    BACKUP_DATE=$(echo "$BACKUP_NAME" | sed 's/hytale_backup_\([0-9]\{8\}\)_\([0-9]\{6\}\).*/\1 \2/' | sed 's/\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\) \([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1-\2-\3 \4:\5:\6/')
    echo "  [$i] $BACKUP_DATE ($BACKUP_SIZE)"
done

echo ""
read -p "Select backup number to restore (or 'q' to cancel): " CHOICE

if [ "$CHOICE" = "q" ]; then
    echo "Restoration cancelled"
    exit 0
fi

if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -ge ${#BACKUPS[@]} ]; then
    echo "❌ Invalid choice"
    exit 1
fi

SELECTED_BACKUP="${BACKUPS[$CHOICE]}"

# Check if server is running and stop it automatically
if pgrep -f "HytaleServer.jar" > /dev/null; then
    echo "⚠️  Hytale server is currently running"
    echo "   Automatically stopping server..."
    
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
    
    # Wait for process to actually stop (up to 2 minutes for systemd)
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
        read -p "Force kill? (yes/no): " FORCE_KILL
        if [[ "$FORCE_KILL" =~ ^[Yy] ]]; then
            sudo pkill -9 -f "HytaleServer.jar"
            sleep 3
            echo "✅ Server force killed"
        else
            echo "Restoration cancelled"
            exit 1
        fi
    fi
    
    # Additional safety pause
    echo "⏳ Waiting 5 more seconds for cleanup..."
    sleep 5
    echo ""
else
    SERVER_WAS_SYSTEMD=false
fi

echo "📋 Selected backup contents:"
tar -tzf "$SELECTED_BACKUP" | head -20
echo ""
echo "⚠️  WARNING: This operation will overwrite current files!"
echo "   Selected backup: $(basename "$SELECTED_BACKUP")"
echo "   Backup date: $(stat -c %y "$SELECTED_BACKUP" | cut -d'.' -f1)"
echo ""
read -p "Do you want to create a safety backup first? (yes/no): " CREATE_BACKUP

if [[ "$CREATE_BACKUP" =~ ^[Yy] ]]; then
    echo "📦 Creating pre-restore safety backup..."
    
    # Create backup with special pre-restore naming
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    PRE_RESTORE_BACKUP="$BACKUP_DIR/hytale_backup_pre-restore_$TIMESTAMP.tar.gz"
    
    sudo tar -czf "$PRE_RESTORE_BACKUP" \
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
    
    sudo chown $USER:$USER "$PRE_RESTORE_BACKUP"
    
    BACKUP_SIZE=$(du -h "$PRE_RESTORE_BACKUP" | cut -f1)
    echo "✅ Pre-restore backup created: $BACKUP_SIZE"
    echo "   Location: $(basename "$PRE_RESTORE_BACKUP")"
fi

echo ""
read -p "Continue with restoration? (yes/no): " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy] ]]; then
    echo "Restoration cancelled"
    exit 0
fi

echo ""
echo "📦 Restoring backup..."

# Restore archive (with sudo since need to overwrite root files)
sudo tar -xzf "$SELECTED_BACKUP" -C "$SERVER_DIR"

# Fix ownership of restored files
echo "🔧 Fixing file permissions..."
sudo chown -R $USER:$USER "$SERVER_DIR/universe" "$SERVER_DIR/config.json" "$SERVER_DIR/permissions.json" "$SERVER_DIR/whitelist.json" "$SERVER_DIR/bans.json" "$SERVER_DIR/mods" 2>/dev/null || true

echo "✅ Restoration completed successfully!"
echo ""
echo "📊 Restored files (modification dates):"
echo "   universe/ - $(sudo stat -c %y "$SERVER_DIR/universe" 2>/dev/null | cut -d'.' -f1 || echo "Not found")"
echo "   config.json - $(sudo stat -c %y "$SERVER_DIR/config.json" 2>/dev/null | cut -d'.' -f1 || echo "Not found")"
echo "   auth.enc - $(sudo stat -c %y "$SERVER_DIR/auth.enc" 2>/dev/null | cut -d'.' -f1 || echo "Not found")"
echo ""

# Offer to restart server
if [ "$SERVER_WAS_SYSTEMD" = true ]; then
    read -p "Restart server via systemd? (yes/no): " RESTART
    if [[ "$RESTART" =~ ^[Yy] ]]; then
        echo "⏳ Waiting 10 seconds before restart (port cleanup)..."
        sleep 10
        sudo systemctl start hytale-server
        echo "✅ Server restarted via systemctl"
        echo "   Use './console.sh' to access console"
        echo ""
        echo "⚠️  Remember to re-authenticate if needed:"
        echo "   /auth login device"
    else
        echo "🚀 To restart manually:"
        echo "   sudo systemctl start hytale-server"
        echo ""
        echo "⚠️  Remember to re-authenticate if needed:"
        echo "   /auth login device"
    fi
else
    echo "🚀 To restart server:"
    echo "   sudo systemctl start hytale-server"
    echo "   or: ./start-server-optimized.sh"
    echo ""
    echo "⚠️  Remember to re-authenticate if needed:"
    echo "   /auth login device"
fi
