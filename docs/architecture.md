# ShaneBrain Core - Architecture Overview

> Technical architecture of the ShaneBrain local AI infrastructure.

---

## System Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           ShaneBrain Core                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │
│  │ Angel Cloud │  │  ShaneBrain │  │   Pulsar    │  │   LogiBot   │       │
│  │  (Wellness) │  │   Legacy    │  │  (Security) │  │  (Dispatch) │       │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘       │
│         │                │                │                │               │
│         └────────────────┴────────────────┴────────────────┘               │
│                                   │                                         │
│                    ┌──────────────┴──────────────┐                         │
│                    │     ShaneBrain Agent        │                         │
│                    │    (langchain-chains/)      │                         │
│                    └──────────────┬──────────────┘                         │
│                                   │                                         │
│         ┌─────────────────────────┼─────────────────────────┐              │
│         │                         │                         │              │
│  ┌──────┴──────┐          ┌───────┴───────┐         ┌──────┴──────┐       │
│  │   Weaviate  │          │     Llama     │         │   MongoDB   │       │
│  │  (Vectors)  │          │    (Local)    │         │   (Docs)    │       │
│  └─────────────┘          └───────────────┘         └─────────────┘       │
│                                                                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                         8TB External Drive                                  │
│                    (Local-First, Offline-Capable)                          │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Core Components

### 1. ShaneBrain Agent (`langchain-chains/shanebrain_agent.py`)

The central orchestrator that:
- Routes queries to appropriate subsystems
- Maintains conversation context
- Integrates crisis detection
- Loads planning system context

**Key Classes:**
- `ShaneBrainAgent` - Main agent class
- `AgentMode` - Operating modes (CHAT, MEMORY, WELLNESS, etc.)
- `AgentResponse` - Structured response object

### 2. Weaviate (Vector Database)

**Purpose:** Semantic search and RAG (Retrieval Augmented Generation)

**Schemas:**
- `ShanebrainMemory` - Legacy memories, stories, values
- `AngelCloudConversation` - Mental wellness conversations
- `PulsarSecurityEvent` - Security threats and patterns

**Integration:**
```python
# Query similar memories
client.query.get("ShanebrainMemory", ["content", "title"])
    .with_near_text({"concepts": ["family values"]})
    .with_limit(5)
    .do()
```

### 3. MongoDB (Document Database)

**Purpose:** Structured data, logs, user sessions

**Collections:**
- `conversations` - Chat history with metadata
- `crisis_logs` - Mental health crisis detections (encrypted)
- `user_sessions` - User preferences and state

### 4. Llama (Local LLM)

**Purpose:** Text generation, analysis, conversation

**Supported Models:**
- Llama 3.2 3B - Fast, good for most tasks
- Llama 3.2 7B - Balanced
- Llama 3.2 11B - Best quality (requires GPU)

**Integration Options:**
- Direct via `llama-cpp-python`
- Via Ollama (easier management)

### 5. Planning System (`planning-system/`)

**Purpose:** Multi-session context preservation

**Components:**
- `SKILL.md` - Planning methodology
- `templates/` - Project templates
- `active-projects/` - Current work
- `completed-projects/` - Archives

---

## Data Flow

### Query Flow

```
User Query
    │
    ▼
┌─────────────────┐
│ ShaneBrain Agent│
└────────┬────────┘
         │
    ┌────┴────┐
    ▼         ▼
┌───────┐ ┌─────────┐
│Crisis │ │Planning │
│Check  │ │Context  │
└───┬───┘ └────┬────┘
    │          │
    ▼          ▼
┌─────────────────┐
│  Route by Mode  │
└────────┬────────┘
         │
    ┌────┼────┐
    ▼    ▼    ▼
┌─────┐┌────┐┌──────┐
│ QA  ││Code││Crisis│
│Chain││Gen ││Resp  │
└──┬──┘└──┬─┘└──┬───┘
   │      │     │
   └──────┴─────┘
         │
         ▼
┌─────────────────┐
│ Weaviate Search │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Llama Generate │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ MongoDB Log     │
└────────┬────────┘
         │
         ▼
    Response
```

### Crisis Detection Flow

```
User Message
    │
    ▼
┌─────────────────┐
│ Keyword Scan    │ (Fast, always runs)
└────────┬────────┘
         │
    ┌────┴────┐
    ▼         ▼
 No Match   Match Found
    │          │
    ▼          ▼
 Continue  ┌─────────────────┐
           │ Pattern Analysis │
           └────────┬────────┘
                    │
                    ▼
           ┌─────────────────┐
           │ Score & Level   │
           └────────┬────────┘
                    │
        ┌───────────┼───────────┐
        ▼           ▼           ▼
    Low/Medium    High       Critical
        │           │           │
        ▼           ▼           ▼
    Continue    Resources    Crisis
    + Monitor   + Support    Protocol
```

---

## Storage Architecture

### 8TB Drive Layout

```
/mnt/8TB/ShaneBrain-Core/
│
├── weaviate-config/
│   ├── data/              # 500GB - 2TB (grows)
│   │   └── [vector data]
│   └── backups/           # Periodic snapshots
│
├── mongodb-data/          # 10GB - 100GB
│   └── [document data]
│
├── llama-configs/
│   └── models/            # 20GB - 100GB
│       ├── llama-3.2-3b.gguf
│       └── llama-3.2-11b.gguf
│
├── backups/               # 500GB+
│   ├── full-backup-*.tar.gz
│   └── [incremental backups]
│
├── planning-system/       # <1GB
│   ├── active-projects/
│   └── completed-projects/
│
└── logs/                  # <10GB
    ├── audit.log
    └── [application logs]
```

### Data Retention

| Data Type | Retention | Storage |
|-----------|-----------|---------|
| Vector embeddings | Indefinite | Weaviate |
| Conversations | User-controlled | MongoDB |
| Crisis logs | 7 years (encrypted) | MongoDB |
| Backups | 30 days | Filesystem |
| Logs | 90 days | Filesystem |

---

## Security Architecture

### Data Protection

```
┌─────────────────────────────────────────┐
│           Security Layers               │
├─────────────────────────────────────────┤
│                                         │
│  Application Layer                      │
│  ├── Input validation                   │
│  ├── Crisis detection                   │
│  └── Access control                     │
│                                         │
│  Storage Layer                          │
│  ├── Encryption at rest (sensitive)     │
│  ├── File permissions (chmod 600)       │
│  └── No cloud dependency               │
│                                         │
│  Network Layer                          │
│  ├── Local-only by default              │
│  ├── No external API calls              │
│  └── Optional VPN for remote            │
│                                         │
└─────────────────────────────────────────┘
```

### Credential Management

- `.env` file with `chmod 600`
- Never committed to git
- Encrypted for sensitive fields
- `setup_credentials.py` for secure setup

---

## Offline Capability

ShaneBrain is designed for complete offline operation:

**Works Offline:**
- All AI inference (Llama local)
- Vector search (Weaviate local)
- Document storage (MongoDB local)
- Planning system (filesystem)

**Optional Cloud (Backup Only):**
- MongoDB Atlas
- Weaviate Cloud
- GitHub (code only)

---

## Performance Considerations

### Hardware Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| RAM | 4GB | 16GB |
| Storage | 100GB | 2TB |
| CPU | 4 cores | 8+ cores |
| GPU | None | NVIDIA 8GB+ |

### Optimization Tips

1. **Use quantized models** (Q4_K_M) for faster inference
2. **Enable GPU acceleration** if available
3. **Limit Weaviate query results** to necessary count
4. **Use conversation memory window** to limit context
5. **Archive old projects** to reduce active data

---

## Extensibility

### Adding New Chains

```python
# langchain-chains/my_chain.py
from langchain.chains import LLMChain

class MyChain:
    def __init__(self, llm=None):
        self.llm = llm

    def run(self, input_data):
        # Your logic here
        pass
```

### Adding New Schemas

1. Create JSON schema in `weaviate-config/schemas/`
2. Run schema initialization
3. Update agent to use new schema

### Adding New Projects

1. Create template in `planning-system/templates/`
2. Add project-specific guidelines
3. Update agent modes if needed

---

## Monitoring

### Health Check

```bash
python scripts/health_check.py --verbose
```

### Docker Logs

```bash
cd weaviate-config
docker-compose logs -f weaviate
```

### MongoDB Logs

```bash
# Check audit log
tail -f $SHANEBRAIN_ROOT/logs/mongodb-audit.log
```

---

**Architecture designed for: Local-first, offline-capable, privacy-preserving AI.**
