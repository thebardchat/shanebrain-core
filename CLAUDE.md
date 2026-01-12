# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ShaneBrain Core is a local-first AI infrastructure powering four projects: Angel Cloud (mental wellness), Pulsar AI (blockchain security), LogiBot (dispatch automation), and ShaneBrain Legacy (digital legacy). The philosophy is local-first, cloud-backup—everything runs offline with cloud as optional redundancy.

## Common Commands

### Install Dependencies
```bash
pip install -r requirements.txt
```

### Start/Stop Services
```bash
# Start everything (Windows)
scripts/start-shanebrain.bat

# Start Weaviate only
cd weaviate-config && docker-compose up -d

# Stop Weaviate
cd weaviate-config && docker-compose down

# View Weaviate logs
cd weaviate-config && docker-compose logs -f weaviate
```

### Ollama (Local LLM)
```bash
# Check Ollama status
ollama list

# Pull the lightweight model (for 8GB RAM systems)
ollama pull llama3.2:1b

# Pull the larger model (needs 16GB+ RAM)
ollama pull llama3.2
```

### Health Check
```bash
python scripts/health_check.py
```

### Run the Main Agent
```bash
python langchain-chains/shanebrain_agent.py
```

### Run Angel Cloud CLI (Mental Wellness Interface)
```bash
python langchain-chains/angel_cloud_cli.py
```

### Weaviate Schema Setup
```bash
# Complete setup (recommended for first-time setup)
python scripts/setup_all_weaviate.py

# Or run individual steps:
python scripts/setup_weaviate_schema.py      # Create core schema classes
python scripts/load_json_schemas.py          # Load JSON schema definitions
python scripts/import_rag_to_weaviate.py RAG.md  # Import RAG knowledge base
python scripts/verify_weaviate.py            # Verify setup and show status

# Query legacy knowledge interactively
python scripts/query_legacy.py

# Run integration tests
python scripts/test_weaviate_integration.py

# Backup/Restore data
python scripts/backup_weaviate.py              # Backup to weaviate-backups/
python scripts/restore_weaviate.py <backup_dir>  # Restore from backup
python scripts/clear_weaviate.py               # Clear data (with confirmation)
```

## Architecture

### Core Components

1. **Ollama LLM** (localhost:11434)
   - Local LLM inference via Ollama
   - Default model: `llama3.2:1b` (for 8GB RAM systems)
   - Configured via `OLLAMA_HOST` and `OLLAMA_MODEL` env vars

2. **Weaviate Vector Database** (localhost:8080)
   - Requires Weaviate 1.27.0+ for Python client v4 compatibility
   - Local embeddings via `text2vec-transformers` (sentence-transformers-all-MiniLM-L6-v2)
   - QnA module via `qna-transformers`
   - Data persisted in `weaviate-config/data/`
   - Docker containers: `shanebrain-weaviate`, `shanebrain-t2v`, `shanebrain-qna`

3. **LangChain Chains** (`langchain-chains/`)
   - `shanebrain_agent.py` - Central agent integrating all components, supports modes: CHAT, MEMORY, WELLNESS, SECURITY, DISPATCH, CODE
   - `angel_cloud_cli.py` - Interactive CLI for Angel Cloud mental wellness
   - `crisis_detection_chain.py` - Mental health crisis detection for Angel Cloud
   - `qa_retrieval_chain.py` - RAG-based question answering
   - `code_generation_chain.py` - Code generation support

4. **Planning System** (`planning-system/`)
   - Markdown-based persistent planning for multi-session continuity
   - Templates in `templates/` (tracked in git)
   - Active projects in `active-projects/` (gitignored - contains personal data)
   - Uses checkbox markers: `[ ]` not started, `[x]` completed, `[~]` in progress, `[!]` blocked

5. **MongoDB Schemas** (`mongodb-schemas/`)
   - `conversations.json`, `user_sessions.json`, `crisis_logs.json`

6. **Weaviate Schemas** (`weaviate-config/schemas/`)
   - `shanebrain-memory.json`, `angel-cloud-conversations.json`, `pulsar-security-events.json`

7. **Weaviate Setup Scripts** (`scripts/`)
   - `setup_all_weaviate.py` - Complete setup orchestration (run this first)
   - `setup_weaviate_schema.py` - Creates core classes (Conversation, LegacyKnowledge, CrisisLog)
   - `load_json_schemas.py` - Loads JSON schemas for advanced classes
   - `import_rag_to_weaviate.py` - Imports RAG.md into LegacyKnowledge
   - `verify_weaviate.py` - Verifies schema and shows record counts
   - `query_legacy.py` - Interactive CLI for querying LegacyKnowledge
   - `test_weaviate_integration.py` - Integration test suite
   - `weaviate_helpers.py` - Reusable helper class for Weaviate operations
   - `backup_weaviate.py` - Export data to JSON backups
   - `restore_weaviate.py` - Import data from JSON backups
   - `clear_weaviate.py` - Clear or delete collections

### Multi-Project Support

The codebase supports four distinct projects with shared infrastructure:
- **Angel Cloud**: Mental wellness with crisis detection (AgentMode.WELLNESS)
- **Pulsar AI**: Blockchain security analysis (AgentMode.SECURITY)
- **LogiBot**: Dispatch automation (AgentMode.DISPATCH)
- **ShaneBrain Legacy**: Digital legacy/family memory (AgentMode.MEMORY)

## Key Patterns

### Environment Configuration
Configuration is in `.env` (gitignored). Template available at `.env.template`. Required variables include `SHANEBRAIN_ROOT` and `WEAVIATE_URL`.

### Optional Dependencies
LangChain chains gracefully handle missing dependencies with `*_AVAILABLE` boolean flags (e.g., `WEAVIATE_AVAILABLE`, `LANGCHAIN_AVAILABLE`).

### Data Privacy
- Personal planning files, conversation logs, and crisis data are gitignored
- Only templates and schemas are tracked
- Local-first means all sensitive data stays on user hardware
