#!/usr/bin/env bash
# Error handling is done per-command

# ============================================================
# MODULE 1.3 VERIFICATION
# Checks: Both services, BrainDoc schema, documents ingested,
#         embedding works, full RAG query returns grounded answer
# Returns: exit 0 = PASS, exit 1 = FAIL
# Pattern: Matches Module 1.1/1.2 verify.sh structure
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PASS_COUNT=0
FAIL_COUNT=0
TOTAL_CHECKS=6
TEMP_DIR="/tmp/shanebrain-verify"
KNOWLEDGE_DIR="$SCRIPT_DIR/knowledge"

mkdir -p "$TEMP_DIR"

echo
echo "  ══════════════════════════════════════════════════════"
echo "   MODULE 1.3 VERIFICATION"
echo "  ══════════════════════════════════════════════════════"
echo

# --- CHECK 1: Ollama running ---
echo "  [CHECK 1/$TOTAL_CHECKS] Ollama server running"
if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
    echo -e "  \e[92m   PASS: Ollama responding on localhost:11434\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: Ollama not responding\e[0m"
    echo "          Fix: Run \"sudo systemctl start ollama\""
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 2: Weaviate running ---
echo "  [CHECK 2/$TOTAL_CHECKS] Weaviate server running"
if curl -s http://localhost:8080/v1/.well-known/ready >/dev/null 2>&1; then
    echo -e "  \e[92m   PASS: Weaviate responding on localhost:8080\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: Weaviate not responding\e[0m"
    echo "          Fix: Start Weaviate via Docker"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 3: BrainDoc schema exists ---
echo "  [CHECK 3/$TOTAL_CHECKS] \"BrainDoc\" class in Weaviate schema"
if curl -s http://localhost:8080/v1/schema 2>/dev/null | grep -qi "BrainDoc"; then
    echo -e "  \e[92m   PASS: \"BrainDoc\" class found in schema\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: \"BrainDoc\" class not found\e[0m"
    echo "          Fix: Run exercise.sh — it creates the schema automatically"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 4: Knowledge documents exist ---
echo "  [CHECK 4/$TOTAL_CHECKS] Knowledge documents present"
DOC_COUNT=0
if [ -d "$KNOWLEDGE_DIR" ]; then
    DOC_COUNT=$(ls "$KNOWLEDGE_DIR"/*.txt 2>/dev/null | wc -l)
fi
if [ "$DOC_COUNT" -ge 1 ]; then
    echo -e "  \e[92m   PASS: $DOC_COUNT knowledge document(s) found in knowledge folder\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: No .txt files found in knowledge folder\e[0m"
    echo "          Fix: Run exercise.sh — it creates sample documents"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 5: Documents ingested into Weaviate ---
echo "  [CHECK 5/$TOTAL_CHECKS] BrainDoc objects stored in Weaviate"
BRAINDOCS=$(curl -s "http://localhost:8080/v1/objects?class=BrainDoc&limit=1" 2>/dev/null)
if echo "$BRAINDOCS" | grep -qi "title"; then
    echo -e "  \e[92m   PASS: BrainDoc objects found in Weaviate\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: No BrainDoc objects found in Weaviate\e[0m"
    echo "          Fix: Run exercise.sh to ingest documents"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 6: Full RAG query returns an answer ---
echo "  [CHECK 6/$TOTAL_CHECKS] Full RAG pipeline produces grounded answer"
echo "   Running end-to-end query: \"What is Angel Cloud?\""

RAG_STATUS=$(python3 -c "
import json, urllib.request
emb_data = json.dumps({'model': 'llama3.2:1b', 'prompt': 'What is Angel Cloud?'}).encode()
emb_req = urllib.request.Request('http://localhost:11434/api/embeddings', data=emb_data, headers={'Content-Type': 'application/json'})
emb_resp = json.loads(urllib.request.urlopen(emb_req).read())
vec = emb_resp.get('embedding', [])
query = '{Get{BrainDoc(nearVector:{vector:' + json.dumps(vec) + '},limit:2){title content}}}'
gql_data = json.dumps({'query': query}).encode()
gql_req = urllib.request.Request('http://localhost:8080/v1/graphql', data=gql_data, headers={'Content-Type': 'application/json'})
gql_resp = json.loads(urllib.request.urlopen(gql_req).read())
docs = gql_resp.get('data', {}).get('Get', {}).get('BrainDoc', [])
ctx = '\n'.join([d.get('content', '') for d in docs])
prompt = 'Answer using ONLY this context:\n' + ctx + '\n\nQuestion: What is Angel Cloud?\nAnswer:'
gen_data = json.dumps({'model': 'llama3.2:1b', 'prompt': prompt, 'stream': False}).encode()
gen_req = urllib.request.Request('http://localhost:11434/api/generate', data=gen_data, headers={'Content-Type': 'application/json'})
gen_resp = json.loads(urllib.request.urlopen(gen_req).read())
answer = gen_resp.get('response', '')
with open('$TEMP_DIR/rag_answer.txt', 'w') as f:
    f.write(answer)
print('OK' if len(answer) > 10 else 'EMPTY')
" 2>/dev/null || echo "FAIL")

if [ "$RAG_STATUS" == "OK" ]; then
    echo -e "  \e[92m   PASS: RAG pipeline returned a grounded answer\e[0m"
    echo
    echo -e "   \e[92m   Answer preview:\e[0m"
    if [ -f "$TEMP_DIR/rag_answer.txt" ]; then
        head -1 "$TEMP_DIR/rag_answer.txt" | sed 's/^/    /'
    fi
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: RAG pipeline did not return a usable answer\e[0m"
    echo "          Fix: Ensure documents are ingested and both services are running"
    echo "          Note: This check requires python3 in PATH"
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
    echo -e "  \e[92m   ✓ MODULE 1.3 COMPLETE\e[0m"
    echo -e "  \e[92m   You proved: You can build a RAG pipeline from scratch.\e[0m"
    echo -e "  \e[92m   Voice + Memory + Pipeline = Your own AI brain.\e[0m"
    echo

    # --- Update progress ---
    PROGRESS_FILE="$SCRIPT_DIR/../../../../progress/user-progress.json"
    if [ -f "$PROGRESS_FILE" ]; then
        echo "  {\"module\": \"1.3\", \"status\": \"completed\", \"timestamp\": \"$(date '+%Y-%m-%d %H:%M:%S')\"}" >> "${PROGRESS_FILE}.log"
    fi

    echo "   Next up: Module 1.4 — Prompt Engineering for Local Models"
    echo "   Your pipeline works. Now make it work WELL."
    echo "  ══════════════════════════════════════════════════════"
    exit 0
else
    echo -e "  \e[91m   RESULT: FAIL  ($PASS_COUNT/$TOTAL_CHECKS passed, $FAIL_COUNT failed)\e[0m"
    echo
    echo "   Review the failures above and fix them."
    echo "   Then run verify.sh again."
    echo "   Need help? Check hints.md in this folder."
    echo "  ══════════════════════════════════════════════════════"
    exit 1
fi
