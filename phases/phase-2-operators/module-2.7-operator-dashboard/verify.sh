#!/usr/bin/env bash
# Error handling is done per-command

# ============================================================
# MODULE 2.7 VERIFICATION — PHASE 2 CAPSTONE
# Checks: Services, all classes, all tools, dashboard exists,
#         end-to-end functionality
# Returns: exit 0 = PASS, exit 1 = FAIL
# ============================================================

PASS_COUNT=0
FAIL_COUNT=0
TOTAL_CHECKS=7
TEMP_DIR="/tmp/module-2.7-verify"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/output"
PHASE_DIR="$SCRIPT_DIR/.."

mkdir -p "$TEMP_DIR"

echo
echo "  ======================================================"
echo "   MODULE 2.7 VERIFICATION — PHASE 2 CAPSTONE"
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

# --- CHECK 3: All 5 Weaviate classes exist ---
echo "  [CHECK 3/$TOTAL_CHECKS] All Phase 2 Weaviate classes present"
CLASS_COUNT=0
for c in BusinessDoc DraftTemplate MessageLog DocTemplate WorkflowLog; do
    curl -s http://localhost:8080/v1/schema 2>/dev/null | grep -qi "$c"
    if [ $? -eq 0 ]; then
        CLASS_COUNT=$((CLASS_COUNT + 1))
        echo -e "     \e[92m✓\e[0m $c"
    else
        echo -e "     \e[91m✗\e[0m $c"
    fi
done
if [ "$CLASS_COUNT" -ge 5 ]; then
    echo -e "  \e[92m   PASS: All 5 classes present\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: Only $CLASS_COUNT/5 classes found\e[0m"
    echo "          Fix: Complete all modules 2.1-2.6"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 4: All collections have data ---
echo "  [CHECK 4/$TOTAL_CHECKS] All collections populated with data"
python3 -c "
import json,urllib.request
classes=['BusinessDoc','DraftTemplate','MessageLog','DocTemplate','WorkflowLog']
ok=0
total=5
for cls in classes:
    try:
        req=urllib.request.Request('http://localhost:8080/v1/graphql',data=json.dumps({'query':'{Aggregate{'+cls+'{meta{count}}}}'}).encode(),headers={'Content-Type':'application/json'})
        resp=json.loads(urllib.request.urlopen(req).read())
        count=resp.get('data',{}).get('Aggregate',{}).get(cls,[{}])[0].get('meta',{}).get('count',0)
        if count>0:
            ok+=1
            print(f'     {cls}: {count} objects')
        else:
            print(f'     {cls}: EMPTY')
    except:
        print(f'     {cls}: ERROR')
print(f'COUNT:{ok}')
" 2>/dev/null > "$TEMP_DIR/data_check.txt"

grep -v "COUNT:" "$TEMP_DIR/data_check.txt" 2>/dev/null || true
DATA_OK=$(grep "COUNT:" "$TEMP_DIR/data_check.txt" 2>/dev/null | cut -d: -f2 || echo "0")
if [ "$DATA_OK" -ge 4 ]; then
    echo -e "  \e[92m   PASS: $DATA_OK/5 collections have data\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: Only $DATA_OK/5 collections have data\e[0m"
    echo "          Fix: Run exercises for modules with empty collections"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 5: Operator Dashboard exists ---
echo "  [CHECK 5/$TOTAL_CHECKS] Operator Dashboard generated"
if [ -f "$OUTPUT_DIR/operator-dashboard.sh" ]; then
    echo -e "  \e[92m   PASS: operator-dashboard.sh found\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: operator-dashboard.sh not found\e[0m"
    echo "          Fix: Run exercise.sh to generate the dashboard"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 6: Dashboard has required components ---
echo "  [CHECK 6/$TOTAL_CHECKS] Dashboard has all required sections"
if [ -f "$OUTPUT_DIR/operator-dashboard.sh" ]; then
    COMP_COUNT=0
    grep -qi "OPERATOR DASHBOARD" "$OUTPUT_DIR/operator-dashboard.sh" && COMP_COUNT=$((COMP_COUNT + 1))
    grep -qi "Answer Desk" "$OUTPUT_DIR/operator-dashboard.sh" && COMP_COUNT=$((COMP_COUNT + 1))
    grep -qi "Draft It" "$OUTPUT_DIR/operator-dashboard.sh" && COMP_COUNT=$((COMP_COUNT + 1))
    grep -qi "Sort and Route" "$OUTPUT_DIR/operator-dashboard.sh" && COMP_COUNT=$((COMP_COUNT + 1))
    grep -qi "Chain Reactions" "$OUTPUT_DIR/operator-dashboard.sh" && COMP_COUNT=$((COMP_COUNT + 1))
    if [ "$COMP_COUNT" -ge 5 ]; then
        echo -e "  \e[92m   PASS: Dashboard contains all 5 tools\e[0m"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "  \e[91m   FAIL: Dashboard missing components ($COMP_COUNT/5 found)\e[0m"
        echo "          Fix: Run exercise.sh to regenerate"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    echo -e "  \e[91m   FAIL: Dashboard file not found\e[0m"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 7: End-to-end pipeline still works ---
echo "  [CHECK 7/$TOTAL_CHECKS] End-to-end business pipeline functional"
echo "   Running quick Q&A test..."

E2E_STATUS=$(python3 -c "
import json,urllib.request
q='What services do we offer?'
emb=json.loads(urllib.request.urlopen(urllib.request.Request('http://localhost:11434/api/embeddings',json.dumps({'model':'llama3.2:1b','prompt':q}).encode(),{'Content-Type':'application/json'})).read()).get('embedding',[])
docs=json.loads(urllib.request.urlopen(urllib.request.Request('http://localhost:8080/v1/graphql',json.dumps({'query':'{Get{BusinessDoc(nearVector:{vector:'+json.dumps(emb)+'},limit:1){title content}}}'}).encode(),{'Content-Type':'application/json'})).read()).get('data',{}).get('Get',{}).get('BusinessDoc',[])
ctx=docs[0].get('content','') if docs else ''
ans=json.loads(urllib.request.urlopen(urllib.request.Request('http://localhost:11434/api/generate',json.dumps({'model':'llama3.2:1b','prompt':'Answer from docs: '+ctx+chr(10)+'Q: '+q+chr(10)+'A:','stream':False}).encode(),{'Content-Type':'application/json'})).read()).get('response','')
print('OK' if len(ans)>10 else 'EMPTY')
" 2>/dev/null || echo "EMPTY")

if [ "$E2E_STATUS" = "OK" ]; then
    echo -e "  \e[92m   PASS: Full pipeline operational\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: Pipeline not producing results\e[0m"
    echo "          Fix: Check services and collection data"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# Cleanup
rm -rf "$TEMP_DIR"

# --- RESULTS ---
echo "  ======================================================"
if [ "$FAIL_COUNT" -eq 0 ]; then
    echo
    echo -e "  \e[92m   +=============================================+\e[0m"
    echo -e "  \e[92m   |                                              |\e[0m"
    echo -e "  \e[92m   |   RESULT: PASS  ($PASS_COUNT/$TOTAL_CHECKS checks passed)          |\e[0m"
    echo -e "  \e[92m   |                                              |\e[0m"
    echo -e "  \e[92m   |   PHASE 2 COMPLETE                          |\e[0m"
    echo -e "  \e[92m   |   STATUS: OPERATOR                          |\e[0m"
    echo -e "  \e[92m   |                                              |\e[0m"
    echo -e "  \e[92m   +=============================================+\e[0m"
    echo
    echo -e "  \e[92m   You proved:\e[0m"
    echo -e "  \e[92m   ✓ Load business documents into searchable AI\e[0m"
    echo -e "  \e[92m   ✓ Get instant answers with source citations\e[0m"
    echo -e "  \e[92m   ✓ Draft business messages with real data\e[0m"
    echo -e "  \e[92m   ✓ Classify and triage incoming messages\e[0m"
    echo -e "  \e[92m   ✓ Generate structured business documents\e[0m"
    echo -e "  \e[92m   ✓ Chain tools into automated workflows\e[0m"
    echo -e "  \e[92m   ✓ Package everything into a daily dashboard\e[0m"
    echo
    echo "   You built a complete business AI toolkit that runs"
    echo "   locally, uses YOUR data, and needs no internet."
    echo
    echo "   Phase 1 made you a BUILDER."
    echo "   Phase 2 made you an OPERATOR."
    echo
    echo "   Your Operator Dashboard: operator-dashboard.sh"
    echo "   Use it every day. Add your real documents."
    echo "   Make it yours."
    echo

    # --- Update progress ---
    PROGRESS_FILE="$SCRIPT_DIR/../../../../progress/user-progress.json"
    if [ -f "$PROGRESS_FILE" ]; then
        echo "  {\"module\": \"2.7\", \"status\": \"completed\", \"timestamp\": \"$(date '+%Y-%m-%d %H:%M:%S')\"}" >> "${PROGRESS_FILE}.log"
    fi

    echo "   Phase 3 — EVERYDAY USERS — coming soon."
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
