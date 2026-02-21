#!/usr/bin/env bash
# Error handling is done per-command

# ============================================================
# MODULE 2.3 VERIFICATION
# Checks: Services, DraftTemplate schema, templates seeded,
#         draft-it.sh generated, drafting pipeline works
# Returns: exit 0 = PASS, exit 1 = FAIL
# ============================================================

PASS_COUNT=0
FAIL_COUNT=0
TOTAL_CHECKS=5
TEMP_DIR="/tmp/module-2.3-verify"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/output"

mkdir -p "$TEMP_DIR"

echo
echo "  ======================================================"
echo "   MODULE 2.3 VERIFICATION"
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

# --- CHECK 3: DraftTemplate schema exists with templates ---
echo "  [CHECK 3/$TOTAL_CHECKS] DraftTemplate class with templates"
TMPL_COUNT=$(python3 -c "import json,urllib.request; req=urllib.request.Request('http://localhost:8080/v1/graphql',data=json.dumps({'query':'{Aggregate{DraftTemplate{meta{count}}}}'}).encode(),headers={'Content-Type':'application/json'}); resp=json.loads(urllib.request.urlopen(req).read()); count=resp.get('data',{}).get('Aggregate',{}).get('DraftTemplate',[{}])[0].get('meta',{}).get('count',0); print(count)" 2>/dev/null || echo "0")
if [ "$TMPL_COUNT" -ge 3 ]; then
    echo -e "  \e[92m   PASS: $TMPL_COUNT DraftTemplate objects stored\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: Only $TMPL_COUNT templates found (need 3+)\e[0m"
    echo "          Fix: Run exercise.sh to create schema and seed templates"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 4: draft-it.sh exists ---
echo "  [CHECK 4/$TOTAL_CHECKS] Draft It tool generated"
if [ -f "$OUTPUT_DIR/draft-it.sh" ]; then
    echo -e "  \e[92m   PASS: draft-it.sh found in output folder\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: draft-it.sh not found\e[0m"
    echo "          Fix: Run exercise.sh to generate the tool"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 5: Drafting pipeline produces output ---
echo "  [CHECK 5/$TOTAL_CHECKS] Drafting pipeline produces a message"
echo "   Running test: \"draft a reply about pricing\""

DRAFT_STATUS=$(python3 -c "
import json,urllib.request
request='draft a reply about our pricing and rates'
emb_data=json.dumps({'model':'llama3.2:1b','prompt':request}).encode()
emb_req=urllib.request.Request('http://localhost:11434/api/embeddings',data=emb_data,headers={'Content-Type':'application/json'})
emb_resp=json.loads(urllib.request.urlopen(emb_req).read())
vec=emb_resp.get('embedding',[])
tq='{Get{DraftTemplate(nearVector:{vector:'+json.dumps(vec)+'},limit:1){title content tone}}}'
t_data=json.dumps({'query':tq}).encode()
t_req=urllib.request.Request('http://localhost:8080/v1/graphql',data=t_data,headers={'Content-Type':'application/json'})
t_resp=json.loads(urllib.request.urlopen(t_req).read())
tmpl=t_resp.get('data',{}).get('Get',{}).get('DraftTemplate',[{}])[0]
bq='{Get{BusinessDoc(nearVector:{vector:'+json.dumps(vec)+'},limit:1){content}}}'
b_data=json.dumps({'query':bq}).encode()
b_req=urllib.request.Request('http://localhost:8080/v1/graphql',data=b_data,headers={'Content-Type':'application/json'})
b_resp=json.loads(urllib.request.urlopen(b_req).read())
biz=b_resp.get('data',{}).get('Get',{}).get('BusinessDoc',[{}])[0]
prompt='Write a professional reply about pricing. Style: '+tmpl.get('content','')+' Facts: '+biz.get('content','')
data=json.dumps({'model':'llama3.2:1b','prompt':prompt,'stream':False}).encode()
req=urllib.request.Request('http://localhost:11434/api/generate',data=data,headers={'Content-Type':'application/json'})
resp=json.loads(urllib.request.urlopen(req).read())
ans=resp.get('response','')
print('OK' if len(ans)>20 else 'EMPTY')
" 2>/dev/null || echo "EMPTY")

if [ "$DRAFT_STATUS" = "OK" ]; then
    echo -e "  \e[92m   PASS: Drafting pipeline generated a message\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: Drafting pipeline did not produce output\e[0m"
    echo "          Fix: Ensure both collections have data and services run"
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
    echo -e "  \e[92m   ✓ MODULE 2.3 COMPLETE\e[0m"
    echo -e "  \e[92m   You proved: You can draft business messages\e[0m"
    echo -e "  \e[92m   with templates, tone control, and real data.\e[0m"
    echo

    PROGRESS_FILE="$SCRIPT_DIR/../../../../progress/user-progress.json"
    if [ -f "$PROGRESS_FILE" ]; then
        echo "  {\"module\": \"2.3\", \"status\": \"completed\", \"timestamp\": \"$(date '+%Y-%m-%d %H:%M:%S')\"}" >> "${PROGRESS_FILE}.log"
    fi

    echo "   Next up: Module 2.4 — Sort and Route"
    echo "   You can write messages. Now learn to triage incoming ones."
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
