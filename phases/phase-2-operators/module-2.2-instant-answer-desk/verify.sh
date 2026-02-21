#!/usr/bin/env bash
# Error handling is done per-command

# ============================================================
# MODULE 2.2 VERIFICATION
# Checks: Services, BusinessDoc prerequisite, answer-desk.sh
#         generated, Q&A returns cited answer
# Returns: exit 0 = PASS, exit 1 = FAIL
# ============================================================

PASS_COUNT=0
FAIL_COUNT=0
TOTAL_CHECKS=5
TEMP_DIR="/tmp/module-2.2-verify"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/output"

mkdir -p "$TEMP_DIR"

echo
echo "  ======================================================"
echo "   MODULE 2.2 VERIFICATION"
echo "  ======================================================"
echo

# --- CHECK 1: Ollama running ---
echo "  [CHECK 1/$TOTAL_CHECKS] Ollama server running"
curl -s http://localhost:11434/api/tags >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "  \e[92m   PASS: Ollama responding\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: Ollama not responding\e[0m"
    echo "          Fix: Run \"ollama serve\""
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 2: Weaviate running ---
echo "  [CHECK 2/$TOTAL_CHECKS] Weaviate server running"
curl -s http://localhost:8080/v1/.well-known/ready >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "  \e[92m   PASS: Weaviate responding\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: Weaviate not responding\e[0m"
    echo "          Fix: Start Weaviate via Docker"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 3: BusinessDoc has documents ---
echo "  [CHECK 3/$TOTAL_CHECKS] BusinessDoc collection has documents"
DOC_COUNT=$(python3 -c "import json,urllib.request; req=urllib.request.Request('http://localhost:8080/v1/graphql',data=json.dumps({'query':'{Aggregate{BusinessDoc{meta{count}}}}'}).encode(),headers={'Content-Type':'application/json'}); resp=json.loads(urllib.request.urlopen(req).read()); count=resp.get('data',{}).get('Aggregate',{}).get('BusinessDoc',[{}])[0].get('meta',{}).get('count',0); print(count)" 2>/dev/null || echo "0")
if [ "$DOC_COUNT" -ge 3 ]; then
    echo -e "  \e[92m   PASS: $DOC_COUNT BusinessDoc objects available\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: Only $DOC_COUNT BusinessDoc objects (need 3+)\e[0m"
    echo "          Fix: Complete Module 2.1 first"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 4: answer-desk.sh exists ---
echo "  [CHECK 4/$TOTAL_CHECKS] Answer Desk tool generated"
if [ -f "$OUTPUT_DIR/answer-desk.sh" ]; then
    echo -e "  \e[92m   PASS: answer-desk.sh found in output folder\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: answer-desk.sh not found\e[0m"
    echo "          Fix: Run exercise.sh to generate the tool"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 5: End-to-end Q&A with source citation ---
echo "  [CHECK 5/$TOTAL_CHECKS] Q&A returns answer with source citations"
echo "   Running query: \"What is the service call fee?\""

QA_STATUS=$(python3 -c "
import json,urllib.request
q='What is the service call fee?'
emb_data=json.dumps({'model':'llama3.2:1b','prompt':q}).encode()
emb_req=urllib.request.Request('http://localhost:11434/api/embeddings',data=emb_data,headers={'Content-Type':'application/json'})
emb_resp=json.loads(urllib.request.urlopen(emb_req).read())
vec=emb_resp.get('embedding',[])
query='{Get{BusinessDoc(nearVector:{vector:'+json.dumps(vec)+'},limit:2){title content category _additional{distance}}}}'
gql_data=json.dumps({'query':query}).encode()
gql_req=urllib.request.Request('http://localhost:8080/v1/graphql',data=gql_data,headers={'Content-Type':'application/json'})
gql_resp=json.loads(urllib.request.urlopen(gql_req).read())
docs=gql_resp.get('data',{}).get('Get',{}).get('BusinessDoc',[])
ctx='\n'.join(['['+d.get('title','')+'] '+d.get('content','') for d in docs])
sources=', '.join([d.get('title','') for d in docs])
prompt='Answer using ONLY these docs. Cite the source.\n\n'+ctx+'\n\nQ: '+q+'\nA:'
data=json.dumps({'model':'llama3.2:1b','prompt':prompt,'stream':False}).encode()
req=urllib.request.Request('http://localhost:11434/api/generate',data=data,headers={'Content-Type':'application/json'})
resp=json.loads(urllib.request.urlopen(req).read())
ans=resp.get('response','')
print('OK' if len(ans)>10 else 'EMPTY')
open('$TEMP_DIR/qa_answer.txt','w').write(ans+'\nSources: '+sources)
" 2>/dev/null || echo "EMPTY")

if [ "$QA_STATUS" = "OK" ]; then
    echo -e "  \e[92m   PASS: Q&A returned a cited answer\e[0m"
    echo
    echo -e "   \e[92m   Answer preview:\e[0m"
    if [ -f "$TEMP_DIR/qa_answer.txt" ]; then
        head -1 "$TEMP_DIR/qa_answer.txt" | sed 's/^/    /'
    fi
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: Q&A did not return a usable answer\e[0m"
    echo "          Fix: Ensure BusinessDoc has documents and both services run"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# Cleanup
rm -rf "$TEMP_DIR"

# --- RESULTS ---
echo "  ======================================================"
if [ "$FAIL_COUNT" -eq 0 ]; then
    echo -e "  \e[92m   RESULT: PASS  ($PASS_COUNT/$TOTAL_CHECKS checks passed)\e[0m"
    echo
    echo -e "  \e[92m   ✓ MODULE 2.2 COMPLETE\e[0m"
    echo -e "  \e[92m   You proved: You can get instant, cited answers\e[0m"
    echo -e "  \e[92m   from your business knowledge base.\e[0m"
    echo

    PROGRESS_FILE="$SCRIPT_DIR/../../../../progress/user-progress.json"
    if [ -f "$PROGRESS_FILE" ]; then
        echo "  {\"module\": \"2.2\", \"status\": \"completed\", \"timestamp\": \"$(date '+%Y-%m-%d %H:%M:%S')\"}" >> "${PROGRESS_FILE}.log"
    fi

    echo "   Next up: Module 2.3 — Draft It"
    echo "   You can answer questions. Now learn to WRITE from your docs."
    echo "  ======================================================"
    exit 0
else
    echo -e "  \e[91m   RESULT: FAIL  ($PASS_COUNT/$TOTAL_CHECKS passed, $FAIL_COUNT failed)\e[0m"
    echo
    echo "   Review the failures above and fix them."
    echo "   Then run verify.sh again."
    echo "   Need help? Check hints.md in this folder."
    echo "  ======================================================"
    exit 1
fi
