#!/usr/bin/env python3
"""
RAG Query Chain with Reranking - ShaneBrain Core
=================================================

Retrieval-Augmented Generation with cosine similarity reranking.
Uses Weaviate for vector search and Ollama for local LLM inference.

Usage:
    python rag_query_chain.py

Author: Shane Brazelton
"""

import os
import requests
import numpy as np
from typing import List, Any

try:
    from weaviate import Client
    WEAVIATE_AVAILABLE = True
except ImportError:
    WEAVIATE_AVAILABLE = False
    print("Warning: weaviate not installed. Install with: pip install weaviate-client")

try:
    from langchain.chains import RetrievalQA
    from langchain.llms.base import LLM
    from langchain.prompts import PromptTemplate
    from langchain_community.vectorstores import Weaviate
    from langchain.schema import Document
    LANGCHAIN_AVAILABLE = True
except ImportError:
    LANGCHAIN_AVAILABLE = False
    print("Warning: langchain not installed. Install with: pip install langchain langchain-community")

WEAVIATE_URL = os.getenv("WEAVIATE_URL", "http://localhost:8080")
OLLAMA_URL = os.getenv("OLLAMA_URL", "http://localhost:11434/api/generate")
EMBED_URL = os.getenv("OLLAMA_EMBED_URL", "http://localhost:11434/api/embeddings")
MODEL = os.getenv("OLLAMA_MODEL", "llama3.2:1b")
TOP_K = 10
SIM_THRESHOLD = 0.7
RERANK_TOP = 3


def get_client():
    """Get Weaviate client."""
    if not WEAVIATE_AVAILABLE:
        raise RuntimeError("Weaviate client not available - pip install weaviate-client")
    return Client(WEAVIATE_URL)


def embed_text(text: str) -> np.ndarray:
    """Generate embeddings using Ollama."""
    response = requests.post(EMBED_URL, json={"model": MODEL, "prompt": text})
    if response.status_code != 200:
        raise ValueError(f"Ollama choked: {response.text}")
    return np.array(response.json()["embedding"])


def rerank_chunks(query: str, chunks: List[Any]) -> List[Any]:
    """Rerank chunks by cosine similarity to query."""
    query_vec = embed_text(query)
    scored = []

    for chunk in chunks:
        # Handle both Document objects and dicts
        content = chunk.page_content if hasattr(chunk, 'page_content') else chunk.get('content', '')
        chunk_vec = embed_text(content)

        # Cosine similarity
        sim = np.dot(query_vec, chunk_vec) / (np.linalg.norm(query_vec) * np.linalg.norm(chunk_vec))

        if sim > SIM_THRESHOLD:
            scored.append((sim, chunk))

    scored.sort(reverse=True, key=lambda x: x[0])
    return [chunk for _, chunk in scored[:RERANK_TOP]]


class OllamaLLM(LLM):
    """Custom LLM wrapper for Ollama."""

    def _call(self, prompt: str, stop: List[str] = None) -> str:
        """Call Ollama API."""
        response = requests.post(OLLAMA_URL, json={
            "model": MODEL,
            "prompt": prompt,
            "stream": False
        })
        if response.status_code != 200:
            raise ValueError(f"Ollama choked: {response.text}")
        return response.json()["response"]

    @property
    def _llm_type(self) -> str:
        return "ollama_custom"


# Prompt template for RAG
PROMPT_TEMPLATE = """
Based on these reranked chunks: {context}

Answer this: {question}

Keep it direct, no bullshit.
"""

PROMPT = PromptTemplate(template=PROMPT_TEMPLATE, input_variables=["context", "question"])


def query_rag(question: str) -> str:
    """
    Query the RAG pipeline with reranking.

    Args:
        question: The question to answer

    Returns:
        Generated answer based on retrieved context
    """
    client = get_client()

    if not client.is_ready():
        raise RuntimeError("Weaviate's ghosted—docker up.")

    # Query Weaviate directly for initial retrieval
    result = client.query.get("Docs", ["content", "source", "chunk_id"]) \
        .with_near_text({"concepts": [question]}) \
        .with_limit(TOP_K) \
        .do()

    initial_chunks = result.get("data", {}).get("Get", {}).get("Docs", [])

    if not initial_chunks:
        return "No relevant context found. The empire's memory is empty on this one."

    # Rerank by cosine similarity
    reranked = rerank_chunks(question, initial_chunks)

    if not reranked:
        return "All chunks below similarity threshold. Try a different query."

    # Build context from reranked chunks
    context = "\n\n---\n\n".join([
        chunk.get('content', '') if isinstance(chunk, dict) else chunk.page_content
        for chunk in reranked
    ])

    # Generate with Ollama
    llm = OllamaLLM()
    prompt = PROMPT.format(context=context, question=question)

    return llm._call(prompt)


def build_qa_chain():
    """Build LangChain RetrievalQA chain (if LangChain available)."""
    if not LANGCHAIN_AVAILABLE:
        raise RuntimeError("LangChain not available - pip install langchain langchain-community")

    client = get_client()
    vectorstore = Weaviate(client, "Docs", "content")
    llm = OllamaLLM()
    retriever = vectorstore.as_retriever(search_kwargs={"k": TOP_K})

    return RetrievalQA.from_chain_type(
        llm=llm,
        chain_type="stuff",
        retriever=retriever,
        chain_type_kwargs={"prompt": PROMPT},
        return_source_documents=True
    )


if __name__ == "__main__":
    print("=" * 60)
    print("RAG Query Chain - ShaneBrain Core")
    print("=" * 60)
    print()

    client = get_client()
    if not client.is_ready():
        raise RuntimeError("Weaviate's ghosted—docker up.")

    question = "Who is Shane?"
    print(f"Query: {question}")
    print()
    print("Response:")
    print("-" * 40)
    print(query_rag(question))
    print("-" * 40)
    print()
    print("Rerank chain locked. Empire queries sharper.")
