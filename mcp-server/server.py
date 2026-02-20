#!/usr/bin/env python3
"""
ShaneBrain MCP Server — Exposes ShaneBrain tools via Model Context Protocol.

19 tools across 7 groups:
  Knowledge (2), Chat (3), RAG (1), Social (2),
  Vault (3), Notes (3), Drafts (2), Security (2), System (1)

Transport: Streamable HTTP on port 8100
"""

import os
import json
import uuid
from datetime import datetime, timezone
from typing import Optional

import ollama
from mcp.server.fastmcp import FastMCP
from weaviate.classes.query import Filter

from weaviate_bridge import DockerWeaviateHelper
from health import check_weaviate, check_ollama, check_gateway

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
OLLAMA_HOST = os.environ.get("OLLAMA_HOST", "http://localhost:11434")
OLLAMA_MODEL = os.environ.get("OLLAMA_MODEL", "shanebrain-3b:latest")
RAG_CHUNK_LIMIT = 5

# ---------------------------------------------------------------------------
# MCP Server
# ---------------------------------------------------------------------------
mcp = FastMCP(
    "ShaneBrain",
    instructions="ShaneBrain AI tools — knowledge, chat, RAG, social, vault, notes, drafts, security, and system health.",
    host="0.0.0.0",
    port=8100,
)


def _get_helper() -> DockerWeaviateHelper:
    """Get a connected Weaviate helper."""
    h = DockerWeaviateHelper()
    h.connect()
    return h


def _close(helper):
    try:
        helper.close()
    except Exception:
        pass


# ===========================================================================
# Group 1: Knowledge (LegacyKnowledge)
# ===========================================================================

@mcp.tool()
def search_knowledge(query: str, category: Optional[str] = None, limit: int = 5) -> str:
    """Search ShaneBrain's legacy knowledge base semantically.

    Args:
        query: What to search for (e.g. "family values", "sobriety journey")
        category: Optional filter — family, faith, technical, philosophy, general, wellness
        limit: Max results (default 5)
    """
    h = _get_helper()
    try:
        results = h.search_knowledge(query, category=category, limit=limit)
        if not results:
            return json.dumps({"results": [], "message": "No matches found."})
        return json.dumps({"results": results, "count": len(results)}, default=str)
    finally:
        _close(h)


@mcp.tool()
def add_knowledge(content: str, category: str, source: str = "mcp", title: Optional[str] = None) -> str:
    """Add an entry to ShaneBrain's legacy knowledge base.

    Args:
        content: The knowledge content
        category: Category — family, faith, technical, philosophy, general, wellness
        source: Where this came from (default "mcp")
        title: Optional title
    """
    h = _get_helper()
    try:
        uid = h.add_knowledge(content, category, source=source, title=title)
        if uid:
            return json.dumps({"success": True, "uuid": uid})
        return json.dumps({"success": False, "error": "Failed to add — collection may not exist."})
    finally:
        _close(h)


# ===========================================================================
# Group 2: Chat (Conversation)
# ===========================================================================

@mcp.tool()
def search_conversations(query: str, mode: Optional[str] = None, limit: int = 10) -> str:
    """Search past ShaneBrain conversations semantically.

    Args:
        query: What to search for
        mode: Optional filter — CHAT, MEMORY, WELLNESS, SECURITY, DISPATCH, CODE
        limit: Max results (default 10)
    """
    h = _get_helper()
    try:
        results = h.search_conversations(query, mode=mode, limit=limit)
        return json.dumps({"results": results, "count": len(results)}, default=str)
    finally:
        _close(h)


@mcp.tool()
def log_conversation(message: str, role: str, mode: str = "CHAT", session_id: Optional[str] = None) -> str:
    """Log a message to ShaneBrain's conversation history.

    Args:
        message: The message content
        role: Role — user, assistant, system
        mode: Agent mode — CHAT, MEMORY, WELLNESS, SECURITY, DISPATCH, CODE
        session_id: Session ID (auto-generated if omitted)
    """
    h = _get_helper()
    try:
        uid = h.log_conversation(message, role, mode=mode, session_id=session_id)
        if uid:
            return json.dumps({"success": True, "uuid": uid})
        return json.dumps({"success": False, "error": "Failed to log."})
    finally:
        _close(h)


@mcp.tool()
def get_conversation_history(session_id: str, limit: int = 50) -> str:
    """Get conversation history for a session.

    Args:
        session_id: The session identifier
        limit: Max messages (default 50)
    """
    h = _get_helper()
    try:
        results = h.get_conversation_history(session_id, limit=limit)
        return json.dumps({"messages": results, "count": len(results)}, default=str)
    finally:
        _close(h)


# ===========================================================================
# Group 3: RAG Chat
# ===========================================================================

def _get_system_prompt():
    """Build the ShaneBrain system prompt with family info."""
    sobriety_days = (datetime.now() - datetime(2023, 11, 27)).days
    sobriety_years = sobriety_days // 365
    sobriety_months = (sobriety_days % 365) // 30

    return f"""You are ShaneBrain - Shane Brazelton's AI, built to serve his family for generations.

CRITICAL RULES:
1. BE BRIEF: 2-4 sentences MAX unless asked for more
2. NEVER HALLUCINATE: If you don't know, say "I don't know that yet"
3. NO FLUFF: Never say "certainly", "I'd be happy to", "great question"
4. FACTS ONLY: Only state what you know for certain

FAMILY (Shane is the FATHER of all 5 sons):
- Shane Brazelton: Father, Creator of ShaneBrain
- Tiffany Brazelton: Wife, Mother
- Gavin Brazelton: Eldest son, married to Angel
- Kai Brazelton: Second son
- Pierce Brazelton: Third son, has ADHD like Shane, wrestler
- Jaxton Brazelton: Fourth son, wrestler
- Ryker Brazelton: Youngest son
- Angel Brazelton: Daughter-in-law, married to Gavin

SOBRIETY: Shane has been sober since November 27, 2023 ({sobriety_years} years, {sobriety_months} months)

Be direct. Be brief. Be accurate."""


@mcp.tool()
def chat_with_shanebrain(message: str) -> str:
    """Full RAG chat with ShaneBrain — searches knowledge, then generates a response via Ollama.

    Args:
        message: Your message to ShaneBrain
    """
    h = _get_helper()
    try:
        # RAG: search knowledge
        chunks = []
        results = h.search_knowledge(message, limit=RAG_CHUNK_LIMIT)
        for r in results:
            content = r.get("content", "")
            title = r.get("title", "")
            if content:
                chunks.append(f"[{title}]\n{content}" if title else content)

        # Build prompt
        system = _get_system_prompt()
        if chunks:
            context = "\n\n---\n\n".join(chunks)
            system += f"\n\nRELEVANT KNOWLEDGE FROM MEMORY:\n{context}\n\nUse this knowledge to answer. If it doesn't help, say you don't know."

        # Generate via Ollama
        client = ollama.Client(host=OLLAMA_HOST)
        response = client.chat(
            model=OLLAMA_MODEL,
            messages=[
                {"role": "system", "content": system},
                {"role": "user", "content": message},
            ],
            options={"temperature": 0.3, "num_predict": 300},
            keep_alive="10m",
        )

        reply = response["message"]["content"]
        return json.dumps({
            "response": reply,
            "knowledge_chunks_used": len(chunks),
        })
    except Exception as e:
        return json.dumps({"error": str(e)})
    finally:
        _close(h)


# ===========================================================================
# Group 4: Social (FriendProfile)
# ===========================================================================

@mcp.tool()
def search_friends(query: str, limit: int = 10) -> str:
    """Search ShaneBrain's friend profiles semantically.

    Args:
        query: What to search for (e.g. a person's name or topic)
        limit: Max results (default 10)
    """
    h = _get_helper()
    try:
        results = h.search_friends(query, limit=limit)
        return json.dumps({"results": results, "count": len(results)}, default=str)
    finally:
        _close(h)


@mcp.tool()
def get_top_friends(limit: int = 10) -> str:
    """Get friend profiles ranked by relationship strength (highest first).

    Args:
        limit: Max results (default 10)
    """
    h = _get_helper()
    try:
        results = h.get_top_friends(limit=limit)
        return json.dumps({"results": results, "count": len(results)}, default=str)
    finally:
        _close(h)


# ===========================================================================
# Group 5: Vault (PersonalDoc)
# ===========================================================================

@mcp.tool()
def vault_search(query: str, category: Optional[str] = None, limit: int = 10) -> str:
    """Search Shane's personal vault (PersonalDoc collection) semantically.

    Args:
        query: What to search for
        category: Optional category filter
        limit: Max results (default 10)
    """
    h = _get_helper()
    try:
        filters = None
        if category:
            filters = Filter.by_property("category").equal(category)
        results = h._generic_near_text("PersonalDoc", query, filters=filters, limit=limit)
        if not results and not h.collection_exists("PersonalDoc"):
            return json.dumps({"results": [], "message": "PersonalDoc collection does not exist yet."})
        return json.dumps({"results": results, "count": len(results)}, default=str)
    finally:
        _close(h)


@mcp.tool()
def vault_add(content: str, category: str, title: Optional[str] = None, tags: Optional[str] = None) -> str:
    """Add a document to Shane's personal vault (PersonalDoc).

    Args:
        content: Document content
        category: Category (e.g. medical, legal, financial, personal, work)
        title: Optional title
        tags: Optional comma-separated tags
    """
    h = _get_helper()
    try:
        data = {
            "content": content,
            "category": category,
            "created_at": datetime.now(timezone.utc).isoformat(),
        }
        if title:
            data["title"] = title
        if tags:
            data["tags"] = [t.strip() for t in tags.split(",")]
        uid = h._generic_insert("PersonalDoc", data)
        if uid:
            return json.dumps({"success": True, "uuid": uid})
        return json.dumps({"success": False, "error": "PersonalDoc collection may not exist yet."})
    finally:
        _close(h)


@mcp.tool()
def vault_list_categories(limit: int = 100) -> str:
    """List document counts per category in the PersonalDoc vault."""
    h = _get_helper()
    try:
        if not h.collection_exists("PersonalDoc"):
            return json.dumps({"error": "PersonalDoc collection does not exist yet.", "categories": {}})
        docs = h._generic_fetch("PersonalDoc", limit=limit)
        counts = {}
        for d in docs:
            cat = d.get("category", "uncategorized")
            counts[cat] = counts.get(cat, 0) + 1
        return json.dumps({"categories": counts, "total": len(docs)})
    finally:
        _close(h)


# ===========================================================================
# Group 6: Notes (DailyNote)
# ===========================================================================

@mcp.tool()
def daily_note_add(content: str, note_type: str = "journal", mood: Optional[str] = None) -> str:
    """Add a daily note (journal, todo, reminder, or reflection).

    Args:
        content: Note content
        note_type: Type — journal, todo, reminder, reflection
        mood: Optional mood tag (e.g. grateful, tired, focused, anxious)
    """
    h = _get_helper()
    try:
        data = {
            "content": content,
            "note_type": note_type,
            "date": datetime.now(timezone.utc).strftime("%Y-%m-%d"),
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }
        if mood:
            data["mood"] = mood
        uid = h._generic_insert("DailyNote", data)
        if uid:
            return json.dumps({"success": True, "uuid": uid})
        return json.dumps({"success": False, "error": "DailyNote collection does not exist yet."})
    finally:
        _close(h)


@mcp.tool()
def daily_note_search(query: str, note_type: Optional[str] = None, limit: int = 10) -> str:
    """Search daily notes semantically.

    Args:
        query: What to search for
        note_type: Optional filter — journal, todo, reminder, reflection
        limit: Max results (default 10)
    """
    h = _get_helper()
    try:
        filters = None
        if note_type:
            filters = Filter.by_property("note_type").equal(note_type)
        results = h._generic_near_text("DailyNote", query, filters=filters, limit=limit)
        if not results and not h.collection_exists("DailyNote"):
            return json.dumps({"results": [], "message": "DailyNote collection does not exist yet."})
        return json.dumps({"results": results, "count": len(results)}, default=str)
    finally:
        _close(h)


@mcp.tool()
def daily_briefing() -> str:
    """Get an AI-generated daily briefing summarizing recent notes via Ollama."""
    h = _get_helper()
    try:
        if not h.collection_exists("DailyNote"):
            return json.dumps({"error": "DailyNote collection does not exist yet."})

        notes = h._generic_fetch("DailyNote", limit=20)
        if not notes:
            return json.dumps({"briefing": "No daily notes found.", "note_count": 0})

        # Build summary prompt
        note_texts = []
        for n in notes:
            ntype = n.get("note_type", "note")
            content = n.get("content", "")
            date = n.get("date", "")
            note_texts.append(f"[{date} - {ntype}] {content}")

        notes_block = "\n".join(note_texts)
        client = ollama.Client(host=OLLAMA_HOST)
        response = client.chat(
            model=OLLAMA_MODEL,
            messages=[
                {"role": "system", "content": "You are ShaneBrain. Summarize these daily notes into a brief daily briefing. Be concise — bullet points preferred."},
                {"role": "user", "content": f"Here are recent notes:\n\n{notes_block}\n\nGive me a daily briefing."},
            ],
            options={"temperature": 0.3, "num_predict": 300},
            keep_alive="10m",
        )
        return json.dumps({
            "briefing": response["message"]["content"],
            "note_count": len(notes),
        })
    except Exception as e:
        return json.dumps({"error": str(e)})
    finally:
        _close(h)


# ===========================================================================
# Group 7: Drafts (PersonalDraft)
# ===========================================================================

@mcp.tool()
def draft_create(prompt: str, draft_type: str = "general", use_vault_context: bool = True) -> str:
    """Generate a writing draft with optional vault context via Ollama.

    Args:
        prompt: What to write about
        draft_type: Type — email, message, post, letter, general
        use_vault_context: Whether to search PersonalDoc for context (default True)
    """
    h = _get_helper()
    try:
        context_chunks = []
        if use_vault_context and h.collection_exists("PersonalDoc"):
            results = h._generic_near_text("PersonalDoc", prompt, limit=3)
            for r in results:
                content = r.get("content", "")
                if content:
                    context_chunks.append(content)

        system = "You are ShaneBrain, helping Shane draft content. Match his voice: direct, warm, no fluff."
        if context_chunks:
            ctx = "\n---\n".join(context_chunks)
            system += f"\n\nRelevant context from vault:\n{ctx}"

        client = ollama.Client(host=OLLAMA_HOST)
        response = client.chat(
            model=OLLAMA_MODEL,
            messages=[
                {"role": "system", "content": system},
                {"role": "user", "content": f"Draft a {draft_type}: {prompt}"},
            ],
            options={"temperature": 0.5, "num_predict": 500},
            keep_alive="10m",
        )

        draft_text = response["message"]["content"]

        # Save to PersonalDraft if collection exists
        saved_uuid = None
        if h.collection_exists("PersonalDraft"):
            saved_uuid = h._generic_insert("PersonalDraft", {
                "content": draft_text,
                "prompt": prompt,
                "draft_type": draft_type,
                "timestamp": datetime.now(timezone.utc).isoformat(),
            })

        return json.dumps({
            "draft": draft_text,
            "draft_type": draft_type,
            "saved": saved_uuid is not None,
            "uuid": saved_uuid,
            "vault_context_used": len(context_chunks),
        })
    except Exception as e:
        return json.dumps({"error": str(e)})
    finally:
        _close(h)


@mcp.tool()
def draft_search(query: str, draft_type: Optional[str] = None, limit: int = 10) -> str:
    """Search saved writing drafts (PersonalDraft) semantically.

    Args:
        query: What to search for
        draft_type: Optional filter — email, message, post, letter, general
        limit: Max results (default 10)
    """
    h = _get_helper()
    try:
        filters = None
        if draft_type:
            filters = Filter.by_property("draft_type").equal(draft_type)
        results = h._generic_near_text("PersonalDraft", query, filters=filters, limit=limit)
        if not results and not h.collection_exists("PersonalDraft"):
            return json.dumps({"results": [], "message": "PersonalDraft collection does not exist yet."})
        return json.dumps({"results": results, "count": len(results)}, default=str)
    finally:
        _close(h)


# ===========================================================================
# Group 8: Security (SecurityLog, PrivacyAudit)
# ===========================================================================

@mcp.tool()
def security_log_search(query: str, limit: int = 10) -> str:
    """Search SecurityLog entries semantically.

    Args:
        query: What to search for (e.g. "failed login", "unusual activity")
        limit: Max results (default 10)
    """
    h = _get_helper()
    try:
        results = h._generic_near_text("SecurityLog", query, limit=limit)
        if not results and not h.collection_exists("SecurityLog"):
            return json.dumps({"results": [], "message": "SecurityLog collection does not exist yet."})
        return json.dumps({"results": results, "count": len(results)}, default=str)
    finally:
        _close(h)


@mcp.tool()
def privacy_audit_search(query: str, limit: int = 10) -> str:
    """Search PrivacyAudit entries semantically.

    Args:
        query: What to search for
        limit: Max results (default 10)
    """
    h = _get_helper()
    try:
        results = h._generic_near_text("PrivacyAudit", query, limit=limit)
        if not results and not h.collection_exists("PrivacyAudit"):
            return json.dumps({"results": [], "message": "PrivacyAudit collection does not exist yet."})
        return json.dumps({"results": results, "count": len(results)}, default=str)
    finally:
        _close(h)


# ===========================================================================
# Group 9: System Health
# ===========================================================================

@mcp.tool()
def system_health() -> str:
    """Check ShaneBrain system health — Weaviate, Ollama, Gateway status and all collection counts."""
    h = _get_helper()
    try:
        weaviate_status = check_weaviate(h)
        ollama_status = check_ollama()
        gateway_status = check_gateway()
        counts = h.get_all_collection_counts()

        return json.dumps({
            "services": {
                "weaviate": weaviate_status,
                "ollama": ollama_status,
                "gateway": gateway_status,
            },
            "collections": counts,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }, default=str)
    except Exception as e:
        return json.dumps({"error": str(e)})
    finally:
        _close(h)


# ===========================================================================
# Entry point
# ===========================================================================

if __name__ == "__main__":
    mcp.run(transport="streamable-http")
