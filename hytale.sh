#!/bin/bash

# Docker helper script for Hytale server management

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Detect docker-compose command (supports both old and new syntax)
detect_docker_compose() {
    if command -v docker-compose &> /dev/null; then
        echo "docker-compose"
    elif docker compose version &> /dev/null 2>&1; then
        echo "docker compose"
    else
        echo ""
    fi
}

DOCKER_COMPOSE=$(detect_docker_compose)

# Ensure server is stopped (graceful first, then force if needed)
ensure_server_stopped() {
    if ! $DOCKER_COMPOSE ps | grep -q "hytale-server.*Up"; then
        return 0  # Already stopped
    fi
    
    # Disable auto-restart BEFORE sending stop command
    echo "🔓 Disabling auto-restart..."
    docker update --restart=no hytale-server 2>/dev/null || true
    sleep 1
    
    echo "📤 Sending /stop command to server..."
    docker exec hytale-server screen -S hytale -X stuff "/stop"$'\n' 2>/dev/null || true
    
    # Give server time to process /stop and disconnect players gracefully
    sleep 5
    
    # Wait for graceful shutdown (check if container is still running)
    echo "⏳ Waiting for server to shut down gracefully..."
    for i in {1..30}; do
        if ! docker ps --format '{{.Names}}' | grep -q "^hytale-server$"; then
            # Double-check it stays down (not restarting)
            sleep 2
            if ! docker ps --format '{{.Names}}' | grep -q "^hytale-server$"; then
                echo "✅ Server shut down gracefully"
                return 0
            else
                echo "⚠️  Container restarted, trying again..."
                docker update --restart=no hytale-server 2>/dev/null || true
            fi
        fi
        sleep 1
    done
    
    # If still running after 30s, force stop
    if docker ps --format '{{.Names}}' | grep -q "^hytale-server$"; then
        echo "⚠️  Server didn't stop gracefully, forcing shutdown..."
        echo "🔨 Forcing container stop..."
        $DOCKER_COMPOSE stop
    fi
}

show_help() {
    echo "Hytale Server - Docker Management"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  install     - Download server files and build Docker image"
    echo "  start       - Start the server"
    echo "  stop        - Stop the server"
    echo "  restart     - Restart the server"
    echo "  logs        - View server logs"
    echo "  console     - Attach to server console (Ctrl+A then D to detach)"
    echo "  backup      - Create a backup"
    echo "  restore     - Restore a backup"
    echo "  status      - Show server status"
    echo "  update      - Update server to latest version"
    echo "  reset       - Remove all data and start fresh"
    echo ""
}

install_server() {
    echo "=========================================="
    echo "Installing Hytale Server"
    echo "=========================================="
    echo ""
    
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        echo "❌ Docker is not installed!"
        echo ""
        echo "Install Docker:"
        echo "  curl -fsSL https://get.docker.com | sh"
        echo "  sudo usermod -aG docker $USER"
        echo ""
        exit 1
    fi
    
    # Detect docker-compose command
    if [ -z "$DOCKER_COMPOSE" ]; then
        echo "❌ Docker Compose is not available!"
        echo ""
        echo "Install Docker Compose:"
        echo "  sudo apt-get install docker-compose-plugin"
        echo ""
        exit 1
    fi
    
    # Download server files if not present
    if [ ! -d "Server" ] || [ ! -f "Assets.zip" ]; then
        echo "📥 Downloading server files (requires authentication)..."
        echo ""
        cd scripts
        ./download-server.sh
        cd ..
        echo ""
    else
        echo "✅ Server files already downloaded"
        echo ""
    fi
    
    # Build Docker image
    echo "🐳 Building Docker image..."
    $DOCKER_COMPOSE build
    
    # Create initial config files
    echo ""
    echo "📝 Creating initial configuration files..."
    mkdir -p universe mods backups logs
    
    # Create machine-id if missing (required for auth persistence)
    if [ ! -f "machine-id" ]; then
        echo "🔑 Generating machine-id for auth persistence..."
        uuidgen | tr -d '-' | tr -d '\n' > machine-id
        echo "✅ Machine-ID created: $(cat machine-id)"
    fi
    
    # Remove any directories that Docker might have created
    rm -rf permissions.json whitelist.json bans.json 2>/dev/null || true
    
    # Create config.json with AuthCredentialStore for auth persistence
    if [ ! -f "config.json" ]; then
        cat > config.json << 'EOF'
{
  "Version": 3,
  "ServerName": "Hytale Server",
  "MOTD": "",
  "Password": "",
  "MaxPlayers": 100,
  "MaxViewRadius": 8,
  "AuthCredentialStore": {
    "Type": "Encrypted",
    "Path": "auth.enc"
  }
}
EOF
    fi
    
    if [ ! -f "permissions.json" ]; then
        echo '{}' > permissions.json
    fi
    
    if [ ! -f "whitelist.json" ]; then
        echo '{}' > whitelist.json
    fi
    
    if [ ! -f "bans.json" ]; then
        echo '{}' > bans.json
    fi
    
    echo ""
    echo "✅ Installation complete!"
    echo ""
    echo "Next steps:"
    echo "  1. ./hytale.sh start"
    echo "  2. ./hytale.sh console"
    echo "  3. Type: /auth login device (follow the prompts)"
    echo "  4. Ctrl+A then D to detach"
    echo ""
    echo "✅ Auth persistence is enabled and will work across restarts!"
    echo ""
}

start_server() {
    echo "🚀 Starting Hytale server..."
    $DOCKER_COMPOSE up -d --no-build
    echo "✅ Server started!"
    echo ""
    echo "View logs: $0 logs"
    echo "Access console: $0 console"
}

stop_server() {
    echo "⏹️  Stopping Hytale server..."
    ensure_server_stopped
    echo "✅ Server stopped!"
}

restart_server() {
    echo "🔄 Restarting Hytale server..."
    $DOCKER_COMPOSE restart
    echo "✅ Server restarted!"
}

show_logs() {
    $DOCKER_COMPOSE logs -f hytale-server
}

open_console() {
    echo "📟 Attaching to server console..."
    echo "   To detach: Press Ctrl+A then D"
    echo "   To stop server: Type /stop"
    echo "   ⚠️  Ctrl+C is disabled to prevent accidental stops"
    echo ""
    docker exec -it hytale-server screen -xRR hytale
}

create_backup() {
    local SKIP_RESTART_PROMPT="${1:-false}"
    local BACKUP_PREFIX="${2:-}"
    
    echo "=========================================="
    echo "Creating Backup"
    echo "=========================================="
    
    # Check if server is running
    if $DOCKER_COMPOSE ps | grep -q "hytale-server.*Up"; then
        stop_server
        echo ""
        SERVER_WAS_RUNNING=true
    else
        SERVER_WAS_RUNNING=false
    fi
    
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    if [ -n "$BACKUP_PREFIX" ]; then
        BACKUP_NAME="hytale_backup_${BACKUP_PREFIX}_$TIMESTAMP.tar.gz"
    else
        BACKUP_NAME="hytale_backup_$TIMESTAMP.tar.gz"
    fi
    
    echo ""
    echo "📦 Creating backup: $BACKUP_NAME"
    
    mkdir -p backups
    
    tar -czf "backups/$BACKUP_NAME" \
        universe/ \
        config.json \
        permissions.json \
        whitelist.json \
        bans.json \
        mods/ \
        .hytale-downloader-credentials.json \
        2>/dev/null || true
    
    BACKUP_SIZE=$(du -h "backups/$BACKUP_NAME" | cut -f1)
    echo "✅ Backup created: $BACKUP_SIZE"
    
    # Cleanup old backups (keep 10)
    BACKUP_COUNT=$(ls -1 backups/hytale_backup_*.tar.gz 2>/dev/null | wc -l)
    if [ "$BACKUP_COUNT" -gt 10 ]; then
        echo "🧹 Cleaning old backups..."
        ls -1t backups/hytale_backup_*.tar.gz | tail -n +11 | xargs rm -f
    fi
    
    if [ "$SERVER_WAS_RUNNING" = true ] && [ "$SKIP_RESTART_PROMPT" = "false" ]; then
        echo ""
        read -p "Restart server? (yes/no): " RESTART
        if [[ "$RESTART" =~ ^[Yy] ]]; then
            start_server
        fi
    fi
}

restore_backup() {
    echo "=========================================="
    echo "Restore Backup"
    echo "=========================================="
    echo ""
    
    # List available backups
    if [ ! -d "backups" ] || [ -z "$(ls -A backups/*.tar.gz 2>/dev/null)" ]; then
        echo "❌ No backups found in backups/"
        exit 1
    fi
    
    echo "Available backups:"
    echo ""
    ls -1th backups/*.tar.gz | nl -w2 -s'. '
    echo ""
    read -p "Enter backup number to restore: " BACKUP_NUM
    
    BACKUP_FILE=$(ls -1th backups/*.tar.gz | sed -n "${BACKUP_NUM}p")
    
    if [ -z "$BACKUP_FILE" ]; then
        echo "❌ Invalid backup number"
        exit 1
    fi
    
    echo ""
    echo "⚠️  This will REPLACE all current data with:"
    echo "   $BACKUP_FILE"
    echo ""
    read -p "Type 'RESTORE' to confirm: " CONFIRM
    
    if [ "$CONFIRM" != "RESTORE" ]; then
        echo "❌ Restore cancelled"
        exit 0
    fi
    
    # Stop server if running
    if $DOCKER_COMPOSE ps | grep -q "hytale-server.*Up"; then
        stop_server
        echo ""
    fi
    
    # Ask about pre-restore backup if any data exists
    if [ -d "universe" ] || [ -d "mods" ] || [ -f "config.json" ]; then
        if [ "$(ls -A universe 2>/dev/null)" ] || [ "$(ls -A mods 2>/dev/null)" ] || [ -f "config.json" ]; then
            echo ""
            read -p "Create a backup before restoring? (yes/no): " CREATE_BACKUP
            if [[ "$CREATE_BACKUP" =~ ^[Yy] ]]; then
                PRE_RESTORE_BACKUP="backups/hytale_backup_pre_restore_$(date +"%Y%m%d_%H%M%S").tar.gz"
                echo ""
                echo "📦 Creating pre-restore backup: $PRE_RESTORE_BACKUP"
                tar -czf "$PRE_RESTORE_BACKUP" universe/ config.json permissions.json whitelist.json bans.json mods/ 2>/dev/null || true
            fi
        fi
    fi
    
    # Remove current data
    echo ""
    echo "🗑️  Removing current data..."
    sudo rm -rf universe/ mods/
    rm -f config.json permissions.json whitelist.json bans.json
    
    # Extract backup
    echo "📂 Extracting backup..."
    tar -xzf "$BACKUP_FILE"
    
    # Fix permissions
    echo "🔧 Fixing permissions..."
    sudo chown -R $(id -u):$(id -g) universe/ mods/ config.json permissions.json whitelist.json bans.json 2>/dev/null || true
    
    # Cleanup old backups (keep 10)
    BACKUP_COUNT=$(ls -1 backups/hytale_backup_*.tar.gz 2>/dev/null | wc -l)
    if [ "$BACKUP_COUNT" -gt 10 ]; then
        echo "🧹 Cleaning old backups..."
        ls -1t backups/hytale_backup_*.tar.gz | tail -n +11 | xargs rm -f
    fi
    
    echo ""
    echo "✅ Backup restored successfully!"
    echo ""
    read -p "Start server now? (yes/no): " START
    if [[ "$START" =~ ^[Yy] ]]; then
        start_server
    fi
}

show_status() {
    echo "=========================================="
    echo "Hytale Server Status"
    echo "=========================================="
    echo ""
    $DOCKER_COMPOSE ps
    echo ""
    
    if $DOCKER_COMPOSE ps | grep -q "hytale-server.*Up"; then
        echo "Status: ✅ Running"
        echo ""
        echo "Container stats:"
        docker stats --no-stream hytale-server
    else
        echo "Status: ⏹️  Stopped"
    fi
}

update_server() {
    echo "=========================================="
    echo "Updating Hytale Server"
    echo "=========================================="
    
    # Create backup first (skip restart prompt)
    echo "📦 Creating backup before update..."
    create_backup true "pre_update"
    
    echo ""
    echo "🔄 Rebuilding Docker image with latest server version..."
    $DOCKER_COMPOSE build --no-cache
    
    echo ""
    echo "📋 Copying updated server files to volume..."
    
    # Create temporary container from new image to extract files
    docker create --name hytale-update-temp hytale-server-hytale-server >/dev/null 2>&1
    
    # Copy Server files (excluding user data directories)
    docker cp hytale-update-temp:/server/Server/. ./Server-temp/
    
    # Remove user data directories from temp (we keep existing data)
    rm -rf ./Server-temp/universe ./Server-temp/worlds ./Server-temp/mods \
           ./Server-temp/backups ./Server-temp/logs \
           ./Server-temp/config.json ./Server-temp/permissions.json \
           ./Server-temp/whitelist.json ./Server-temp/bans.json \
           ./Server-temp/auth.enc 2>/dev/null
    
    # Copy updated files to volume using running container
    docker run --rm -v hytale-server-data:/data -v "$PWD/Server-temp":/source alpine sh -c \
        "cp -rf /source/* /data/ 2>/dev/null || true && cp -rf /source/.* /data/ 2>/dev/null || true"
    
    # Cleanup
    docker rm hytale-update-temp >/dev/null 2>&1
    rm -rf ./Server-temp
    
    echo "✅ Server files updated!"
    echo ""
    echo "✅ Update complete!"
    echo ""
    read -p "Restart server now? (yes/no): " RESTART
    if [[ "$RESTART" =~ ^[Yy] ]]; then
        restart_server
    fi
}

reset_server() {
    echo "=========================================="
    echo "🔥 RESET HYTALE SERVER"
    echo "=========================================="
    echo ""
    echo "This will DELETE:"
    echo "  • All worlds (universe/)"
    echo "  • All configuration"
    echo "  • Docker containers, volumes and images"
    echo ""
    read -p "Type 'RESET' to confirm: " CONFIRM
    
    if [ "$CONFIRM" != "RESET" ]; then
        echo "❌ Reset cancelled"
        exit 0
    fi
    
    echo ""
    echo "🗑️  Removing containers and data..."
    # Force stop without graceful shutdown (we're destroying everything anyway)
    $DOCKER_COMPOSE down -v --remove-orphans
    docker rmi hytale-server-hytale-server 2>/dev/null || true
    
    # Use sudo for Docker-created files and directories
    sudo rm -rf universe/ logs/ backups/ mods/ machine-id config.json permissions.json whitelist.json bans.json
    
    echo "✅ Reset complete!"
    echo ""
    echo "To reinstall: $0 install"
}

# Main command handler
case "${1:-help}" in
    install)
        install_server
        ;;
    start)
        start_server
        ;;
    stop)
        stop_server
        ;;
    restart)
        restart_server
        ;;
    logs)
        show_logs
        ;;
    console)
        open_console
        ;;
    backup)
        create_backup
        ;;
    restore)
        restore_backup
        ;;
    status)
        show_status
        ;;
    update)
        update_server
        ;;
    reset)
        reset_server
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "❌ Unknown command: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
