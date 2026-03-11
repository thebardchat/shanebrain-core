# 🗄️ RAID Migration — All Repos to Unified Root
### shanebrain-core · March 2026

---

## Goal

Every `thebardchat` repo cloned to a single RAID root so:
- Claude Code launched from one place knows every project
- N8N on Pulsar0100 has predictable paths
- One backup command covers the entire ecosystem
- No more "where did I put that?" — ever

---

## Target Structure

```
/mnt/shanebrain-raid/shanebrain-core/
├── shanebrain-core/        ← already here ✅
├── constitution/           ← reference copy
├── srm-dispatch/           
├── thought-tree/           
├── mini-shanebrain/        
└── angel-cloud-roblox/     
```

---

## Pre-flight Checks

```bash
# Verify RAID is mounted and healthy
df -h /mnt/shanebrain-raid
cat /proc/mdstat

# Check available space (need ~2GB for all repos)
du -sh /mnt/shanebrain-raid/shanebrain-core/

# Confirm you're on the right machine
hostname   # should be: shanebrain-1
```

---

## Migration Script

Run this on the Pi. SSH in first:
```bash
ssh shane@100.67.120.6
```

Then:
```bash
#!/bin/bash
# migrate-repos.sh
# Run from Pi · clones all thebardchat repos to RAID root

RAID_ROOT="/mnt/shanebrain-raid/shanebrain-core"
GITHUB="https://github.com/thebardchat"

echo "📍 Working from: $RAID_ROOT"
cd "$RAID_ROOT" || { echo "❌ RAID not mounted!"; exit 1; }

REPOS=(
  "constitution"
  "srm-dispatch"
  "thought-tree"
  "mini-shanebrain"
  "angel-cloud-roblox"
)

for REPO in "${REPOS[@]}"; do
  if [ -d "$REPO" ]; then
    echo "🔄 Updating: $REPO"
    cd "$REPO" && git pull && cd "$RAID_ROOT"
  else
    echo "📥 Cloning: $REPO"
    git clone "$GITHUB/$REPO.git"
  fi
done

echo ""
echo "✅ All repos synced to RAID"
echo ""
ls -la "$RAID_ROOT"
```

Save as `/mnt/shanebrain-raid/shanebrain-core/migrate-repos.sh` then:
```bash
chmod +x migrate-repos.sh
./migrate-repos.sh
```

---

## Per-Repo Checklist

After cloning each repo, drop in the new CLAUDE.md files from this session:

### `constitution/`
- [ ] Cloned to RAID ✓
- [ ] `CONSTITUTION.md` matches GitHub version

### `srm-dispatch/`
- [ ] Cloned to RAID
- [ ] Replace `README.md` with updated version
- [ ] Add `CLAUDE.md` (new file)
- [ ] Set repo About + topics on GitHub

### `thought-tree/`
- [ ] Cloned to RAID
- [ ] Replace `README.md` with updated version
- [ ] Add `CLAUDE.md` (new file)
- [ ] Set repo About + topics on GitHub

### `mini-shanebrain/`
- [ ] Cloned to RAID
- [ ] Update `README.md` header
- [ ] Add `CLAUDE.md` (new file)
- [ ] Test Ollama fallback still works from RAID path

### `angel-cloud-roblox/`
- [ ] Cloned to RAID
- [ ] Update `README.md` header
- [ ] Add `CLAUDE.md` (new file)
- [ ] Confirm Rojo sync path still correct

### `shanebrain-core/`
- [ ] Already on RAID ✓
- [ ] Replace `README.md` with modernized version
- [ ] Replace `CLAUDE.md` with v2.1

---

## Daily Sync Script

Once everything is on RAID, add this to cron or run manually:

```bash
#!/bin/bash
# sync-all-repos.sh — run daily or before major work sessions

RAID_ROOT="/mnt/shanebrain-raid/shanebrain-core"

for dir in "$RAID_ROOT"/*/; do
  if [ -d "$dir/.git" ]; then
    REPO=$(basename "$dir")
    echo "🔄 $REPO"
    cd "$dir" && git pull --quiet
  fi
done

echo "✅ All repos current"
```

Add to crontab (optional):
```bash
crontab -e
# Add line: 0 6 * * * /mnt/shanebrain-raid/shanebrain-core/sync-all-repos.sh
```

---

## Claude Code Launch from RAID Root

From any project on the RAID, Claude Code has full ecosystem awareness:

```bash
# Launch from ecosystem root — sees everything
cd /mnt/shanebrain-raid/shanebrain-core/
claude

# Or launch from specific project
cd /mnt/shanebrain-raid/shanebrain-core/srm-dispatch/
claude
```

---

## N8N Path Update (Pulsar0100)

After migration, update any N8N workflows on Pulsar0100 that reference old paths.
Old path pattern: `/home/shane/[repo]/`
New path pattern: `/mnt/shanebrain-raid/shanebrain-core/[repo]/`

Access N8N from Pi via Tailscale: `http://100.81.70.117:[N8N_PORT]`

---

## Backup Command (covers everything)

```bash
# Full ecosystem backup — one command
rsync -av --progress \
  /mnt/shanebrain-raid/shanebrain-core/ \
  shane@[BACKUP_DESTINATION]:/shanebrain-backup/

# Or tar for local snapshot
tar -czf /mnt/shanebrain-raid/backups/ecosystem-$(date +%Y%m%d).tar.gz \
  /mnt/shanebrain-raid/shanebrain-core/
```

---

## Verification

After migration is complete:

```bash
# Confirm all repos present
ls /mnt/shanebrain-raid/shanebrain-core/

# Confirm RAID health
cat /proc/mdstat

# Confirm all services still running
docker ps                          # Weaviate + Open WebUI
curl http://localhost:11434/api/tags  # Ollama
curl http://localhost:8008/health     # FastMCP
```

---

*Migration doc · March 2026 · thebardchat ecosystem*
