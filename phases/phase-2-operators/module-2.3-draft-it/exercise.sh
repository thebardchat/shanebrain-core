#!/usr/bin/env bash
# Error handling is done per-command

# ============================================================
# MODULE 2.3 EXERCISE: Draft It
# Goal: Create DraftTemplate schema, seed templates, build
#       a message drafting tool with tone control & context
# Time: ~20 minutes
# RAM impact: ~300MB beyond Ollama + Weaviate baseline
# Prerequisites: Module 2.1 (BusinessDoc), Module 2.2
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/output"
TEMP_DIR="/tmp/module-2.3"

echo
echo "  ======================================================"
echo "   MODULE 2.3 EXERCISE: Draft It"
echo "  ======================================================"
echo
echo "   Build a message drafting tool with templates and"
echo "   tone control. Three tasks."
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
    echo -e "  \e[91m   ✗ BusinessDoc class not found. Complete Module 2.1 first.\e[0m"
    read -p "  Press Enter to continue..."
    exit 1
fi
echo -e "  \e[92m   ✓ BusinessDoc exists (Module 2.1 complete)\e[0m"
echo

mkdir -p "$TEMP_DIR"
mkdir -p "$OUTPUT_DIR"

# ============================================================
# TASK 1: Create DraftTemplate schema and seed templates
# ============================================================
echo "  ------------------------------------------------------"
echo
echo "  [TASK 1/3] Create DraftTemplate schema and seed templates"
echo

# Create schema
curl -s http://localhost:8080/v1/schema 2>/dev/null | grep -qi "DraftTemplate"
if [ $? -ne 0 ]; then
    echo "   Creating \"DraftTemplate\" class..."
    curl -s -X POST http://localhost:8080/v1/schema -H "Content-Type: application/json" -d '{"class":"DraftTemplate","description":"Reusable business message templates","vectorizer":"none","properties":[{"name":"title","dataType":["text"],"description":"Template name"},{"name":"content","dataType":["text"],"description":"Template text"},{"name":"messageType","dataType":["text"],"description":"Message type: email, text, letter, memo"},{"name":"tone","dataType":["text"],"description":"Tone: professional, friendly, firm"}]}' >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "  \e[92m   ✓ \"DraftTemplate\" class created\e[0m"
    else
        echo -e "  \e[91m   ✗ Failed to create DraftTemplate schema\e[0m"
        read -p "  Press Enter to continue..."
        exit 1
    fi
else
    echo -e "  \e[92m   ✓ \"DraftTemplate\" class already exists\e[0m"
fi
echo

# Seed templates
echo "   Seeding starter templates..."
echo

# Template 1: Customer Welcome
T1=$(python3 -c "import json,urllib.request; content='Hi [NAME], welcome! We are glad you chose us. Here is what to expect: we will schedule your appointment, our technician will arrive on time, and we will follow up after the job to make sure everything is right. If you have any questions, just call or text us anytime. Looking forward to working with you.'; emb_data=json.dumps({'model':'llama3.2:1b','prompt':content}).encode(); req=urllib.request.Request('http://localhost:11434/api/embeddings',data=emb_data,headers={'Content-Type':'application/json'}); resp=json.loads(urllib.request.urlopen(req).read()); vec=resp.get('embedding',[]); payload={'class':'DraftTemplate','properties':{'title':'Customer Welcome','content':content,'messageType':'email','tone':'friendly'},'vector':vec}; data=json.dumps(payload).encode(); store_req=urllib.request.Request('http://localhost:8080/v1/objects',data=data,headers={'Content-Type':'application/json'}); urllib.request.urlopen(store_req); print('OK')" 2>/dev/null || echo "WARN")
if [ "$T1" = "OK" ]; then echo -e "  \e[92m   ✓ Template: Customer Welcome [friendly]\e[0m"; else echo -e "  \e[93m   ⚠ Customer Welcome — may be duplicate\e[0m"; fi

# Template 2: Quote Follow-Up
T2=$(python3 -c "import json,urllib.request; content='Hi [NAME], I wanted to follow up on the estimate we provided on [DATE]. The total was [AMOUNT] which includes all labor and materials. This estimate is valid for 30 days. If you have any questions about the scope of work or pricing, I am happy to walk through it. Ready to get started? Just let me know and we will get you on the schedule.'; emb_data=json.dumps({'model':'llama3.2:1b','prompt':content}).encode(); req=urllib.request.Request('http://localhost:11434/api/embeddings',data=emb_data,headers={'Content-Type':'application/json'}); resp=json.loads(urllib.request.urlopen(req).read()); vec=resp.get('embedding',[]); payload={'class':'DraftTemplate','properties':{'title':'Quote Follow-Up','content':content,'messageType':'email','tone':'professional'},'vector':vec}; data=json.dumps(payload).encode(); store_req=urllib.request.Request('http://localhost:8080/v1/objects',data=data,headers={'Content-Type':'application/json'}); urllib.request.urlopen(store_req); print('OK')" 2>/dev/null || echo "WARN")
if [ "$T2" = "OK" ]; then echo -e "  \e[92m   ✓ Template: Quote Follow-Up [professional]\e[0m"; else echo -e "  \e[93m   ⚠ Quote Follow-Up — may be duplicate\e[0m"; fi

# Template 3: Complaint Response
T3=$(python3 -c "import json,urllib.request; content='Dear [NAME], thank you for letting us know about this issue. I take every complaint seriously. Here is what I am going to do: I will review the details of your case, contact you within 24 hours with a resolution plan, and make sure this is handled to your satisfaction. We stand behind our work and want to make this right.'; emb_data=json.dumps({'model':'llama3.2:1b','prompt':content}).encode(); req=urllib.request.Request('http://localhost:11434/api/embeddings',data=emb_data,headers={'Content-Type':'application/json'}); resp=json.loads(urllib.request.urlopen(req).read()); vec=resp.get('embedding',[]); payload={'class':'DraftTemplate','properties':{'title':'Complaint Response','content':content,'messageType':'email','tone':'professional'},'vector':vec}; data=json.dumps(payload).encode(); store_req=urllib.request.Request('http://localhost:8080/v1/objects',data=data,headers={'Content-Type':'application/json'}); urllib.request.urlopen(store_req); print('OK')" 2>/dev/null || echo "WARN")
if [ "$T3" = "OK" ]; then echo -e "  \e[92m   ✓ Template: Complaint Response [professional]\e[0m"; else echo -e "  \e[93m   ⚠ Complaint Response — may be duplicate\e[0m"; fi

# Template 4: Payment Reminder
T4=$(python3 -c "import json,urllib.request; content='Hi [NAME], this is a friendly reminder that invoice [NUMBER] for [AMOUNT] is now past due. Payment was due on [DATE]. We accept cash, check, and all major credit cards. Please submit payment at your earliest convenience. If you have already sent payment, please disregard this notice. If you need to discuss a payment plan, call us directly.'; emb_data=json.dumps({'model':'llama3.2:1b','prompt':content}).encode(); req=urllib.request.Request('http://localhost:11434/api/embeddings',data=emb_data,headers={'Content-Type':'application/json'}); resp=json.loads(urllib.request.urlopen(req).read()); vec=resp.get('embedding',[]); payload={'class':'DraftTemplate','properties':{'title':'Payment Reminder','content':content,'messageType':'email','tone':'firm'},'vector':vec}; data=json.dumps(payload).encode(); store_req=urllib.request.Request('http://localhost:8080/v1/objects',data=data,headers={'Content-Type':'application/json'}); urllib.request.urlopen(store_req); print('OK')" 2>/dev/null || echo "WARN")
if [ "$T4" = "OK" ]; then echo -e "  \e[92m   ✓ Template: Payment Reminder [firm]\e[0m"; else echo -e "  \e[93m   ⚠ Payment Reminder — may be duplicate\e[0m"; fi

# Template 5: Job Completion
T5=$(python3 -c "import json,urllib.request; content='Hi [NAME], good news — the job at [ADDRESS] is complete. Here is a summary of what we did: [WORK_SUMMARY]. The total comes to [AMOUNT]. Payment is due upon completion. Thank you for choosing us. We will follow up in 48 hours to make sure everything is working properly. Our work comes with a 90-day warranty on labor.'; emb_data=json.dumps({'model':'llama3.2:1b','prompt':content}).encode(); req=urllib.request.Request('http://localhost:11434/api/embeddings',data=emb_data,headers={'Content-Type':'application/json'}); resp=json.loads(urllib.request.urlopen(req).read()); vec=resp.get('embedding',[]); payload={'class':'DraftTemplate','properties':{'title':'Job Completion','content':content,'messageType':'email','tone':'professional'},'vector':vec}; data=json.dumps(payload).encode(); store_req=urllib.request.Request('http://localhost:8080/v1/objects',data=data,headers={'Content-Type':'application/json'}); urllib.request.urlopen(store_req); print('OK')" 2>/dev/null || echo "WARN")
if [ "$T5" = "OK" ]; then echo -e "  \e[92m   ✓ Template: Job Completion [professional]\e[0m"; else echo -e "  \e[93m   ⚠ Job Completion — may be duplicate\e[0m"; fi

echo
echo "   Five templates loaded. Press any key to build the drafting tool..."
read -n1 -s -p "  "
echo
echo

# ============================================================
# TASK 2: Generate the Draft It tool
# ============================================================
echo "  ------------------------------------------------------"
echo
echo "  [TASK 2/3] Generate the Draft It tool"
echo

cat > "$OUTPUT_DIR/draft-it.sh" << 'DRAFT_IT_EOF'
#!/usr/bin/env bash
# Error handling is done per-command

TEMP_DIR="/tmp/draft-it"
mkdir -p "$TEMP_DIR"

echo
echo "  ======================================================"
echo "   DRAFT IT — Business Message Drafter"
echo "   Describe what you need. Get a draft with your data."
echo "  ======================================================"
echo
echo "   Tone options: professional, friendly, firm"
echo "   Type examples: email, text, letter, memo"
echo

while true; do
    echo "  ------------------------------------------------------"
    read -p "  What do you need to write? (Q to quit): " REQUEST
    if [[ "${REQUEST,,}" == "q" ]]; then break; fi
    if [ -z "$REQUEST" ]; then continue; fi

    TONE="professional"
    read -p "  Tone (professional/friendly/firm) [professional]: " TONE_INPUT
    if [ -n "$TONE_INPUT" ]; then TONE="$TONE_INPUT"; fi

    echo
    echo "   Finding templates and business context..."
    echo

    # Find matching template and business context, then draft
    python3 -c "
import json,urllib.request
request=r'''$REQUEST'''
tone='$TONE'
emb_data=json.dumps({'model':'llama3.2:1b','prompt':request}).encode()
emb_req=urllib.request.Request('http://localhost:11434/api/embeddings',data=emb_data,headers={'Content-Type':'application/json'})
emb_resp=json.loads(urllib.request.urlopen(emb_req).read())
vec=emb_resp.get('embedding',[])
tq='{Get{DraftTemplate(nearVector:{vector:'+json.dumps(vec)+'},limit:1){title content messageType tone}}}'
t_data=json.dumps({'query':tq}).encode()
t_req=urllib.request.Request('http://localhost:8080/v1/graphql',data=t_data,headers={'Content-Type':'application/json'})
t_resp=json.loads(urllib.request.urlopen(t_req).read())
templates=t_resp.get('data',{}).get('Get',{}).get('DraftTemplate',[])
tmpl=templates[0] if templates else {}
bq='{Get{BusinessDoc(nearVector:{vector:'+json.dumps(vec)+'},limit:2){title content category}}}'
b_data=json.dumps({'query':bq}).encode()
b_req=urllib.request.Request('http://localhost:8080/v1/graphql',data=b_data,headers={'Content-Type':'application/json'})
b_resp=json.loads(urllib.request.urlopen(b_req).read())
biz_docs=b_resp.get('data',{}).get('Get',{}).get('BusinessDoc',[])
biz_ctx=chr(10).join([d.get('content','') for d in biz_docs])
tmpl_text=tmpl.get('content','No template found.')
prompt='You are a business message drafter. Write a '+tone+' message based on this request: '+request+chr(10)+chr(10)+'Use this template as a style guide:'+chr(10)+tmpl_text+chr(10)+chr(10)+'Use these business facts (include real numbers):'+chr(10)+biz_ctx+chr(10)+chr(10)+'Write a complete, ready-to-send message. Replace any [PLACEHOLDER] with reasonable defaults. Keep it concise.'
data=json.dumps({'model':'llama3.2:1b','prompt':prompt,'stream':False}).encode()
req=urllib.request.Request('http://localhost:11434/api/generate',data=data,headers={'Content-Type':'application/json'})
resp=json.loads(urllib.request.urlopen(req).read())
print(resp.get('response','No draft generated.'))
print(chr(10)+'   Template used: '+tmpl.get('title','none'))
print('   Business docs: '+', '.join([d.get('title','') for d in biz_docs]))
" 2>/dev/null

    echo
    echo -e "   \e[92m   Edit the draft as needed, then send it.\e[0m"
    echo
done

echo
echo "   Drafting session closed."
rm -rf "$TEMP_DIR"
exit 0
DRAFT_IT_EOF

chmod +x "$OUTPUT_DIR/draft-it.sh"

if [ -f "$OUTPUT_DIR/draft-it.sh" ]; then
    echo -e "  \e[92m   ✓ draft-it.sh created in output folder\e[0m"
else
    echo -e "  \e[91m   ✗ Failed to create draft-it.sh\e[0m"
    read -p "  Press Enter to continue..."
    exit 1
fi

echo
echo "   Press any key to test the drafting tool..."
read -n1 -s -p "  "
echo
echo

# ============================================================
# TASK 3: Test the Draft It tool
# ============================================================
echo "  ------------------------------------------------------"
echo
echo "  [TASK 3/3] Test your Draft It tool"
echo
echo "   Try these drafting requests:"
echo "     - \"reply to a customer asking about our rates\" (friendly)"
echo "     - \"follow up on a quote from last week\" (professional)"
echo "     - \"respond to a complaint about late arrival\" (professional)"
echo "     - \"remind a customer about overdue payment\" (firm)"
echo

while true; do
    echo "  ------------------------------------------------------"
    read -p "  What do you need to write? (Q to quit): " TEST_REQ

    if [[ "${TEST_REQ,,}" == "q" ]]; then break; fi
    if [ -z "$TEST_REQ" ]; then continue; fi

    TEST_TONE="professional"
    read -p "  Tone (professional/friendly/firm) [professional]: " TONE_INPUT
    if [ -n "$TONE_INPUT" ]; then TEST_TONE="$TONE_INPUT"; fi

    echo
    echo "   Finding templates and business context..."
    echo

    python3 -c "
import json,urllib.request
request=r'''$TEST_REQ'''
tone='$TEST_TONE'
emb_data=json.dumps({'model':'llama3.2:1b','prompt':request}).encode()
emb_req=urllib.request.Request('http://localhost:11434/api/embeddings',data=emb_data,headers={'Content-Type':'application/json'})
emb_resp=json.loads(urllib.request.urlopen(emb_req).read())
vec=emb_resp.get('embedding',[])
tq='{Get{DraftTemplate(nearVector:{vector:'+json.dumps(vec)+'},limit:1){title content tone}}}'
t_data=json.dumps({'query':tq}).encode()
t_req=urllib.request.Request('http://localhost:8080/v1/graphql',data=t_data,headers={'Content-Type':'application/json'})
t_resp=json.loads(urllib.request.urlopen(t_req).read())
templates=t_resp.get('data',{}).get('Get',{}).get('DraftTemplate',[])
tmpl=templates[0] if templates else {}
bq='{Get{BusinessDoc(nearVector:{vector:'+json.dumps(vec)+'},limit:2){title content category}}}'
b_data=json.dumps({'query':bq}).encode()
b_req=urllib.request.Request('http://localhost:8080/v1/graphql',data=b_data,headers={'Content-Type':'application/json'})
b_resp=json.loads(urllib.request.urlopen(b_req).read())
biz_docs=b_resp.get('data',{}).get('Get',{}).get('BusinessDoc',[])
biz_ctx=chr(10).join([d.get('content','') for d in biz_docs])
tmpl_text=tmpl.get('content','No template found.')
prompt='You are a business message drafter. Write a '+tone+' message based on this request: '+request+chr(10)+chr(10)+'Style guide:'+chr(10)+tmpl_text+chr(10)+chr(10)+'Business facts:'+chr(10)+biz_ctx+chr(10)+chr(10)+'Write a complete, ready-to-send message. Replace placeholders with reasonable defaults. Keep it concise.'
data=json.dumps({'model':'llama3.2:1b','prompt':prompt,'stream':False}).encode()
req=urllib.request.Request('http://localhost:11434/api/generate',data=data,headers={'Content-Type':'application/json'})
resp=json.loads(urllib.request.urlopen(req).read())
print(resp.get('response','No draft.'))
print()
print('   Template: '+tmpl.get('title','none')+' ['+tmpl.get('tone','')+']')
print('   Biz docs: '+', '.join([d.get('title','') for d in biz_docs]))
" 2>/dev/null

    echo
done

# ============================================================
echo
echo "  ======================================================"
echo "   EXERCISE COMPLETE"
echo "  ======================================================"
echo
echo "   Your Draft It tool is built and tested. It lives at:"
echo "     $OUTPUT_DIR/draft-it.sh"
echo
echo "   To make it better: save your best real messages as"
echo "   templates in the DraftTemplate collection."
echo
echo "   Now run verify.sh to confirm everything passed."
echo

rm -rf "$TEMP_DIR"

read -p "  Press Enter to continue..."
exit 0
