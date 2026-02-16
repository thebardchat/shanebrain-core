"""
Angel Cloud Chat Engine — RAG-powered chat with ShaneBrain via Ollama.
Adapted from bot/bot.py for the Angel Cloud web interface.
"""

import sys
import os
from datetime import datetime, timezone

# Add parent dir so we can import from scripts/
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import ollama
from scripts.weaviate_helpers import WeaviateHelper

MODEL = "shanebrain-3b:latest"
RAG_CHUNK_LIMIT = 5

# ============================================================
# FAMILY DATA
# ============================================================
FAMILY = {
    "shane": {"name": "Shane Brazelton", "birth": "1977-11", "role": "Father, Creator of ShaneBrain"},
    "tiffany": {"name": "Tiffany Brazelton", "birth": "1994-06", "role": "Wife, Mother"},
    "gavin": {"name": "Gavin Brazelton", "birth": "1997-09", "role": "Eldest son, married to Angel"},
    "kai": {"name": "Kai Brazelton", "birth": "2003-11", "role": "Second son"},
    "pierce": {"name": "Pierce Brazelton", "birth": "2011-02", "role": "Third son, has ADHD like Shane, wrestler"},
    "jaxton": {"name": "Jaxton Brazelton", "birth": "2013-08", "role": "Fourth son, wrestler"},
    "ryker": {"name": "Ryker Brazelton", "birth": "2021-04", "role": "Youngest son"},
    "angel": {"name": "Angel Brazelton", "birth": None, "role": "Daughter-in-law, married to Gavin, Angel Cloud named after her"},
}

POSITIVE_WORDS = ["love", "great", "amazing", "awesome", "thank", "blessed", "proud", "congrats", "lol", "haha"]
NEGATIVE_WORDS = ["hate", "stupid", "terrible", "worst", "angry", "disappointed", "sucks"]
SUPPORTIVE_WORDS = ["praying", "support", "here for you", "got your back", "amen", "keep going", "proud of you"]


def calculate_age(birth_str):
    if not birth_str:
        return None
    year, month = map(int, birth_str.split("-"))
    today = datetime.now()
    age = today.year - year
    if today.month < month:
        age -= 1
    return age


def get_family_info():
    lines = []
    for key, person in FAMILY.items():
        age = calculate_age(person["birth"])
        age_str = f", {age} years old" if age else ""
        lines.append(f"- {person['name']}{age_str}: {person['role']}")
    return "\n".join(lines)


def get_system_prompt():
    family_info = get_family_info()
    sobriety_days = (datetime.now() - datetime(2023, 11, 27)).days
    sobriety_years = sobriety_days // 365
    sobriety_months = (sobriety_days % 365) // 30

    return f"""You are ShaneBrain - Shane Brazelton's AI, built to serve his family for generations.

CRITICAL RULES - FOLLOW EXACTLY:
1. BE BRIEF: 2-4 sentences MAX unless asked for more
2. NEVER HALLUCINATE: If you don't know, say "I don't know that yet - I'll ask Shane"
3. NO FLUFF: Never say "certainly", "I'd be happy to", "great question"
4. FACTS ONLY: Only state what you know for certain

FAMILY (Shane is the FATHER of all 5 sons):
{family_info}

RELATIONSHIPS:
- Shane is the FATHER of Gavin, Kai, Pierce, Jaxton, and Ryker
- Gavin, Kai, Pierce, Jaxton, and Ryker are BROTHERS to each other
- Tiffany is Shane's wife
- Angel is married to Gavin (daughter-in-law)

SOBRIETY: Shane has been sober since November 27, 2023 ({sobriety_years} years, {sobriety_months} months)

SHANE'S VALUES:
- "God is in your heart. Family is worth more than any dollar."
- "File structure first. Action over theory."
- "ADHD is a superpower, not a limitation."

PROJECTS:
- ShaneBrain: This system (WORKING)
- Angel Cloud: Mental wellness platform
- Pulsar AI: Blockchain security (planned)

WHEN YOU DON'T KNOW SOMETHING:
Say: "I don't know that yet. I'll add it to my questions for Shane."
DO NOT make up information about the family.

Be direct. Be brief. Be accurate."""


def build_rag_prompt(knowledge_chunks: list) -> str:
    base = get_system_prompt()
    if not knowledge_chunks:
        return base
    context = "\n\n---\n\n".join(knowledge_chunks)
    return f"""{base}

RELEVANT KNOWLEDGE FROM MEMORY:
{context}

Use this knowledge to answer. If it doesn't help, say you don't know. NEVER invent information."""


def quick_sentiment(text):
    text_lower = text.lower()
    for word in SUPPORTIVE_WORDS:
        if word in text_lower:
            return "supportive"
    for word in NEGATIVE_WORDS:
        if word in text_lower:
            return "negative"
    for word in POSITIVE_WORDS:
        if word in text_lower:
            return "positive"
    return "neutral"


def quick_topics(text):
    topic_keywords = {
        "family": ["family", "kids", "son", "wife", "dad", "father", "brother"],
        "tech": ["code", "ai", "python", "bot", "server", "raspberry", "ollama", "weaviate"],
        "faith": ["god", "pray", "church", "faith", "blessed", "amen"],
        "sobriety": ["sober", "sobriety", "drinking", "recovery"],
        "adhd": ["adhd", "focus", "hyperfocus", "distracted"],
        "work": ["dispatch", "truck", "job", "work", "hustle"],
        "wrestling": ["wrestling", "wrestle", "match", "tournament"],
    }
    text_lower = text.lower()
    found = []
    for topic, words in topic_keywords.items():
        if any(w in text_lower for w in words):
            found.append(topic)
    return found[:3] if found else ["general"]


def generate_response(user_message: str, user: dict) -> dict:
    """
    Generate a ShaneBrain response for an Angel Cloud user.
    Returns {"response": str, "session_id": str}
    """
    session_id = f"angel-cloud:{user['id']}"

    # 1. RAG — search LegacyKnowledge
    chunks = []
    try:
        with WeaviateHelper() as helper:
            results = helper.search_knowledge(user_message, limit=RAG_CHUNK_LIMIT)
            if results:
                for r in results:
                    content = r.get("content", "")
                    title = r.get("title", "")
                    if content:
                        chunks.append(f"[{title}]\n{content}" if title else content)
    except Exception as e:
        print(f"[CHAT-ENGINE] RAG search failed: {e}")

    # 2. Build system prompt with RAG context
    system_prompt = build_rag_prompt(chunks)

    # 3. Call Ollama
    try:
        result = ollama.chat(
            model=MODEL,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_message},
            ],
            options={"temperature": 0.3, "num_predict": 200},
        )
        response_text = result["message"]["content"].strip()
    except Exception as e:
        print(f"[CHAT-ENGINE] Ollama error: {e}")
        return {"response": "ShaneBrain is resting. Try again in a moment.", "session_id": session_id}

    # 4. Log conversation + update FriendProfile in Weaviate
    try:
        sentiment = quick_sentiment(user_message)
        topics = quick_topics(user_message)
        with WeaviateHelper() as helper:
            helper.log_conversation(
                message=user_message,
                role="user",
                mode="CHAT",
                session_id=session_id,
            )
            helper.log_conversation(
                message=response_text,
                role="assistant",
                mode="CHAT",
                session_id=session_id,
            )
            helper.upsert_friend_profile(
                name=user.get("display_name") or user["username"],
                facebook_id=f"angel-cloud:{user.get('email', user['id'])}",
                sentiment=sentiment,
                topics=topics,
            )
    except Exception as e:
        print(f"[CHAT-ENGINE] Weaviate logging failed (non-fatal): {e}")

    return {"response": response_text, "session_id": session_id}
