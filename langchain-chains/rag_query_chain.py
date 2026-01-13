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
from typing import List, Any, Optional

try:
    import weaviate
    from weaviate.classes.query import MetadataQuery
    WEAVIATE_AVAILABLE = True
except ImportError:
    WEAVIATE_AVAILABLE = False
    print("Warning: weaviate not installed. Install with: pip install weaviate-client")

try:
    from langchain.chains import RetrievalQA
    from langchain.llms.base import LLM
    from langchain_core.prompts import PromptTemplate
    from langchain.schema import Document
    LANGCHAIN_AVAILABLE = True
except ImportError:
    try:
        from langchain.chains import RetrievalQA
        from langchain.llms.base import LLM
        from langchain.prompts import PromptTemplate
        from langchain.schema import Document
        LANGCHAIN_AVAILABLE = True
    except ImportError:
        LANGCHAIN_AVAILABLE = False
        print("Warning: langchain not installed. Install with: pip install langchain langchain-community")

WEAVIATE_HOST = os.getenv("WEAVIATE_HOST", "localhost")
WEAVIATE_PORT = int(os.getenv("WEAVIATE_PORT", "8080"))
OLLAMA_URL = os.getenv("OLLAMA_URL", "http://localhost:11434/api/generate")
EMBED_URL = os.getenv("OLLAMA_EMBED_URL", "http://localhost:11434/api/embeddings")
MODEL = os.getenv("OLLAMA_MODEL", "llama3.2:1b")
TOP_K = 10
SIM_THRESHOLD = 0.7
RERANK_TOP = 3


def get_client():
    """Get Weaviate v4 client."""
    if not WEAVIATE_AVAILABLE:
        raise RuntimeError("Weaviate client not available - pip install weaviate-client")
    return weaviate.connect_to_local(host=WEAVIATE_HOST, port=WEAVIATE_PORT)


def embed_text(text: str) -> np.ndarray:
    """Generate embeddings using Ollama."""
    response = requests.post(EMBED_URL, json={"model": MODEL, "prompt": text})
    if response.status_code != 200:
        raise ValueError(f"Ollama embedding failed: {response.text}")
    return np.array(response.json()["embedding"])


def rerank_chunks(query: str, chunks: List[Any]) -> List[Any]:
    """Rerank chunks by cosine similarity to query."""
    query_vec = embed_text(query)
    scored = []

    for chunk in chunks:
        # Handle both Document objects and dicts
        if hasattr(chunk, 'page_content'):
            content = chunk.page_content
        elif hasattr(chunk, 'properties'):
            content = chunk.properties.get('content', '')
        elif isinstance(chunk, dict):
            content = chunk.get('content', '')
        else:
            content = str(chunk)

        if not content:
            continue

        chunk_vec = embed_text(content)

        # Cosine similarity
        norm_product = np.linalg.norm(query_vec) * np.linalg.norm(chunk_vec)
        if norm_product == 0:
            continue
        sim = np.dot(query_vec, chunk_vec) / norm_product

        if sim > SIM_THRESHOLD:
            scored.append((sim, chunk))

    scored.sort(reverse=True, key=lambda x: x[0])
    return [chunk for _, chunk in scored[:RERANK_TOP]]


class OllamaLLM(LLM):
    """Custom LLM wrapper for Ollama."""

    def _call(self, prompt: str, stop: Optional[List[str]] = None) -> str:
        """Call Ollama API."""
        response = requests.post(OLLAMA_URL, json={
            "model": MODEL,
            "prompt": prompt,
            "stream": False
        })
        if response.status_code != 200:
            raise ValueError(f"Ollama generation failed: {response.text}")
        return response.json()["response"]

    @property
    def _llm_type(self) -> str:
        return "ollama_custom"


# Prompt template for RAG
PROMPT_TEMPLATE = """
Based on these retrieved context chunks:

{context}

Answer this question: {question}

Provide a direct, concise answer based on the context provided.
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
    client = None
    try:
        client = get_client()

        if not client.is_ready():
            raise RuntimeError("Weaviate is offline - ensure Docker containers are running")

        # Get the Docs collection
        docs_collection = client.collections.get("Docs")

        # Query using near_text (requires vectorizer or manual vector)
        # Since we use custom vectors, we need to embed the query first
        query_vector = embed_text(question)

        # Query with vector
        results = docs_collection.query.near_vector(
            near_vector=query_vector.tolist(),
            limit=TOP_K,
            return_metadata=MetadataQuery(distance=True)
        )

        initial_chunks = list(results.objects)

        if not initial_chunks:
            return "No relevant context found in the knowledge base."

        # Rerank by cosine similarity
        reranked = rerank_chunks(question, initial_chunks)

        if not reranked:
            return "All retrieved chunks below similarity threshold. Try rephrasing your query."

        # Build context from reranked chunks
        context_parts = []
        for chunk in reranked:
            if hasattr(chunk, 'properties'):
                content = chunk.properties.get('content', '')
            elif isinstance(chunk, dict):
                content = chunk.get('content', '')
            else:
                content = str(chunk)
            if content:
                context_parts.append(content)

        context = "\n\n---\n\n".join(context_parts)

        # Generate with Ollama
        llm = OllamaLLM()
        prompt = PROMPT.format(context=context, question=question)

        return llm._call(prompt)

    finally:
        if client:
            client.close()


def build_qa_chain():
    """Build LangChain RetrievalQA chain (if LangChain available)."""
    if not LANGCHAIN_AVAILABLE:
        raise RuntimeError("LangChain not available - pip install langchain langchain-community")

    # Note: LangChain's Weaviate integration may need updates for v4
    # This is a simplified implementation using custom retrieval
    raise NotImplementedError(
        "LangChain Weaviate integration pending v4 compatibility updates. "
        "Use query_rag() function directly for now."
    )


if __name__ == "__main__":
    print("=" * 60)
    print("RAG Query Chain - ShaneBrain Core")
    print("=" * 60)
    print()

    client = None
    try:
        client = get_client()
        if not client.is_ready():
            raise RuntimeError("Weaviate is offline - ensure Docker containers are running")
        client.close()
        client = None

        question = "Who is Shane?"
        print(f"Query: {question}")
        print()
        print("Response:")
        print("-" * 40)
        print(query_rag(question))
        print("-" * 40)
        print()
        print("RAG query chain operational.")

    except Exception as e:
        print(f"Error: {e}")
    finally:
        if client:
            client.close()
