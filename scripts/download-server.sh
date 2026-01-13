#!/bin/bash

# Hytale Server Download Script (Linux only)
# Uses the Hytale Downloader CLI

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$SERVER_DIR"

DOWNLOADER_URL="https://downloader.hytale.com/hytale-downloader.zip"
DOWNLOADER_ZIP="hytale-downloader.zip"
DOWNLOADER_DIR="hytale-downloader"
DOWNLOADER_BIN="$DOWNLOADER_DIR/hytale-downloader-linux-amd64"
JAVA_VERSION="25"
JAVA_BUILD="25.0.1+8"
GAME_ZIP="game.zip"

echo "=========================================="
echo "Hytale Server Installation"
echo "=========================================="
echo ""

# Check and install Java 25 if needed
echo "🔍 Checking Java 25..."
JAVA_INSTALLED=false
JAVA_CORRECT_VERSION=false

if command -v java &> /dev/null; then
    JAVA_INSTALLED=true
    CURRENT_VERSION=$(java -version 2>&1 | head -n 1 | awk -F '"' '{print $2}' | cut -d. -f1)
    
    if [ "$CURRENT_VERSION" = "$JAVA_VERSION" ]; then
        JAVA_CORRECT_VERSION=true
        echo "✅ Java 25 already installed"
        java -version 2>&1 | head -n 1
    else
        echo "⚠️  Java $CURRENT_VERSION detected, but Java 25 is required"
    fi
else
    echo "❌ Java not installed"
fi

# Install Java 25 if needed
if [ "$JAVA_CORRECT_VERSION" = false ]; then
    echo ""
    echo "⚠️  Java 25 is required to run the Hytale server"
    echo ""
    read -p "Do you want to install Java 25 automatically? (yes/no): " INSTALL_JAVA
    
    if [[ ! "$INSTALL_JAVA" =~ ^[YyOo] ]]; then
        echo ""
        echo "❌ Installation cancelled"
        echo ""
        echo "To install Java 25 manually:"
        echo "  https://adoptium.net/temurin/releases/?version=25"
        echo ""
        exit 1
    fi
    
    echo ""
    echo "📥 Installing Java 25 (Adoptium Temurin)..."
    
    JAVA_TARBALL="OpenJDK25U-jdk_x64_linux_hotspot_${JAVA_BUILD/+/_}.tar.gz"
    JAVA_URL="https://github.com/adoptium/temurin25-binaries/releases/download/jdk-${JAVA_BUILD}/OpenJDK25U-jdk_x64_linux_hotspot_${JAVA_BUILD/+/_}.tar.gz"
    JAVA_DIR="jdk-${JAVA_BUILD}"
    
    # Download Java 25
    echo "⏳ Downloading Java 25..."
    wget -q --show-progress "$JAVA_URL" -O "$JAVA_TARBALL"
    
    # Extract
    echo "📦 Extracting..."
    tar -xzf "$JAVA_TARBALL"
    
    # Install to /opt
    echo "📂 Installing to /opt/..."
    sudo mv "$JAVA_DIR" /opt/
    
    # Configure as default alternative
    echo "⚙️  Configuring Java..."
    sudo update-alternatives --install /usr/bin/java java /opt/$JAVA_DIR/bin/java 1
    sudo update-alternatives --set java /opt/$JAVA_DIR/bin/java
    
    # Cleanup
    rm "$JAVA_TARBALL"
    
    echo "✅ Java 25 installed successfully!"
    java -version 2>&1 | head -n 1
fi

echo ""
echo "=========================================="
echo "Hytale Server Download"
echo "=========================================="
echo ""

# Check if server is running
if pgrep -f "HytaleServer.jar" > /dev/null; then
    echo "⚠️  WARNING: Hytale server is currently running!"
    echo "   It is recommended to stop the server before updating."
    echo ""
    read -p "Do you want to continue anyway? (yes/no): " CONTINUE
    if [[ ! "$CONTINUE" =~ ^[YyOo] ]]; then
        echo "Download cancelled"
        exit 0
    fi
fi

# Download Hytale Downloader if it doesn't exist
if [ ! -f "$DOWNLOADER_BIN" ]; then
    echo "📥 Downloading Hytale Downloader CLI..."
    wget -O "$DOWNLOADER_ZIP" "$DOWNLOADER_URL"
    
    echo "📦 Extracting Hytale Downloader..."
    unzip -o "$DOWNLOADER_ZIP" -d "$DOWNLOADER_DIR"
    rm "$DOWNLOADER_ZIP"
    
    chmod +x "$DOWNLOADER_BIN"
    echo "✅ Hytale Downloader installed"
fi

# Check downloader version
echo ""
echo "🔍 Hytale Downloader version:"
"$DOWNLOADER_BIN" -version

# Check for updates
echo ""
echo "🔄 Checking for downloader updates..."
"$DOWNLOADER_BIN" -check-update

# Display available game version
echo ""
echo "🎮 Available game version:"
"$DOWNLOADER_BIN" -print-version

# Download server files
echo ""
echo "📥 Downloading Hytale server files..."
echo "⏳ This may take several minutes..."
"$DOWNLOADER_BIN" -download-path "$GAME_ZIP"

# Extract files
echo ""
echo "📦 Extracting server files..."
unzip -q "$GAME_ZIP"
rm "$GAME_ZIP"

# Check that files are present
if [ ! -d "Server" ] || [ ! -f "Assets.zip" ]; then
    echo "❌ Error: Server/ and Assets.zip files not found"
    exit 1
fi

echo ""
echo "⚙️  Configuring server for your system..."

# Detect total RAM
TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_RAM_GB=$((TOTAL_RAM_KB / 1024 / 1024))

echo "   Detected RAM: ${TOTAL_RAM_GB}GB"

# Calculate optimal JVM memory settings (leave 2GB for system)
if [ $TOTAL_RAM_GB -le 4 ]; then
    # 4GB or less: use 2GB max
    XMS="1G"
    XMX="2G"
    echo "   ⚠️  Low RAM detected - using conservative settings"
elif [ $TOTAL_RAM_GB -le 8 ]; then
    # 5-8GB: use 4GB max
    XMS="2G"
    XMX="4G"
    echo "   Using moderate settings"
elif [ $TOTAL_RAM_GB -le 16 ]; then
    # 9-16GB: use 6GB max
    XMS="3G"
    XMX="6G"
    echo "   Using optimized settings"
else
    # 16GB+: use 8GB max
    XMS="4G"
    XMX="8G"
    echo "   Using high-performance settings"
fi

# Update start-server-optimized.sh with detected values
sed -i "s/-Xms[0-9]*[GM]/-Xms$XMS/" "$SCRIPT_DIR/start-server-optimized.sh"
sed -i "s/-Xmx[0-9]*[GM]/-Xmx$XMX/" "$SCRIPT_DIR/start-server-optimized.sh"

echo "   Memory configured: $XMS (initial) → $XMX (max)"

echo ""
echo "✅ Download and extraction complete!"
echo ""
echo "📁 Installed files:"
echo "   - Server/"
echo "   - Assets.zip"
echo ""
echo "🚀 You can now start the server with:"
echo "   cd scripts && ./start-server-optimized.sh"
echo ""
echo "💡 Or install as a background service:"
echo "   cd scripts && sudo ./install-service.sh"
echo "   sudo systemctl start hytale-server"

