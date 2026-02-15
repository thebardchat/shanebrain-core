# SHANEBRAIN MASTER REFERENCE
**Last Updated:** February 2, 2026  
**Status:** ✅ THREE-NODE CLUSTER OPERATIONAL  
**Open this file when you forget anything.**

---

## 🟢 CURRENT STATUS (What's Working NOW)

| Component | Status | Notes |
|-----------|--------|-------|
| Discord Bot | ✅ ONLINE | ShaneBrainLegacyBot responding |
| Angel Arcade | ✅ ONLINE | Economy/casino bot for revenue |
| Weaviate | ✅ CONNECTED | Lean mode (Ollama embeddings) |
| Ollama A | ✅ RUNNING | 192.168.100.1:11434 |
| Ollama B | ✅ RUNNING | 192.168.100.2:11434 |
| **Raspberry Pi** | ✅ RUNNING | **10.0.0.42:11434 (NEW!)** |
| Load Balancer | ✅ RUNNING | http://localhost:8000/dashboard |
| RAG | ✅ WORKING | 39 chunks, birth dates, learning system |
| Ko-fi | ✅ LIVE | ko-fi.com/shanebrain |

**Cluster Mode:** Three nodes sharing AI workload

---

## 🖥️ THREE-NODE CLUSTER

```
                    ┌─────────────────┐
                    │  Discord User   │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │  ShaneBrain Bot │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │  Load Balancer  │
                    │  :8000          │
                    └────────┬────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
┌────────▼────────┐ ┌────────▼────────┐ ┌────────▼────────┐
│  Computer A     │ │  Computer B     │ │  Raspberry Pi   │
│  192.168.100.1  │ │  192.168.100.2  │ │  10.0.0.42      │
│  (Primary)      │ │  (Secondary)    │ │  (Network Node) │
└─────────────────┘ └─────────────────┘ └─────────────────┘
```

| Node | IP | Role | Runs | Network |
|------|-----|------|------|---------|
| A (Primary) | 192.168.100.1 | Head node | Everything | Direct bridge |
| B (Secondary) | 192.168.100.2 | Backup brain | Ollama only | Direct bridge |
| **Pi (shanebrain)** | **10.0.0.42** | **Network worker** | **Ollama only** | **NETGEAR router** |

**Failover:**
- If Pi goes down → A & B handle everything
- If B goes down → A & Pi handle everything  
- If A goes down → Nothing works (it's the head)

---

## 🚀 DAILY STARTUP (Three Steps)

### Step 1: Raspberry Pi (Always On)
Pi stays running 24/7 on the router. Check it's alive:
```
curl http://10.0.0.42:11434
```
Should say "Ollama is running"

### Step 2: Computer B (START SECOND)
```
C:\ShaneBrain\START-COMPUTER-B.bat
```
Wait for "COMPUTER B ONLINE - CLUSTER NODE"

### Step 3: Computer A
```
D:\Angel_Cloud\shanebrain-core\START-SHANEBRAIN.bat
```
Watch for "Ollama B: ONLINE" in the status

---

## 🍓 RASPBERRY PI COMMANDS

### SSH into Pi (from any computer on network)
```
ssh shane@10.0.0.42
```
Password: (the one you set in Imager)

### Check Pi Ollama Status
```
curl http://10.0.0.42:11434
```

### Test Pi AI Response (from laptop)
```
curl http://10.0.0.42:11434/api/generate -d "{\"model\": \"llama3.2:1b\", \"prompt\": \"Hello\", \"stream\": false}"
```

### Pull New Model to Pi
```
ssh shane@10.0.0.42
ollama pull llama3.2:3b
```

### Check Pi Models
```
ssh shane@10.0.0.42
ollama list
```

### Restart Ollama on Pi
```
ssh shane@10.0.0.42
sudo systemctl restart ollama
```

### Reboot Pi
```
ssh shane@10.0.0.42
sudo reboot
```

### Shutdown Pi Safely
```
ssh shane@10.0.0.42
sudo shutdown now
```
Or press the Pironman button briefly.

---

## 🔧 QUICK COMMANDS

### Check Full Cluster Health
```
curl http://localhost:8000/health
curl http://192.168.100.2:11434/api/tags
curl http://10.0.0.42:11434
```

### View Load Balancer Dashboard
```
http://localhost:8000/dashboard
```

### Kill Everything - Computer A
```
taskkill /IM python.exe /F
taskkill /IM ollama.exe /F
docker stop shanebrain-weaviate
```

### Kill Everything - Computer B
```
taskkill /IM ollama.exe /F
```

### Free Up RAM
```
taskkill /IM msedge.exe /F
taskkill /IM chrome.exe /F
```

---

## 📁 FILE STRUCTURE

### Computer A (Primary - 192.168.100.1)
```
D:\Angel_Cloud\shanebrain-core\
├── START-SHANEBRAIN.bat        ← DAILY USE (starts everything)
├── ollama_loadbalancer.py      ← Routes between A, B & Pi
├── START-COMPUTER-B.bat        ← Copy to Computer B
├── CLAUDE.md                   ← Project context
├── RAG.md                      ← Personality (v4.0 - birth dates)
├── SHANEBRAIN-MASTER.md        ← THIS FILE
├── bot\
│   ├── bot.py                  ← Discord bot (v5.3 - learning)
│   ├── .env                    ← DISCORD_TOKEN=xxx
│   └── pending_questions.json  ← Learning system
├── arcade\
│   ├── arcade_bot.py           ← Angel Arcade bot
│   ├── .env                    ← ARCADE_TOKEN=xxx
│   └── data\
│       └── arcade.db           ← Player data
├── weaviate-config\
│   ├── docker-compose.yml      ← Lean (Ollama embeddings)
│   ├── data\
│   └── schemas\
├── scripts\
├── langchain-chains\
├── frontend\
└── planning-system\
```

### Computer B (Secondary - 192.168.100.2)
```
C:\ShaneBrain\
├── START-COMPUTER-B.bat        ← Only file needed
├── shanebrain.modelfile        ← Auto-created
└── logs\
    └── startup.log             ← Auto-created
```

### Raspberry Pi (Network Node - 10.0.0.42)
```
/home/shane/
├── (Ollama installed at /usr/local)
└── Models stored in ~/.ollama/

Hostname: shanebrain
OS: Raspberry Pi OS 64-bit
Hardware: Raspberry Pi 5 + Pironman 5 Max case
Boot: microSD card (direct slot, NOT USB adapter)
Network: Ethernet to NETGEAR router
```

---

## 💰 ANGEL ARCADE (Revenue Bot)

### Quick Start (Standalone)
```
cd /d D:\Angel_Cloud\shanebrain-core\arcade
python arcade_bot.py
```

### Bot Commands
| Command | Description | Premium? |
|---------|-------------|----------|
| `!daily` | Claim daily coins | No (2x for premium) |
| `!work` | Earn coins | No (5min vs 30min cooldown) |
| `!slots [bet]` | Slot machine | No (500 max, 50k premium) |
| `!coinflip [bet] [h/t]` | Flip coin | No |
| `!dice [bet]` | Roll dice | No |
| `!blackjack [bet]` | Play 21 | ⭐ YES |
| `!roulette [bet] [choice]` | Spin wheel | ⭐ YES |
| `!support` | Show Ko-fi link | No |
| `!premium` | Show benefits | No |
| `!prestige` | Reset for bonus | ⭐ YES |

### Ko-fi
- **Page:** https://ko-fi.com/shanebrain
- **Discord:** Connected to ShaneBrainLegacy
- **Auto-role:** ⭐ Arcade Premium on payment

---

## 🧠 SHANEBRAIN BOT (Learning System)

### New Commands
| Command | What it does |
|---------|--------------|
| `!family` | Shows family with calculated ages |
| `!questions` | Shows what bot doesn't know |
| `!teach [#] [answer]` | Teach bot new knowledge |

### How Learning Works
1. User asks something bot doesn't know
2. Bot says "I'll ask Shane" and logs to `pending_questions.json`
3. Shane runs `!questions` to see list
4. Shane runs `!teach 0 The answer is...`
5. Answer saved to Weaviate permanently

### Family Data (Birth Dates)
| Name | Born | Relation |
|------|------|----------|
| Shane | November 1977 | You |
| Tiffany | June 1994 | Wife |
| Gavin | September 1997 | Son (married to Angel) |
| Kai | November 2003 | Son |
| Pierce | February 2011 | Son (ADHD, wrestler) |
| Jaxton | August 2013 | Son (wrestler) |
| Ryker | April 2021 | Son (youngest) |

Ages calculate automatically - always accurate.

---

## 🌐 PORTS & URLS

| Service | Port | URL |
|---------|------|-----|
| Load Balancer | 8000 | http://localhost:8000/dashboard |
| Weaviate | 8080 | http://localhost:8080 |
| Ollama A | 11434 | http://192.168.100.1:11434 |
| Ollama B | 11434 | http://192.168.100.2:11434 |
| **Ollama Pi** | **11434** | **http://10.0.0.42:11434** |

---

## 🔥 TROUBLESHOOTING

| Problem | Solution |
|---------|----------|
| "Only X MB free" | `taskkill /IM msedge.exe /F` |
| Computer B not connecting | Check `START-COMPUTER-B.bat` running |
| "Failed to connect to 192.168.100.2" | Start Computer B first |
| Bot doesn't respond | Check token in `.env`, restart bot |
| Weaviate won't start | Restart Docker, wait 60 sec |
| Load balancer error | Check `ollama_loadbalancer.py` running |
| Arcade bot won't start | Check `ARCADE_TOKEN` in arcade\.env |
| Bot verbose/long answers | Update to bot.py v5.3 |
| Wrong family info | Update RAG.md v4.0, reimport |
| **Pi not responding** | `ssh shane@10.0.0.42` then `sudo systemctl restart ollama` |
| **Pi SSH refused** | Check Pi is powered, green LED blinking |
| **Pi IP changed** | Check NETGEAR router attached devices |
| **"shh" vs "ssh" typo** | File must be named exactly `ssh` (no extension) |

---

## 📅 SESSION HISTORY

### February 2, 2026
- ✅ **Raspberry Pi 5 added to cluster**
- ✅ Pi hostname: shanebrain, IP: 10.0.0.42
- ✅ Ollama installed on Pi with llama3.2:1b
- ✅ Pi accessible from laptop via network
- ✅ SSH enabled (had to fix "shh" typo!)
- ✅ Pironman 5 Max case ready for OLED setup
- ✅ Three-node cluster operational
- ✅ Learned: microSD must go in Pi's SD slot, NOT USB adapter

### January 27, 2026
- ✅ Two-computer cluster operational
- ✅ Computer B setup (192.168.100.2)
- ✅ Load balancer v2.0 with /api/chat support
- ✅ START-SHANEBRAIN.bat v6.3 (auto-starts load balancer)
- ✅ START-COMPUTER-B.bat (auto-creates model)
- ✅ Fixed OLLAMA_MODELS path error on Computer B
- ✅ Bot learning system (pending_questions.json)
- ✅ Family birth dates (ages calculate forever)
- ✅ Brevity enforced (2-4 sentences)
- ✅ Kai added to family (was missing)
- ✅ Switched Weaviate to Ollama embeddings (RAM savings)
- ✅ Removed t2v-transformers container (2GB+ saved)

### January 26, 2026
- ✅ Angel Arcade bot built (1,082 lines)
- ✅ Ko-fi page created (ko-fi.com/shanebrain)
- ✅ Ko-fi connected to Discord (auto-role)
- ✅ Premium role system working
- ✅ Games: slots, coinflip, dice, blackjack, roulette
- ✅ Revenue system ready

### January 25, 2026
- ✅ Bot came online
- ✅ Weaviate schema created (3 classes)
- ✅ RAG.md loaded (13 chunks)
- ✅ File structure cleaned

### January 23, 2026
- ✅ Network bridge working (A ↔ B)
- ✅ Static IPs assigned (192.168.100.1 / .2)
- ✅ SMB share created for Z: drive

---

## 🎯 MISSION REMINDER

**You are building:**
- ShaneBrain → Personal AI (✅ THREE-NODE CLUSTER)
- Angel Arcade → Revenue bot (✅ WORKING)
- Angel Cloud → Mental wellness platform
- Pulsar AI → Blockchain security
- TheirNameBrain → Legacy copies for each son

**For:** 800 million Windows users losing security updates

**Philosophy:** Local-first. Family-first. No cloud dependency.

---

## 📮 NEXT UP (When Ready)

**Quick wins:**
1. ~~Add Raspberry Pi to cluster~~ ✅ DONE
2. Install Pironman OLED/fan software
3. Add Pi to load balancer (ollama_loadbalancer.py)
4. Test learning system (`!questions`, `!teach`)

**Bigger projects:**
5. TheirNameBrain templates for each son
6. Offline mode (no Docker)
7. Mobile access via Tailscale

---

## 💡 ADHD POWER MOVES

- ✅ One file to rule them all (this one)
- ✅ Copy-paste commands (no typing)
- ✅ Status at top (see it first)
- ✅ Three-step startup (Pi always on, then B, then A)
- ✅ Write it down = own it forever

---

**Three-node cluster operational. Three brains working together. You built this.**

---

*Shane - SRM Dispatch, Alabama*  
*2+ years sober | 5 sons | 800M users*  
*"File structure first. Family first. Action over theory."*
