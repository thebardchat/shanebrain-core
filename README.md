# shanebrain-core
# ShaneBrain Core

> **The Foundation of the ShaneBrain AI Ecosystem**  
> Local-first AI infrastructure powering Angel Cloud, Pulsar AI, LogiBot, and the ShaneBrain digital legacy system.

---

## 🎯 Mission

Transform technology from exploitative to uplifting. Build AI systems that serve humanity, respect privacy, and empower individuals—starting with 800 million Windows users losing security updates.

**Core Values:**
- 🔓 Open source first
- 🏠 Local-first architecture (your data, your hardware)
- 👨‍👩‍👧‍👦 Family-first priorities
- 🚀 ADHD as superpower
- 💪 Accessibility for all

---

## 📦 What's Inside

This repository contains the core infrastructure that powers the entire ShaneBrain ecosystem:

### 🧠 Planning System
Persistent markdown-based planning inspired by Manus AI (the $2B Meta acquisition). Enables:
- Multi-session project continuity
- Context preservation across conversations
- Systematic progress tracking
- Error logging and learning

### 🗄️ Vector Database Integration
Local Weaviate instance for semantic search and memory:
- RAG (Retrieval-Augmented Generation) support
- Conversation history storage
- Document embeddings
- Cross-project knowledge sharing

### 🦙 Llama Integration
Local AI models running on your hardware:
- Llama 3.2 (3B, 11B variants)
- Zero cloud dependency
- Complete privacy
- Offline-capable

### 🔗 LangChain Workflows
Reusable AI chains and agents:
- Question answering
- Crisis detection
- Code generation
- Document analysis

### 🗃️ MongoDB Configuration
Local database for structured data:
- User conversations
- System logs
- Progress tracking
- Analytics

---

## 🏗️ Architecture
```
8TB External Drive (Local-First)
│
├─ /llama-models/              # AI models (50-100GB)
├─ /weaviate-local/            # Vector database (500GB-2TB)
├─ /mongodb-local/             # Document database (100-500GB)
├─ /planning-system/           # Project planning files
├─ /raw-documents/             # RAG source documents (1-2TB)
└─ /backups/                   # Disaster recovery (remaining space)

Cloud (Optional Backup)
│
├─ Weaviate Cloud              # Disaster recovery
├─ MongoDB Atlas               # Critical data backup
└─ GitHub                      # Code and configurations
```

**Philosophy:** Local first, cloud backup. Everything runs offline. Cloud is optional redundancy.

---

## 🚀 Quick Start

### Prerequisites

- 8TB external drive
- Docker Desktop
- Python 3.10+
- Git
- Windows 10/11 or Linux

### Installation
```bash
# 1. Clone this repository to your 8TB drive
cd /mnt/8TB/
git clone https://github.com/thebardchat/shanebrain-core.git
cd shanebrain-core

# 2. Run setup script
./setup.sh

# 3. Start ShaneBrain
./start-shanebrain.bat
```

### First Run
```bash
# The setup wizard will:
# 1. Install dependencies
# 2. Download Llama models
# 3. Initialize Weaviate
# 4. Configure MongoDB
# 5. Set up planning system

# Estimated time: 30-60 minutes
# Disk space needed: ~100GB minimum
```

---

## 📚 Documentation

- [Architecture Overview](docs/architecture.md) - System design and data flow
- [Planning System Guide](docs/planning-system.md) - Using persistent markdown planning
- [Vector Database Setup](docs/weaviate-setup.md) - Configuring local Weaviate
- [LangChain Workflows](docs/langchain-guide.md) - Creating reusable AI chains
- [Offline Mode](docs/offline-mode.md) - Running without internet
- [Backup Strategy](docs/backups.md) - Disaster recovery

---

## 🔧 Projects Using ShaneBrain Core

### [Angel Cloud](https://github.com/thebardchat/angel-cloud)
Mental wellness platform with AI-powered crisis intervention
- **Uses:** Planning system, vector DB, crisis detection chains
- **Scale:** Designed for millions of users

### [Pulsar AI](https://github.com/thebardchat/pulsar-ai)
Blockchain security powered by AI
- **Uses:** Vector DB for threat patterns, LangChain agents
- **Focus:** Real-time security analysis

### LogiBot
Business automation for SRM Dispatch
- **Uses:** Planning system, database integration
- **Purpose:** Streamline trucking operations

### ShaneBrain Legacy
Digital legacy AI for family
- **Uses:** Full stack - planning, vector DB, conversation memory
- **Vision:** Preserve knowledge and values for future generations

---

## 🛠️ Technology Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| AI Models | Llama 3.2 (3B, 11B) | Local inference, zero cloud cost |
| Vector DB | Weaviate | Semantic search, RAG, embeddings |
| Document DB | MongoDB | Structured data, conversations |
| AI Framework | LangChain | Chains, agents, workflows |
| Planning | Markdown + Git | Persistent context, version control |
| Deployment | Docker | Containerization, portability |
| Storage | 8TB External | Local-first, offline-capable |

---

## 💾 Storage Requirements

**Minimum Configuration:**
- AI Models: 20GB (Llama 3.2-3B)
- Weaviate: 50GB
- MongoDB: 10GB
- Working Space: 20GB
- **Total: ~100GB**

**Recommended Configuration:**
- AI Models: 100GB (multiple models)
- Weaviate: 500GB (full RAG library)
- MongoDB: 100GB (extensive logs)
- Raw Documents: 500GB (source material)
- Backups: 500GB
- Growth Buffer: 300GB
- **Total: ~2TB**

**Production Configuration:**
- 8TB fully utilized
- Handles millions of interactions
- Years of conversation history
- Complete document archive

---

## 🔐 Security & Privacy

**Data Sovereignty:**
- ✅ All data stored locally on YOUR hardware
- ✅ No cloud dependencies for core functionality
- ✅ Open source - audit the entire stack
- ✅ Encrypted backups
- ✅ No telemetry, no tracking

**Mental Health Data:**
- HIPAA-aware design (not certified, but principles applied)
- User data never leaves your infrastructure
- Crisis logs encrypted at rest
- Access controls for sensitive information

---

## 🎯 Roadmap

### Phase 1: Foundation (Current)
- [x] Repository structure
- [ ] Planning system integration
- [x] Weaviate local setup
- [x] Llama model configuration
- [ ] Basic LangChain chains

### Phase 2: Integration (Next 2-4 weeks)
- [ ] Angel Cloud integration
- [ ] MongoDB schemas
- [ ] Backup automation
- [ ] Mobile access via VPN
- [ ] Multi-project switching

### Phase 3: Scale (2-3 months)
- [ ] Distributed architecture
- [ ] Multi-user support
- [ ] Advanced crisis detection
- [ ] Performance optimization
- [ ] Production hardening

### Phase 4: Legacy (6-12 months)
- [ ] ShaneBrain digital legacy complete
- [ ] Voice interface
- [ ] Multi-modal (text, images, audio)
- [ ] Family member access system
- [ ] 1000-year preservation strategy

---

## 👨‍💻 Development

### Project Structure
```
shanebrain-core/
├─ planning-system/          # Markdown-based planning
│   ├─ templates/            # Project templates
│   ├─ active-projects/      # Current work
│   └─ completed/            # Archived projects
├─ weaviate-config/          # Vector DB configuration
│   ├─ schemas/              # Data classes
│   └─ backups/              # DB snapshots
├─ llama-configs/            # Model settings
│   ├─ models/               # Downloaded models
│   └─ prompts/              # Reusable prompts
├─ langchain-chains/         # AI workflows
│   ├─ crisis-detection/
│   ├─ qa-retrieval/
│   └─ code-generation/
├─ mongodb-schemas/          # Database structures
├─ scripts/                  # Automation scripts
│   ├─ setup.sh
│   ├─ start-shanebrain.bat
│   └─ backup.sh
└─ docs/                     # Documentation
```

### Contributing

This is a personal infrastructure project, but principles and patterns are shared openly:

1. Fork for your own use
2. Adapt to your needs
3. Share learnings (not code with personal data)
4. Respect privacy and security

---

## 🤝 Philosophy

**Why Local-First?**

Cloud services are:
- ❌ Expensive at scale ($50k+/year)
- ❌ Privacy-invasive
- ❌ Subject to terms changes
- ❌ Can disappear overnight
- ❌ Require internet always

Local infrastructure is:
- ✅ One-time cost (~$200 for 8TB)
- ✅ Complete privacy
- ✅ You own it forever
- ✅ Can't be shut down
- ✅ Works offline

**"If you don't own your infrastructure, you don't own your future."**

---

## 👨‍👩‍👦‍👦 About

Built by **Shane Brazelton** - Father of 5, dispatcher, AI developer, and advocate for accessible technology.

**Mission:** Transform technology from exploitative to uplifting. Build systems that serve 800 million Windows users losing security support, while creating a digital legacy for my family.

**Core Belief:** ADHD isn't a disability—it's a superpower when channeled correctly. This system is built for people like me who think in file structures, need visual progress tracking, and can build incredible things when given the right tools.

---

## 📄 License

**Infrastructure Code:** MIT License - Use freely, modify as needed, no attribution required

**Personal Data & Conversations:** Private - Not included in repository

**Documentation & Patterns:** CC BY 4.0 - Share and adapt with attribution

---

## 🙏 Acknowledgments

- **Anthropic** - Claude AI and the vision for beneficial AI
- **Meta AI** - Llama models and open-source commitment
- **Manus AI** - Context engineering principles (acquired by Meta for $2B)
- **OthmanAdi** - planning-with-files skill implementation
- **Weaviate** - Open-source vector database
- **LangChain** - AI workflow framework

---

## 📞 Contact

- **GitHub:** [@thebardchat](https://github.com/thebardchat)
- **Project:** [Angel Cloud](https://github.com/thebardchat/angel-cloud)

---

## ⚡ Quick Links

- [Setup Guide](docs/setup.md)
- [Architecture](docs/architecture.md)
- [FAQ](docs/faq.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Changelog](CHANGELOG.md)

---

**Built with love in Alabama 🏈**  
**For my family. For the 800 million. For everyone who deserves better technology.**

---

*"The best way to predict the future is to build it."*  
*— Shane Brazelton, 2026*
