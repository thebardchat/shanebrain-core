# Changelog

All notable changes to ShaneBrain Core infrastructure and services.

## 2026-03-06 — System Maintenance & Optimization

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
