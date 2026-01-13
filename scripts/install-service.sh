#!/bin/bash

# Hytale server installation script as systemd service

set -e

SERVICE_NAME="hytale-server"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
USER=$(whoami)

echo "=========================================="
echo "Hytale Service Installation"
echo "=========================================="

# Check root permissions
if [ "$EUID" -ne 0 ]; then 
    echo "❌ This script must be run with sudo"
    echo "   Usage: sudo ./install-service.sh"
    exit 1
fi

# Check that files exist
if [ ! -f "$SCRIPT_DIR/start-server-optimized.sh" ]; then
    echo "❌ Error: scripts/start-server-optimized.sh not found"
    exit 1
fi

# Check that screen is installed
if ! command -v screen &> /dev/null; then
    echo "❌ Error: 'screen' is not installed"
    echo "   Install it with: sudo apt install screen"
    exit 1
fi

echo "📝 Creating service file..."

# Create service file
cat > "$SERVICE_FILE" << 'SERVICEEOF'
[Unit]
Description=Hytale Dedicated Server
After=network.target

[Service]
Type=forking
User=USER_PLACEHOLDER
WorkingDirectory=SERVERDIR_PLACEHOLDER
ExecStart=/usr/bin/screen -dmS hytale-server /bin/bash -c 'trap "" SIGINT; while true; do SCRIPTDIR_PLACEHOLDER/start-server-optimized.sh; EXIT_CODE=$?; if [ $EXIT_CODE -eq 0 ]; then echo "=== Server stopped cleanly with /stop ==="; break; fi; echo "=== Server interrupted (code: $EXIT_CODE) ==="; echo "=== Use /stop command in-game to stop cleanly ==="; echo "=== Restarting in 5 seconds... ==="; sleep 5; done'
ExecStop=/bin/bash -c 'screen -S hytale-server -p 0 -X stuff "/stop\n"; sleep 10; screen -S hytale-server -X quit 2>/dev/null || true'
Restart=on-failure
RestartSec=15
StandardOutput=journal
StandardError=journal

# Resource limits
LimitNOFILE=65536
TimeoutStartSec=300
TimeoutStopSec=120

# Security (relaxed to allow screen)
NoNewPrivileges=true
ReadWritePaths=SERVERDIR_PLACEHOLDER
ReadWritePaths=/run/screen

[Install]
WantedBy=multi-user.target
SERVICEEOF

# Replace placeholders
sed -i "s|USER_PLACEHOLDER|$USER|g" "$SERVICE_FILE"
sed -i "s|SERVERDIR_PLACEHOLDER|$SERVER_DIR|g" "$SERVICE_FILE"
sed -i "s|SCRIPTDIR_PLACEHOLDER|$SCRIPT_DIR|g" "$SERVICE_FILE"

echo "✅ Service file created: $SERVICE_FILE"

# Reload systemd
echo "🔄 Reloading systemd..."
systemctl daemon-reload

# Enable service
echo "✅ Enabling service..."
systemctl enable "$SERVICE_NAME"

echo ""
echo "=========================================="
echo "✅ Installation Complete!"
echo "=========================================="
echo ""
echo "Available commands:"
echo "  sudo systemctl start $SERVICE_NAME     # Start"
echo "  sudo systemctl stop $SERVICE_NAME      # Stop"
echo "  sudo systemctl restart $SERVICE_NAME   # Restart"
echo "  sudo systemctl status $SERVICE_NAME    # Status"
echo "  sudo journalctl -u $SERVICE_NAME -f    # Real-time logs"
echo ""
echo "To access server console:"
echo "  ./console.sh"
echo "  (Ctrl+A then D to detach without stopping server)"
echo ""
echo "To start server now:"
echo "  sudo systemctl start $SERVICE_NAME"
