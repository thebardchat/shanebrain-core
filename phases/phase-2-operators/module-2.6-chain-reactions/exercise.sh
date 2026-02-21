#!/usr/bin/env bash
# Error handling is done per-command

# ============================================================
# MODULE 2.6 EXERCISE: Chain Reactions
# Goal: Create WorkflowLog schema, build multi-step chains
#       that combine all previous tools, log everything
# Time: ~20 minutes
# RAM impact: ~400MB beyond Ollama + Weaviate baseline
# Prerequisites: Modules 2.1-2.5 (all previous Phase 2)
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/output"
TEMP_DIR="/tmp/module-2.6"

echo
echo "  ======================================================"
echo "   MODULE 2.6 EXERCISE: Chain Reactions"
echo "  ======================================================"
echo
echo "   Chain all your tools into multi-step workflows."
echo "   Three tasks."
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

# Check all prerequisite classes
PREREQ_OK=1
for c in BusinessDoc DraftTemplate MessageLog DocTemplate; do
    curl -s http://localhost:8080/v1/schema 2>/dev/null | grep -qi "$c"
    if [ $? -ne 0 ]; then
        echo -e "  \e[91m   ✗ $c class not found. Complete earlier modules first.\e[0m"
        PREREQ_OK=0
    else
        echo -e "  \e[92m   ✓ $c exists\e[0m"
    fi
done
if [ "$PREREQ_OK" = "0" ]; then
    echo
    echo -e "  \e[91m   Complete Modules 2.1-2.5 before starting this module.\e[0m"
    read -p "  Press Enter to continue..."
    exit 1
fi
echo

mkdir -p "$TEMP_DIR"
mkdir -p "$OUTPUT_DIR"

# ============================================================
# TASK 1: Create WorkflowLog schema
# ============================================================
echo "  ------------------------------------------------------"
echo
echo "  [TASK 1/3] Create WorkflowLog schema"
echo

curl -s http://localhost:8080/v1/schema 2>/dev/null | grep -qi "WorkflowLog"
if [ $? -ne 0 ]; then
    echo "   Creating \"WorkflowLog\" class..."
    curl -s -X POST http://localhost:8080/v1/schema -H "Content-Type: application/json" -d '{"class":"WorkflowLog","description":"Multi-step workflow execution logs","vectorizer":"none","properties":[{"name":"workflowName","dataType":["text"],"description":"Name of the workflow that ran"},{"name":"input","dataType":["text"],"description":"Original trigger input"},{"name":"steps","dataType":["text"],"description":"JSON array of step names and results"},{"name":"finalOutput","dataType":["text"],"description":"Final output of the chain"},{"name":"timestamp","dataType":["text"],"description":"Execution timestamp"}]}' >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "  \e[92m   ✓ \"WorkflowLog\" class created\e[0m"
    else
        echo -e "  \e[91m   ✗ Failed to create WorkflowLog schema\e[0m"
        read -p "  Press Enter to continue..."
        exit 1
    fi
else
    echo -e "  \e[92m   ✓ \"WorkflowLog\" class already exists\e[0m"
fi
echo
echo "   Press any key to run demo workflows..."
read -n1 -s -p "  "
echo
echo

# ============================================================
# TASK 2: Run demo workflow chains
# ============================================================
echo "  ------------------------------------------------------"
echo
echo "  [TASK 2/3] Run demo workflow chains"
echo
echo "   Running the Complaint Response chain with a sample"
echo "   message. Watch each step execute in sequence."
echo

DEMO_MSG="I am really frustrated. Your team came out last week to fix my furnace and it broke again two days later. I paid good money and the problem is not fixed. I want this resolved or my money back."

echo "   INPUT: $DEMO_MSG"
echo
echo "   -- Step 1/4: Classify --------------------------"
echo

python3 -c "
import json,urllib.request,datetime
msg=r'''$DEMO_MSG'''
prompt='Classify this business message. Respond with EXACTLY three lines:\nCATEGORY: (quote_request, complaint, scheduling, payment, or general)\nPRIORITY: (HIGH, MEDIUM, or LOW)\nACTION: (one specific next step)\n\nMessage: '+msg
data=json.dumps({'model':'llama3.2:1b','prompt':prompt,'stream':False}).encode()
req=urllib.request.Request('http://localhost:11434/api/generate',data=data,headers={'Content-Type':'application/json'})
resp=json.loads(urllib.request.urlopen(req).read())
answer=resp.get('response','')
lines=answer.strip().split(chr(10))
parts={l.split(':',1)[0].strip().upper():l.split(':',1)[1].strip() for l in lines if ':' in l}
cat=parts.get('CATEGORY','complaint')
pri=parts.get('PRIORITY','HIGH')
act=parts.get('ACTION','Respond immediately')
result={'category':cat,'priority':pri,'action':act}
json.dump(result,open('$TEMP_DIR/step1.json','w'))
print('   Category: '+cat)
print('   Priority: '+pri)
print('   Action: '+act)
" 2>/dev/null

echo
echo "   -- Step 2/4: Find relevant policy ---------------"
echo

python3 -c "
import json,urllib.request
q='warranty policy complaint resolution'
emb_data=json.dumps({'model':'llama3.2:1b','prompt':q}).encode()
emb_req=urllib.request.Request('http://localhost:11434/api/embeddings',data=emb_data,headers={'Content-Type':'application/json'})
emb_resp=json.loads(urllib.request.urlopen(emb_req).read())
vec=emb_resp.get('embedding',[])
query='{Get{BusinessDoc(nearVector:{vector:'+json.dumps(vec)+'},limit:2){title content category}}}'
gql_data=json.dumps({'query':query}).encode()
gql_req=urllib.request.Request('http://localhost:8080/v1/graphql',data=gql_data,headers={'Content-Type':'application/json'})
gql_resp=json.loads(urllib.request.urlopen(gql_req).read())
docs=gql_resp.get('data',{}).get('Get',{}).get('BusinessDoc',[])
ctx=chr(10).join([d.get('content','') for d in docs])
sources=[d.get('title','')+'['+d.get('category','')+']' for d in docs]
json.dump({'context':ctx,'sources':sources},open('$TEMP_DIR/step2.json','w'))
print('   Found: '+', '.join(sources))
print('   Policy context loaded.')
" 2>/dev/null

echo
echo "   -- Step 3/4: Draft response ---------------------"
echo

python3 -c "
import json,urllib.request
step1=json.load(open('$TEMP_DIR/step1.json'))
step2=json.load(open('$TEMP_DIR/step2.json'))
msg=r'''$DEMO_MSG'''
tq_emb=json.dumps({'model':'llama3.2:1b','prompt':'complaint response professional'}).encode()
tq_req=urllib.request.Request('http://localhost:11434/api/embeddings',data=tq_emb,headers={'Content-Type':'application/json'})
tq_resp=json.loads(urllib.request.urlopen(tq_req).read())
vec=tq_resp.get('embedding',[])
tq='{Get{DraftTemplate(nearVector:{vector:'+json.dumps(vec)+'},limit:1){title content tone}}}'
t_data=json.dumps({'query':tq}).encode()
t_req=urllib.request.Request('http://localhost:8080/v1/graphql',data=t_data,headers={'Content-Type':'application/json'})
t_resp=json.loads(urllib.request.urlopen(t_req).read())
tmpl=t_resp.get('data',{}).get('Get',{}).get('DraftTemplate',[{}])[0]
prompt='Write a professional response to this customer complaint. Use the template style and business policy below.'+chr(10)+chr(10)+'COMPLAINT: '+msg+chr(10)+'CLASSIFICATION: '+step1.get('category','')+' / '+step1.get('priority','')+chr(10)+'TEMPLATE STYLE: '+tmpl.get('content','')+chr(10)+'BUSINESS POLICY: '+step2.get('context','')+chr(10)+chr(10)+'Write a concise, empathetic, professional response that references relevant policies.'
data=json.dumps({'model':'llama3.2:1b','prompt':prompt,'stream':False}).encode()
req=urllib.request.Request('http://localhost:11434/api/generate',data=data,headers={'Content-Type':'application/json'})
resp=json.loads(urllib.request.urlopen(req).read())
draft=resp.get('response','No draft generated.')
print(draft)
open('$TEMP_DIR/step3.txt','w').write(draft)
print()
print('   Template used: '+tmpl.get('title','none'))
" 2>/dev/null

echo
echo "   -- Step 4/4: Log workflow -----------------------"
echo

python3 -c "
import json,urllib.request,datetime
step1=json.load(open('$TEMP_DIR/step1.json'))
step2=json.load(open('$TEMP_DIR/step2.json'))
draft=open('$TEMP_DIR/step3.txt').read()
msg=r'''$DEMO_MSG'''
ts=datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
steps_log=json.dumps([{'step':'classify','result':step1},{'step':'find_policy','result':{'sources':step2.get('sources',[])}},{'step':'draft_response','result':'Generated professional response'}])
emb_data=json.dumps({'model':'llama3.2:1b','prompt':msg}).encode()
emb_req=urllib.request.Request('http://localhost:11434/api/embeddings',data=emb_data,headers={'Content-Type':'application/json'})
emb_resp=json.loads(urllib.request.urlopen(emb_req).read())
vec=emb_resp.get('embedding',[])
payload={'class':'WorkflowLog','properties':{'workflowName':'complaint-response','input':msg,'steps':steps_log,'finalOutput':draft[:500],'timestamp':ts},'vector':vec}
data=json.dumps(payload).encode()
store_req=urllib.request.Request('http://localhost:8080/v1/objects',data=data,headers={'Content-Type':'application/json'})
urllib.request.urlopen(store_req)
print('   Workflow logged: complaint-response @ '+ts)
print('   Steps recorded: classify -> find_policy -> draft_response')
" 2>/dev/null

echo
echo -e "  \e[92m   ✓ Complaint Response chain complete and logged\e[0m"
echo
echo "   Press any key to build the interactive chain tool..."
read -n1 -s -p "  "
echo
echo

# ============================================================
# TASK 3: Generate Chain Reactions tool and test
# ============================================================
echo "  ------------------------------------------------------"
echo
echo "  [TASK 3/3] Build and test Chain Reactions tool"
echo

cat > "$OUTPUT_DIR/chain-reactions.sh" << 'CHAIN_EOF'
#!/usr/bin/env bash
# Error handling is done per-command

TEMP_DIR="/tmp/chain-reactions"
mkdir -p "$TEMP_DIR"

echo
echo "  ======================================================"
echo "   CHAIN REACTIONS — Workflow Automation"
echo "   Paste a message. The chain handles the rest."
echo "  ======================================================"
echo
echo "   Workflows:"
echo "     1. Complaint Response (classify > policy > draft)"
echo "     2. New Lead (classify > pricing > welcome + quote)"
echo "     3. Job Complete (report > follow-up message)"
echo

# Health checks
curl -s http://localhost:11434/api/tags >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo -e "  \e[91m   Ollama not running.\e[0m"
    read -p "  Press Enter to continue..."
    exit 1
fi
curl -s http://localhost:8080/v1/.well-known/ready >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo -e "  \e[91m   Weaviate not running.\e[0m"
    read -p "  Press Enter to continue..."
    exit 1
fi
echo -e "  \e[92m   Systems online.\e[0m"
echo

while true; do
    echo "  ------------------------------------------------------"
    read -p "  Select workflow (1/2/3) or Q to quit: " WF
    if [[ "${WF,,}" == "q" ]]; then break; fi
    if [ -z "$WF" ]; then continue; fi

    read -p "  Paste the message or describe the situation: " INPUT
    if [ -z "$INPUT" ]; then continue; fi
    echo

    # Run the selected workflow chain
    python3 -c "
import json,urllib.request,datetime
wf='$WF'
inp=r'''$INPUT'''
ts=datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
emb_data=json.dumps({'model':'llama3.2:1b','prompt':inp}).encode()
emb_req=urllib.request.Request('http://localhost:11434/api/embeddings',data=emb_data,headers={'Content-Type':'application/json'})
emb_resp=json.loads(urllib.request.urlopen(emb_req).read())
vec=emb_resp.get('embedding',[])
bq='{Get{BusinessDoc(nearVector:{vector:'+json.dumps(vec)+'},limit:2){title content category}}}'
b_data=json.dumps({'query':bq}).encode()
b_req=urllib.request.Request('http://localhost:8080/v1/graphql',data=b_data,headers={'Content-Type':'application/json'})
b_resp=json.loads(urllib.request.urlopen(b_req).read())
biz=b_resp.get('data',{}).get('Get',{}).get('BusinessDoc',[])
biz_ctx=chr(10).join([d.get('content','') for d in biz])
wf_names={'1':'complaint-response','2':'new-lead','3':'job-complete'}
wf_name=wf_names.get(wf,'custom')
prompts={
    '1':'A customer sent this complaint: '+inp+chr(10)+chr(10)+'Step 1: Classify it (category and priority).'+chr(10)+'Step 2: Find the relevant policy from: '+biz_ctx+chr(10)+'Step 3: Write a professional response addressing their concern and citing relevant policy.'+chr(10)+chr(10)+'Output each step clearly labeled.',
    '2':'A potential customer sent this: '+inp+chr(10)+chr(10)+'Step 1: Classify as a lead.'+chr(10)+'Step 2: Reference this pricing info: '+biz_ctx+chr(10)+'Step 3: Write a friendly welcome message with pricing details.'+chr(10)+'Step 4: Generate a brief estimate.'+chr(10)+chr(10)+'Output each step clearly labeled.',
    '3':'This job was just completed: '+inp+chr(10)+chr(10)+'Step 1: Generate a brief job completion report.'+chr(10)+'Step 2: Draft a customer follow-up message referencing: '+biz_ctx+chr(10)+chr(10)+'Output each step clearly labeled.'
}
prompt=prompts.get(wf,prompts['1'])
data=json.dumps({'model':'llama3.2:1b','prompt':prompt,'stream':False}).encode()
req=urllib.request.Request('http://localhost:11434/api/generate',data=data,headers={'Content-Type':'application/json'})
resp=json.loads(urllib.request.urlopen(req).read())
output=resp.get('response','No output.')
print(output)
payload={'class':'WorkflowLog','properties':{'workflowName':wf_name,'input':inp,'steps':'chain executed','finalOutput':output[:500],'timestamp':ts},'vector':vec}
store_data=json.dumps(payload).encode()
store_req=urllib.request.Request('http://localhost:8080/v1/objects',data=store_data,headers={'Content-Type':'application/json'})
urllib.request.urlopen(store_req)
print(chr(10)+'   Workflow: '+wf_name+' -- logged at '+ts)
" 2>/dev/null

    echo
done

echo
echo "   All workflows logged. Check WorkflowLog for history."
rm -rf "$TEMP_DIR"
exit 0
CHAIN_EOF

chmod +x "$OUTPUT_DIR/chain-reactions.sh"

if [ -f "$OUTPUT_DIR/chain-reactions.sh" ]; then
    echo -e "  \e[92m   ✓ chain-reactions.sh created in output folder\e[0m"
else
    echo -e "  \e[91m   ✗ Failed to create chain-reactions.sh\e[0m"
    read -p "  Press Enter to continue..."
    exit 1
fi

echo
echo "   Test with your own scenarios. Examples:"
echo "     Workflow 1: \"The product I bought last week stopped working\""
echo "     Workflow 2: \"I need someone to look at my roof, possible leak\""
echo "     Workflow 3: \"Replaced HVAC unit at 456 Oak St, 6 hour job\""
echo

while true; do
    echo "  ------------------------------------------------------"
    read -p "  Workflow (1=complaint, 2=lead, 3=job done, Q=quit): " TEST_WF

    if [[ "${TEST_WF,,}" == "q" ]]; then break; fi
    if [ -z "$TEST_WF" ]; then continue; fi

    read -p "  Message or description: " TEST_INPUT
    if [ -z "$TEST_INPUT" ]; then continue; fi

    echo
    echo "   Running chain..."
    echo

    python3 -c "
import json,urllib.request,datetime
wf='$TEST_WF'
inp=r'''$TEST_INPUT'''
ts=datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
emb_data=json.dumps({'model':'llama3.2:1b','prompt':inp}).encode()
emb_req=urllib.request.Request('http://localhost:11434/api/embeddings',data=emb_data,headers={'Content-Type':'application/json'})
emb_resp=json.loads(urllib.request.urlopen(emb_req).read())
vec=emb_resp.get('embedding',[])
bq='{Get{BusinessDoc(nearVector:{vector:'+json.dumps(vec)+'},limit:2){content}}}'
b_data=json.dumps({'query':bq}).encode()
b_req=urllib.request.Request('http://localhost:8080/v1/graphql',data=b_data,headers={'Content-Type':'application/json'})
b_resp=json.loads(urllib.request.urlopen(b_req).read())
biz=b_resp.get('data',{}).get('Get',{}).get('BusinessDoc',[])
biz_ctx=chr(10).join([d.get('content','') for d in biz])
wf_names={'1':'complaint-response','2':'new-lead','3':'job-complete'}
prompts={
    '1':'Complaint: '+inp+chr(10)+'1. Classify (category+priority). 2. Find policy from: '+biz_ctx+chr(10)+'3. Draft professional response. Label each step.',
    '2':'Lead message: '+inp+chr(10)+'1. Classify. 2. Pricing from: '+biz_ctx+chr(10)+'3. Welcome message. 4. Brief estimate. Label each step.',
    '3':'Completed job: '+inp+chr(10)+'1. Job report. 2. Follow-up message using: '+biz_ctx+chr(10)+'Label each step.'
}
prompt=prompts.get(wf,prompts['1'])
data=json.dumps({'model':'llama3.2:1b','prompt':prompt,'stream':False}).encode()
req=urllib.request.Request('http://localhost:11434/api/generate',data=data,headers={'Content-Type':'application/json'})
resp=json.loads(urllib.request.urlopen(req).read())
output=resp.get('response','')
print(output)
payload={'class':'WorkflowLog','properties':{'workflowName':wf_names.get(wf,'custom'),'input':inp,'steps':'chain executed','finalOutput':output[:500],'timestamp':ts},'vector':vec}
sd=json.dumps(payload).encode()
sr=urllib.request.Request('http://localhost:8080/v1/objects',data=sd,headers={'Content-Type':'application/json'})
urllib.request.urlopen(sr)
print(chr(10)+'   Logged: '+wf_names.get(wf,'custom'))
" 2>/dev/null

    echo
done

# ============================================================
echo
echo "  ======================================================"
echo "   EXERCISE COMPLETE"
echo "  ======================================================"
echo
echo "   Chain Reactions is built. It lives at:"
echo "     $OUTPUT_DIR/chain-reactions.sh"
echo
echo "   Every workflow execution is logged in WorkflowLog."
echo "   Now run verify.sh to confirm everything passed."
echo

rm -rf "$TEMP_DIR"

read -p "  Press Enter to continue..."
exit 0
