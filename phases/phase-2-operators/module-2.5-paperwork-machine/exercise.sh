#!/usr/bin/env bash
# Error handling is done per-command

# ============================================================
# MODULE 2.5 EXERCISE: Paperwork Machine
# Goal: Create DocTemplate schema, seed templates, build
#       document generator that outputs to files
# Time: ~20 minutes
# RAM impact: ~300MB beyond Ollama + Weaviate baseline
# Prerequisites: Module 2.1 (BusinessDoc), Module 2.3
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/output"
DOC_DIR="$SCRIPT_DIR/output/documents"
TEMP_DIR="/tmp/module-2.5"

echo
echo "  ======================================================"
echo "   MODULE 2.5 EXERCISE: Paperwork Machine"
echo "  ======================================================"
echo
echo "   Build a document generator with templates and real"
echo "   business data. Three tasks."
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
echo -e "  \e[92m   ✓ BusinessDoc exists\e[0m"
echo

mkdir -p "$TEMP_DIR"
mkdir -p "$OUTPUT_DIR"
mkdir -p "$DOC_DIR"

# ============================================================
# TASK 1: Create DocTemplate schema and seed templates
# ============================================================
echo "  ------------------------------------------------------"
echo
echo "  [TASK 1/3] Create DocTemplate schema and seed templates"
echo

# Create schema
curl -s http://localhost:8080/v1/schema 2>/dev/null | grep -qi "DocTemplate"
if [ $? -ne 0 ]; then
    echo "   Creating \"DocTemplate\" class..."
    curl -s -X POST http://localhost:8080/v1/schema -H "Content-Type: application/json" -d '{"class":"DocTemplate","description":"Business document templates","vectorizer":"none","properties":[{"name":"title","dataType":["text"],"description":"Template name"},{"name":"content","dataType":["text"],"description":"Template structure"},{"name":"docType","dataType":["text"],"description":"Document type: estimate, report, checklist, letter"},{"name":"requiredFields","dataType":["text"],"description":"Comma-separated required fields"}]}' >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "  \e[92m   ✓ \"DocTemplate\" class created\e[0m"
    else
        echo -e "  \e[91m   ✗ Failed to create DocTemplate schema\e[0m"
        read -p "  Press Enter to continue..."
        exit 1
    fi
else
    echo -e "  \e[92m   ✓ \"DocTemplate\" class already exists\e[0m"
fi
echo

# Seed templates
echo "   Seeding document templates..."
echo

# Template 1: Standard Estimate
DT1=$(python3 -c "
import json,urllib.request
content='ESTIMATE\nDate: [DATE]\nCustomer: [CUSTOMER_NAME]\nAddress: [ADDRESS]\n\nSERVICE DESCRIPTION:\n[DESCRIPTION]\n\nLINE ITEMS:\n  Labor: [HOURS] hours @ [RATE]/hour = [LABOR_TOTAL]\n  Materials: [MATERIALS] (15% markup) = [MATERIALS_TOTAL]\n  Service call fee: \$85.00\n  -----------------\n  ESTIMATED TOTAL: [TOTAL]\n\nTERMS:\n- Estimate valid for 30 days\n- Payment due upon completion\n- 90-day warranty on labor\n- We accept cash, check, and all major credit cards'
emb_data=json.dumps({'model':'llama3.2:1b','prompt':content}).encode()
req=urllib.request.Request('http://localhost:11434/api/embeddings',data=emb_data,headers={'Content-Type':'application/json'})
resp=json.loads(urllib.request.urlopen(req).read())
vec=resp.get('embedding',[])
payload={'class':'DocTemplate','properties':{'title':'Standard Estimate','content':content,'docType':'estimate','requiredFields':'customer_name, address, description, hours, materials'},'vector':vec}
data=json.dumps(payload).encode()
store_req=urllib.request.Request('http://localhost:8080/v1/objects',data=data,headers={'Content-Type':'application/json'})
urllib.request.urlopen(store_req)
print('OK')
" 2>/dev/null || echo "WARN")
if [ "$DT1" = "OK" ]; then echo -e "  \e[92m   ✓ Template: Standard Estimate\e[0m"; else echo -e "  \e[93m   ⚠ Standard Estimate — may be duplicate\e[0m"; fi

# Template 2: Daily Job Report
DT2=$(python3 -c "
import json,urllib.request
content='DAILY JOB REPORT\nDate: [DATE]\nSite: [ADDRESS]\nJob: [JOB_NAME]\nCrew: [CREW_MEMBERS]\n\nWORK PERFORMED:\n[WORK_DETAILS]\n\nMATERIALS USED:\n[MATERIALS_LIST]\n\nISSUES/NOTES:\n[ISSUES]\n\nNEXT STEPS:\n[NEXT_STEPS]\n\nHours on site: [HOURS]\nReport submitted by: [SUBMITTED_BY]'
emb_data=json.dumps({'model':'llama3.2:1b','prompt':content}).encode()
req=urllib.request.Request('http://localhost:11434/api/embeddings',data=emb_data,headers={'Content-Type':'application/json'})
resp=json.loads(urllib.request.urlopen(req).read())
vec=resp.get('embedding',[])
payload={'class':'DocTemplate','properties':{'title':'Daily Job Report','content':content,'docType':'report','requiredFields':'date, address, job_name, work_details, hours'},'vector':vec}
data=json.dumps(payload).encode()
store_req=urllib.request.Request('http://localhost:8080/v1/objects',data=data,headers={'Content-Type':'application/json'})
urllib.request.urlopen(store_req)
print('OK')
" 2>/dev/null || echo "WARN")
if [ "$DT2" = "OK" ]; then echo -e "  \e[92m   ✓ Template: Daily Job Report\e[0m"; else echo -e "  \e[93m   ⚠ Daily Job Report — may be duplicate\e[0m"; fi

# Template 3: Job Checklist
DT3=$(python3 -c "
import json,urllib.request
content='JOB CHECKLIST\nJob: [JOB_NAME]\nDate: [DATE]\nTechnician: [TECH_NAME]\n\nPRE-ARRIVAL:\n[ ] Review job details and customer notes\n[ ] Load required tools and materials\n[ ] Confirm appointment with customer\n[ ] Check route and estimated travel time\n\nON-SITE:\n[ ] Introduce yourself and confirm scope of work\n[ ] Protect work area (drop cloths, shoe covers)\n[ ] Complete the work per specifications\n[ ] Test and verify the repair or installation\n\nCOMPLETION:\n[ ] Clean up work area thoroughly\n[ ] Walk customer through completed work\n[ ] Collect payment or confirm billing\n[ ] Provide receipt and warranty information\n\nFOLLOW-UP:\n[ ] Submit job report\n[ ] Schedule 48-hour follow-up call\n[ ] Update customer file with job details'
emb_data=json.dumps({'model':'llama3.2:1b','prompt':content}).encode()
req=urllib.request.Request('http://localhost:11434/api/embeddings',data=emb_data,headers={'Content-Type':'application/json'})
resp=json.loads(urllib.request.urlopen(req).read())
vec=resp.get('embedding',[])
payload={'class':'DocTemplate','properties':{'title':'Job Checklist','content':content,'docType':'checklist','requiredFields':'job_name, date, tech_name'},'vector':vec}
data=json.dumps(payload).encode()
store_req=urllib.request.Request('http://localhost:8080/v1/objects',data=data,headers={'Content-Type':'application/json'})
urllib.request.urlopen(store_req)
print('OK')
" 2>/dev/null || echo "WARN")
if [ "$DT3" = "OK" ]; then echo -e "  \e[92m   ✓ Template: Job Checklist\e[0m"; else echo -e "  \e[93m   ⚠ Job Checklist — may be duplicate\e[0m"; fi

# Template 4: Customer Letter
DT4=$(python3 -c "
import json,urllib.request
content='[COMPANY_NAME]\n[DATE]\n\nDear [CUSTOMER_NAME],\n\n[BODY]\n\nIf you have any questions, please do not hesitate to contact us.\n\nSincerely,\n[SENDER_NAME]\n[COMPANY_NAME]\n[PHONE]'
emb_data=json.dumps({'model':'llama3.2:1b','prompt':content}).encode()
req=urllib.request.Request('http://localhost:11434/api/embeddings',data=emb_data,headers={'Content-Type':'application/json'})
resp=json.loads(urllib.request.urlopen(req).read())
vec=resp.get('embedding',[])
payload={'class':'DocTemplate','properties':{'title':'Customer Letter','content':content,'docType':'letter','requiredFields':'customer_name, body, sender_name'},'vector':vec}
data=json.dumps(payload).encode()
store_req=urllib.request.Request('http://localhost:8080/v1/objects',data=data,headers={'Content-Type':'application/json'})
urllib.request.urlopen(store_req)
print('OK')
" 2>/dev/null || echo "WARN")
if [ "$DT4" = "OK" ]; then echo -e "  \e[92m   ✓ Template: Customer Letter\e[0m"; else echo -e "  \e[93m   ⚠ Customer Letter — may be duplicate\e[0m"; fi

echo
echo "   Press any key to build the document generator..."
read -n1 -s -p "  "
echo
echo

# ============================================================
# TASK 2: Generate the Paperwork Machine tool
# ============================================================
echo "  ------------------------------------------------------"
echo
echo "  [TASK 2/3] Generate the Paperwork Machine tool"
echo

cat > "$OUTPUT_DIR/paperwork-machine.sh" << 'PAPERWORK_EOF'
#!/usr/bin/env bash
# Error handling is done per-command

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOC_DIR="$SCRIPT_DIR/documents"
TEMP_DIR="/tmp/paperwork-machine"
mkdir -p "$DOC_DIR"
mkdir -p "$TEMP_DIR"

echo
echo "  ======================================================"
echo "   PAPERWORK MACHINE — Document Generator"
echo "   Describe what you need. Get a formatted document."
echo "  ======================================================"
echo
echo "   Document types: estimate, report, checklist, letter"
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
echo -e "  \e[92m   Systems online. Ready to generate documents.\e[0m"
echo

while true; do
    echo "  ------------------------------------------------------"
    read -p "  Describe the document you need (Q to quit): " REQUEST
    if [[ "${REQUEST,,}" == "q" ]]; then break; fi
    if [ -z "$REQUEST" ]; then continue; fi
    echo
    echo "   Finding template and business data..."
    echo "   Generating document..."

    python3 -c "
import json,urllib.request,datetime
request=r'''$REQUEST'''
emb_data=json.dumps({'model':'llama3.2:1b','prompt':request}).encode()
emb_req=urllib.request.Request('http://localhost:11434/api/embeddings',data=emb_data,headers={'Content-Type':'application/json'})
emb_resp=json.loads(urllib.request.urlopen(emb_req).read())
vec=emb_resp.get('embedding',[])
tq='{Get{DocTemplate(nearVector:{vector:'+json.dumps(vec)+'},limit:1){title content docType requiredFields}}}'
t_data=json.dumps({'query':tq}).encode()
t_req=urllib.request.Request('http://localhost:8080/v1/graphql',data=t_data,headers={'Content-Type':'application/json'})
t_resp=json.loads(urllib.request.urlopen(t_req).read())
tmpl=t_resp.get('data',{}).get('Get',{}).get('DocTemplate',[{}])[0]
bq='{Get{BusinessDoc(nearVector:{vector:'+json.dumps(vec)+'},limit:2){title content category}}}'
b_data=json.dumps({'query':bq}).encode()
b_req=urllib.request.Request('http://localhost:8080/v1/graphql',data=b_data,headers={'Content-Type':'application/json'})
b_resp=json.loads(urllib.request.urlopen(b_req).read())
biz_docs=b_resp.get('data',{}).get('Get',{}).get('BusinessDoc',[])
biz_ctx=chr(10).join([d.get('content','') for d in biz_docs])
prompt='Generate a business document based on this request: '+request+chr(10)+chr(10)+'Use this template structure:'+chr(10)+tmpl.get('content','')+chr(10)+chr(10)+'Use these real business details (rates, terms, policies):'+chr(10)+biz_ctx+chr(10)+chr(10)+'Fill in all placeholders with realistic values based on the request. Output the complete document ready to use.'
data=json.dumps({'model':'llama3.2:1b','prompt':prompt,'stream':False}).encode()
req=urllib.request.Request('http://localhost:11434/api/generate',data=data,headers={'Content-Type':'application/json'})
resp=json.loads(urllib.request.urlopen(req).read())
doc=resp.get('response','No document generated.')
print(doc)
ts=datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
fname=tmpl.get('docType','doc')+'-'+ts+'.txt'
fpath='$DOC_DIR/'+fname
open(fpath,'w').write(doc)
print(chr(10)+'   Template: '+tmpl.get('title','')+' ['+tmpl.get('docType','')+']')
print('   Saved to: '+fname)
" 2>/dev/null

    echo
done

echo
echo "   Documents saved in: $DOC_DIR"
rm -rf "$TEMP_DIR"
exit 0
PAPERWORK_EOF

chmod +x "$OUTPUT_DIR/paperwork-machine.sh"

if [ -f "$OUTPUT_DIR/paperwork-machine.sh" ]; then
    echo -e "  \e[92m   ✓ paperwork-machine.sh created in output folder\e[0m"
else
    echo -e "  \e[91m   ✗ Failed to create paperwork-machine.sh\e[0m"
    read -p "  Press Enter to continue..."
    exit 1
fi

echo
echo "   Press any key to test the document generator..."
read -n1 -s -p "  "
echo
echo

# ============================================================
# TASK 3: Test the Paperwork Machine
# ============================================================
echo "  ------------------------------------------------------"
echo
echo "  [TASK 3/3] Test the Paperwork Machine"
echo
echo "   Try generating these documents:"
echo "     - \"estimate for fixing a leaky roof at 789 Pine St for Sarah Johnson\""
echo "     - \"daily report for the Smith renovation project\""
echo "     - \"checklist for a new installation job\""
echo "     - \"letter to customer about warranty extension\""
echo

while true; do
    echo "  ------------------------------------------------------"
    read -p "  Describe the document (Q to quit): " TEST_REQ

    if [[ "${TEST_REQ,,}" == "q" ]]; then break; fi
    if [ -z "$TEST_REQ" ]; then continue; fi

    echo
    echo "   Finding template and generating..."
    echo

    python3 -c "
import json,urllib.request,datetime
request=r'''$TEST_REQ'''
emb_data=json.dumps({'model':'llama3.2:1b','prompt':request}).encode()
emb_req=urllib.request.Request('http://localhost:11434/api/embeddings',data=emb_data,headers={'Content-Type':'application/json'})
emb_resp=json.loads(urllib.request.urlopen(emb_req).read())
vec=emb_resp.get('embedding',[])
tq='{Get{DocTemplate(nearVector:{vector:'+json.dumps(vec)+'},limit:1){title content docType}}}'
t_data=json.dumps({'query':tq}).encode()
t_req=urllib.request.Request('http://localhost:8080/v1/graphql',data=t_data,headers={'Content-Type':'application/json'})
t_resp=json.loads(urllib.request.urlopen(t_req).read())
tmpl=t_resp.get('data',{}).get('Get',{}).get('DocTemplate',[{}])[0]
bq='{Get{BusinessDoc(nearVector:{vector:'+json.dumps(vec)+'},limit:2){content}}}'
b_data=json.dumps({'query':bq}).encode()
b_req=urllib.request.Request('http://localhost:8080/v1/graphql',data=b_data,headers={'Content-Type':'application/json'})
b_resp=json.loads(urllib.request.urlopen(b_req).read())
biz=b_resp.get('data',{}).get('Get',{}).get('BusinessDoc',[])
biz_ctx=chr(10).join([d.get('content','') for d in biz])
prompt='Generate a business document for: '+request+chr(10)+'Template:'+chr(10)+tmpl.get('content','')+chr(10)+'Business data:'+chr(10)+biz_ctx+chr(10)+'Fill in all placeholders. Output the complete document.'
data=json.dumps({'model':'llama3.2:1b','prompt':prompt,'stream':False}).encode()
req=urllib.request.Request('http://localhost:11434/api/generate',data=data,headers={'Content-Type':'application/json'})
resp=json.loads(urllib.request.urlopen(req).read())
doc=resp.get('response','')
print(doc)
ts=datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
fname=tmpl.get('docType','doc')+'-'+ts+'.txt'
fpath='$DOC_DIR/'+fname
open(fpath,'w').write(doc)
print()
print('   Template: '+tmpl.get('title',''))
print('   Saved to: '+fname)
" 2>/dev/null

    echo
done

# ============================================================
echo
echo "  ======================================================"
echo "   EXERCISE COMPLETE"
echo "  ======================================================"
echo
echo "   Your Paperwork Machine is built. It lives at:"
echo "     $OUTPUT_DIR/paperwork-machine.sh"
echo
echo "   Generated documents are saved in:"
echo "     $DOC_DIR"
echo
echo "   Now run verify.sh to confirm everything passed."
echo

rm -rf "$TEMP_DIR"

read -p "  Press Enter to continue..."
exit 0
