# ShaneBrain Core - Troubleshooting Guide

> Solutions to common problems with ShaneBrain.

---

## Quick Diagnostics

```bash
# Run full health check
python scripts/health_check.py --verbose

# Check Docker status
docker ps

# Check Weaviate
curl http://localhost:8080/v1/.well-known/ready

# Check disk space
df -h
```

---

## Docker Issues

### Docker Not Running

**Symptoms:**
- "Cannot connect to Docker daemon"
- "docker: command not found"

**Solutions:**

Linux:
```bash
# Start Docker
sudo systemctl start docker

# Enable on boot
sudo systemctl enable docker

# Check status
sudo systemctl status docker
```

Windows/Mac:
- Open Docker Desktop application
- Wait for it to fully start (whale icon stops animating)

### Permission Denied

**Symptoms:**
- "Got permission denied while trying to connect"

**Solutions:**

```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Log out and back in, or:
newgrp docker

# Verify
docker ps
```

### Container Won't Start

**Symptoms:**
- "Container exited with code 1"
- Container keeps restarting

**Solutions:**

```bash
# Check logs
cd weaviate-config
docker-compose logs weaviate

# Common fixes:
# 1. Remove old containers
docker-compose down -v
docker-compose up -d

# 2. Check port conflicts
sudo lsof -i :8080

# 3. Check disk space
df -h
```

---

## Weaviate Issues

### Connection Refused

**Symptoms:**
- "ConnectionRefusedError"
- "Could not connect to Weaviate"

**Solutions:**

```bash
# 1. Check if running
docker ps | grep weaviate

# 2. Start if not running
cd weaviate-config
docker-compose up -d

# 3. Wait for ready
for i in {1..30}; do
  curl -s http://localhost:8080/v1/.well-known/ready && break
  sleep 2
done

# 4. Check logs if still failing
docker-compose logs weaviate
```

### Out of Memory

**Symptoms:**
- Weaviate crashes after adding data
- "OOM killed" in logs

**Solutions:**

```yaml
# Edit docker-compose.yml
services:
  weaviate:
    deploy:
      resources:
        limits:
          memory: 4g  # Increase this
```

Then restart:
```bash
docker-compose down
docker-compose up -d
```

### Schema Not Found

**Symptoms:**
- "Class 'ShanebrainMemory' not found"

**Solutions:**

```bash
# Reinitialize schemas
python << 'EOF'
import weaviate
import json
from pathlib import Path

client = weaviate.Client("http://localhost:8080")

for schema_file in Path("weaviate-config/schemas").glob("*.json"):
    with open(schema_file) as f:
        schema = json.load(f)
    try:
        client.schema.create_class(schema)
        print(f"Created: {schema['class']}")
    except Exception as e:
        print(f"Exists or error: {e}")
EOF
```

---

## MongoDB Issues

### Connection Failed

**Symptoms:**
- "ServerSelectionTimeoutError"
- Cannot connect to MongoDB

**Solutions:**

Local MongoDB:
```bash
# Check if running
sudo systemctl status mongod

# Start if not
sudo systemctl start mongod

# Or use Docker
docker run -d -p 27017:27017 --name mongo mongo:latest
```

Atlas MongoDB:
```bash
# Test connection string
python << 'EOF'
from pymongo import MongoClient
import os
uri = os.environ.get("MONGODB_ATLAS_URI")
if uri:
    client = MongoClient(uri, serverSelectionTimeoutMS=5000)
    print(client.admin.command('ping'))
EOF
```

### Authentication Failed

**Symptoms:**
- "Authentication failed"

**Solutions:**

1. Check credentials in `.env`
2. URL-encode special characters in password
3. Verify user has correct permissions in Atlas

```python
# URL-encode password
from urllib.parse import quote_plus
password = quote_plus("my@password!")
```

---

## Llama/Model Issues

### Model Not Found

**Symptoms:**
- "Model file not found"
- LLM returns empty responses

**Solutions:**

```bash
# List installed models
ls -la llama-configs/models/

# Download if missing
./llama-configs/download-models.sh 3b

# Or use Ollama
ollama list
ollama pull llama3.2
```

### Out of Memory (GPU)

**Symptoms:**
- "CUDA out of memory"
- Model crashes during inference

**Solutions:**

1. Use smaller model:
```bash
# Use 3B instead of 11B
export LLAMA_DEFAULT_MODEL=llama-3.2-3b
```

2. Reduce GPU layers in `.env`:
```
LLAMA_GPU_LAYERS=20  # Lower number
```

3. Use CPU-only:
```
LLAMA_GPU_LAYERS=0
```

### Slow Inference

**Symptoms:**
- Responses take > 30 seconds
- High CPU usage

**Solutions:**

1. Use quantized models (Q4_K_M)
2. Enable GPU if available
3. Reduce context length:
```
LLAMA_CONTEXT_LENGTH=2048  # Reduce from 4096
```

---

## Planning System Issues

### Files Not Found

**Symptoms:**
- "task_plan.md not found"
- Planning context not loading

**Solutions:**

```bash
# Check files exist
ls -la planning-system/active-projects/

# Create if missing
cp planning-system/templates/angel-cloud-template.md \
   planning-system/active-projects/task_plan.md
```

### Git Conflicts

**Symptoms:**
- Planning files showing as changed in git
- Merge conflicts

**Solutions:**

Planning files are in `.gitignore` for privacy. If you're seeing them:

```bash
# Remove from git tracking
git rm --cached planning-system/active-projects/*.md

# Verify .gitignore
cat .gitignore | grep planning
```

---

## Environment Issues

### .env Not Loading

**Symptoms:**
- "Environment variable not found"
- Defaults being used instead of configured values

**Solutions:**

```bash
# Check file exists
ls -la .env

# Check permissions
stat .env
# Should be -rw------- (600)

# Fix permissions
chmod 600 .env

# Test loading
python -c "
from pathlib import Path
for line in Path('.env').read_text().splitlines():
    if line and not line.startswith('#'):
        print(line.split('=')[0])
"
```

### Path Issues

**Symptoms:**
- "Directory not found"
- Wrong data location

**Solutions:**

```bash
# Check SHANEBRAIN_ROOT
echo $SHANEBRAIN_ROOT

# Verify path exists
ls -la /mnt/8TB/ShaneBrain-Core/

# Update .env if wrong
nano .env
# Change SHANEBRAIN_ROOT to correct path
```

---

## Network Issues

### Can't Download Models

**Symptoms:**
- Download fails or times out
- SSL errors

**Solutions:**

```bash
# Test connectivity
curl -I https://huggingface.co

# Use alternative download
wget -c [model-url]

# Or download on another machine and copy
```

### Port Conflicts

**Symptoms:**
- "Address already in use"
- Service won't start

**Solutions:**

```bash
# Find what's using the port
sudo lsof -i :8080
sudo lsof -i :27017

# Kill the process
sudo kill -9 [PID]

# Or change ports in docker-compose.yml
```

---

## Performance Issues

### Slow Queries

**Symptoms:**
- Weaviate queries > 5 seconds
- Agent responses very slow

**Solutions:**

1. Check Weaviate memory:
```bash
docker stats shanebrain-weaviate
```

2. Limit query results:
```python
.with_limit(5)  # Not 100
```

3. Use filters to narrow search

### High Disk Usage

**Symptoms:**
- Disk filling up
- Backup failures

**Solutions:**

```bash
# Check usage
du -sh /mnt/8TB/ShaneBrain-Core/*

# Clean old backups
./scripts/backup.sh cleanup

# Remove old Docker data
docker system prune -a
```

---

## Getting More Help

### Collect Diagnostics

```bash
# Create diagnostic report
python scripts/health_check.py --json > diagnostics.json
docker-compose logs > docker-logs.txt
df -h > disk-usage.txt
```

### Where to Ask

1. **GitHub Issues:** [Report a bug](https://github.com/thebardchat/shanebrain-core/issues)
2. **Check Logs:** Always include relevant log output
3. **Health Check:** Run before asking for help

### Information to Include

When reporting issues:
- Health check output
- Error message (full)
- Steps to reproduce
- Your environment (OS, Docker version, etc.)

---

**Still stuck? Run the health check and share the output.**

```bash
python scripts/health_check.py --verbose --json
```
