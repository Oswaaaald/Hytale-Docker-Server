#!/bin/bash

# Script to connect to the server console

SCREEN_NAME="hytale-server"

echo "=========================================="
echo "Hytale Server Console"
echo "=========================================="
echo ""
echo "You are about to connect to the server console."
echo ""
echo "To DETACH (exit without stopping the server):"
echo "  Press: Ctrl+A then D"
echo ""
echo "⚠️  DO NOT use Ctrl+C (this would stop the server!)"
echo ""
read -p "Press Enter to continue..."

# Check if session exists (check as root since service runs as root)
if ! sudo screen -list | grep -q "$SCREEN_NAME"; then
    echo ""
    echo "❌ Error: No '$SCREEN_NAME' session found"
    echo ""
    echo "Is the server running?"
    echo "  sudo systemctl status hytale-server"
    exit 1
fi

# Connect to session (with sudo since session belongs to root)
sudo screen -r "$SCREEN_NAME"
