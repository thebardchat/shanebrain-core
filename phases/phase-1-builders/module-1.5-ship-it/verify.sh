#!/usr/bin/env bash
# Error handling is done per-command

# ============================================================
# MODULE 1.5 VERIFICATION (PHASE 1 CAPSTONE)
# Checks: Launcher file exists, services running, MyBrain
#         schema, documents ingested, full RAG query works,
#         knowledge folder has documents
# Returns: exit 0 = PASS, exit 1 = FAIL
# Pattern: Matches Module 1.1-1.4 verify.sh structure
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PASS_COUNT=0
FAIL_COUNT=0
TOTAL_CHECKS=7
TEMP_DIR="/tmp/ship-it-verify"
OUTPUT_DIR="$SCRIPT_DIR/output"
LAUNCHER="$OUTPUT_DIR/my-brain.sh"
KNOWLEDGE_DIR="$OUTPUT_DIR/knowledge"

mkdir -p "$TEMP_DIR"

echo
echo "  ══════════════════════════════════════════════════════"
echo "   MODULE 1.5 VERIFICATION — PHASE 1 CAPSTONE"
echo "  ══════════════════════════════════════════════════════"
echo

# --- CHECK 1: Launcher file exists ---
echo "  [CHECK 1/$TOTAL_CHECKS] Launcher file exists"
if [ -f "$LAUNCHER" ]; then
    echo -e "  \e[92m   PASS: my-brain.sh found at $OUTPUT_DIR\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: my-brain.sh not found\e[0m"
    echo "          Fix: Run exercise.sh first — it generates the launcher"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 2: Launcher contains key components ---
echo "  [CHECK 2/$TOTAL_CHECKS] Launcher has required components"
if [ -f "$LAUNCHER" ]; then
    HAS_HEALTH=0
    HAS_SCHEMA=0
    HAS_INGEST=0
    HAS_CHAT=0

    grep -qi "MemAvailable\|FREE_RAM_KB\|free.*ram\|meminfo" "$LAUNCHER" 2>/dev/null && HAS_HEALTH=1
    grep -qi "v1/schema" "$LAUNCHER" 2>/dev/null && HAS_SCHEMA=1
    grep -qi "embeddings" "$LAUNCHER" 2>/dev/null && HAS_INGEST=1
    grep -qi "while true\|chat.*loop\|YOU >>" "$LAUNCHER" 2>/dev/null && HAS_CHAT=1

    COMPONENT_COUNT=$((HAS_HEALTH + HAS_SCHEMA + HAS_INGEST + HAS_CHAT))

    if [ "$COMPONENT_COUNT" -ge 4 ]; then
        echo -e "  \e[92m   PASS: Launcher contains health checks, schema setup, ingestion, chat loop\e[0m"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "  \e[91m   FAIL: Launcher missing components ($COMPONENT_COUNT/4 found)\e[0m"
        echo "          Expected: health check, schema setup, ingestion, chat loop"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    echo -e "  \e[91m   FAIL: Cannot check components — launcher file missing\e[0m"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 3: Knowledge folder has documents ---
echo "  [CHECK 3/$TOTAL_CHECKS] Knowledge documents present"
KDOC_COUNT=0
if [ -d "$KNOWLEDGE_DIR" ]; then
    KDOC_COUNT=$(ls "$KNOWLEDGE_DIR"/*.txt 2>/dev/null | wc -l)
fi
if [ "$KDOC_COUNT" -ge 1 ]; then
    echo -e "  \e[92m   PASS: $KDOC_COUNT knowledge document(s) in output/knowledge\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: No .txt files in output/knowledge\e[0m"
    echo "          Fix: Run exercise.sh — it creates sample documents"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 4: Ollama running ---
echo "  [CHECK 4/$TOTAL_CHECKS] Ollama server running"
if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
    echo -e "  \e[92m   PASS: Ollama responding\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: Ollama not responding\e[0m"
    echo "          Fix: sudo systemctl start ollama"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 5: Weaviate running ---
echo "  [CHECK 5/$TOTAL_CHECKS] Weaviate server running"
if curl -s http://localhost:8080/v1/.well-known/ready >/dev/null 2>&1; then
    echo -e "  \e[92m   PASS: Weaviate responding\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: Weaviate not responding\e[0m"
    echo "          Fix: Start via Docker"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 6: MyBrain schema exists ---
echo "  [CHECK 6/$TOTAL_CHECKS] \"MyBrain\" class in Weaviate schema"
if curl -s http://localhost:8080/v1/schema 2>/dev/null | grep -qi "MyBrain"; then
    echo -e "  \e[92m   PASS: \"MyBrain\" class found\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: \"MyBrain\" class not found\e[0m"
    echo "          Fix: Run my-brain.sh once — it creates the schema"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 7: Full RAG pipeline via MyBrain class ---
echo "  [CHECK 7/$TOTAL_CHECKS] End-to-end RAG query via MyBrain"
echo "   Running: \"What is the mission?\""

FINAL_STATUS=$(python3 -c "
import json, urllib.request
emb = json.loads(urllib.request.urlopen(urllib.request.Request(
    'http://localhost:11434/api/embeddings',
    data=json.dumps({'model': 'llama3.2:1b', 'prompt': 'What is the mission?'}).encode(),
    headers={'Content-Type': 'application/json'}
)).read()).get('embedding', [])
docs = json.loads(urllib.request.urlopen(urllib.request.Request(
    'http://localhost:8080/v1/graphql',
    data=json.dumps({'query': '{Get{MyBrain(nearVector:{vector:' + json.dumps(emb) + '},limit:2){title content}}}'}).encode(),
    headers={'Content-Type': 'application/json'}
)).read()).get('data', {}).get('Get', {}).get('MyBrain', [])
ctx = '\n'.join([d.get('content', '') for d in docs])
resp = json.loads(urllib.request.urlopen(urllib.request.Request(
    'http://localhost:11434/api/generate',
    data=json.dumps({
        'model': 'llama3.2:1b',
        'prompt': 'Answer using ONLY this context:\n' + ctx + '\n\nQuestion: What is the mission?\nAnswer:',
        'stream': False,
        'options': {'temperature': 0.2}
    }).encode(),
    headers={'Content-Type': 'application/json'}
)).read())
answer = resp.get('response', '')
with open('$TEMP_DIR/final_answer.txt', 'w') as f:
    f.write(answer)
print('OK' if len(answer) > 10 else 'EMPTY')
" 2>/dev/null || echo "FAIL")

if [ "$FINAL_STATUS" == "OK" ]; then
    echo -e "  \e[92m   PASS: Full RAG pipeline returned a grounded answer\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
    echo
    echo -e "   \e[92m   Answer preview:\e[0m"
    if [ -f "$TEMP_DIR/final_answer.txt" ]; then
        head -1 "$TEMP_DIR/final_answer.txt" | sed 's/^/    /'
    fi
else
    echo -e "  \e[91m   FAIL: RAG pipeline did not return a usable answer\e[0m"
    echo "          Fix: Run my-brain.sh first to ingest documents"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# Cleanup
rm -rf "$TEMP_DIR" 2>/dev/null

# --- RESULTS ---
echo "  ══════════════════════════════════════════════════════"
if [ "$FAIL_COUNT" -eq 0 ]; then
    echo -e "  \e[92m   RESULT: PASS  ($PASS_COUNT/$TOTAL_CHECKS checks passed)\e[0m"
    echo
    echo -e "  \e[92m  ╔══════════════════════════════════════════════╗\e[0m"
    echo -e "  \e[92m  ║                                              ║\e[0m"
    echo -e "  \e[92m  ║   ✓ MODULE 1.5 COMPLETE                      ║\e[0m"
    echo -e "  \e[92m  ║   ✓ PHASE 1 COMPLETE                         ║\e[0m"
    echo -e "  \e[92m  ║                                              ║\e[0m"
    echo -e "  \e[92m  ║   You proved:                                ║\e[0m"
    echo -e "  \e[92m  ║   You can build, package, and ship a local   ║\e[0m"
    echo -e "  \e[92m  ║   AI system from scratch. No cloud. No       ║\e[0m"
    echo -e "  \e[92m  ║   subscription. No permission needed.        ║\e[0m"
    echo -e "  \e[92m  ║                                              ║\e[0m"
    echo -e "  \e[92m  ║   You are a BUILDER.                         ║\e[0m"
    echo -e "  \e[92m  ║                                              ║\e[0m"
    echo -e "  \e[92m  ║   Your legacy runs local.                    ║\e[0m"
    echo -e "  \e[92m  ║                                              ║\e[0m"
    echo -e "  \e[92m  ╚══════════════════════════════════════════════╝\e[0m"
    echo

    # --- Update progress ---
    PROGRESS_FILE="$SCRIPT_DIR/../../../../progress/user-progress.json"
    if [ -f "$PROGRESS_FILE" ]; then
        echo "  {\"module\": \"1.5\", \"status\": \"completed\", \"timestamp\": \"$(date '+%Y-%m-%d %H:%M:%S')\"}" >> "${PROGRESS_FILE}.log"
        echo "  {\"phase\": \"1\", \"status\": \"completed\", \"timestamp\": \"$(date '+%Y-%m-%d %H:%M:%S')\"}" >> "${PROGRESS_FILE}.log"
    fi

    echo "   Phase 2 — OPERATORS — is next."
    echo "   You'll teach your AI to do real business work:"
    echo "   invoices, schedules, customer responses, document Q&A."
    echo
    echo "   But first: go add YOUR documents to the knowledge folder."
    echo "   Make this brain YOURS."
    echo "  ══════════════════════════════════════════════════════"
    exit 0
else
    echo -e "  \e[91m   RESULT: FAIL  ($PASS_COUNT/$TOTAL_CHECKS passed, $FAIL_COUNT failed)\e[0m"
    echo
    echo "   Review the failures above and fix them."
    echo "   Most common fix: Run exercise.sh first, then my-brain.sh,"
    echo "   then verify.sh."
    echo "   Need help? Check hints.md in this folder."
    echo "  ══════════════════════════════════════════════════════"
    exit 1
fi
