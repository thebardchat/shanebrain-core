#!/usr/bin/env python3
"""
RAG Ingestion Pipeline - ShaneBrain Core
=========================================

Chunks and embeds markdown documents into Weaviate for RAG retrieval.
Uses Ollama for local embeddings - no cloud dependencies.

Usage:
    python rag_ingest.py

Author: Shane Brazelton
"""

import os
import requests
from pathlib import Path

try:
    import weaviate
    from weaviate.classes.config import Property, DataType, Configure
    WEAVIATE_AVAILABLE = True
except ImportError:
    WEAVIATE_AVAILABLE = False
    print("Warning: weaviate not installed. Install with: pip install weaviate-client")

WEAVIATE_HOST = os.getenv("WEAVIATE_HOST", "localhost")
WEAVIATE_PORT = int(os.getenv("WEAVIATE_PORT", "8080"))
OLLAMA_URL = os.getenv("OLLAMA_URL", "http://localhost:11434/api/embeddings")
MODEL = os.getenv("OLLAMA_MODEL", "llama3.2:1b")
CHUNK_SIZE = 512
OVERLAP = 128
DOCS_DIR = Path(__file__).parent.parent


def get_client():
    """Get Weaviate v4 client."""
    if not WEAVIATE_AVAILABLE:
        raise RuntimeError("Weaviate client not available - pip install weaviate-client")
    return weaviate.connect_to_local(host=WEAVIATE_HOST, port=WEAVIATE_PORT)


def embed_text(text):
    """Generate embeddings using Ollama."""
    response = requests.post(OLLAMA_URL, json={"model": MODEL, "prompt": text})
    if response.status_code != 200:
        raise ValueError(f"Ollama embedding failed: {response.text}")
    return response.json()["embedding"]


def chunk_text(text):
    """Split text into overlapping chunks."""
    chunks = []
    lines = text.splitlines()
    current_chunk = ""
    for line in lines:
        if len(current_chunk) + len(line) > CHUNK_SIZE:
            chunks.append(current_chunk.strip())
            current_chunk = current_chunk[-OVERLAP:] + line
        else:
            current_chunk += line + "\n"
    if current_chunk:
        chunks.append(current_chunk.strip())
    return chunks


def ensure_schema(client):
    """Ensure Docs collection exists in Weaviate v4."""
    try:
        collections = client.collections.list_all()
        if "Docs" not in collections:
            print("Creating Docs collection...")
            client.collections.create(
                name="Docs",
                description="RAG document chunks for ShaneBrain",
                vectorizer_config=Configure.Vectorizer.none(),
                properties=[
                    Property(name="content", data_type=DataType.TEXT, description="Chunk content"),
                    Property(name="source", data_type=DataType.TEXT, description="Source file path"),
                    Property(name="chunk_id", data_type=DataType.INT, description="Chunk index in document")
                ]
            )
            print("Docs collection created.")
        else:
            print("Docs collection already exists.")
    except Exception as e:
        print(f"Schema check error: {e}")
        raise


def ingest_docs():
    """Ingest all markdown docs from repo root."""
    client = None
    try:
        client = get_client()

        if not client.is_ready():
            raise RuntimeError("Weaviate is offline - ensure Docker containers are running")

        ensure_schema(client)
        docs_collection = client.collections.get("Docs")

        for doc_path in DOCS_DIR.glob("*.md"):
            print(f"Processing {doc_path.name}...")
            with open(doc_path, 'r', encoding='utf-8') as f:
                content = f.read()

            chunks = chunk_text(content)
            ingested = 0
            for i, chunk in enumerate(chunks):
                if not chunk.strip():
                    continue
                vector = embed_text(chunk)
                docs_collection.data.insert(
                    properties={"content": chunk, "source": str(doc_path), "chunk_id": i},
                    vector=vector
                )
                ingested += 1
            print(f"{doc_path.name} vectorized. {ingested} chunks ingested.")

    finally:
        if client:
            client.close()


if __name__ == "__main__":
    print("=" * 60)
    print("RAG Ingestion Pipeline - ShaneBrain Core")
    print("=" * 60)
    print()

    ingest_docs()

    print()
    print("RAG ingestion complete. Knowledge base updated.")
