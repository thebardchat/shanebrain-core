# Changelog

All notable changes to ShaneBrain Core infrastructure and services.

## 2026-03-07 — Security Logging & Hardening

### Angel Cloud Gateway Security Logging
- Wired `log_security_event()` into gateway for: failed logins, registrations, password changes, unauthorized bot API calls
- Events logged to Weaviate `SecurityLog` collection with event_type, source, severity, timestamp
- All 4 bot-secret-protected endpoints now log unauthorized access attempts as severity=high
- End-to-end verified: failed login → Weaviate SecurityLog → CLI viewer

### PrivacyAudit Pipeline
- Added `log_privacy_event()` to `weaviate_bridge.py` — logs to PrivacyAudit collection
- Wired into gateway for: account creation, password changes, Discord/GitHub/Roblox account linking
- Audit trail for all PII storage and cross-platform identity linking events

### Gateway Sessions — SQLite Persistence
- Sessions now stored in `angel_cloud.db` `sessions` table instead of in-memory dict
- Users stay logged in across gateway restarts (30-day expiry)
- Expired sessions auto-cleaned on startup
- Added `create_session()`, `get_session_user()`, `delete_session()`, `cleanup_expired_sessions()` to models.py

### MCP Server
- Added `security_log_recent` tool (chronological fetch, complements semantic search) — now 20 tools across 9 groups
- Security group: search (semantic), recent (chronological), privacy audit search

### Restic Backup Hardening
- Added `mountpoint -q` check to `scripts/backup.sh` — skips backup if 8TB external not mounted
- Added `angel-cloud/`, `mcp-server/`, `langchain-chains/` to backup list (were missing)

### Weaviate Helpers
- Added `get_recent_security_events()` method with optional severity filter
- CLI demo now lists all 17 collections with total object count
- Added `--security` CLI flag: `python scripts/weaviate_helpers.py --security [severity]`

### Social Bot
- Version bumped to v2.0.0 (reflects dedup, token monitoring, misfire protection from v1)
- Added `--security` command to view security events with color-coded severity

### Fixes
- Updated gateway landing page fallback counts (165→153 knowledge, 51→61 conversations)
- Updated CLAUDE.md to reflect 20 MCP tools

---

## 2026-03-06 — System Maintenance & Optimization

### Social Bot Hardening
- Fixed burst post bug: added `misfire_grace_time=60` and `coalesce=True` to APScheduler jobs
- Previously, every restart fired all "missed" cron triggers at once (15 burst posts in one incident)
- Deleted 15 burst duplicate posts from Facebook
- Bot now skips missed triggers older than 60 seconds on startup
- Added dedup protection: MD5 hash check prevents posting identical content back-to-back
- Added daily token expiry monitoring (checks on startup + every 24h, warns at <30 days)
- Added `--verify` now shows token expiry date and days remaining
- Added `delete_post()` method to FacebookAPI

### Weaviate Collection Migration
- Migrated 6 training collections from `vectorizer: none` to `text2vec-ollama + nomic-embed-text`
- BrainDoc (3), BusinessDoc (5), Document (1), DraftTemplate (5), MessageLog (5), MyBrain (3)
- All 17 collections now support semantic search (previously only 10 could)

### Environment Fix
- Fixed Windows line endings (`\r`) in `.env` via `dos2unix`
- Quoted values with spaces/commas (`PAGE_PERSONALITY`, `FACEBOOK_POST_SCHEDULE`)
- Moved restic password from hardcoded in `backup.sh` to `.env`

### Weaviate Automated Backups
- Created `scripts/weaviate_backup.sh` — daily filesystem backup of all 16 collections
- Keeps last 7 days of backups, auto-prunes older ones
- Cron job at 3:15 AM daily (after existing restic backup at 3:00 AM)
- Logs to `social/logs/weaviate-backup.log`

### MCP Server Fixes
- Added HTTP `/health` endpoint (returns Weaviate + Ollama status, 200/503)
- Added Docker healthcheck to MCP container in `docker-compose.yml`
- Fixed connection leak: all 19 tools now use `with` context manager instead of manual connect/close
- Fixed `get_all_collection_counts()` — now includes all 16 collections (was missing 6 training-module collections)
- Fixed docstring: corrected transport description (SSE, not Streamable HTTP) and group count (9, not 7)

### Service Updates
- Ollama updated 0.15.6 → 0.17.7
- Weaviate updated 1.28.0 → 1.36.2 (data auto-migrated, 17 collections / 251 objects intact)
- Open WebUI updated to latest `main` image (1.4 GB old layers pruned)
- Portainer CE pulled fresh `latest` image

### Storage Optimization
- **SD card: 92% → 44%** (2.5 GB → 16 GB free)
  - Removed unused desktop apps: Chromium, Firefox, LibreOffice, FreeCAD (~3.2 GB)
  - Moved containerd to RAID at `/mnt/shanebrain-raid/containerd/` (~6.5 GB)
  - Moved Ollama libs to RAID, symlinked `/usr/local/lib/ollama` → `/mnt/shanebrain-raid/ollama/lib` (~3.4 GB)
  - Cleared apt + pip cache (~0.8 GB)
- **RAID: 26 GB → 19 GB used**
  - Removed duplicate containerd data from move (6.5 GB)
  - Removed unused Weaviate `latest` image (261 MB)
  - Removed deprecated mini-shanebrain directory
- **8TB external: 49 GB → 36 GB used**
  - Removed Angel_Cloud/Cache (6.3 GB)
  - Removed old Ollama_Data backup (6.3 GB)
  - Removed .tmp.driveupload, stale angelcloud copies

### Configuration
- Containerd root moved to RAID, config at `/etc/containerd/config.toml`
- Ollama libs symlinked to RAID: `/usr/local/lib/ollama` → `/mnt/shanebrain-raid/ollama/lib`
- MCP server transport committed: streamable-http → SSE
- `.gitignore` hardened: blocks `*.env.txt`, `*.db`, state files, training output dirs
- `CLAUDE.md` updated to v2.4 (Ollama 0.17.7, 17 Weaviate collections, Python 3.13, SSE)
- Deleted redundant `.env.txt` files containing exposed secrets

### Containers
- Open WebUI + Portainer recreated after containerd move (data preserved via RAID volumes)
- All 4 containers healthy: Weaviate, MCP, Open WebUI, Portainer

### Social Bot Upgrades
- Posts now signed `— ShaneBrain AI` with AI disclosure in generation prompt
- Auto-reply enabled: harvester replies to Facebook comments every 15 min, signed as AI
- Deleted 3 duplicate burst posts caused by scheduler flush during restart
- Reply prompt explicitly identifies as Shane's AI assistant, never impersonates
- Switched from llama3.2:1b to shanebrain-3b (fixed repetitive BGKPJR content)
- Expanded PAGE_PERSONALITY with full bio (Alabama, dispatch, ADHD, sobriety, faith)
- Post prompt blocks space/rocket/BGKPJR drift, focuses on everyday life

### Final System State
- **Hardware:** Pi 5 — 40.6°C, 5.1 GB RAM used / 15 GB, load 2.5
- **Storage:** SD 44% (16 GB free) | RAID 2% (1.7 TB free) | 8TB 1% (7.3 TB free)
- **RAID:** [UU] both NVMe drives healthy
- **Services:** 6/6 systemd active (Ollama, Discord, Arcade, Social, Gateway, Rojo)
- **Containers:** 4/4 healthy (Weaviate 1.36.2, MCP, Open WebUI, Portainer CE)
- **Ollama:** v0.17.7 — 4 models (shanebrain-3b, llama3.2:3b, llama3.2:1b, nomic-embed-text)
- **Weaviate:** v1.36.2 — 17 collections, 251 objects
- **Endpoints:** Gateway :4200 (200), Open WebUI :3000 (200), Portainer :9000 (307), Weaviate :8080 (ready)

---

## 2026-02-20 — MCP Server

- Built custom FastMCP server exposing 19 ShaneBrain tools
- Docker container `shanebrain-mcp` on port 8100
- 9 tool groups: Knowledge, Chat, RAG, Social, Vault, Notes, Drafts, Security, System
- Registered globally with Claude Code

## 2026-02-16 — RAID Migration & Roblox Game

- Ollama models moved from SD card to RAID
- Docker data-root moved from SD card to RAID
- SD card freed from 92% to 79%
- Built "The Cloud Climb" Roblox game MVP (32 Luau files)
- Added tmux dashboard, starship prompt, shell configs

## 2026-02-15 — Foundation Fixes

- UFW rules for Docker bridge networks to Ollama
- Rebuilt Conversation + CrisisLog collections (text2vec-ollama)
- Rebuilt LegacyKnowledge with nomic-embed-text (fixed 2048→768 dim mismatch)
- Created shanebrain-3b custom model from llama3.2:3b
- Archived 19 repos, merged 4 repos
- Removed leaked .env from angel-cloud-auth-bridge
