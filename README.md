# 🎮 Hytale Server - Complete Guide

Installation and management of a dedicated Hytale server on **Linux** in just a few commands.

---

## 📋 Prerequisites

- **OS**: Linux (Ubuntu, Debian, CentOS, etc.)
- **RAM**: 4GB minimum (8GB recommended for production)
- **Java**: Version 25 (installed automatically by the script)
- **Port**: UDP 5520 open (⚠️ UDP, not TCP!)

---

## 🚀 Installation in 3 Steps

### 1️⃣ Download the Server
```bash
cd scripts
./download-server.sh
```
Automatically installs Java 25 if needed, then downloads the server files (3.5 GB).

### 2️⃣ Install the Service (optional but recommended)
```bash
cd scripts
sudo ./install-service.sh
```
Configures automatic startup on system boot.

### 3️⃣ Start the Server
```bash
sudo systemctl start hytale-server
```
Or without service: `cd scripts && ./start-server-optimized.sh`

**First startup**: Authenticate with `/auth login device` in the console and follow the instructions (https://accounts.hytale.com/device).

---

## 📜 Available Scripts

All scripts are in the `scripts/` folder.

### `download-server.sh`
📥 **Downloads/updates the server**

```bash
cd scripts
./download-server.sh
```
- Checks and automatically installs Java 25 (Adoptium Temurin)
- Uses the official Hytale Downloader CLI
- Checks if the server is running before updating
- Downloads Server/ and Assets.zip (3.5 GB)

```bash
cd scripts
./download-server.sh  # Install or update
```

---

### `install-service.sh`
⚙️ **Installs the systemd service**
- Automatic startup on boot
- Management with `systemctl start/stop/restart`
- Console accessible via screen

```bash
cd scripts
sudo ./install-service.sh  # Run only once
```

**Useful commands after installation:**
```bash
sudo systemctl start hytale-server    # Start
sudo systemctl stop hytale-server     # Stop
sudo systemctl restart hytale-server  # Restart
sudo systemctl status hytale-server   # View status
```

---

### `console.sh`
🖥️ **Access the server console**
- Connects to the screen session
- **To exit**: Ctrl+A then D (⚠️ NOT Ctrl+C!)
- **To stop**: Type `/stop` in the console

```bash
cd scripts
./console.sh  # Open the console
```

**Protection**: Ctrl+C is disabled, only `/stop` stops the server.

---

### `backup.sh`
💾 **Create a backup**
- Backs up universe/, config, mods, auth
- Automatic rotation (keeps 10 backups max)
- Format: `backup-2026-01-13_19-30-00.tar.gz`

```bash
cd scripts
./backup.sh  # Create a backup now
```

**Before any update or major change, make a backup!**

---

### `restore-backup.sh`
♻️ **Restore a backup**
- Interactive menu listing all backups
- Automatically stops the server if necessary
- Offers to restart after restoration

```bash
cd scripts
./restore-backup.sh  # Restoration menu
```

---

### `reset.sh`
🔥 **Complete server reset**
- Deletes EVERYTHING except scripts and documentation
- Double confirmation required (type "RESET")
- Useful to start from scratch

```bash
cd scripts
./reset.sh  # ⚠️ Irreversible deletion!
```

**After reset**: `./download-server.sh` then restart.

---

## 🔧 Network Configuration

### Local Firewall

**Ubuntu/Debian (ufw)**:
```bash
sudo ufw allow 5520/udp
```

**RHEL/CentOS/Fedora (firewalld)**:
```bash
sudo firewall-cmd --permanent --add-port=5520/udp
sudo firewall-cmd --reload
```

**Other (iptables)**:
```bash
sudo iptables -A INPUT -p udp --dport 5520 -j ACCEPT
sudo iptables-save | sudo tee /etc/iptables/rules.v4
```

### Port Forwarding (Router)

If the server is behind a router/box:

1. Access the router interface (192.168.1.1 or 192.168.0.1)
2. Go to "Port Forwarding" / "NAT"
3. Create a rule:
   - **External port**: 5520
   - **Internal port**: 5520
   - **Protocol**: **UDP** ⚠️ (not TCP!)
   - **Local IP**: Server IP (ex: 192.168.1.100)

### Verify Connectivity

```bash
# Check that the server is listening on the port
sudo ss -tulpn | grep 5520

# Expected output:
# udp   LISTEN  0.0.0.0:5520
```

---

## 🎮 Mods

1. Download mods (.zip or .jar)
2. Place in the `mods/` folder
3. Restart the server

```bash
sudo systemctl restart hytale-server
```

---

## 📁 Structure des Fichiers

```
hytale-server/
├── scripts/             # Tous les scripts de gestion
│   ├── download-server.sh
│   ├── install-service.sh
│   ├── start-server-optimized.sh
│   ├── console.sh
│   ├── backup.sh
│   ├── restore-backup.sh
│   └── reset.sh
├── README.md            # This file
├── Server/              # Server binaries
├── Assets.zip           # Game assets (3.5 GB)
├── universe/            # Worlds and players
├── mods/                # Installed mods
├── backups/             # Backups
├── logs/                # Server logs
├── config.json          # Configuration
├── auth.enc             # Authentication
└── hytale-downloader/   # Download CLI
```

---

## 🔄 Server Update

```bash
# 1. Create a backup
./backup.sh

# 2. Stop the server
sudo systemctl stop hytale-server

# 3. Download the new version
./download-server.sh

# 4. Restart
sudo systemctl start hytale-server
```

**Check available updates**:
```bash
./hytale-downloader/hytale-downloader-linux-amd64 -print-version
```

---

## ❓ Quick Help

| Problem | Solution |
|----------|----------|
| Server doesn't start | Check Java 25: `java --version` |
| Can't connect | Check firewall and port forwarding UDP 5520 |
| Screen console stuck | Ctrl+A then D to detach, not Ctrl+C! |
| Permission error | Run commands with `sudo` |
| Jitter in game | Reduce MaxViewRadius in config.json |
| Server crashes | Increase RAM in start-server-optimized.sh |

---

## 🌟 Recommended Workflow

**Daily usage**:
- Start/stop: `sudo systemctl start/stop hytale-server`
- Console: `./console.sh` (exit with Ctrl+A D)
- Backup before changes: `./backup.sh`

**Maintenance**:
- Regular backup: `./backup.sh` (weekly recommended)
- Check updates: `./download-server.sh` displays available version
- Apply updates: backup → stop → download → start

**In case of problems**:
- Restore backup: `./restore-backup.sh`
- Complete reset: `./reset.sh` then `./download-server.sh`

---

**Support**: [hytale.com/support](https://hytale.com/support)

## ⚙️ Optimizations

### View Distance

View distance is the main driver of RAM usage.

**Recommendations:**
- Maximum: 12 chunks (384 blocks)
- Default Hytale: 384 blocks ≈ 24 chunks Minecraft
- Default Minecraft: 10 chunks (160 blocks)

⚠️ Expect higher RAM usage than Minecraft with default settings.

### AOT Cache (Ahead-Of-Time)

The pre-trained AOT cache (`HytaleServer.aot`) improves startup times by skipping JIT warmup.

**Usage:**
```bash
java -XX:AOTCache=Server/HytaleServer.aot -jar Server/HytaleServer.jar --assets Assets.zip
```

(Automatically enabled with `start-server-optimized.sh`)

### Disable Sentry

⚠️ **Important during plugin development!**

Sentry collects crash reports. Disable it during development:
```bash
java -jar Server/HytaleServer.jar --assets Assets.zip --disable-sentry
```

### Recommended JVM Arguments

For 8GB of RAM:
```bash
java \
    -Xms4G -Xmx8G \
    -XX:+UseG1GC \
    -XX:MaxGCPauseMillis=50 \
    -XX:G1HeapRegionSize=16M \
    -XX:+AlwaysPreTouch \
    -XX:+ParallelRefProcEnabled \
    -XX:+DisableExplicitGC \
    -XX:AOTCache=Server/HytaleServer.aot \
    -jar Server/HytaleServer.jar \
    --assets Assets.zip
```

## 🔄 Automatic Backups

Enable backups:
```bash
java -jar Server/HytaleServer.jar \
    --assets Assets.zip \
    --backup \
    --backup-dir backups \
    --backup-frequency 30
```

- Backups every 30 minutes
- Stored in `backups/`

## 🌐 Multi-Server Architecture

Hytale natively supports routing between servers (no need for BungeeCord).

### Player Transfer (Referral)

**From a plugin:**
```java
PlayerRef.referToServer("play.example.com", 5520, payloadBytes);
```

⚠️ **Security**: The payload goes through the client - use HMAC signature to prevent tampering.

### Redirect on Connection

**From a plugin:**
```java
PlayerSetupConnectEvent.referToServer("lobby.example.com", 5520, payloadBytes);
```

Use cases: Load balancing, regional routing, force lobby connection.

### Fallback After Disconnect

In case of crash, the client automatically reconnects to a fallback server (coming soon).

### Custom Proxy

Build custom proxies with Netty QUIC. Packet definitions available in:
```
com.hypixel.hytale.protocol.packets
```

## 🛠️ Systemd Service (Linux)

To run the server as a system service:

```bash
chmod +x install-service.sh
sudo ./install-service.sh
```

Commands:
```bash
sudo systemctl start hytale-server
sudo systemctl stop hytale-server
sudo systemctl restart hytale-server
sudo systemctl status hytale-server
sudo journalctl -u hytale-server -f  # View logs
```

## 📝 Useful Commands

### Server Help
```bash
java -jar Server/HytaleServer.jar --help
```

### Check Available Version
```bash
./hytale-downloader/hytale-downloader -print-version
```

### Update the Server
```bash
./download-server.sh  # Re-downloads the latest version
```

### Offline Mode (testing only)
```bash
java -jar Server/HytaleServer.jar --assets Assets.zip --auth-mode offline
```

## 🔐 Security and Limits

### Server Limits
- **100 servers** per Hytale license
- For more: purchase additional licenses or Server Provider account
- See: [Server Provider Authentication Guide](https://support.hytale.com/hc/en-us/articles/server-provider-guide)

### Configuration Files

Files like `config.json`, `permissions.json`, etc. are:
- Read at startup
- Written during in-game actions
- ⚠️ Manual modifications during runtime = possibly overwritten

## 🎯 Upcoming Features

- **Server Discovery**: Catalog integrated in main menu
- **Party System**: Persistent groups across servers
- **Integrated Payments**: Payment gateway in the client
- **SRV Records Support**: Under evaluation
- **First-Party APIs**: Endpoints for UUID lookup, player profiles, telemetry, etc.

## 📚 Resources

- [Official Documentation](https://support.hytale.com/hc/en-us/articles/hytale-server-manual)
- [Adoptium Java 25](https://adoptium.net/)
- [JVM Parameters Guide](https://www.baeldung.com/jvm-parameters)
- [CurseForge Hytale Mods](https://www.curseforge.com/hytale)

## 🆘 Common Problems

### "Wrong Java Version"
→ Install Java 25 from Adoptium

### "Server files not found"
→ Run `./download-server.sh`

### "Port already in use"
→ Change the port with `--bind 0.0.0.0:OTHER_PORT`

### "Players can't connect"
→ Check:
1. UDP port 5520 open in firewall
2. Port forwarding configured (UDP, not TCP)
3. Server authenticated with `/auth login device`

### "High memory usage"
→ Reduce view distance in world configuration

## 📄 License

This server requires a valid Hytale license. See [Terms of Use](https://www.hytale.com/terms).
