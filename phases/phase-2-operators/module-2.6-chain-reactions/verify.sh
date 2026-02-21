#!/usr/bin/env bash
# Error handling is done per-command

# ============================================================
# MODULE 2.6 VERIFICATION
# Checks: Services, all prerequisite classes, WorkflowLog,
#         chain-reactions.sh generated, workflow logged
# Returns: exit 0 = PASS, exit 1 = FAIL
# ============================================================

PASS_COUNT=0
FAIL_COUNT=0
TOTAL_CHECKS=6
TEMP_DIR="/tmp/module-2.6-verify"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/output"

mkdir -p "$TEMP_DIR"

echo
echo "  ======================================================"
echo "   MODULE 2.6 VERIFICATION"
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

# --- CHECK 3: All prerequisite classes exist ---
echo "  [CHECK 3/$TOTAL_CHECKS] All Phase 2 Weaviate classes present"
CLASS_COUNT=0
for c in BusinessDoc DraftTemplate MessageLog DocTemplate WorkflowLog; do
    curl -s http://localhost:8080/v1/schema 2>/dev/null | grep -qi "$c"
    if [ $? -eq 0 ]; then
        CLASS_COUNT=$((CLASS_COUNT + 1))
    fi
done
if [ "$CLASS_COUNT" -ge 5 ]; then
    echo -e "  \e[92m   PASS: All 5 Phase 2 classes found\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: Only $CLASS_COUNT/5 classes found\e[0m"
    echo "          Fix: Complete Modules 2.1-2.5, then run this exercise"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 4: WorkflowLog has entries ---
echo "  [CHECK 4/$TOTAL_CHECKS] WorkflowLog has workflow records"
WF_COUNT=$(python3 -c "import json,urllib.request; req=urllib.request.Request('http://localhost:8080/v1/graphql',data=json.dumps({'query':'{Aggregate{WorkflowLog{meta{count}}}}'}).encode(),headers={'Content-Type':'application/json'}); resp=json.loads(urllib.request.urlopen(req).read()); count=resp.get('data',{}).get('Aggregate',{}).get('WorkflowLog',[{}])[0].get('meta',{}).get('count',0); print(count)" 2>/dev/null || echo "0")
if [ "$WF_COUNT" -ge 1 ]; then
    echo -e "  \e[92m   PASS: $WF_COUNT workflow(s) logged\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: No workflows logged\e[0m"
    echo "          Fix: Run exercise.sh — Task 2 runs a demo workflow"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 5: chain-reactions.sh exists ---
echo "  [CHECK 5/$TOTAL_CHECKS] Chain Reactions tool generated"
if [ -f "$OUTPUT_DIR/chain-reactions.sh" ]; then
    echo -e "  \e[92m   PASS: chain-reactions.sh found\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: chain-reactions.sh not found\e[0m"
    echo "          Fix: Run exercise.sh to generate the tool"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 6: End-to-end chain works ---
echo "  [CHECK 6/$TOTAL_CHECKS] Workflow chain produces output"
echo "   Running test chain on: \"I need a quote for painting\""

CHAIN_STATUS=$(python3 -c "
import json,urllib.request
inp='I need a quote for painting my office lobby'
emb_data=json.dumps({'model':'llama3.2:1b','prompt':inp}).encode()
emb_req=urllib.request.Request('http://localhost:11434/api/embeddings',data=emb_data,headers={'Content-Type':'application/json'})
emb_resp=json.loads(urllib.request.urlopen(emb_req).read())
vec=emb_resp.get('embedding',[])
bq='{Get{BusinessDoc(nearVector:{vector:'+json.dumps(vec)+'},limit:1){content}}}'
b_data=json.dumps({'query':bq}).encode()
b_req=urllib.request.Request('http://localhost:8080/v1/graphql',data=b_data,headers={'Content-Type':'application/json'})
b_resp=json.loads(urllib.request.urlopen(b_req).read())
biz=b_resp.get('data',{}).get('Get',{}).get('BusinessDoc',[{}])[0]
prompt='Lead: '+inp+' Pricing: '+biz.get('content','')+' 1. Classify. 2. Draft welcome with pricing.'
data=json.dumps({'model':'llama3.2:1b','prompt':prompt,'stream':False}).encode()
req=urllib.request.Request('http://localhost:11434/api/generate',data=data,headers={'Content-Type':'application/json'})
resp=json.loads(urllib.request.urlopen(req).read())
out=resp.get('response','')
print('OK' if len(out)>20 else 'EMPTY')
" 2>/dev/null || echo "EMPTY")

if [ "$CHAIN_STATUS" = "OK" ]; then
    echo -e "  \e[92m   PASS: Workflow chain produced output\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: Workflow chain did not produce output\e[0m"
    echo "          Fix: Ensure all services and collections are populated"
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
    echo -e "  \e[92m   ✓ MODULE 2.6 COMPLETE\e[0m"
    echo -e "  \e[92m   You proved: You can chain multiple AI tools\e[0m"
    echo -e "  \e[92m   into automated workflows with full logging.\e[0m"
    echo

    PROGRESS_FILE="$SCRIPT_DIR/../../../../progress/user-progress.json"
    if [ -f "$PROGRESS_FILE" ]; then
        echo "  {\"module\": \"2.6\", \"status\": \"completed\", \"timestamp\": \"$(date '+%Y-%m-%d %H:%M:%S')\"}" >> "${PROGRESS_FILE}.log"
    fi

    echo "   Next up: Module 2.7 — Your Operator Dashboard"
    echo "   Package everything into one tool. The capstone."
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
