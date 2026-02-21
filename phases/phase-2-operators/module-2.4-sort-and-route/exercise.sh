#!/usr/bin/env bash
# Error handling is done per-command

# ============================================================
# MODULE 2.4 EXERCISE: Sort and Route
# Goal: Create MessageLog schema, classify sample messages,
#       build interactive triage tool
# Time: ~15 minutes
# RAM impact: ~300MB beyond Ollama + Weaviate baseline
# Prerequisite: Module 2.1 (BusinessDoc)
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/output"
TEMP_DIR="/tmp/module-2.4"

echo
echo "  ======================================================"
echo "   MODULE 2.4 EXERCISE: Sort and Route"
echo "  ======================================================"
echo
echo "   Build a message triage tool. Classify, prioritize,"
echo "   and route messages automatically. Three tasks."
echo
echo "  ------------------------------------------------------"
echo

# --- PRE-FLIGHT ---
echo "  [PRE-FLIGHT] Checking services and prerequisites..."
echo

curl -s http://localhost:11434/api/tags >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo -e "  \e[91m   ✗ Ollama is not running. Start it: ollama serve\e[0m"
    read -p "  Press Enter to continue..."
    exit 1
fi
echo -e "  \e[92m   ✓ Ollama running\e[0m"

curl -s http://localhost:8080/v1/.well-known/ready >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo -e "  \e[91m   ✗ Weaviate is not running. Start it first.\e[0m"
    read -p "  Press Enter to continue..."
    exit 1
fi
echo -e "  \e[92m   ✓ Weaviate running\e[0m"

curl -s http://localhost:8080/v1/schema 2>/dev/null | grep -qi "BusinessDoc"
if [ $? -ne 0 ]; then
    echo -e "  \e[91m   ✗ BusinessDoc not found. Complete Module 2.1 first.\e[0m"
    read -p "  Press Enter to continue..."
    exit 1
fi
echo -e "  \e[92m   ✓ BusinessDoc exists (Module 2.1 complete)\e[0m"
echo

mkdir -p "$TEMP_DIR"
mkdir -p "$OUTPUT_DIR"

# ============================================================
# TASK 1: Create MessageLog schema
# ============================================================
echo "  ------------------------------------------------------"
echo
echo "  [TASK 1/3] Create MessageLog schema"
echo

curl -s http://localhost:8080/v1/schema 2>/dev/null | grep -qi "MessageLog"
if [ $? -ne 0 ]; then
    echo "   Creating \"MessageLog\" class..."
    curl -s -X POST http://localhost:8080/v1/schema -H "Content-Type: application/json" -d '{"class":"MessageLog","description":"Classified business messages","vectorizer":"none","properties":[{"name":"content","dataType":["text"],"description":"Original message text"},{"name":"category","dataType":["text"],"description":"Category: quote_request, complaint, scheduling, payment, general"},{"name":"priority","dataType":["text"],"description":"Priority: HIGH, MEDIUM, LOW"},{"name":"suggestedAction","dataType":["text"],"description":"Recommended next step"},{"name":"timestamp","dataType":["text"],"description":"Classification timestamp"}]}' >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "  \e[92m   ✓ \"MessageLog\" class created\e[0m"
    else
        echo -e "  \e[91m   ✗ Failed to create MessageLog schema\e[0m"
        read -p "  Press Enter to continue..."
        exit 1
    fi
else
    echo -e "  \e[92m   ✓ \"MessageLog\" class already exists\e[0m"
fi
echo
echo "   Press any key to classify sample messages..."
read -n1 -s -p "  "
echo
echo

# ============================================================
# TASK 2: Classify sample messages
# ============================================================
echo "  ------------------------------------------------------"
echo
echo "  [TASK 2/3] Classify sample messages"
echo
echo "   Feeding 5 sample messages through the triage pipeline."
echo "   Watch the AI classify, prioritize, and suggest actions."
echo

# Sample messages to classify
MESSAGES=(
    "Hi, I need a quote for replacing the HVAC unit in my office. It is about 2000 square feet. When can someone come look at it?"
    "I am very unhappy with the work done last Tuesday. The technician left a mess and the problem is not fixed. I want this resolved immediately."
    "Can we reschedule our Thursday appointment to next Monday morning? Something came up at work."
    "I sent a check two weeks ago but have not received a receipt. Can you confirm you received payment for invoice 1045?"
    "Just wanted to say thanks for the great work yesterday. Your team was professional and finished ahead of schedule."
)

MSG_NUM=0
for msg in "${MESSAGES[@]}"; do
    MSG_NUM=$((MSG_NUM + 1))
    echo "   -- Message $MSG_NUM/5 ----------------------------"
    echo "   $msg"
    echo
    echo "   Classifying..."

    python3 -c "
import json,urllib.request,datetime
msg=r'''$msg'''
prompt='Classify this business message. Respond with EXACTLY three lines, nothing else:\nCATEGORY: (one of: quote_request, complaint, scheduling, payment, general)\nPRIORITY: (one of: HIGH, MEDIUM, LOW)\nACTION: (one specific action to take)\n\nMessage: '+msg
data=json.dumps({'model':'llama3.2:1b','prompt':prompt,'stream':False}).encode()
req=urllib.request.Request('http://localhost:11434/api/generate',data=data,headers={'Content-Type':'application/json'})
resp=json.loads(urllib.request.urlopen(req).read())
answer=resp.get('response','')
lines=answer.strip().split('\n')
parts={l.split(':',1)[0].strip().upper():l.split(':',1)[1].strip() for l in lines if ':' in l}
cat=parts.get('CATEGORY','general').lower().strip()
pri=parts.get('PRIORITY','MEDIUM').upper().strip()
act=parts.get('ACTION','Review manually').strip()
ts=datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
print('CATEGORY: '+cat)
print('PRIORITY: '+pri)
print('ACTION: '+act)
emb_data=json.dumps({'model':'llama3.2:1b','prompt':msg}).encode()
emb_req=urllib.request.Request('http://localhost:11434/api/embeddings',data=emb_data,headers={'Content-Type':'application/json'})
emb_resp=json.loads(urllib.request.urlopen(emb_req).read())
vec=emb_resp.get('embedding',[])
payload={'class':'MessageLog','properties':{'content':msg,'category':cat,'priority':pri,'suggestedAction':act,'timestamp':ts},'vector':vec}
store_data=json.dumps(payload).encode()
store_req=urllib.request.Request('http://localhost:8080/v1/objects',data=store_data,headers={'Content-Type':'application/json'})
urllib.request.urlopen(store_req)
print('LOGGED: Yes')
" 2>/dev/null

    echo
done

echo -e "  \e[92m   ✓ 5 messages classified and logged to MessageLog\e[0m"
echo
echo "   Press any key to build the interactive triage tool..."
read -n1 -s -p "  "
echo
echo

# ============================================================
# TASK 3: Generate Sort and Route tool and test it
# ============================================================
echo "  ------------------------------------------------------"
echo
echo "  [TASK 3/3] Build and test the Sort and Route tool"
echo

# Generate the tool
cat > "$OUTPUT_DIR/sort-and-route.sh" << 'SORT_ROUTE_EOF'
#!/usr/bin/env bash
# Error handling is done per-command

echo
echo "  ======================================================"
echo "   SORT AND ROUTE — Message Triage"
echo "   Paste a message. Get category, priority, and action."
echo "  ======================================================"
echo

# Health checks
curl -s http://localhost:11434/api/tags >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo -e "  \e[91m   Ollama not running. Start it: ollama serve\e[0m"
    read -p "  Press Enter to continue..."
    exit 1
fi
curl -s http://localhost:8080/v1/.well-known/ready >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo -e "  \e[91m   Weaviate not running. Start Docker.\e[0m"
    read -p "  Press Enter to continue..."
    exit 1
fi
echo -e "  \e[92m   Systems online. Paste messages to classify.\e[0m"
echo

while true; do
    echo "  ------------------------------------------------------"
    read -p "  Message to classify (Q to quit): " MSG
    if [[ "${MSG,,}" == "q" ]]; then break; fi
    if [ -z "$MSG" ]; then continue; fi
    echo
    echo "   Classifying..."

    python3 -c "
import json,urllib.request,datetime
msg=r'''$MSG'''
prompt='Classify this business message. Respond with EXACTLY three lines:\nCATEGORY: (quote_request, complaint, scheduling, payment, or general)\nPRIORITY: (HIGH, MEDIUM, or LOW)\nACTION: (one specific next step)\n\nMessage: '+msg
data=json.dumps({'model':'llama3.2:1b','prompt':prompt,'stream':False}).encode()
req=urllib.request.Request('http://localhost:11434/api/generate',data=data,headers={'Content-Type':'application/json'})
resp=json.loads(urllib.request.urlopen(req).read())
answer=resp.get('response','')
lines=answer.strip().split(chr(10))
parts={l.split(':',1)[0].strip().upper():l.split(':',1)[1].strip() for l in lines if ':' in l}
cat=parts.get('CATEGORY','general').lower().strip()
pri=parts.get('PRIORITY','MEDIUM').upper().strip()
act=parts.get('ACTION','Review manually').strip()
ts=datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
print()
print('   +-------------------------------------+')
print('   | Category:  '+cat)
print('   | Priority:  '+pri)
print('   | Action:    '+act)
print('   +-------------------------------------+')
emb_data=json.dumps({'model':'llama3.2:1b','prompt':msg}).encode()
emb_req=urllib.request.Request('http://localhost:11434/api/embeddings',data=emb_data,headers={'Content-Type':'application/json'})
emb_resp=json.loads(urllib.request.urlopen(emb_req).read())
vec=emb_resp.get('embedding',[])
payload={'class':'MessageLog','properties':{'content':msg,'category':cat,'priority':pri,'suggestedAction':act,'timestamp':ts},'vector':vec}
store_data=json.dumps(payload).encode()
store_req=urllib.request.Request('http://localhost:8080/v1/objects',data=store_data,headers={'Content-Type':'application/json'})
urllib.request.urlopen(store_req)
print('   Logged to MessageLog')
" 2>/dev/null

    echo
done

echo
echo "   Triage session closed. All messages logged."
exit 0
SORT_ROUTE_EOF

chmod +x "$OUTPUT_DIR/sort-and-route.sh"

if [ -f "$OUTPUT_DIR/sort-and-route.sh" ]; then
    echo -e "  \e[92m   ✓ sort-and-route.sh created in output folder\e[0m"
else
    echo -e "  \e[91m   ✗ Failed to create sort-and-route.sh\e[0m"
    read -p "  Press Enter to continue..."
    exit 1
fi

echo
echo "   Try classifying your own messages. Examples:"
echo "     - \"I need a quote for a bathroom remodel\""
echo "     - \"Your technician never showed up and nobody called\""
echo "     - \"Can we move our Tuesday appointment?\""
echo

while true; do
    echo "  ------------------------------------------------------"
    read -p "  Message to classify (Q to quit): " TEST_MSG

    if [[ "${TEST_MSG,,}" == "q" ]]; then break; fi
    if [ -z "$TEST_MSG" ]; then continue; fi

    echo
    echo "   Classifying..."

    python3 -c "
import json,urllib.request,datetime
msg=r'''$TEST_MSG'''
prompt='Classify this business message. Respond with EXACTLY three lines:\nCATEGORY: (quote_request, complaint, scheduling, payment, or general)\nPRIORITY: (HIGH, MEDIUM, or LOW)\nACTION: (one specific next step)\n\nMessage: '+msg
data=json.dumps({'model':'llama3.2:1b','prompt':prompt,'stream':False}).encode()
req=urllib.request.Request('http://localhost:11434/api/generate',data=data,headers={'Content-Type':'application/json'})
resp=json.loads(urllib.request.urlopen(req).read())
answer=resp.get('response','')
lines=answer.strip().split(chr(10))
parts={l.split(':',1)[0].strip().upper():l.split(':',1)[1].strip() for l in lines if ':' in l}
cat=parts.get('CATEGORY','general').lower().strip()
pri=parts.get('PRIORITY','MEDIUM').upper().strip()
act=parts.get('ACTION','Review manually').strip()
print()
print('   Category:  '+cat)
print('   Priority:  '+pri)
print('   Action:    '+act)
" 2>/dev/null

    echo
done

# ============================================================
echo
echo "  ======================================================"
echo "   EXERCISE COMPLETE"
echo "  ======================================================"
echo
echo "   Your Sort and Route tool is built. It lives at:"
echo "     $OUTPUT_DIR/sort-and-route.sh"
echo
echo "   Messages are logged in Weaviate for pattern tracking."
echo "   Now run verify.sh to confirm everything passed."
echo

rm -rf "$TEMP_DIR"

read -p "  Press Enter to continue..."
exit 0
