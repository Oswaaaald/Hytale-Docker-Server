#!/bin/bash

# Hard reset script - Deletes everything except scripts and documentation
# Allows starting from scratch easily

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$SERVER_DIR"

# Request sudo early if needed
if [ -e "auth.enc" ] && [ ! -w "auth.enc" ]; then
    echo "🔒 Some files require sudo privileges..."
    sudo -v || { echo "❌ Sudo required to delete server files"; exit 1; }
fi

echo "========================================"
echo "🔥 HYTALE SERVER HARD RESET"
echo "========================================"
echo ""
echo "This script will PERMANENTLY DELETE:"
echo "  • All worlds (universe/)"
echo "  • All logs (logs/)"
echo "  • All backups (backups/)"
echo "  • Server JAR files"
echo "  • Authentication (auth.enc)"
echo "  • Configuration (config.json)"
echo "  • Installed mods (mods/)"
echo "  • Downloader and archives"
echo "  • Systemd service (if installed)"
echo ""
echo "✅ WILL BE KEPT:"
echo "  • All scripts (.sh)"
echo "  • All documentation (.md)"
echo ""

# Check if systemd service exists and remove it
if systemctl list-unit-files | grep -q "hytale-server.service"; then
    echo "🔧 Systemd service detected"
    
    # Stop service if running
    if systemctl is-active --quiet hytale-server.service 2>/dev/null; then
        echo "   Stopping service..."
        sudo systemctl stop hytale-server.service
        sleep 2
    fi
    
    # Disable and remove service
    echo "   Disabling service..."
    sudo systemctl disable hytale-server.service 2>/dev/null || true
    
    echo "   Removing service file..."
    sudo rm -f /etc/systemd/system/hytale-server.service
    
    echo "   Reloading systemd..."
    sudo systemctl daemon-reload
    
    echo "✅ Systemd service removed"
    echo ""
fi

# Check if server is running (manual launch)
if pgrep -f "HytaleServer.jar" > /dev/null; then
    echo "⚠️  Server is currently RUNNING (manual mode)"
    read -p "Do you want to stop it to continue? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Stopping server..."
        sudo pkill -f "HytaleServer.jar"
        sleep 2
        echo "✅ Server stopped"
    else
        echo "❌ Reset cancelled"
        exit 1
    fi
fi

echo ""
echo "⚠️  WARNING: This action is IRREVERSIBLE!"
echo ""
read -p "Are you ABSOLUTELY SURE you want to continue? Type 'RESET' to confirm: " CONFIRM

if [ "$CONFIRM" != "RESET" ]; then
    echo "❌ Reset cancelled"
    exit 0
fi

echo ""
echo "🗑️  Deletion in progress..."
echo ""

# Function to delete with sudo if necessary
safe_remove() {
    local path="$1"
    if [ -e "$path" ]; then
        # Try to delete normally first
        if rm -rf "$path" 2>/dev/null; then
            echo "  ✓ Deleted: $path"
        else
            # If deletion failed (permission denied), use sudo
            sudo rm -rf "$path"
            echo "  ✓ Deleted (sudo): $path"
        fi
    fi
}

# Delete data folders
safe_remove "universe"
safe_remove "logs"
safe_remove "backups"
safe_remove "mods"
safe_remove "Server"

# Delete configuration and auth files
safe_remove "auth.enc"
safe_remove "config.json"
safe_remove "config.json.bak"
safe_remove "bans.json"
safe_remove "permissions.json"
safe_remove "whitelist.json"

# Delete JAR files and libraries
safe_remove "HytaleServer.jar"
safe_remove "lib"
safe_remove "natives"

# Delete downloader and archives
safe_remove "hytale-downloader"
safe_remove ".hytale-downloader-credentials.json"
safe_remove "game.zip"
safe_remove "Assets.zip"

# Delete other temporary files
safe_remove ".server.lock"
safe_remove "crash-reports"

echo ""
echo "✅ Reset complete!"
echo ""
echo "📁 Kept files:"
ls -1 *.sh *.md 2>/dev/null || echo "  (none)"
echo ""
echo "To reinstall the server:"
echo "  1. ./download-server.sh"
echo "  2. sudo ./install-service.sh (optional)"
echo ""
