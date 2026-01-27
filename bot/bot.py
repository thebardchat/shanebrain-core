"""
ShaneBrainLegacyBot v5.3 - LEARNING EDITION
- Correct family info with birth dates
- Strict brevity (2-4 sentences)
- Logs questions it can't answer
- !teach command for Shane to add knowledge
"""
import discord
from discord.ext import commands
import os
from dotenv import load_dotenv
import asyncio
import random
from datetime import datetime, timedelta
import json

# Ollama
try:
    import ollama
    OLLAMA_AVAILABLE = True
except ImportError:
    OLLAMA_AVAILABLE = False
    print("WARNING: ollama not installed. Run: pip install ollama")

# Weaviate v4
try:
    import weaviate
    from weaviate.classes.query import MetadataQuery
    WEAVIATE_AVAILABLE = True
except ImportError:
    WEAVIATE_AVAILABLE = False
    print("WARNING: weaviate-client not installed. Run: pip install weaviate-client")

# Web search
try:
    from duckduckgo_search import DDGS
    SEARCH_AVAILABLE = True
except ImportError:
    SEARCH_AVAILABLE = False
    print("WARNING: duckduckgo-search not installed. Run: pip install duckduckgo-search")

load_dotenv()
TOKEN = os.getenv('DISCORD_TOKEN')

# ============================================================
# CONFIGURATION
# ============================================================
intents = discord.Intents.all()
bot = commands.Bot(command_prefix='!', intents=intents, help_command=None)

# Ollama config
OLLAMA_MODEL = 'shanebrain-3b:latest'
OLLAMA_TEMPERATURE = 0.3

# Weaviate config
WEAVIATE_HOST = "localhost"
WEAVIATE_PORT = 8080
WEAVIATE_CLASS = "LegacyKnowledge"
RAG_CHUNK_LIMIT = 5

# Questions log file
QUESTIONS_FILE = "D:\\Angel_Cloud\\shanebrain-core\\bot\\pending_questions.json"

# Global client
weaviate_client = None

# ============================================================
# FAMILY DATA - BIRTH DATES FOR AGE CALCULATION
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

def calculate_age(birth_str):
    """Calculate age from 'YYYY-MM' string"""
    if not birth_str:
        return None
    year, month = map(int, birth_str.split('-'))
    today = datetime.now()
    age = today.year - year
    if today.month < month:
        age -= 1
    return age

def get_family_info():
    """Generate current family info with calculated ages"""
    lines = []
    for key, person in FAMILY.items():
        age = calculate_age(person["birth"])
        age_str = f", {age} years old" if age else ""
        lines.append(f"- {person['name']}{age_str}: {person['role']}")
    return "\n".join(lines)

# ============================================================
# QUESTION LOGGING SYSTEM
# ============================================================
def load_pending_questions():
    """Load pending questions from file"""
    try:
        if os.path.exists(QUESTIONS_FILE):
            with open(QUESTIONS_FILE, 'r') as f:
                return json.load(f)
    except:
        pass
    return []

def save_pending_question(question, asker, timestamp):
    """Save a question ShaneBrain couldn't answer"""
    questions = load_pending_questions()
    questions.append({
        "question": question,
        "asker": asker,
        "timestamp": timestamp,
        "answered": False
    })
    try:
        os.makedirs(os.path.dirname(QUESTIONS_FILE), exist_ok=True)
        with open(QUESTIONS_FILE, 'w') as f:
            json.dump(questions, f, indent=2)
        print(f"[LEARNING] Logged question: {question[:50]}...")
        return True
    except Exception as e:
        print(f"[LEARNING] Failed to save question: {e}")
        return False

def mark_question_answered(index):
    """Mark a question as answered"""
    questions = load_pending_questions()
    if 0 <= index < len(questions):
        questions[index]["answered"] = True
        with open(QUESTIONS_FILE, 'w') as f:
            json.dump(questions, f, indent=2)
        return True
    return False

# ============================================================
# WEAVIATE FUNCTIONS
# ============================================================
def get_weaviate_client():
    global weaviate_client
    if not WEAVIATE_AVAILABLE:
        return None
    if weaviate_client is not None:
        try:
            if weaviate_client.is_ready():
                return weaviate_client
        except:
            pass
    try:
        weaviate_client = weaviate.connect_to_local(host=WEAVIATE_HOST, port=WEAVIATE_PORT)
        if weaviate_client.is_ready():
            print(f"[WEAVIATE] Connected to {WEAVIATE_HOST}:{WEAVIATE_PORT}")
            return weaviate_client
    except Exception as e:
        print(f"[WEAVIATE] Connection failed: {e}")
    return None

def close_weaviate_client():
    global weaviate_client
    if weaviate_client:
        try:
            weaviate_client.close()
        except:
            pass
        weaviate_client = None

def query_knowledge_base(question: str, limit: int = RAG_CHUNK_LIMIT) -> list:
    client = get_weaviate_client()
    if not client:
        return []
    try:
        collection = client.collections.get(WEAVIATE_CLASS)
        try:
            results = collection.query.hybrid(query=question, limit=limit, return_metadata=MetadataQuery(score=True))
            chunks = []
            for obj in results.objects:
                content = obj.properties.get("content", "")
                title = obj.properties.get("title", "")
                if content:
                    chunk_text = f"[{title}]\n{content}" if title else content
                    chunks.append(chunk_text)
            print(f"[RAG] Found {len(chunks)} chunks via hybrid search")
            return chunks
        except Exception as e:
            print(f"[RAG] Hybrid search failed: {e}, trying BM25...")
            results = collection.query.bm25(query=question, limit=limit)
            chunks = []
            for obj in results.objects:
                content = obj.properties.get("content", "")
                title = obj.properties.get("title", "")
                if content:
                    chunk_text = f"[{title}]\n{content}" if title else content
                    chunks.append(chunk_text)
            print(f"[RAG] Found {len(chunks)} chunks via BM25")
            return chunks
    except Exception as e:
        print(f"[RAG] Query error: {e}")
        return []

def save_to_memory(title: str, content: str, category: str = "general", source: str = "discord"):
    client = get_weaviate_client()
    if not client:
        return False
    try:
        collection = client.collections.get(WEAVIATE_CLASS)
        collection.data.insert({"title": title, "content": content, "category": category, "source": source})
        print(f"[MEMORY] Saved: {title}")
        return True
    except Exception as e:
        print(f"[MEMORY] Save error: {e}")
        return False

def get_weaviate_stats():
    client = get_weaviate_client()
    if not client:
        return None
    try:
        collections = client.collections.list_all()
        stats = {}
        for name in collections:
            try:
                coll = client.collections.get(name)
                count = coll.aggregate.over_all(total_count=True).total_count
                stats[name] = count
            except:
                stats[name] = "?"
        return stats
    except:
        return None

# ============================================================
# SYSTEM PROMPT - STRICT BREVITY + CORRECT FAMILY
# ============================================================
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

def build_rag_prompt(question: str, knowledge_chunks: list) -> str:
    base = get_system_prompt()
    if not knowledge_chunks:
        return base
    context = "\n\n---\n\n".join(knowledge_chunks)
    return f"""{base}

RELEVANT KNOWLEDGE FROM MEMORY:
{context}

Use this knowledge to answer. If it doesn't help, say you don't know. NEVER invent information."""

# ============================================================
# CHAT FUNCTION WITH RAG + LEARNING
# ============================================================
async def chat_with_shanebrain(user_message: str, asker: str = "unknown") -> str:
    if not OLLAMA_AVAILABLE:
        return "⚠️ Ollama not available."

    print(f"[SHANEBRAIN] Query: {user_message[:50]}...")
    knowledge_chunks = query_knowledge_base(user_message)
    system_prompt = build_rag_prompt(user_message, knowledge_chunks)

    try:
        response = ollama.chat(
            model=OLLAMA_MODEL,
            messages=[
                {'role': 'system', 'content': system_prompt},
                {'role': 'user', 'content': user_message},
            ],
            options={'temperature': OLLAMA_TEMPERATURE, 'num_predict': 200}  # Limit response length
        )
        answer = response['message']['content']
        
        # Check if ShaneBrain doesn't know
        dont_know_phrases = ["don't know", "i'll ask shane", "ask shane", "not sure", "don't have that information"]
        if any(phrase in answer.lower() for phrase in dont_know_phrases):
            save_pending_question(user_message, asker, datetime.now().isoformat())
        
        print(f"[SHANEBRAIN] Response: {len(answer)} chars")
        return answer

    except Exception as e:
        print(f"[OLLAMA ERROR] {e}")
        return f"⚠️ Brain freeze. Is Ollama running? Error: {str(e)[:100]}"

# ============================================================
# QUOTE DATABASE (abbreviated for space)
# ============================================================
ALL_QUOTES = [
    "Don't give me the roadmap. Give me the next step.",
    "Momentum is the only metric that matters right now.",
    "ADHD isn't a bug; it's a high-velocity processor.",
    "God is in your heart. Family is worth more than any dollar.",
    "If you don't own your infrastructure, you don't own your future.",
    "File structure first. Action over theory.",
    "I dispatch dump trucks by day and AI agents by night.",
    "We run local-first. I don't trust the cloud with my brain.",
    "7.4 gigs of RAM is a constraint, not an excuse.",
    "I do this for the five boys waiting at home.",
    "Family first. The code can wait.",
    "Sole provider means there is no Plan B.",
    "800 million Windows users. That's who we're building for.",
    "This isn't just code. This is legacy.",
    "Sobriety isn't just not drinking. It's building something real.",
    "Take care of each other. Always.",
]

# ============================================================
# BOT EVENTS
# ============================================================
@bot.event
async def on_ready():
    client = get_weaviate_client()
    stats = get_weaviate_stats() if client else None
    pending = load_pending_questions()
    unanswered = len([q for q in pending if not q.get("answered")])
    
    print("=" * 60)
    print("    SHANEBRAIN LEGACY BOT v5.3 - LEARNING EDITION")
    print("=" * 60)
    print(f"    Bot:      {bot.user.name}")
    print(f"    Servers:  {len(bot.guilds)}")
    print(f"    Quotes:   {len(ALL_QUOTES)}")
    print(f"\n    BRAIN STATUS:")
    print(f"    Ollama:   {'READY' if OLLAMA_AVAILABLE else 'OFFLINE'}")
    print(f"    Model:    {OLLAMA_MODEL}")
    print(f"    Weaviate: {'CONNECTED' if client else 'OFFLINE'}")
    if stats:
        print(f"    Classes:  {stats}")
    print(f"    Pending:  {unanswered} questions for Shane")
    print("=" * 60)

@bot.event
async def on_message(message):
    if message.author.bot:
        return
    
    # Respond to mentions or DMs
    if bot.user in message.mentions or isinstance(message.channel, discord.DMChannel):
        async with message.channel.typing():
            clean_msg = message.content.replace(f'<@{bot.user.id}>', '').strip()
            if clean_msg:
                response = await chat_with_shanebrain(clean_msg, message.author.name)
                # Split long responses
                if len(response) > 1900:
                    response = response[:1900] + "..."
                await message.reply(response)
    
    await bot.process_commands(message)

# ============================================================
# LEARNING COMMANDS
# ============================================================
@bot.command(name='questions')
async def show_questions(ctx):
    """Show pending questions for Shane to answer"""
    questions = load_pending_questions()
    unanswered = [(i, q) for i, q in enumerate(questions) if not q.get("answered")]
    
    if not unanswered:
        await ctx.send("✅ No pending questions! ShaneBrain is all caught up.")
        return
    
    embed = discord.Embed(title="❓ Pending Questions for Shane", color=0xFFFF00)
    for i, q in unanswered[:10]:  # Show max 10
        embed.add_field(
            name=f"#{i}: {q['asker']} asked",
            value=q['question'][:200],
            inline=False
        )
    
    if len(unanswered) > 10:
        embed.set_footer(text=f"Showing 10 of {len(unanswered)} questions")
    else:
        embed.set_footer(text=f"{len(unanswered)} questions pending")
    
    await ctx.send(embed=embed)

@bot.command(name='teach')
@commands.has_permissions(administrator=True)
async def teach(ctx, question_num: int, *, answer: str):
    """Teach ShaneBrain an answer. Usage: !teach 0 The answer is..."""
    questions = load_pending_questions()
    
    if question_num < 0 or question_num >= len(questions):
        await ctx.send("❌ Invalid question number. Use `!questions` to see the list.")
        return
    
    q = questions[question_num]
    
    # Save to Weaviate
    title = f"Q: {q['question'][:50]}"
    content = f"Question: {q['question']}\nAnswer: {answer}\nTaught by: {ctx.author.name}\nDate: {datetime.now().isoformat()}"
    
    if save_to_memory(title, content, "taught", "discord_teach"):
        mark_question_answered(question_num)
        await ctx.send(f"🧠 Got it! I learned:\n**Q:** {q['question'][:100]}\n**A:** {answer[:200]}")
    else:
        await ctx.send("❌ Couldn't save - Weaviate offline")

@bot.command(name='family')
async def family_cmd(ctx):
    """Show family information"""
    embed = discord.Embed(title="👨‍👩‍👦‍👦 The Brazelton Family", color=0x00FFFF)
    
    for key, person in FAMILY.items():
        age = calculate_age(person["birth"])
        age_str = f" ({age})" if age else ""
        embed.add_field(name=f"{person['name']}{age_str}", value=person['role'], inline=False)
    
    embed.set_footer(text="Family first. Always.")
    await ctx.send(embed=embed)

# ============================================================
# UTILITY COMMANDS
# ============================================================
@bot.command(name='help')
async def help_cmd(ctx):
    embed = discord.Embed(title="🧠 ShaneBrain Commands", color=0x00FFFF)
    embed.add_field(name="Chat", value="@ShaneBrain [message] - Talk to me", inline=False)
    embed.add_field(name="!family", value="Show family info", inline=True)
    embed.add_field(name="!brain", value="Check brain status", inline=True)
    embed.add_field(name="!quote", value="Get a quote", inline=True)
    embed.add_field(name="!search [query]", value="Web search", inline=True)
    embed.add_field(name="!remember [text]", value="Save to memory", inline=True)
    embed.add_field(name="!questions", value="See pending questions", inline=True)
    embed.add_field(name="!teach [#] [answer]", value="Teach an answer (admin)", inline=True)
    await ctx.send(embed=embed)

@bot.command(name='brain')
async def brain_status(ctx):
    client = get_weaviate_client()
    stats = get_weaviate_stats() if client else None
    pending = load_pending_questions()
    unanswered = len([q for q in pending if not q.get("answered")])
    
    embed = discord.Embed(title="🧠 Brain Status", color=0x00FFFF)
    embed.add_field(name="Ollama", value="✅ Ready" if OLLAMA_AVAILABLE else "❌ Offline", inline=True)
    embed.add_field(name="Model", value=OLLAMA_MODEL, inline=True)
    embed.add_field(name="Weaviate", value="✅ Connected" if client else "❌ Offline", inline=True)
    embed.add_field(name="Search", value="✅ Ready" if SEARCH_AVAILABLE else "❌ Offline", inline=True)
    embed.add_field(name="Pending Qs", value=str(unanswered), inline=True)
    
    if stats:
        stats_text = "\n".join([f"• {k}: {v}" for k, v in stats.items()])
        embed.add_field(name="Knowledge", value=stats_text, inline=False)
    
    await ctx.send(embed=embed)

@bot.command(name='quote')
async def quote(ctx):
    q = random.choice(ALL_QUOTES)
    embed = discord.Embed(title="💬 Words to Build By", description=f"*\"{q}\"*\n\n— Shane", color=0x00FFFF)
    await ctx.send(embed=embed)

@bot.command(name='remember')
async def remember(ctx, *, text: str):
    if save_to_memory(f"Memory from {ctx.author.name}", text, "memory", "discord"):
        await ctx.send(f"🧠 Got it.")
    else:
        await ctx.send("❌ Weaviate offline")

@bot.command(name='search')
async def search(ctx, *, query: str):
    if not SEARCH_AVAILABLE:
        await ctx.send("❌ Search not available.")
        return
    async with ctx.channel.typing():
        try:
            with DDGS() as ddgs:
                results = list(ddgs.text(query, max_results=3))
            if not results:
                await ctx.send("No results.")
                return
            embed = discord.Embed(title=f"🔍 {query}", color=0x00FFFF)
            for r in results:
                embed.add_field(name=r.get('title', '')[:100], value=r.get('body', '')[:150], inline=False)
            await ctx.send(embed=embed)
        except Exception as e:
            await ctx.send(f"❌ Error: {str(e)[:100]}")

# ============================================================
# ERROR HANDLING
# ============================================================
@bot.event
async def on_command_error(ctx, error):
    if isinstance(error, commands.MissingPermissions):
        await ctx.send("❌ No permission.")
    elif isinstance(error, commands.CommandNotFound):
        pass
    else:
        print(f"[ERROR] {error}")

# ============================================================
# CLEANUP
# ============================================================
import atexit
atexit.register(close_weaviate_client)

# ============================================================
# RUN
# ============================================================
if __name__ == "__main__":
    if TOKEN:
        bot.run(TOKEN)
    else:
        print("ERROR: No DISCORD_TOKEN in .env")