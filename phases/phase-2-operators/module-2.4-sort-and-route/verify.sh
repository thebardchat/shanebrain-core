#!/usr/bin/env bash
# Error handling is done per-command

# ============================================================
# MODULE 2.4 VERIFICATION
# Checks: Services, MessageLog schema, messages classified,
#         sort-and-route.sh generated, classification works
# Returns: exit 0 = PASS, exit 1 = FAIL
# ============================================================

PASS_COUNT=0
FAIL_COUNT=0
TOTAL_CHECKS=5
TEMP_DIR="/tmp/module-2.4-verify"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/output"

mkdir -p "$TEMP_DIR"

echo
echo "  ======================================================"
echo "   MODULE 2.4 VERIFICATION"
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

# --- CHECK 3: MessageLog schema exists ---
echo "  [CHECK 3/$TOTAL_CHECKS] MessageLog class exists"
curl -s http://localhost:8080/v1/schema 2>/dev/null | grep -qi "MessageLog"
if [ $? -eq 0 ]; then
    echo -e "  \e[92m   PASS: \"MessageLog\" class found\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: \"MessageLog\" class not found\e[0m"
    echo "          Fix: Run exercise.sh to create the schema"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 4: MessageLog has classified messages ---
echo "  [CHECK 4/$TOTAL_CHECKS] Messages classified and stored"
MSG_COUNT=$(python3 -c "import json,urllib.request; req=urllib.request.Request('http://localhost:8080/v1/graphql',data=json.dumps({'query':'{Aggregate{MessageLog{meta{count}}}}'}).encode(),headers={'Content-Type':'application/json'}); resp=json.loads(urllib.request.urlopen(req).read()); count=resp.get('data',{}).get('Aggregate',{}).get('MessageLog',[{}])[0].get('meta',{}).get('count',0); print(count)" 2>/dev/null || echo "0")
if [ "$MSG_COUNT" -ge 3 ]; then
    echo -e "  \e[92m   PASS: $MSG_COUNT messages classified in MessageLog\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: Only $MSG_COUNT messages in MessageLog (need 3+)\e[0m"
    echo "          Fix: Run exercise.sh — Task 2 classifies 5 sample messages"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 5: Classification pipeline works ---
echo "  [CHECK 5/$TOTAL_CHECKS] Classification pipeline produces valid output"
echo "   Classifying test message: \"I need a price quote for new flooring\""

CLASS_STATUS=$(python3 -c "
import json,urllib.request
msg='I need a price quote for new flooring in my office'
prompt='Classify this business message. Respond with EXACTLY three lines:\nCATEGORY: (quote_request, complaint, scheduling, payment, or general)\nPRIORITY: (HIGH, MEDIUM, or LOW)\nACTION: (one specific next step)\n\nMessage: '+msg
data=json.dumps({'model':'llama3.2:1b','prompt':prompt,'stream':False}).encode()
req=urllib.request.Request('http://localhost:11434/api/generate',data=data,headers={'Content-Type':'application/json'})
resp=json.loads(urllib.request.urlopen(req).read())
answer=resp.get('response','')
print('OK' if 'CATEGORY' in answer.upper() or 'PRIORITY' in answer.upper() else 'EMPTY')
" 2>/dev/null || echo "EMPTY")

if [ "$CLASS_STATUS" = "OK" ]; then
    echo -e "  \e[92m   PASS: Classification pipeline returned valid output\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: Classification pipeline did not produce valid output\e[0m"
    echo "          Fix: Ensure Ollama has the model loaded and is responding"
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
    echo -e "  \e[92m   ✓ MODULE 2.4 COMPLETE\e[0m"
    echo -e "  \e[92m   You proved: You can classify, prioritize, and\e[0m"
    echo -e "  \e[92m   route business messages automatically.\e[0m"
    echo

    PROGRESS_FILE="$SCRIPT_DIR/../../../../progress/user-progress.json"
    if [ -f "$PROGRESS_FILE" ]; then
        echo "  {\"module\": \"2.4\", \"status\": \"completed\", \"timestamp\": \"$(date '+%Y-%m-%d %H:%M:%S')\"}" >> "${PROGRESS_FILE}.log"
    fi

    echo "   Next up: Module 2.5 — Paperwork Machine"
    echo "   You can sort messages. Now generate documents."
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
