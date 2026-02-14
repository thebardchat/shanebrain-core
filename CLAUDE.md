# CLAUDE.md - ShaneBrain Core

> **Last Updated:** February 14, 2026
> **Version:** 2.0
> **Owner:** Shane Brazelton (SRM Dispatch, Alabama)
> **Repo:** github.com/thebardchat/shanebrain-core

---

## Project Overview

ShaneBrain Core is a local-first AI infrastructure powering the Angel Cloud ecosystem. It serves as the central orchestrator for all projects: Angel Cloud (mental wellness), Pulsar Sentinel (post-quantum security), LogiBot (dispatch automation), and ShaneBrain Legacy (digital legacy). Philosophy: local-first, cloud-backup — everything runs offline with cloud as optional redundancy.

---

## Quick Start

```bash
# Start everything (Windows)
START-SHANEBRAIN.bat

# Or start manually:
# 1. Start Computer B first (if cluster mode)
# 2. Start Weaviate
cd weaviate-config && docker-compose up -d

# 3. Run the bot
cd bot && python bot.py

# 4. Run Angel Arcade (optional)
cd arcade && python arcade_bot.py
```

---

## Common Commands

```bash
# Install dependencies
pip install -r requirements.txt

# Start/Stop Weaviate
cd weaviate-config && docker-compose up -d
cd weaviate-config && docker-compose down

# Ollama
ollama list                    # Check models
ollama pull llama3.2:1b        # Lightweight (8GB RAM)
ollama serve                   # Start server

# Weaviate setup (first time)
python scripts/setup_all_weaviate.py

# Import RAG knowledge
python scripts/import_rag_to_weaviate.py RAG.md

# Verify setup
python scripts/verify_weaviate.py

# Query knowledge
python scripts/query_legacy.py

# Backup/Restore
python scripts/backup_weaviate.py
python scripts/restore_weaviate.py <backup_dir>

# Health check
python scripts/health_check.py

# Run the agent
python langchain-chains/shanebrain_agent.py

# Run Angel Cloud CLI
python langchain-chains/angel_cloud_cli.py
```

---

## File Structure

```
shanebrain-core/
├── CLAUDE.md                    # This file
├── README.md                    # Project README
├── RAG.md                       # ShaneBrain personality + knowledge (v4.0)
├── SHANEBRAIN-MASTER.md         # Quick reference for Shane
├── requirements.txt             # Python dependencies
├── START-SHANEBRAIN.bat         # Master launcher (v6.3)
├── START-COMPUTER-B.bat         # Cluster secondary node
├── ollama_loadbalancer.py       # Routes between Computer A & B
├── shanebrain.modelfile         # Custom Ollama model config
├── shanebrain-3b.modelfile      # 3B model config
├── agent_manifest.json          # Agent manifest
│
├── bot/
│   ├── bot.py                   # Discord bot (v5.3 - learning system)
│   ├── .env                     # Bot token (NEVER commit)
│   └── pending_questions.json   # Learning queue
│
├── arcade/
│   ├── arcade_bot.py            # Angel Arcade economy/casino bot
│   ├── .env                     # Arcade token (NEVER commit)
│   └── data/arcade.db           # Player data
│
├── langchain-chains/
│   ├── shanebrain_agent.py      # Central agent (CHAT, MEMORY, WELLNESS, SECURITY, DISPATCH, CODE)
│   ├── angel_cloud_cli.py       # Interactive CLI for mental wellness
│   ├── crisis_detection_chain.py # Crisis detection
│   ├── qa_retrieval_chain.py    # RAG Q&A
│   └── code_generation_chain.py # Code generation
│
├── weaviate-config/
│   ├── docker-compose.yml       # Lean mode (Ollama embeddings)
│   ├── data/                    # Persistent storage
│   └── schemas/                 # Collection definitions
│
├── scripts/                     # Setup, import, backup, health check scripts
├── mongodb-schemas/             # MongoDB collection schemas
├── planning-system/             # Markdown planning (active-projects gitignored)
└── frontend/                    # Web frontend (planned)
```

---

## Architecture

### Two-Computer Cluster
```
Computer A (192.168.100.1) ── Load Balancer ── Computer B (192.168.100.2)
        Primary (everything)                        Secondary (Ollama only)
```

### Core Components

1. **Ollama LLM** (localhost:11434)
   - Model: `shanebrain-3b:latest` (770 MB) or `llama3.2:1b` fallback
   - Load balanced across two machines

2. **Weaviate** (localhost:8080)
   - Lean mode: Ollama embeddings (no t2v-transformers container)
   - 39 RAG chunks loaded
   - Classes: LegacyKnowledge, Conversation, CrisisLog

3. **Discord Bot** — ShaneBrainLegacyBot
   - RAG-enabled knowledge responses
   - Learning system (`!questions`, `!teach`)
   - Family data with auto-calculated ages

4. **Angel Arcade** — Economy/casino bot for Discord revenue
   - Games: slots, coinflip, dice, blackjack, roulette
   - Ko-fi integration for premium roles

5. **LangChain Chains** — Agent modes: CHAT, MEMORY, WELLNESS, SECURITY, DISPATCH, CODE

### Agent Modes

| Mode | Purpose |
|------|---------|
| CHAT | General conversation |
| MEMORY | Shane's knowledge/legacy retrieval |
| WELLNESS | Angel Cloud mental health support |
| SECURITY | Pulsar AI threat detection |
| DISPATCH | SRM trucking operations |
| CODE | Code generation/debugging |

---

## Ecosystem Projects

| Project | Repo | Status | Description |
|---------|------|--------|-------------|
| ShaneBrain Core | shanebrain-core | Active | Central AI orchestrator, Discord bot, cluster |
| Pulsar Sentinel | pulsar_sentinel | Active | Post-quantum security framework, full UI |
| Loudon/DeSarro | loudon-desarro | Active | 50,000 SF athletic complex 3D visualizations |
| Mini-ShaneBrain | mini-shanebrain | Active | Facebook automation bot (Node.js) |
| Angel Cloud | (in shanebrain-core) | Building | Mental wellness platform |
| Angel Arcade | (in shanebrain-core) | Active | Discord economy/casino bot |
| Legacy AI | Planned | Planned | Personal "TheirNameBrain" for each family member |
| LogiBot | Planned | Planned | SRM Dispatch automation |

---

## Key Patterns

### Environment Configuration
All secrets in `.env` files (gitignored). Template at `.env.template`.

### Optional Dependencies
LangChain chains handle missing deps with `*_AVAILABLE` boolean flags.

### Data Privacy
- Personal planning files, conversation logs, crisis data gitignored
- Local-first: all sensitive data stays on user hardware
- Only templates and schemas tracked in git

---

## Ports

| Service | Port |
|---------|------|
| Load Balancer | 8000 |
| Weaviate | 8080 |
| Ollama A | 11434 (192.168.100.1) |
| Ollama B | 11434 (192.168.100.2) |

---

## Security

- NEVER commit `.env` files
- NEVER paste connection strings in chat
- Keep repos PRIVATE until production ready
- Use Tailscale for remote access, not port forwarding

---

## Contact

**Owner:** Shane Brazelton
**Company:** SRM Dispatch (Alabama)
**Ko-fi:** ko-fi.com/shanebrain
**Discord:** discord.gg/xbHQZkggU7
**Mission:** 800 million users. Digital legacy for generations.
