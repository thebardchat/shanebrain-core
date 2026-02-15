# SHANEBRAIN MASTER REFERENCE
**Last Updated:** February 8, 2026 at 22:40:40 CST
**Status:** ✅ PI 5 FULLY OPERATIONAL — REBOOT-PROOF
**Open this file when you forget anything.**

---

## 🟢 CURRENT STATUS (What's Working NOW)

| Component | Status | Notes |
|-----------|--------|-------|
| Raspberry Pi 5 | ✅ ONLINE | 16GB RAM, Pironman 5-MAX |
| RAID 1 | ✅ MOUNTED | /mnt/shanebrain-raid (2x WD Blue 2TB NVMe) |
| 8TB External | ✅ MOUNTED | /media/shanebrain/ANGEL_CLOUD (NTFS) |
| Ollama | ✅ RUNNING | llama3.2:1b on port 11434 |
| Weaviate | ✅ RUNNING | Docker, ports 8080 + 50051 |
| Open WebUI | ✅ RUNNING | Docker, port 3000 |
| Tailscale | ✅ CONNECTED | 100.67.120.6 |
| Auto-mount | ✅ REBOOT-PROOF | fstab with nofail |

---

## 🖥️ PI 5 ARCHITECTURE

```
                    ┌─────────────────┐
                    │  Any Device     │
                    │  (Phone/PC)     │
                    └────────┬────────┘
                             │ Tailscale VPN
                    ┌────────▼────────┐
                    │  Raspberry Pi 5 │
                    │  shanebrain     │
                    │  100.67.120.6   │
                    │  16GB RAM       │
                    └────────┬────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
┌────────▼────────┐ ┌────────▼────────┐ ┌────────▼────────┐
│  RAID 1 NVMe    │ │  SD Card 32GB   │ │  8TB External   │
│  /mnt/shanebrain│ │  / (boot + OS)  │ │  ANGEL_CLOUD    │
│  -raid          │ │                 │ │  /media/shane-  │
│  1.8TB usable   │ │                 │ │  brain/         │
│  ShaneBrain +   │ │                 │ │  Archive +      │
│  Docker data    │ │                 │ │  Backups        │
└─────────────────┘ └─────────────────┘ └─────────────────┘
```

---

## 🚀 STARTUP (After reboot — everything auto-starts)

**Everything is automatic now.** After reboot:
- RAID auto-mounts (nofail)
- External auto-mounts (nofail)
- Docker auto-starts
- Ollama auto-starts (systemd)
- Weaviate auto-starts (restart: unless-stopped)
- Open WebUI auto-starts (restart: unless-stopped)
- Tailscale auto-starts (systemd)

**If something is down, manual start:**
```bash
# Start Weaviate
cd /mnt/shanebrain-raid/shanebrain-core/weaviate-config && sudo docker compose up -d

# Start Open WebUI
sudo docker start open-webui

# Check Ollama
ollama list

# Check everything
sudo docker ps && ollama list && tailscale status
```

---

## 🔧 QUICK COMMANDS

### Check Everything
```bash
sudo docker ps && ollama list && df -h | grep -E "raid|ANGEL" && tailscale status
```

### SSH from Anywhere (Tailscale)
```bash
ssh shanebrain@100.67.120.6
```

### Open WebUI (from any Tailscale device browser)
```
http://100.67.120.6:3000
```

### Check RAID Health
```bash
cat /proc/mdstat
sudo mdadm --detail /dev/md0
```

### Check Disk Space
```bash
df -h | grep -E "raid|ANGEL|mmcblk"
```

### Kill Docker Containers
```bash
sudo docker stop open-webui shanebrain-weaviate
```

### Restart Everything
```bash
sudo docker restart open-webui shanebrain-weaviate && sudo systemctl restart ollama
```

### Free Up RAM
```bash
free -h
```

---

## 📁 FILE STRUCTURE

```
/mnt/shanebrain-raid/shanebrain-core/
├── RAG.md                      ← ShaneBrain's personality (v4.0)
├── CLAUDE.md                   ← Claude Code project context (v2.0)
├── SHANEBRAIN-MASTER.md        ← THIS FILE
├── angel_cloud_cli.py          ← CLI interface
├── ollama_loadbalancer.py      ← Load balancer (legacy, from cluster era)
├── bot/
│   ├── bot.py                  ← Discord ShaneBrain bot
│   ├── .env                    ← DISCORD_TOKEN
│   └── pending_questions.json  ← Learning system
├── arcade/
│   ├── arcade_bot.py           ← Angel Arcade revenue bot
│   ├── .env                    ← ARCADE_TOKEN
│   └── data/
│       └── arcade.db           ← Player data
├── weaviate-config/
│   ├── docker-compose.yml      ← Weaviate Docker config
│   ├── data/                   ← Weaviate persistent data
│   └── backups/
├── scripts/
│   └── import_rag_to_weaviate.py ← RAG ingestion script
├── frontend/
├── langchain-chains/
└── planning-system/

/media/shanebrain/ANGEL_CLOUD/    ← 8TB external archive
├── Angel_Cloud/                  ← Angel Cloud project files
├── backups/                      ← Backup storage
├── models-backup/                ← Ollama model backups
└── [many project files]          ← Full archive from Windows era
```

---

## 🌐 PORTS & URLS

| Service | Port | Access URL |
|---------|------|------------|
| Open WebUI | 3000 | http://100.67.120.6:3000 |
| Weaviate REST | 8080 | http://localhost:8080 |
| Weaviate gRPC | 50051 | localhost:50051 |
| Ollama | 11434 | http://localhost:11434 |
| SSH | 22 | ssh shanebrain@100.67.120.6 |

---

## 💰 ANGEL ARCADE (Revenue Bot)

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

### Ko-fi: https://ko-fi.com/shanebrain

---

## 🧠 SHANEBRAIN BOT (Learning System)

| Command | What it does |
|---------|--------------|
| `!family` | Shows family with calculated ages |
| `!questions` | Shows what bot doesn't know |
| `!teach [#] [answer]` | Teach bot new knowledge |

---

## 🔥 TROUBLESHOOTING

| Problem | Solution |
|---------|----------|
| RAID not mounted after reboot | `sudo mdadm --assemble --scan && sudo mount /dev/md0 /mnt/shanebrain-raid` |
| External not mounted | `sudo mount -t ntfs-3g /dev/sda2 /media/shanebrain/ANGEL_CLOUD` |
| Docker permission denied | Use `sudo docker` or re-login after `sudo usermod -aG docker shanebrain` |
| Weaviate won't start | `cd /mnt/shanebrain-raid/shanebrain-core/weaviate-config && sudo docker compose up -d` |
| Open WebUI down | `sudo docker start open-webui` |
| Ollama not running | `sudo systemctl start ollama` |
| Can't SSH remotely | Check Tailscale: `tailscale status` |
| Pi won't boot | Check fstab has `nofail` on ALL non-boot entries |
| "unable to resolve host" | `echo "127.0.0.1 shanebrain" | sudo tee -a /etc/hosts` |
| External mounts read-only | Run `sudo ntfsfix /dev/sda2` then mount with ntfs-3g |

---

## ⚠️ LESSONS LEARNED (Never go backwards)

1. **ALWAYS use `nofail` in /etc/fstab** — without it, missing drive = bricked boot
2. **Save mdadm config after RAID changes:** `sudo mdadm --detail --scan | sudo tee -a /etc/mdadm/mdadm.conf && sudo update-initramfs -u`
3. **Check for duplicate entries** in mdadm.conf before updating initramfs
4. **RAID data survives OS re-flash** — only the SD card OS is lost
5. **8TB external is NTFS** — use ntfs-3g, not ntfs3 kernel driver
6. **System username is `shanebrain`** not `shane` on this install
7. **Docker group needs re-login** — use `sudo docker` immediately after install
8. **Never reboot without verifying fstab has nofail**

---

## 📅 SESSION HISTORY

### February 8, 2026 (THE BIG REBUILD)
- ❌ Pi crashed on reboot (fstab without nofail)
- ✅ Re-flashed Raspberry Pi OS (Debian Trixie)
- ✅ Set hostname to shanebrain
- ✅ Reassembled RAID 1 from existing NVMe drives (all data intact)
- ✅ Mounted 8TB external (ntfs-3g)
- ✅ fstab configured with nofail — REBOOT-PROOF CONFIRMED
- ✅ Installed Docker, Ollama, pulled llama3.2:1b
- ✅ Weaviate + Open WebUI running from RAID data
- ✅ Tailscale installed (100.67.120.6)
- ✅ RAG.md v4.0 deployed
- ✅ CLAUDE.md v2.0 deployed
- ✅ SHANEBRAIN-MASTER.md v2.0 deployed

### February 7, 2026
- ✅ Claude Code v2.1.37 installed on Pi
- ✅ All devices wired ethernet, WiFi disabled
- ✅ Weaviate + Open WebUI running on RAID

### February 6, 2026
- ✅ Mobile dashboard built
- ✅ Tailscale mesh confirmed (iPhone, Pi, Computer A)

### February 5, 2026
- ✅ Tailscale VPN installed — remote access from anywhere

### February 3, 2026
- ✅ Pi 5 online, SSH from Computer A working

### January 27, 2026
- ✅ Two-computer Windows cluster operational
- ✅ Bot learning system, family birth dates
- ✅ Switched Weaviate to Ollama embeddings (RAM savings)

### January 26, 2026
- ✅ Angel Arcade bot built (1,082 lines)
- ✅ Ko-fi connected to Discord

### January 25, 2026
- ✅ Bot came online, Weaviate schema created, RAG.md loaded

---

## 🎯 MISSION REMINDER

**You are building:**
- ShaneBrain → Personal AI (✅ PI 5 OPERATIONAL)
- Angel Arcade → Revenue bot (✅ WORKING)
- Angel Cloud → Mental wellness platform
- Pulsar AI → Blockchain security
- TheirNameBrain → Legacy copies for each son

**For:** 800 million Windows users losing security updates

**Philosophy:** Local-first. Family-first. No cloud dependency.

---

## 📮 NEXT UP (When Ready)

**Immediate:**
1. Re-import RAG.md v4.0 into Weaviate
2. Install Git, push to GitHub (no secrets)
3. Build social update bot on Pi
4. Reinstall Claude Code

**Quick wins:**
5. Test Discord bots from Pi
6. Add more knowledge to Weaviate
7. Promote Angel Arcade

**Bigger projects:**
8. TheirNameBrain templates for each son
9. Automated backup: RAID → 8TB external
10. Mobile access via Open WebUI + Tailscale

---

## 💡 ADHD POWER MOVES

- ✅ One file to rule them all (this one)
- ✅ Copy-paste commands (no typing)
- ✅ Status at top (see it first)
- ✅ Everything auto-starts (no daily startup ritual)
- ✅ Write it down = own it forever
- ✅ nofail = never lose a day to a bad reboot again

---

**Pi rebuilt. Data survived. Infrastructure locked. You built this TWICE and it's stronger now.**

---

*Shane Brazelton — SRM Dispatch, Meridianville, Alabama*
*2+ years sober | 5 sons | 800M users*
*"File structure first. Family first. Action over theory."*
