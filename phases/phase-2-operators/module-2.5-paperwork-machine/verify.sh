#!/usr/bin/env bash
# Error handling is done per-command

# ============================================================
# MODULE 2.5 VERIFICATION
# Checks: Services, DocTemplate schema, templates seeded,
#         paperwork-machine.sh generated, document generation
# Returns: exit 0 = PASS, exit 1 = FAIL
# ============================================================

PASS_COUNT=0
FAIL_COUNT=0
TOTAL_CHECKS=5
TEMP_DIR="/tmp/module-2.5-verify"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/output"
DOC_DIR="$SCRIPT_DIR/output/documents"

mkdir -p "$TEMP_DIR"

echo
echo "  ======================================================"
echo "   MODULE 2.5 VERIFICATION"
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

# --- CHECK 3: DocTemplate schema with templates ---
echo "  [CHECK 3/$TOTAL_CHECKS] DocTemplate class with templates"
TMPL_COUNT=$(python3 -c "import json,urllib.request; req=urllib.request.Request('http://localhost:8080/v1/graphql',data=json.dumps({'query':'{Aggregate{DocTemplate{meta{count}}}}'}).encode(),headers={'Content-Type':'application/json'}); resp=json.loads(urllib.request.urlopen(req).read()); count=resp.get('data',{}).get('Aggregate',{}).get('DocTemplate',[{}])[0].get('meta',{}).get('count',0); print(count)" 2>/dev/null || echo "0")
if [ "$TMPL_COUNT" -ge 3 ]; then
    echo -e "  \e[92m   PASS: $TMPL_COUNT DocTemplate objects stored\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: Only $TMPL_COUNT templates (need 3+)\e[0m"
    echo "          Fix: Run exercise.sh to create and seed templates"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 4: paperwork-machine.sh exists ---
echo "  [CHECK 4/$TOTAL_CHECKS] Paperwork Machine tool generated"
if [ -f "$OUTPUT_DIR/paperwork-machine.sh" ]; then
    echo -e "  \e[92m   PASS: paperwork-machine.sh found\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: paperwork-machine.sh not found\e[0m"
    echo "          Fix: Run exercise.sh to generate the tool"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 5: Document generation works ---
echo "  [CHECK 5/$TOTAL_CHECKS] Document generation pipeline works"
echo "   Generating test document: \"estimate for window repair\""

GEN_STATUS=$(python3 -c "
import json,urllib.request
request='estimate for window repair at 100 Main St for Test Customer'
emb_data=json.dumps({'model':'llama3.2:1b','prompt':request}).encode()
emb_req=urllib.request.Request('http://localhost:11434/api/embeddings',data=emb_data,headers={'Content-Type':'application/json'})
emb_resp=json.loads(urllib.request.urlopen(emb_req).read())
vec=emb_resp.get('embedding',[])
tq='{Get{DocTemplate(nearVector:{vector:'+json.dumps(vec)+'},limit:1){title content docType}}}'
t_data=json.dumps({'query':tq}).encode()
t_req=urllib.request.Request('http://localhost:8080/v1/graphql',data=t_data,headers={'Content-Type':'application/json'})
t_resp=json.loads(urllib.request.urlopen(t_req).read())
tmpl=t_resp.get('data',{}).get('Get',{}).get('DocTemplate',[{}])[0]
bq='{Get{BusinessDoc(nearVector:{vector:'+json.dumps(vec)+'},limit:1){content}}}'
b_data=json.dumps({'query':bq}).encode()
b_req=urllib.request.Request('http://localhost:8080/v1/graphql',data=b_data,headers={'Content-Type':'application/json'})
b_resp=json.loads(urllib.request.urlopen(b_req).read())
biz=b_resp.get('data',{}).get('Get',{}).get('BusinessDoc',[{}])[0]
prompt='Generate a brief estimate document for window repair. Template: '+tmpl.get('content','')+' Business data: '+biz.get('content','')
data=json.dumps({'model':'llama3.2:1b','prompt':prompt,'stream':False}).encode()
req=urllib.request.Request('http://localhost:11434/api/generate',data=data,headers={'Content-Type':'application/json'})
resp=json.loads(urllib.request.urlopen(req).read())
doc=resp.get('response','')
print('OK' if len(doc)>30 else 'EMPTY')
" 2>/dev/null || echo "EMPTY")

if [ "$GEN_STATUS" = "OK" ]; then
    echo -e "  \e[92m   PASS: Document generation pipeline works\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: Document generation did not produce output\e[0m"
    echo "          Fix: Ensure DocTemplate and BusinessDoc have data"
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
    echo -e "  \e[92m   ✓ MODULE 2.5 COMPLETE\e[0m"
    echo -e "  \e[92m   You proved: You can generate structured business\e[0m"
    echo -e "  \e[92m   documents from templates and real business data.\e[0m"
    echo

    PROGRESS_FILE="$SCRIPT_DIR/../../../../progress/user-progress.json"
    if [ -f "$PROGRESS_FILE" ]; then
        echo "  {\"module\": \"2.5\", \"status\": \"completed\", \"timestamp\": \"$(date '+%Y-%m-%d %H:%M:%S')\"}" >> "${PROGRESS_FILE}.log"
    fi

    echo "   Next up: Module 2.6 — Chain Reactions"
    echo "   You built all the tools. Now chain them together."
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
