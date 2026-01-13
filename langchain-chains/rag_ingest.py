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
    from weaviate import Client
    WEAVIATE_AVAILABLE = True
except ImportError:
    WEAVIATE_AVAILABLE = False
    print("Warning: weaviate not installed. Install with: pip install weaviate-client")

WEAVIATE_URL = os.getenv("WEAVIATE_URL", "http://localhost:8080")
OLLAMA_URL = os.getenv("OLLAMA_URL", "http://localhost:11434/api/embeddings")
MODEL = os.getenv("OLLAMA_MODEL", "llama3.2:1b")
CHUNK_SIZE = 512
OVERLAP = 128
DOCS_DIR = Path(__file__).parent.parent


def get_client():
    """Get Weaviate client."""
    if not WEAVIATE_AVAILABLE:
        raise RuntimeError("Weaviate client not available - pip install weaviate-client")
    return Client(WEAVIATE_URL)


def embed_text(text):
    """Generate embeddings using Ollama."""
    response = requests.post(OLLAMA_URL, json={"model": MODEL, "prompt": text})
    if response.status_code != 200:
        raise ValueError(f"Ollama fried: {response.text}")
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
    """Ensure Docs class exists in Weaviate."""
    schema = client.schema.get()
    class_names = [c["class"] for c in schema.get("classes", [])]

    if "Docs" not in class_names:
        print("Creating Docs class...")
        client.schema.create_class({
            "class": "Docs",
            "description": "RAG document chunks for ShaneBrain",
            "vectorizer": "none",  # We provide our own vectors
            "properties": [
                {"name": "content", "dataType": ["text"], "description": "Chunk content"},
                {"name": "source", "dataType": ["string"], "description": "Source file path"},
                {"name": "chunk_id", "dataType": ["int"], "description": "Chunk index in document"}
            ]
        })
        print("Docs class created.")


def ingest_docs():
    """Ingest all markdown docs from repo root."""
    client = get_client()

    if not client.is_ready():
        raise RuntimeError("Weaviate's offline—docker up that bitch.")

    ensure_schema(client)

    for doc_path in DOCS_DIR.glob("*.md"):
        print(f"Hauling {doc_path.name}...")
        with open(doc_path, 'r', encoding='utf-8') as f:
            content = f.read()

        chunks = chunk_text(content)
        for i, chunk in enumerate(chunks):
            if not chunk.strip():
                continue
            vector = embed_text(chunk)
            client.data_object.create(
                {"content": chunk, "source": str(doc_path), "chunk_id": i},
                "Docs",
                vector=vector
            )
        print(f"{doc_path.name} vectored and locked. {len(chunks)} chunks.")


if __name__ == "__main__":
    print("=" * 60)
    print("RAG Ingestion Pipeline - ShaneBrain Core")
    print("=" * 60)
    print()

    ingest_docs()

    print()
    print("RAG haul complete. Empire's smarter.")
