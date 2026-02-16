# CLAUDE.md - ShaneBrain Core Project Context

> **Updated:** February 15, 2026
> **Version:** 2.2
> **Owner:** Shane Brazelton (SRM Dispatch, Alabama)
> **Repo:** github.com/thebardchat/shanebrain-core

## What Is This Project?

ShaneBrain Core — a personal AI assistant/legacy system running on Raspberry Pi 5. Python stack with Ollama llama3.2:1b for local LLM, Weaviate for vector/RAG storage, Open WebUI for chat interface. Local-first, cloud-backup — everything runs offline with cloud as optional redundancy.

## Hardware

- Raspberry Pi 5, 16GB RAM
- Pironman 5-MAX case with dual WD Blue SN5000 2TB NVMe (RAID 1)
- RAID 1 storage at /mnt/shanebrain-raid/
- 8TB external at /media/shane/ANGEL_CLOUD (NTFS via ntfs-3g)
- Wired ethernet, Tailscale VPN (100.67.120.6)
- Always-on, 27W USB-C power
- System username: shanebrain

## Running Services

| Service | Port | Container |
|---------|------|-----------|
| Ollama | 11434 | Native (systemd) — llama3.2:1b, llama3.2:3b, nomic-embed-text |
| Weaviate | 8080 (REST), 50051 (gRPC) | Docker: shanebrain-weaviate |
| Open WebUI | 3000 | Docker: open-webui |
| Portainer CE | 9000 | Docker: portainer |
| Angel Cloud Gateway | 4200 | systemd: angel-cloud-gateway (FastAPI/uvicorn) |
| GitHub Poller | — | systemd timer: angel-cloud-github-poller (every 15 min) |
| Social Bot | — | systemd: shanebrain-social |
| Discord Bot | — | systemd: shanebrain-discord |
| Arcade Bot | — | systemd: shanebrain-arcade |
| Glances | 61208 | System monitor |
| Tailscale | — | 100.67.120.6 |

## Key Files

- RAG.md — ShaneBrain personality and knowledge (MOST IMPORTANT FILE)
- CLAUDE.md — This file (project context for Claude Code)
- angel_cloud_cli.py — CLI interface
- scripts/ — Python scripts
- scripts/weaviate_helpers.py — Weaviate CRUD (Conversation, LegacyKnowledge, CrisisLog, SocialKnowledge, FriendProfile)
- scripts/import_rag_to_weaviate.py — RAG ingestion into Weaviate
- weaviate-config/docker-compose.yml — Docker config
- bot/ — Discord ShaneBrain bot (v5.4 with Weaviate harvesting)
- arcade/ — Angel Arcade revenue bot
- social/ — Facebook social bot with Weaviate knowledge harvesting
- social/fb_bot.py — Main entry point (`python -m social.fb_bot`)
- social/facebook_api.py — Facebook Graph API wrapper
- social/comment_harvester.py — Polls comments, stores in Weaviate
- social/friend_profiler.py — Builds living friend profiles
- systemd/shanebrain-social.service — systemd unit file
- angel-cloud/ — Angel Cloud Gateway (FastAPI, port 4200)
- angel-cloud/gateway.py — Main FastAPI app (registration, login, dashboard, community, Discord/GitHub link APIs)
- angel-cloud/models.py — SQLite user model + angel progression + activity log + Discord/GitHub linking + leaderboard
- angel-cloud/weaviate_bridge.py — Creates FriendProfile on registration
- angel-cloud/github_poller.py — Polls GitHub commits/PRs every 15 min, awards points to linked users
- angel-cloud/templates/community.html — Community leaderboard + activity feed
- systemd/angel-cloud-gateway.service — systemd unit file
- langchain-chains/ — Agent modes: CHAT, MEMORY, WELLNESS, SECURITY, DISPATCH, CODE

## Ecosystem Projects

| Project | Repo | Status | Description |
|---------|------|--------|-------------|
| ShaneBrain Core | shanebrain-core | Active | Central AI orchestrator, Discord bot, social bot |
| Pulsar Sentinel | pulsar_sentinel | Active | Post-quantum security framework, full UI |
| Loudon/DeSarro | loudon-desarro | Active | 50,000 SF athletic complex 3D visualizations |
| Mini-ShaneBrain | mini-shanebrain | DEPRECATED | Merged into shanebrain-core/social/ (Feb 15) |
| Angel Cloud Gateway | (in shanebrain-core/angel-cloud/) | Active | Front door — registration, login, angel progression, streaming chat, community leaderboard, Discord + GitHub cross-platform point system |
| Angel Arcade | (in shanebrain-core) | Active | Discord economy/casino bot |
| Legacy AI | Planned | Planned | Personal "TheirNameBrain" for each family member |
| LogiBot | Planned | Planned | SRM Dispatch automation |

## Guidelines

- Optimize everything for ARM64 (aarch64) architecture
- Python 3.11+, keep scripts modular and lean
- Never suggest cloud dependencies unless explicitly asked
- All data stays local on RAID
- RAG.md is the source of truth for who Shane is
- Use weaviate-client v4 for all Weaviate interactions
- Ollama endpoint: http://localhost:11434
- Weaviate endpoint: http://localhost:8080
- ALWAYS use nofail in /etc/fstab entries
- System username is shanebrain (not shane)

## Project Owner

Shane Brazelton — dump truck dispatcher in Meridianville, Alabama building AI infrastructure for families. Direct communicator. Solutions over explanations. "File structure first."

## The Mission

800 million Windows users losing security updates. ShaneBrain proves affordable local AI works. Angel Cloud ecosystem: mental wellness + security + digital legacy for every family.

## Common Commands

```bash
# Install dependencies
pip install -r requirements.txt

# Start/Stop Weaviate
cd weaviate-config && docker-compose up -d
cd weaviate-config && docker-compose down

# Social bot
python -m social.fb_bot --verify       # Check Facebook token
python -m social.fb_bot --dry-run      # Preview a post
python -m social.fb_bot --post         # Publish one post
python -m social.fb_bot --harvest      # Poll comments into Weaviate
python -m social.fb_bot --status       # Show page stats
python -m social.fb_bot --friends      # Show friend profiles
python -m social.fb_bot                # Start scheduler (posting + harvesting)

# Angel Cloud Gateway
sudo systemctl start angel-cloud-gateway    # Start gateway on port 4200
sudo systemctl status angel-cloud-gateway   # Check status
curl http://localhost:4200/api/health        # Health check
curl http://localhost:4200/api/stats         # Public stats
```

## Security

- NEVER commit `.env` files
- NEVER paste connection strings in chat
- Keep repos PRIVATE until production ready
- Use Tailscale for remote access, not port forwarding
- UFW firewall, fail2ban, unattended-upgrades on Pi

## Contact

**Owner:** Shane Brazelton
**Company:** SRM Dispatch (Alabama)
**Ko-fi:** ko-fi.com/shanebrain
**Discord:** discord.gg/xbHQZkggU7
**Mission:** 800 million users. Digital legacy for generations.
