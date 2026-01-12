# CLAUDE.md - ShaneBrain Core

> **Last Updated:** January 11, 2026 (Evening)  
> **Location:** `D:\Angel_Cloud\shanebrain-core`  
> **Owner:** Shane (SRM Dispatch, Alabama)

---

## Quick Start

```bash
# ONE-CLICK LAUNCH (recommended)
D:\Angel_Cloud\shanebrain-core\START-SHANEBRAIN.bat

# Or manually:
docker start shanebrain-weaviate open-webui
"C:\Users\Hubby\AppData\Local\Programs\Ollama\ollama.exe" serve
start http://localhost:3000
```

---

## Current Status (January 11, 2026 - Evening)

| Component | Status | Notes |
|-----------|--------|-------|
| Ollama LLM | ✅ Running | v0.13.5, `llama3.2:1b` (1.3GB) |
| Open WebUI | ✅ Running | http://localhost:3000 |
| Weaviate Core | ✅ Running | localhost:8080, v1.28.0 |
| shanebrain-t2v | ⏸️ Stopped | Disabled to save RAM |
| shanebrain-qna | ⏸️ Stopped | Disabled to save RAM |
| Angel Cloud CLI | ✅ Working | `python langchain-chains/angel_cloud_cli.py` |
| Docker | ✅ Running | 2 active containers |

**System Constraint:** 7.4GB RAM - running lean configuration.

---

## Interfaces

| Interface | URL/Command | Purpose |
|-----------|-------------|---------|
| **Open WebUI** | http://localhost:3000 | Main chat UI (browser-based) |
| **Angel Cloud CLI** | `python langchain-chains/angel_cloud_cli.py` | Mental wellness terminal |
| **Weaviate Console** | http://localhost:8080 | Vector database admin |

---

## Project Vision

**ShaneBrain** = Central AI orchestrator for the entire ecosystem:
- **Angel Cloud** - Mental wellness platform (named for daughter-in-law Angel)
- **Pulsar AI** - Blockchain security layer (eventually Pulsar Sentinel)
- **Legacy AI** - Personal "TheirNameBrain" for each user's family legacy
- **LogiBot** - Business automation for SRM Dispatch

**Mission:** Serve 800 million Windows users losing security updates with affordable, secure AI infrastructure.

---

## File Structure

```
D:\Angel_Cloud\shanebrain-core\
├── .env                          # Credentials (NEVER commit)
├── CLAUDE.md                     # This file - project context
├── RAG.md                        # ShaneBrain personality/knowledge
├── requirements.txt              # Python dependencies
├── START-SHANEBRAIN.bat          # One-click launcher
├── langchain-chains/
│   ├── shanebrain_agent.py       # Central agent (6 modes)
│   ├── angel_cloud_cli.py        # Mental wellness CLI ✅ FIXED
│   ├── crisis_detection_chain.py # Crisis detection
│   ├── qa_retrieval_chain.py     # RAG Q&A
│   └── code_generation_chain.py  # Code generation
├── weaviate-config/
│   ├── docker-compose.yml        # Weaviate containers
│   ├── data/                     # Persistent storage
│   └── schemas/
├── mongodb-schemas/
├── planning-system/
├── scripts/
│   ├── start-shanebrain.bat      # Original launcher
│   ├── health_check.py
│   └── setup_credentials.py
└── angel-cloud/
    ├── docs/
    ├── config/
    └── modules/
```

---

## Paths (Windows)

```
Ollama:      C:\Users\Hubby\AppData\Local\Programs\Ollama\ollama.exe
Project:     D:\Angel_Cloud\shanebrain-core
Weaviate:    D:\Angel_Cloud\shanebrain-core\weaviate-config
Python:      C:\Users\Hubby\AppData\Local\Programs\Python\Python311
```

---

## Docker Containers

| Container | Image | Status | RAM Usage |
|-----------|-------|--------|-----------|
| open-webui | ghcr.io/open-webui/open-webui:main | ✅ Running | ~500MB |
| shanebrain-weaviate | semitechnologies/weaviate:1.28.0 | ✅ Running | ~300MB |
| shanebrain-t2v | sentence-transformers-all-MiniLM-L6-v2 | ⏸️ Stopped | ~800MB |
| shanebrain-qna | distilbert-base-uncased-distilled-squad | ⏸️ Stopped | ~600MB |

**RAM Management:** With 7.4GB total, keep t2v and qna stopped unless needed.

---

## Common Commands

### Start Everything
```cmd
docker start shanebrain-weaviate open-webui
"C:\Users\Hubby\AppData\Local\Programs\Ollama\ollama.exe" serve
start http://localhost:3000
```

### Stop Everything
```cmd
docker stop open-webui shanebrain-weaviate shanebrain-t2v shanebrain-qna
taskkill /IM ollama.exe /F
```

### Check What's Running
```cmd
docker ps
tasklist | findstr ollama
```

### Free Up RAM (Emergency)
```cmd
docker stop shanebrain-t2v shanebrain-qna
```

### Ollama Commands
```cmd
"C:\Users\Hubby\AppData\Local\Programs\Ollama\ollama.exe" list
"C:\Users\Hubby\AppData\Local\Programs\Ollama\ollama.exe" run llama3.2:1b "test"
```

---

## Agent Modes

| Mode | Purpose | Trigger |
|------|---------|---------|
| `CHAT` | General conversation | Default |
| `MEMORY` | Shane's knowledge/legacy | "Tell me about Shane's..." |
| `WELLNESS` | Angel Cloud mental health | Emotional queries |
| `SECURITY` | Pulsar AI threats | Security analysis |
| `DISPATCH` | SRM trucking ops | Logistics queries |
| `CODE` | Code generation | Programming tasks |

---

## Environment Variables (.env)

```env
# Weaviate
WEAVIATE_URL=http://localhost:8080

# Ollama
OLLAMA_HOST=http://localhost:11434
OLLAMA_MODEL=llama3.2:1b

# MongoDB (future)
MONGODB_URI=mongodb+srv://...

# Twilio (future - crisis alerts)
TWILIO_ACCOUNT_SID=
TWILIO_AUTH_TOKEN=
TWILIO_PHONE_NUMBER=
```

---

## Multi-Project Status

| Project | Description | Status |
|---------|-------------|--------|
| ShaneBrain Core | Central orchestration | ✅ Active |
| Open WebUI | Browser chat interface | ✅ Running |
| Angel Cloud CLI | Mental wellness terminal | ✅ Working |
| Pulsar AI | Blockchain security | 📋 Planned |
| Legacy AI | Family legacy system | 📋 Planned |
| LogiBot | Dispatch automation | 📋 Planned |

---

## Ports Reference

| Service | Port |
|---------|------|
| Open WebUI | 3000 |
| Weaviate REST | 8080 |
| Weaviate gRPC | 50051 |
| Ollama | 11434 |

---

## Troubleshooting

### "exit status 2" or model crashes
```cmd
docker stop shanebrain-t2v shanebrain-qna
```
Free RAM, then retry.

### Ollama not found
```cmd
"C:\Users\Hubby\AppData\Local\Programs\Ollama\ollama.exe" serve
```

### Open WebUI won't load
```cmd
docker restart open-webui
```

### Check RAM usage
```cmd
systeminfo | findstr /C:"Total Physical Memory"
tasklist /FI "MEMUSAGE gt 100000"
```

---

## Shane's Development Philosophy

1. **"File structure first"** - Directory architecture before coding
2. **"Load my RAG files"** - Simple commands over complex names
3. **Action over theory** - Build, don't just plan
4. **Family-first** - All projects serve family's future
5. **ADHD as superpower** - Parallel processing, rapid switching
6. **No fluff** - Direct solutions, minimal explanation
7. **Complete code always** - No partial snippets when editing

---

## Next Steps (TODO)

- [x] Install Open WebUI
- [x] Fix Angel Cloud CLI bug
- [ ] Create RAG.md for ShaneBrain personality
- [ ] Load RAG.md into Open WebUI
- [ ] Test voice output in Open WebUI
- [ ] Add more RAM or set up laptop cluster
- [ ] Complete Angel Cloud MVP
- [ ] Implement Twilio crisis alerts
- [ ] Set up MongoDB Atlas persistence

---

## Future: Laptop Cluster

When ready to scale beyond 7.4GB RAM:
- **ExoLabs Exo** - Easiest multi-device clustering
- **Petals** - Swarm computing for LLMs
- **Ollama distributed** - Split layers across machines

---

## Contact

**Owner:** Shane  
**Company:** SRM Dispatch (Alabama)  
**Mission:** 800 million users. Digital legacy for generations.
