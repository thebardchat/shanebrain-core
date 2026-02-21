#!/usr/bin/env bash
# Error handling is done per-command

# ============================================================
# MODULE 1.5 EXERCISE: Ship It
# Goal: Build a complete my-brain.sh launcher, test it,
#       verify it works end-to-end as a daily-use tool
# Time: ~15 minutes
# RAM impact: Same as Module 1.3 — pipeline operations only
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/output"
LAUNCHER="$OUTPUT_DIR/my-brain.sh"
KNOWLEDGE_DIR="$OUTPUT_DIR/knowledge"

echo
echo "  ══════════════════════════════════════════════════════"
echo "   MODULE 1.5 EXERCISE: Ship It"
echo "  ══════════════════════════════════════════════════════"
echo
echo "   This is the capstone. You're building a production"
echo "   launcher that packages everything from Modules 1.1-1.4"
echo "   into one tool."
echo
echo "   3 tasks: Generate it. Test it. Verify it."
echo
echo "  ──────────────────────────────────────────────────────"
echo

# --- PRE-FLIGHT ---
if ! curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
    echo -e "  \e[91m   ✗ Ollama is not running. Start it: sudo systemctl start ollama\e[0m"
    read -p "  Press Enter to continue..."
    exit 1
fi
echo -e "  \e[92m   ✓ Ollama running\e[0m"

if ! curl -s http://localhost:8080/v1/.well-known/ready >/dev/null 2>&1; then
    echo -e "  \e[93m   ⚠ Weaviate not running. The launcher will detect this too.\e[0m"
else
    echo -e "  \e[92m   ✓ Weaviate running\e[0m"
fi
echo

# ============================================================
# TASK 1: Generate the launcher
# ============================================================
echo "  ──────────────────────────────────────────────────────"
echo
echo "  [TASK 1/3] Generating my-brain.sh"
echo

mkdir -p "$OUTPUT_DIR"
mkdir -p "$KNOWLEDGE_DIR"

# Create knowledge docs if they don't exist
if [ ! -f "$KNOWLEDGE_DIR/mission.txt" ]; then
    echo "Angel Cloud is a family-driven, faith-rooted AI platform. Our mission is to make AI literacy accessible to every person. We believe you should own your AI, not rent it. Everything runs local. No cloud dependencies. No subscriptions. Built in Alabama for the world." > "$KNOWLEDGE_DIR/mission.txt"
fi
if [ ! -f "$KNOWLEDGE_DIR/values.txt" ]; then
    echo "The Angel Cloud values are: Faith first. Family always. Sobriety as strength. Every person deserves access to AI. Local-first means you own your data. We build for the 800 million Windows users losing security updates. Legacy matters." > "$KNOWLEDGE_DIR/values.txt"
fi
if [ ! -f "$KNOWLEDGE_DIR/technical.txt" ]; then
    echo "The system runs on Ollama with llama3.2:1b for inference and embeddings. Weaviate provides vector storage and semantic search on localhost:8080. The RAG pipeline connects them. Everything fits in 7.4GB RAM. No cloud. No subscriptions." > "$KNOWLEDGE_DIR/technical.txt"
fi

# Write the launcher
echo "    Writing my-brain.sh..."

cat > "$LAUNCHER" << 'LAUNCHER_EOF'
#!/usr/bin/env bash
# Error handling is done per-command

# ============================================================
# MY BRAIN — Personal Local AI Assistant
# Built with: Ollama + Weaviate + RAG Pipeline
# Architecture: Angel Cloud / ShaneBrain Blueprint
# ============================================================

BRAIN_DIR="$(cd "$(dirname "$0")" && pwd)"
KNOWLEDGE_DIR="$BRAIN_DIR/knowledge"
MODEL="llama3.2:1b"
OLLAMA_URL="http://localhost:11434"
WEAVIATE_URL="http://localhost:8080"
TEMP_DIR="/tmp/my-brain"
SCHEMA_CLASS="MyBrain"

mkdir -p "$TEMP_DIR"

# ============================================================
# BANNER
# ============================================================
clear
echo
echo "    ╔══════════════════════════════════════════════╗"
echo "    ║                                              ║"
echo "    ║   ███╗   ███╗██╗   ██╗                       ║"
echo "    ║   ████╗ ████║╚██╗ ██╔╝                       ║"
echo "    ║   ██╔████╔██║ ╚████╔╝                        ║"
echo "    ║   ██║╚██╔╝██║  ╚██╔╝                         ║"
echo "    ║   ██║ ╚═╝ ██║   ██║                          ║"
echo "    ║   ╚═╝     ╚═╝   ╚═╝                          ║"
echo "    ║                                              ║"
echo "    ║   ██████╗ ██████╗  █████╗ ██╗███╗   ██╗      ║"
echo "    ║   ██╔══██╗██╔══██╗██╔══██╗██║████╗  ██║      ║"
echo "    ║   ██████╔╝██████╔╝███████║██║██╔██╗ ██║      ║"
echo "    ║   ██╔══██╗██╔══██╗██╔══██║██║██║╚██╗██║      ║"
echo "    ║   ██████╔╝██║  ██║██║  ██║██║██║ ╚████║      ║"
echo "    ║   ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝      ║"
echo "    ║                                              ║"
echo "    ║   Your legacy runs local.                    ║"
echo "    ║                                              ║"
echo "    ╚══════════════════════════════════════════════╝"
echo

# ============================================================
# HEALTH CHECKS
# ============================================================
echo "  [SYSTEM] Running health checks..."
echo

# RAM Check
FREE_RAM_KB=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
FREE_MB=$((FREE_RAM_KB / 1024))

if [ "$FREE_MB" -lt 2048 ]; then
    echo -e "  \e[91m  ✗ BLOCKED: ${FREE_MB}MB RAM free. Need 2048MB minimum.\e[0m"
    read -p "  Press Enter to continue..."
    exit 1
fi
if [ "$FREE_MB" -lt 4096 ]; then
    echo -e "  \e[93m  ⚠ RAM: ${FREE_MB}MB free. Performance may be slow.\e[0m"
else
    echo -e "  \e[92m  ✓ RAM: ${FREE_MB}MB free\e[0m"
fi

# Ollama Check
if ! curl -s "$OLLAMA_URL/api/tags" >/dev/null 2>&1; then
    echo -e "  \e[93m  ⚠ Ollama not responding. Check: sudo systemctl status ollama\e[0m"
    echo "     On Linux, Ollama runs as a systemd service."
    echo "     Start it with: sudo systemctl start ollama"
    read -p "  Press Enter to continue..."
    exit 1
fi
echo -e "  \e[92m  ✓ Ollama running\e[0m"

# Model Check
if ! curl -s "$OLLAMA_URL/api/tags" 2>/dev/null | grep -qi "$MODEL"; then
    echo -e "  \e[93m  ⚠ Model $MODEL not found. Pulling...\e[0m"
    ollama pull "$MODEL"
fi
echo -e "  \e[92m  ✓ Model: $MODEL\e[0m"

# Weaviate Check
if ! curl -s "$WEAVIATE_URL/v1/.well-known/ready" >/dev/null 2>&1; then
    echo -e "  \e[91m  ✗ Weaviate not running on $WEAVIATE_URL\e[0m"
    echo "     Start it and re-run this launcher."
    read -p "  Press Enter to continue..."
    exit 1
fi
echo -e "  \e[92m  ✓ Weaviate running\e[0m"
echo

# ============================================================
# SCHEMA SETUP (idempotent)
# ============================================================
if ! curl -s "$WEAVIATE_URL/v1/schema" 2>/dev/null | grep -qi "$SCHEMA_CLASS"; then
    echo "  [SETUP] Creating knowledge schema..."
    curl -s -X POST "$WEAVIATE_URL/v1/schema" -H "Content-Type: application/json" -d "{\"class\":\"$SCHEMA_CLASS\",\"description\":\"Personal brain knowledge base\",\"vectorizer\":\"none\",\"properties\":[{\"name\":\"title\",\"dataType\":[\"text\"]},{\"name\":\"content\",\"dataType\":[\"text\"]},{\"name\":\"source\",\"dataType\":[\"text\"]}]}" >/dev/null 2>&1
    echo -e "  \e[92m  ✓ Schema created\e[0m"
else
    echo -e "  \e[92m  ✓ Schema exists\e[0m"
fi
echo

# ============================================================
# SMART INGESTION
# ============================================================
echo "  [INGEST] Scanning knowledge folder..."
NEW_COUNT=0
SKIP_COUNT=0

for f in "$KNOWLEDGE_DIR"/*.txt; do
    [ -f "$f" ] || continue
    FNAME=$(basename "$f")
    # Check if already ingested by title match
    if curl -s "$WEAVIATE_URL/v1/objects?class=$SCHEMA_CLASS&limit=100" 2>/dev/null | grep -qi "$FNAME"; then
        SKIP_COUNT=$((SKIP_COUNT + 1))
    else
        echo "    Ingesting: $FNAME"
        python3 -c "
import json, urllib.request
content = open('$f').read()
emb = json.loads(urllib.request.urlopen(urllib.request.Request(
    '$OLLAMA_URL/api/embeddings',
    data=json.dumps({'model': '$MODEL', 'prompt': content}).encode(),
    headers={'Content-Type': 'application/json'}
)).read()).get('embedding', [])
urllib.request.urlopen(urllib.request.Request(
    '$WEAVIATE_URL/v1/objects',
    data=json.dumps({
        'class': '$SCHEMA_CLASS',
        'properties': {'title': '$FNAME', 'content': content, 'source': '$f'},
        'vector': emb
    }).encode(),
    headers={'Content-Type': 'application/json'}
))
" 2>/dev/null
        NEW_COUNT=$((NEW_COUNT + 1))
    fi
done
echo -e "  \e[92m  ✓ Ingestion: $NEW_COUNT new, $SKIP_COUNT already loaded\e[0m"
echo

# ============================================================
# INTERACTIVE CHAT
# ============================================================
echo "  ══════════════════════════════════════════════════════"
echo "   MY BRAIN — Ready"
echo "   Ask anything. Type /bye to exit."
echo "  ══════════════════════════════════════════════════════"
echo

while true; do
    read -p "  YOU >> " USER_Q

    if [[ "${USER_Q,,}" == "/bye" ]]; then
        break
    fi
    if [ -z "$USER_Q" ]; then
        continue
    fi

    python3 -c "
import json, urllib.request
q = '''$USER_Q'''
emb = json.loads(urllib.request.urlopen(urllib.request.Request(
    '$OLLAMA_URL/api/embeddings',
    data=json.dumps({'model': '$MODEL', 'prompt': q}).encode(),
    headers={'Content-Type': 'application/json'}
)).read()).get('embedding', [])
docs = json.loads(urllib.request.urlopen(urllib.request.Request(
    '$WEAVIATE_URL/v1/graphql',
    data=json.dumps({'query': '{Get{$SCHEMA_CLASS(nearVector:{vector:' + json.dumps(emb) + '},limit:2){title content}}}'}).encode(),
    headers={'Content-Type': 'application/json'}
)).read()).get('data', {}).get('Get', {}).get('$SCHEMA_CLASS', [])
ctx = '\n'.join([d.get('content', '') for d in docs])
prompt = \"\"\"You are My Brain, a personal local AI assistant. Answer using ONLY the context below. If the context does not contain the answer, say: I don't have that information in my knowledge base.

CONTEXT:
\"\"\" + ctx + \"\"\"

QUESTION:
\"\"\" + q + \"\"\"

ANSWER:\"\"\"
resp = json.loads(urllib.request.urlopen(urllib.request.Request(
    '$OLLAMA_URL/api/generate',
    data=json.dumps({'model': '$MODEL', 'prompt': prompt, 'stream': False, 'options': {'temperature': 0.2}}).encode(),
    headers={'Content-Type': 'application/json'}
)).read())
print('\n  BRAIN >> ' + resp.get('response', 'No response.').strip() + '\n')
" 2>/dev/null
    echo
done

echo
echo "   Your legacy runs local. See you next time."
echo
rm -rf "$TEMP_DIR" 2>/dev/null
exit 0
LAUNCHER_EOF

chmod +x "$LAUNCHER"

echo -e "  \e[92m   ✓ my-brain.sh generated: $LAUNCHER\e[0m"
echo
echo "   The launcher is ready. It includes:"
echo "     - ASCII banner"
echo "     - RAM / Ollama / Weaviate health checks"
echo "     - Auto model pull if missing"
echo "     - Idempotent schema creation"
echo "     - Smart ingestion (skips duplicates)"
echo "     - Interactive RAG chat with guardrails"
echo
echo "   Press any key to test it..."
read -n1 -s ; echo
echo

# ============================================================
# TASK 2: Test the launcher
# ============================================================
echo "  ──────────────────────────────────────────────────────"
echo
echo "  [TASK 2/3] Test my-brain.sh"
echo
echo "   The launcher is about to run. It will:"
echo "   1. Show the banner"
echo "   2. Run health checks"
echo "   3. Set up schema"
echo "   4. Ingest knowledge documents"
echo "   5. Open an interactive chat"
echo
echo "   Ask it a question like: \"What are the Angel Cloud values?\""
echo "   Then type /bye to exit back to this exercise."
echo
echo "   Press any key to launch..."
read -n1 -s ; echo
echo

bash "$LAUNCHER"

echo
echo "  ──────────────────────────────────────────────────────"
echo
echo "  [TASK 3/3] Verify your launcher"
echo
echo "   If the chat worked and gave you an answer from your"
echo "   knowledge documents, your launcher is production-ready."
echo
echo "   Run verify.sh for the final automated check:"
echo
echo "       ./verify.sh"
echo
echo "  ══════════════════════════════════════════════════════"
echo "   EXERCISE COMPLETE"
echo "  ══════════════════════════════════════════════════════"
echo

read -p "  Press Enter to continue..."
exit 0
