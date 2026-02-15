# RAG Pipeline - ShaneBrain Haul

Locked core: Retrieval-Augmented Generation for eternal knowledge. Weaviate vectors the docs (CLAUDE.md, RAG.md eternal), Ollama (llama3.2:1b) generates, LangChain chains the queries. No cloud bullshit—local fortress on 7.4GB RAM.

## Pipeline Breakdown (One Load at a Time)

### Ingestion Haul
- **Docs in:** RAG.md (Shane profile, family, mission), CLAUDE.md (status, ports).
- **Vectorize:** Weaviate schema (docker-compose up in weaviate-config/). Python loader: `from weaviate import Client; client = Client('http://localhost:8080'); client.data_object.create({...})`.
- **Chunk size:** 512 tokens, overlap 128. Embed with Ollama: `ollama.embed('llama3.2:1b', text)`.
- **Command:** Run `python langchain-chains/rag_ingest.py` (stub if missing: import weaviate/weaviate-client, loop docs, chunk/embed/store).

### Retrieval Grind
- **Query hits:** Semantic search on Weaviate. `client.query.get('Docs', ['content']).with_near_text({'concepts': [query]}).do()`.
- **Top-K:** 5 chunks, rerank by relevance (cosine sim >0.7).
- **Crisis hook:** In angel_cloud_cli.py, chain to RAG for wellness pulls (e.g., "Shane's sobriety: 2 years locked").

### Generation Blast
- **Augment prompt:** "Based on retrieved: [chunks]. Answer: [query]".
- **Ollama serve:** `ollama run llama3.2:1b --prompt-template`.
- **Output:** Fused response, no hallucinations—family legacy eternal.

## Chaos Fixes
- RAM choke? Pause t2v/qna in CLAUDE.md.
- Test run: `python -c "from langchain import *; chain = RetrievalQA(...); print(chain.run('Who is Shane?'))"`.
- Scale: Add Mongo for logs, Pulsar for secure vectors.
