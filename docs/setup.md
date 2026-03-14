# ShaneBrain Core - Setup Guide

> Complete setup instructions for the ShaneBrain local AI infrastructure.

---

## Prerequisites

Before you begin, ensure you have:

- [ ] **8TB External Drive** - Mounted and accessible
- [ ] **Docker Desktop** - [Download](https://www.docker.com/products/docker-desktop/)
- [ ] **Python 3.10+** - [Download](https://www.python.org/downloads/)
- [ ] **Git** - [Download](https://git-scm.com/downloads)
- [ ] **4GB+ RAM** - Recommended for Weaviate
- [ ] **NVIDIA GPU** (Optional) - For faster Llama inference

---

## Quick Start (5 minutes)

```bash
# 1. Clone the repository to your 8TB drive
cd /mnt/8TB/  # or your drive mount point
git clone https://github.com/thebardchat/shanebrain-core.git
cd shanebrain-core

# 2. Run the setup script
chmod +x scripts/setup.sh
./scripts/setup.sh

# 3. Configure credentials
python scripts/setup_credentials.py

# 4. Start ShaneBrain
./scripts/start-shanebrain.bat  # Windows
# or
./scripts/offline-mode.sh start  # Linux/Mac
```

---

## Detailed Setup

### Step 1: Mount Your 8TB Drive

**Linux:**
```bash
# Find your drive
lsblk

# Create mount point
sudo mkdir -p /mnt/8TB

# Mount (replace sdX with your drive)
sudo mount /dev/sdX1 /mnt/8TB

# Add to /etc/fstab for auto-mount:
# UUID=your-uuid /mnt/8TB ext4 defaults 0 2
```

**Windows:**
- Drive should auto-mount as a letter (e.g., `D:\`)
- Update `SHANEBRAIN_ROOT` in `.env` to match

### Step 2: Clone Repository

```bash
cd /mnt/8TB
git clone https://github.com/thebardchat/shanebrain-core.git
cd shanebrain-core
```

### Step 3: Run Setup Script

```bash
chmod +x scripts/setup.sh
./scripts/setup.sh
```

This will:
- Create directory structure
- Install Python dependencies
- Start Docker services
- Initialize Weaviate schemas

### Step 4: Configure Credentials

```bash
python scripts/setup_credentials.py
```

You'll be prompted for:
- **ShaneBrain root path** - Your 8TB drive location
- **MongoDB Atlas** (optional) - Cloud backup credentials
- **Weaviate Cloud** (optional) - Cloud backup credentials
- **Encryption key** - Auto-generated if not provided

### Step 5: Download Llama Models (Optional)

```bash
chmod +x llama-configs/download-models.sh
./llama-configs/download-models.sh
```

Or use Ollama:
```bash
# Install Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Download Llama 3.2
ollama pull llama3.2
```

### Step 6: Verify Installation

```bash
python scripts/health_check.py
```

You should see all green checkmarks.

---

## Configuration

### Environment Variables

Key variables in `.env`:

| Variable | Description | Default |
|----------|-------------|---------|
| `SHANEBRAIN_ROOT` | Root data directory | `/mnt/8TB/ShaneBrain-Core` |
| `WEAVIATE_HOST` | Weaviate host | `localhost` |
| `WEAVIATE_PORT` | Weaviate port | `8080` |
| `MONGODB_LOCAL` | Use local MongoDB | `true` |
| `LLAMA_DEFAULT_MODEL` | Default Llama model | `llama-3.2-3b` |

### Directory Structure

After setup, your 8TB drive will have:

```
/mnt/8TB/ShaneBrain-Core/
├── weaviate-config/data/     # Vector database (grows over time)
├── mongodb-data/             # Document database
├── llama-configs/models/     # AI models (~2-15GB each)
├── backups/                  # Automatic backups
├── logs/                     # System logs
└── planning-system/          # Your project files
```

---

## First Run

### Create Your First Project

1. Copy a template:
```bash
cp planning-system/templates/angel-cloud-template.md \
   planning-system/active-projects/task_plan.md
```

2. Edit your task plan:
```bash
nano planning-system/active-projects/task_plan.md
```

3. Start working with Claude:
```
Load my planning files from active-projects/
```

### Test the Agent

```bash
python langchain-chains/shanebrain_agent.py
```

---

## Troubleshooting

### Docker Issues

**Docker not running:**
```bash
# Linux
sudo systemctl start docker

# Windows/Mac
# Start Docker Desktop application
```

**Permission denied:**
```bash
sudo usermod -aG docker $USER
# Log out and back in
```

### Weaviate Issues

**Connection refused:**
```bash
cd weaviate-config
docker-compose up -d
docker-compose logs -f
```

**Out of memory:**
Edit `docker-compose.yml` and reduce memory limits.

### Model Issues

**Model not found:**
```bash
./llama-configs/download-models.sh list
./llama-configs/download-models.sh 3b
```

---

## Next Steps

1. **Read the Architecture Guide** - [architecture.md](architecture.md)
2. **Set up Planning System** - [planning-system.md](planning-system.md)
3. **Review Security Practices** - [security.md](security.md)
4. **Start Building!**

---

## Getting Help

- **Health Check:** `python scripts/health_check.py --verbose`
- **Logs:** `docker-compose logs -f` (in weaviate-config/)
- **GitHub Issues:** [Report a bug](https://github.com/thebardchat/shanebrain-core/issues)

---

**Remember: Progress, not perfection!**
