# 🎮 Hytale Server Setup

Two options to run your Hytale server on Linux: **Docker** (recommended) or **Bash scripts**.

---

## 🐳 Option 1: Docker (Recommended)

**Advantages**: Isolated environment, automatic updates, easy backups, cross-platform.

### Prerequisites
- **Docker** & **Docker Compose** installed
- **4GB RAM minimum** (8GB recommended)
- **UDP port 5520** open

### Quick Setup

```bash
# 1. Install & start server
./hytale.sh install
./hytale.sh start

# 2. First connection - authenticate
./hytale.sh console
# Type: /auth login device
# Follow the link: https://accounts.hytale.com/device
```

### Commands

```bash
./hytale.sh start         # Start server
./hytale.sh stop          # Stop server gracefully
./hytale.sh restart       # Restart server
./hytale.sh console       # Access console (exit: Ctrl+A then D)
./hytale.sh logs          # View logs
./hytale.sh status        # Server status

./hytale.sh backup        # Create backup
./hytale.sh restore       # Restore from backup
./hytale.sh update        # Update server (with auto-backup)

./hytale.sh reset         # Reset everything (⚠️ destructive)
```

**Memory/RAM config**: Edit `docker-compose.yml` (XMS/XMX variables), see [Performance Tuning](#%EF%B8%8F-performance-tuning).  
**Backups**: Automatic rotation (keeps 10 most recent), update backups named `pre_update_*`.

---

## 🔧 Option 2: Bash Scripts

**Advantages**: Direct control, no Docker needed, systemd service support.

### Prerequisites
- **Java 25** (auto-installed by script)
- **4GB RAM minimum** (8GB recommended)  
- **UDP port 5520** open

### Quick Setup

```bash
cd scripts

# 1. Download server
./download-server.sh

# 2. Install systemd service (optional)
sudo ./install-service.sh

# 3. Start server
sudo systemctl start hytale-server
# Or without service: ./start-server-optimized.sh
```

### Commands

**With systemd service**:
```bash
sudo systemctl start hytale-server      # Start
sudo systemctl stop hytale-server       # Stop
sudo systemctl restart hytale-server    # Restart
sudo systemctl status hytale-server     # Status
```

**Direct scripts** (in `scripts/` folder):
```bash
./download-server.sh        # Download/update server
./start-server-optimized.sh # Start server
./console.sh                # Access console (exit: Ctrl+A then D)
./backup.sh                 # Create backup
./restore-backup.sh         # Restore from backup
./reset.sh                  # Reset everything (⚠️ destructive)
```

---

## 🔥 Firewall Configuration

### Ubuntu/Debian
```bash
sudo ufw allow 5520/udp
```

### RHEL/CentOS/Fedora
```bash
sudo firewall-cmd --permanent --add-port=5520/udp
sudo firewall-cmd --reload
```

### Router/NAT
Port forward **UDP 5520** to your server's local IP.

**Verify**:
```bash
sudo ss -tulpn | grep 5520
```

---

## 📁 File Structure

```
hytale-server/
├── hytale.sh              # Docker management (Option 1)
├── docker-compose.yml     # Docker config
├── Dockerfile
├── scripts/               # Bash scripts (Option 2)
│   ├── download-server.sh
│   ├── install-service.sh
│   ├── start-server-optimized.sh
│   ├── console.sh
│   ├── backup.sh
│   ├── restore-backup.sh
│   └── reset.sh
├── Server/                # Server files
├── Assets.zip             # Game assets (3.5GB)
├── universe/              # Worlds
├── mods/                  # Mods
├── logs/                  # Logs
├── backups/               # Backups
├── config.json            # Server config
└── auth.enc               # Authentication
```

---

## 🎮 Add Mods

1. Download mods (`.zip` or `.jar`)
2. Place in `mods/` folder
3. Restart server

**Docker**: `./hytale.sh restart`  
**Scripts**: `sudo systemctl restart hytale-server`

---

## 🔄 Update Server

### Docker
```bash
./hytale.sh update
# Auto-creates backup → rebuilds image → restarts
```

### Bash Scripts
```bash
cd scripts
./backup.sh                  # Create backup first
sudo systemctl stop hytale-server
./download-server.sh         # Download new version
sudo systemctl start hytale-server
```

---

## ⚙️ Performance Tuning

### View Distance
Main RAM consumer. Edit `config.json`:
```json
"MaxViewRadius": 8
```
- **8 chunks**: ~4GB RAM
- **12 chunks**: ~8GB RAM
- **16+ chunks**: 12GB+ RAM

### Memory Settings

**Docker**: Edit `docker-compose.yml`
```yaml
environment:
  - XMS=4G    # Initial
  - XMX=8G    # Maximum
```

**Bash**: Edit `scripts/start-server-optimized.sh`
```bash
-Xms4G -Xmx8G
```

---

## ❓ Troubleshooting

| Problem | Solution |
|---------|----------|
| Server won't start | **Docker**: Check logs with `./hytale.sh logs`<br>**Scripts**: Check Java 25 with `java --version` |
| Can't connect | Verify UDP 5520 open + port forwarding configured |
| High RAM usage | Reduce `MaxViewRadius` in `config.json` |
| Auth error | Run `/auth login device` in console |
| Console stuck | Exit with **Ctrl+A then D** (not Ctrl+C!) |

---

## 🆘 Support

- [Hytale Server Manual](https://support.hytale.com/hc/en-us/articles/hytale-server-manual)
- [Support Portal](https://hytale.com/support)
- [Java 25 Download](https://adoptium.net/)

---

## 📄 License

Requires valid Hytale license. See [Terms of Use](https://www.hytale.com/terms).

