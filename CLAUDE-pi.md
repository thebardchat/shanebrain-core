# ShaneBrain Core

Personal AI assistant brain — the core of the Angel Cloud ecosystem (mental wellness and digital legacy platform).

## Stack

- **Runtime:** Python 3.11+ on Raspberry Pi 5 (8GB RAM, ~7.4GB usable)
- **Local LLM:** Ollama with llama3.2:1b
- **Vector/RAG:** Weaviate
- **Interface:** Open WebUI
- **OS:** Linux (Raspberry Pi OS)

## Key Files

- `RAG.md` — Personality, memory, and context for the AI assistant
- `angel_cloud_cli.py` — CLI interface
- `START-SHANEBRAIN.bat` — Windows launcher (for cross-platform use)

## Guidelines

- **RAM is precious.** Optimize everything for low memory. Avoid bloated libraries. Prefer lightweight alternatives.
- **Local-first.** Never suggest cloud services or dependencies unless explicitly asked. Everything runs on the Pi.
- **Modular and lean.** Keep scripts small, single-purpose, and easy to maintain.
- **Python 3.11+** — Use modern Python features (match/case, tomllib, etc.) where appropriate.
- **No unnecessary dependencies.** Minimize pip packages. Prefer stdlib when possible.

## Architecture Notes

- Ollama serves the LLM locally via API (default: http://localhost:11434)
- Weaviate handles vector storage and RAG retrieval
- Open WebUI provides the browser-based chat interface
- All components must coexist within ~7.4GB RAM budget
