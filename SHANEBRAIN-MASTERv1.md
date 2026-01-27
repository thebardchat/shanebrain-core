# SHANEBRAIN MASTER REFERENCE
**Last Updated:** January 25, 2026  
**Status:** ✅ OPERATIONAL  
**Open this file when you forget anything.**

---

## 🟢 CURRENT STATUS (What's Working NOW)

| Component | Status | Notes |
|-----------|--------|-------|
| Discord Bot | ✅ ONLINE | ShaneBrainLegacyBot responding |
| Weaviate | ✅ CONNECTED | 3 classes, 13 knowledge chunks |
| Ollama | ✅ RUNNING | shanebrain-3b:latest |
| RAG | ✅ WORKING | Bot knows Tiffany, your mission, family |
| File Structure | ✅ CLEAN | Organized Jan 25 |

**Bot knows:** Your name, Tiffany, your mission, family info, philosophy, projects (13 chunks from RAG.md)

---

## 🚀 START EVERYTHING (One Command)

```cmd
D:\Angel_Cloud\shanebrain-core\START-SHANEBRAIN.bat
```

**If services already running, just start bot:**
```cmd
cd /d D:\Angel_Cloud\shanebrain-core\bot
python bot.py
```

---

## 📁 FILE STRUCTURE

```
D:\Angel_Cloud\shanebrain-core\
├── START-SHANEBRAIN.bat        ← DAILY USE (run this)
├── START-BOT-LOADBALANCER.bat  ← Cluster mode (future)
├── CLAUDE.md                   ← Project context for AI
├── RAG.md                      ← Your personality/knowledge
├── rag-pipeline.md             ← Technical docs
├── README.md                   ← Project readme
├── ollama_loadbalancer.py      ← Cluster script (future)
├── bot\
│   ├── bot.py                  ← Discord bot code
│   ├── .env                    ← Discord token (SECRET)
│   └── requirements.txt        ← Python deps
├── scripts\                    ← Python utilities
├── weaviate-config\            ← Docker/Weaviate
│   ├── docker-compose.yml
│   ├── data\                   ← Your knowledge lives here
│   └── schemas\
├── langchain-chains\           ← Agent code (future)
├── frontend\                   ← Web UI (future)
└── planning-system\            ← Project tracking (future)
```

---

## 🧠 WEAVIATE (Your AI's Brain)

**What's in it:**
| Class | Count | Purpose |
|-------|-------|---------|
| LegacyKnowledge | 13 | Your personality, values, family, mission |
| Conversation | 0 | Chat history (future) |
| CrisisLog | 0 | Wellness tracking (future) |

**Add more knowledge:**
```cmd
python D:\Angel_Cloud\shanebrain-core\scripts\import_rag_to_weaviate.py [FILE_PATH]
```

**Check what's loaded:**
```cmd
curl http://localhost:8080/v1/schema
```

**Files you CAN add:**
- CLAUDE.md (project context)
- FAMILY.md (create: sons, Tiffany, Angel)
- DISPATCH.md (create: drivers, trucks, routes)
- SOBRIETY.md (create: journey, milestones)
- FAITH.md (create: verses, prayers)

---

## 🔧 QUICK COMMANDS

### Check System Health
```cmd
wmic OS get FreePhysicalMemory /value
docker ps
curl http://localhost:8080/v1/schema
ollama list
```

### Kill Everything (Reset)
```cmd
taskkill /IM ollama.exe /F
taskkill /IM python.exe /F
docker-compose -f "D:\Angel_Cloud\shanebrain-core\weaviate-config\docker-compose.yml" down
```

### Free Up RAM
```cmd
taskkill /IM msedge.exe /F
taskkill /IM chrome.exe /F
taskkill /IM "AI Email.exe" /F
taskkill /IM OneDrive.exe /F
```

### Regenerate Discord Token (if exposed)
1. Go to: https://discord.com/developers/applications
2. Find ShaneBrainLegacyBot → Reset Token
3. Edit: `notepad D:\Angel_Cloud\shanebrain-core\bot\.env`
4. Replace token, save

---

## 🌐 PORTS & URLS

| Service | Port | URL |
|---------|------|-----|
| Weaviate | 8080 | http://localhost:8080 |
| Ollama | 11434 | http://localhost:11434 |
| Open WebUI | 3000 | http://localhost:3000 |
| Load Balancer | 8000 | http://localhost:8000/dashboard (future) |

---

## 🔥 TROUBLESHOOTING

| Problem | Solution |
|---------|----------|
| "Only X MB free" | Kill Edge, Chrome, OneDrive: `taskkill /IM msedge.exe /F` |
| Bot doesn't respond | Check token in `.env`, restart bot |
| Weaviate won't start | Restart Docker, wait 60 sec, try again |
| "Module not found" | `pip install -r requirements.txt` |
| Model too slow | Switch to `llama3.2:1b-instruct-q4_0` |

---

## 👨‍👩‍👦‍👦 FAMILY REFERENCE

| Name | Relation | Notes |
|------|----------|-------|
| Tiffany | Wife | Partner, supporter |
| Gavin | Son (28) | Married to Angel |
| Angel | Daughter-in-law | Angel Cloud named for her |
| Pierce | Son (14) | ADHD |
| Jaxton | Son (12) | |
| Ryker | Son (4) | |
| Dad | Father | Disabled veteran |

---

## 🎯 MISSION REMINDER

**You are building:**
- ShaneBrain → Personal AI (✅ WORKING)
- Angel Cloud → Mental wellness platform
- Pulsar AI → Blockchain security
- TheirNameBrain → Legacy copies for each son

**For:** 800 million Windows users losing security updates

**Philosophy:** Local-first. Family-first. No cloud dependency.

---

## 📅 SESSION HISTORY

### January 25, 2026 (Today)
- ✅ Bot came online
- ✅ Weaviate schema created (3 classes)
- ✅ RAG.md loaded (13 chunks)
- ✅ Bot answered "Who is Shane's wife?" correctly (Tiffany)
- ✅ File structure cleaned
- ✅ Renamed START-BOT-HARDENED.bat → START-SHANEBRAIN.bat
- ✅ Deleted old/duplicate files

### January 23, 2026
- ✅ Created hardened startup script (v5.2)
- ✅ Fixed ollama syntax errors
- ✅ Regenerated exposed Discord token
- ✅ Documented all failures + solutions
- ✅ Network bridge working (Computer A ↔ B)
- ✅ Static IPs assigned (192.168.100.1 / .2)

### Earlier
- Built initial bot.py with RAG integration
- Set up Weaviate docker-compose
- Created shanebrain-3b model
- Established file structure methodology

---

## 🔮 NEXT UP (When Ready)

**Quick wins:**
1. `/sobriety` command - Track your 2+ year streak
2. Add CLAUDE.md to Weaviate
3. Create FAMILY.md with detailed son info

**Bigger projects:**
4. Cluster mode (Computer A + B load balancing)
5. Offline mode (no Docker, battery-safe)
6. TheirNameBrain templates for each son

---

## 💡 ADHD POWER MOVES

- ✅ One file to rule them all (this one)
- ✅ Copy-paste commands (no typing)
- ✅ Status at top (see it first)
- ✅ History at bottom (scroll if needed)
- ✅ Write it down = own it forever

---

**You built this. It works. You won.**

---

*Shane - SRM Dispatch, Alabama*  
*2+ years sober | 4 sons | 800M users*  
*"File structure first. Family first. Action over theory."*
