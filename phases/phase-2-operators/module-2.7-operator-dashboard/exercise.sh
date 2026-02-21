#!/usr/bin/env bash
# Error handling is done per-command

# ============================================================
# MODULE 2.7 EXERCISE: Your Operator Dashboard
# Goal: Generate a single-launcher dashboard that provides
#       access to all Phase 2 tools with health and stats
# Time: ~15 minutes
# RAM impact: ~200MB for dashboard itself (tools add their own)
# Prerequisites: Modules 2.1-2.6 (all Phase 2)
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PHASE_DIR="$SCRIPT_DIR/.."
OUTPUT_DIR="$SCRIPT_DIR/output"
TEMP_DIR="/tmp/module-2.7"

echo
echo "  ======================================================"
echo "   MODULE 2.7 EXERCISE: Your Operator Dashboard"
echo "  ======================================================"
echo
echo "   Package all Phase 2 tools into one dashboard."
echo "   Two tasks."
echo
echo "  ------------------------------------------------------"
echo

# --- PRE-FLIGHT ---
echo "  [PRE-FLIGHT] Checking services and all prerequisites..."
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

# Check all classes
ALL_OK=1
for c in BusinessDoc DraftTemplate MessageLog DocTemplate WorkflowLog; do
    curl -s http://localhost:8080/v1/schema 2>/dev/null | grep -qi "$c"
    if [ $? -ne 0 ]; then
        echo -e "  \e[91m   ✗ $c not found. Complete its module first.\e[0m"
        ALL_OK=0
    else
        echo -e "  \e[92m   ✓ $c exists\e[0m"
    fi
done
if [ "$ALL_OK" = "0" ]; then
    echo
    echo -e "  \e[91m   Complete Modules 2.1-2.6 before this capstone.\e[0m"
    read -p "  Press Enter to continue..."
    exit 1
fi
echo

mkdir -p "$TEMP_DIR"
mkdir -p "$OUTPUT_DIR"

# ============================================================
# TASK 1: Generate the Operator Dashboard
# ============================================================
echo "  ------------------------------------------------------"
echo
echo "  [TASK 1/2] Generate the Operator Dashboard"
echo
echo "   Building operator-dashboard.sh — your daily command center."
echo

cat > "$OUTPUT_DIR/operator-dashboard.sh" << 'DASHBOARD_EOF'
#!/usr/bin/env bash
# Error handling is done per-command

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMP_DIR="/tmp/operator-dashboard"
mkdir -p "$TEMP_DIR"

# ========================================================
# DASHBOARD FUNCTION
# ========================================================
show_dashboard() {
    clear
    echo
    echo "    +==================================================+"
    echo "    |                                                  |"
    echo "    |       OPERATOR DASHBOARD                        |"
    echo "    |       Business AI Toolkit                       |"
    echo "    |                                                  |"
    echo "    |       Local AI. Your data. Your tools.          |"
    echo "    |                                                  |"
    echo "    +==================================================+"
    echo

    # ========================================================
    # HEALTH CHECK
    # ========================================================
    echo "   [SYSTEM STATUS]"
    echo

    # RAM check
    FREE_RAM_KB=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    FREE_MB=$((FREE_RAM_KB / 1024))
    if [ "$FREE_MB" -lt 2048 ]; then
        echo -e "  \e[91m   ✗ RAM: ${FREE_MB}MB free -- LOW. Close apps.\e[0m"
    else
        echo -e "  \e[92m   ✓ RAM: ${FREE_MB}MB free\e[0m"
    fi

    # Ollama check
    curl -s http://localhost:11434/api/tags >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo -e "  \e[91m   ✗ Ollama: Not running\e[0m"
        echo "     Start with: ollama serve"
    else
        echo -e "  \e[92m   ✓ Ollama: Running\e[0m"
    fi

    # Weaviate check
    curl -s http://localhost:8080/v1/.well-known/ready >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo -e "  \e[91m   ✗ Weaviate: Not running\e[0m"
        echo "     Start with: docker start weaviate"
    else
        echo -e "  \e[92m   ✓ Weaviate: Running\e[0m"
    fi
    echo

    # ========================================================
    # KNOWLEDGE BASE STATS
    # ========================================================
    echo "   [KNOWLEDGE BASE]"
    echo
    python3 -c "
import json,urllib.request
classes=['BusinessDoc','DraftTemplate','MessageLog','DocTemplate','WorkflowLog']
labels=['Business Docs','Draft Templates','Messages Triaged','Doc Templates','Workflows Logged']
for cls,lbl in zip(classes,labels):
    try:
        req=urllib.request.Request('http://localhost:8080/v1/graphql',data=json.dumps({'query':'{Aggregate{'+cls+'{meta{count}}}}'}).encode(),headers={'Content-Type':'application/json'})
        resp=json.loads(urllib.request.urlopen(req).read())
        count=resp.get('data',{}).get('Aggregate',{}).get(cls,[{}])[0].get('meta',{}).get('count',0)
        print(f'     {lbl}: {count}')
    except: print(f'     {lbl}: unavailable')
" 2>/dev/null
    echo

    # ========================================================
    # TOOL MENU
    # ========================================================
    echo "   [TOOLS]"
    echo "   -------------------------------------"
    echo "     1.  Answer Desk        (Q&A with citations)"
    echo "     2.  Draft It           (Message drafting)"
    echo "     3.  Sort and Route     (Message triage)"
    echo "     4.  Paperwork Machine  (Document generator)"
    echo "     5.  Chain Reactions    (Workflow automation)"
    echo
    echo "   -------------------------------------"
    echo "     H.  Full Health Check"
    echo "     Q.  Quit"
    echo
}

# ========================================================
# TOOL: Answer Desk
# ========================================================
tool_answer() {
    clear
    echo
    echo "  ======================================================"
    echo "   ANSWER DESK — Business Q&A"
    echo "  ======================================================"
    echo
    while true; do
        read -p "  Question (B to go back): " AQ
        if [[ "${AQ,,}" == "b" ]]; then return; fi
        if [ -z "$AQ" ]; then continue; fi
        python3 -c "
import json,urllib.request
q=r'''$AQ'''
emb=json.loads(urllib.request.urlopen(urllib.request.Request('http://localhost:11434/api/embeddings',json.dumps({'model':'llama3.2:1b','prompt':q}).encode(),{'Content-Type':'application/json'})).read()).get('embedding',[])
docs=json.loads(urllib.request.urlopen(urllib.request.Request('http://localhost:8080/v1/graphql',json.dumps({'query':'{Get{BusinessDoc(nearVector:{vector:'+json.dumps(emb)+'},limit:2){title content category}}}'}).encode(),{'Content-Type':'application/json'})).read()).get('data',{}).get('Get',{}).get('BusinessDoc',[])
ctx=chr(10).join(['['+d['title']+'] '+d['content'] for d in docs])
ans=json.loads(urllib.request.urlopen(urllib.request.Request('http://localhost:11434/api/generate',json.dumps({'model':'llama3.2:1b','prompt':'Answer from docs only. Cite sources.'+chr(10)+ctx+chr(10)+'Q: '+q+chr(10)+'A:','stream':False}).encode(),{'Content-Type':'application/json'})).read()).get('response','')
print(ans)
print(chr(10)+'Sources: '+', '.join([d['title']+'['+d['category']+']' for d in docs]))
" 2>/dev/null
        echo
    done
}

# ========================================================
# TOOL: Draft It
# ========================================================
tool_draft() {
    clear
    echo
    echo "  ======================================================"
    echo "   DRAFT IT — Message Drafter"
    echo "  ======================================================"
    echo
    while true; do
        read -p "  What to write? (B to go back): " DR
        if [[ "${DR,,}" == "b" ]]; then return; fi
        if [ -z "$DR" ]; then continue; fi
        DT="professional"
        read -p "  Tone (professional/friendly/firm) [professional]: " DT_INPUT
        if [ -n "$DT_INPUT" ]; then DT="$DT_INPUT"; fi
        python3 -c "
import json,urllib.request
r=r'''$DR'''
t='$DT'
emb=json.loads(urllib.request.urlopen(urllib.request.Request('http://localhost:11434/api/embeddings',json.dumps({'model':'llama3.2:1b','prompt':r}).encode(),{'Content-Type':'application/json'})).read()).get('embedding',[])
tmpl=json.loads(urllib.request.urlopen(urllib.request.Request('http://localhost:8080/v1/graphql',json.dumps({'query':'{Get{DraftTemplate(nearVector:{vector:'+json.dumps(emb)+'},limit:1){title content}}}'}).encode(),{'Content-Type':'application/json'})).read()).get('data',{}).get('Get',{}).get('DraftTemplate',[{}])[0]
biz=json.loads(urllib.request.urlopen(urllib.request.Request('http://localhost:8080/v1/graphql',json.dumps({'query':'{Get{BusinessDoc(nearVector:{vector:'+json.dumps(emb)+'},limit:2){content}}}'}).encode(),{'Content-Type':'application/json'})).read()).get('data',{}).get('Get',{}).get('BusinessDoc',[])
ctx=chr(10).join([d['content'] for d in biz])
ans=json.loads(urllib.request.urlopen(urllib.request.Request('http://localhost:11434/api/generate',json.dumps({'model':'llama3.2:1b','prompt':'Write a '+t+' message for: '+r+chr(10)+'Style: '+tmpl.get('content','')+chr(10)+'Facts: '+ctx,'stream':False}).encode(),{'Content-Type':'application/json'})).read()).get('response','')
print(ans)
" 2>/dev/null
        echo
    done
}

# ========================================================
# TOOL: Sort and Route
# ========================================================
tool_sort() {
    clear
    echo
    echo "  ======================================================"
    echo "   SORT AND ROUTE — Message Triage"
    echo "  ======================================================"
    echo
    while true; do
        read -p "  Message to classify (B to go back): " SM
        if [[ "${SM,,}" == "b" ]]; then return; fi
        if [ -z "$SM" ]; then continue; fi
        python3 -c "
import json,urllib.request,datetime
m=r'''$SM'''
ans=json.loads(urllib.request.urlopen(urllib.request.Request('http://localhost:11434/api/generate',json.dumps({'model':'llama3.2:1b','prompt':'Classify: CATEGORY (quote_request/complaint/scheduling/payment/general), PRIORITY (HIGH/MEDIUM/LOW), ACTION (next step). Three lines only.'+chr(10)+m,'stream':False}).encode(),{'Content-Type':'application/json'})).read()).get('response','')
print(ans)
emb=json.loads(urllib.request.urlopen(urllib.request.Request('http://localhost:11434/api/embeddings',json.dumps({'model':'llama3.2:1b','prompt':m}).encode(),{'Content-Type':'application/json'})).read()).get('embedding',[])
urllib.request.urlopen(urllib.request.Request('http://localhost:8080/v1/objects',json.dumps({'class':'MessageLog','properties':{'content':m,'category':'classified','priority':'see above','suggestedAction':'see above','timestamp':datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')},'vector':emb}).encode(),{'Content-Type':'application/json'}))
" 2>/dev/null
        echo
    done
}

# ========================================================
# TOOL: Paperwork Machine
# ========================================================
tool_paper() {
    clear
    echo
    echo "  ======================================================"
    echo "   PAPERWORK MACHINE — Document Generator"
    echo "  ======================================================"
    echo
    echo "   Types: estimate, report, checklist, letter"
    echo
    while true; do
        read -p "  Describe the document (B to go back): " PD
        if [[ "${PD,,}" == "b" ]]; then return; fi
        if [ -z "$PD" ]; then continue; fi
        python3 -c "
import json,urllib.request,datetime
r=r'''$PD'''
emb=json.loads(urllib.request.urlopen(urllib.request.Request('http://localhost:11434/api/embeddings',json.dumps({'model':'llama3.2:1b','prompt':r}).encode(),{'Content-Type':'application/json'})).read()).get('embedding',[])
tmpl=json.loads(urllib.request.urlopen(urllib.request.Request('http://localhost:8080/v1/graphql',json.dumps({'query':'{Get{DocTemplate(nearVector:{vector:'+json.dumps(emb)+'},limit:1){title content docType}}}'}).encode(),{'Content-Type':'application/json'})).read()).get('data',{}).get('Get',{}).get('DocTemplate',[{}])[0]
biz=json.loads(urllib.request.urlopen(urllib.request.Request('http://localhost:8080/v1/graphql',json.dumps({'query':'{Get{BusinessDoc(nearVector:{vector:'+json.dumps(emb)+'},limit:2){content}}}'}).encode(),{'Content-Type':'application/json'})).read()).get('data',{}).get('Get',{}).get('BusinessDoc',[])
ctx=chr(10).join([d['content'] for d in biz])
doc=json.loads(urllib.request.urlopen(urllib.request.Request('http://localhost:11434/api/generate',json.dumps({'model':'llama3.2:1b','prompt':'Generate document for: '+r+chr(10)+'Template: '+tmpl.get('content','')+chr(10)+'Business data: '+ctx+chr(10)+'Fill all placeholders.','stream':False}).encode(),{'Content-Type':'application/json'})).read()).get('response','')
print(doc)
print(chr(10)+'Template: '+tmpl.get('title',''))
" 2>/dev/null
        echo
    done
}

# ========================================================
# TOOL: Chain Reactions
# ========================================================
tool_chain() {
    clear
    echo
    echo "  ======================================================"
    echo "   CHAIN REACTIONS — Workflow Automation"
    echo "  ======================================================"
    echo
    echo "   1. Complaint Response  2. New Lead  3. Job Complete"
    echo
    while true; do
        read -p "  Workflow (1/2/3, B to go back): " CW
        if [[ "${CW,,}" == "b" ]]; then return; fi
        if [ -z "$CW" ]; then continue; fi
        read -p "  Message or description: " CI
        if [ -z "$CI" ]; then continue; fi
        python3 -c "
import json,urllib.request,datetime
wf='$CW'
inp=r'''$CI'''
emb=json.loads(urllib.request.urlopen(urllib.request.Request('http://localhost:11434/api/embeddings',json.dumps({'model':'llama3.2:1b','prompt':inp}).encode(),{'Content-Type':'application/json'})).read()).get('embedding',[])
biz=json.loads(urllib.request.urlopen(urllib.request.Request('http://localhost:8080/v1/graphql',json.dumps({'query':'{Get{BusinessDoc(nearVector:{vector:'+json.dumps(emb)+'},limit:2){content}}}'}).encode(),{'Content-Type':'application/json'})).read()).get('data',{}).get('Get',{}).get('BusinessDoc',[])
ctx=chr(10).join([d['content'] for d in biz])
ps={'1':'Complaint: '+inp+chr(10)+'1.Classify 2.Find policy from: '+ctx+chr(10)+'3.Draft response. Label steps.','2':'Lead: '+inp+chr(10)+'1.Classify 2.Pricing from: '+ctx+chr(10)+'3.Welcome msg 4.Estimate. Label steps.','3':'Job done: '+inp+chr(10)+'1.Report 2.Follow-up using: '+ctx+chr(10)+'Label steps.'}
out=json.loads(urllib.request.urlopen(urllib.request.Request('http://localhost:11434/api/generate',json.dumps({'model':'llama3.2:1b','prompt':ps.get(wf,ps['1']),'stream':False}).encode(),{'Content-Type':'application/json'})).read()).get('response','')
print(out)
wn={'1':'complaint-response','2':'new-lead','3':'job-complete'}
ts=datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
urllib.request.urlopen(urllib.request.Request('http://localhost:8080/v1/objects',json.dumps({'class':'WorkflowLog','properties':{'workflowName':wn.get(wf,'custom'),'input':inp,'steps':'chain','finalOutput':out[:500],'timestamp':ts},'vector':emb}).encode(),{'Content-Type':'application/json'}))
print(chr(10)+'Logged: '+wn.get(wf,'custom'))
" 2>/dev/null
        echo
    done
}

# ========================================================
# FULL HEALTH CHECK
# ========================================================
full_health() {
    clear
    echo
    echo "  ======================================================"
    echo "   FULL HEALTH CHECK"
    echo "  ======================================================"
    echo

    FREE_RAM_KB=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    FREE_MB=$((FREE_RAM_KB / 1024))
    echo "   RAM Free: ${FREE_MB}MB"

    curl -s http://localhost:11434/api/tags >/dev/null 2>&1 && echo -e "   Ollama: \e[92mRunning\e[0m" || echo -e "   Ollama: \e[91mDown\e[0m"
    curl -s http://localhost:8080/v1/.well-known/ready >/dev/null 2>&1 && echo -e "   Weaviate: \e[92mRunning\e[0m" || echo -e "   Weaviate: \e[91mDown\e[0m"
    curl -s http://localhost:11434/api/tags 2>/dev/null | grep -qi "llama3.2:1b" && echo -e "   Model: \e[92mllama3.2:1b loaded\e[0m" || echo -e "   Model: \e[91mllama3.2:1b not found\e[0m"

    echo
    echo "   Weaviate Classes:"
    for c in BusinessDoc DraftTemplate MessageLog DocTemplate WorkflowLog; do
        curl -s http://localhost:8080/v1/schema 2>/dev/null | grep -qi "$c" && echo -e "     \e[92m✓\e[0m $c" || echo -e "     \e[91m✗\e[0m $c"
    done
    echo
    read -p "  Press Enter to return to dashboard..."
}

# ========================================================
# MAIN LOOP
# ========================================================
while true; do
    show_dashboard
    read -p "  Select tool (1-5) or option: " CHOICE

    case "$CHOICE" in
        1) tool_answer ;;
        2) tool_draft ;;
        3) tool_sort ;;
        4) tool_paper ;;
        5) tool_chain ;;
        [hH]) full_health ;;
        [qQ])
            echo
            echo "   +==================================================+"
            echo "   |   Keep operating. Your business runs smarter    |"
            echo "   |   because your AI runs local.                   |"
            echo "   +==================================================+"
            echo
            rm -rf "$TEMP_DIR"
            exit 0
            ;;
        *)
            echo -e "  \e[91m   Invalid selection.\e[0m"
            sleep 2
            ;;
    esac
done
DASHBOARD_EOF

chmod +x "$OUTPUT_DIR/operator-dashboard.sh"

if [ -f "$OUTPUT_DIR/operator-dashboard.sh" ]; then
    echo -e "  \e[92m   ✓ operator-dashboard.sh created\e[0m"
else
    echo -e "  \e[91m   ✗ Failed to create operator-dashboard.sh\e[0m"
    read -p "  Press Enter to continue..."
    exit 1
fi

echo
echo "   Your Operator Dashboard is built. This is your daily"
echo "   command center — every Phase 2 tool in one place."
echo
echo "   Press any key to test it..."
read -n1 -s -p "  "
echo
echo

# ============================================================
# TASK 2: Launch and test the dashboard
# ============================================================
echo "  ------------------------------------------------------"
echo
echo "  [TASK 2/2] Test your Operator Dashboard"
echo
echo "   The dashboard will launch now. Test each tool:"
echo "     1 — Ask \"What are our rates?\""
echo "     2 — Draft a friendly pricing reply"
echo "     3 — Classify \"I need a quote for a kitchen remodel\""
echo "     4 — Generate \"estimate for plumbing repair\""
echo "     5 — Run a complaint chain"
echo "     H — Check full system health"
echo "     Q — Quit back to exercise"
echo
echo "   Press any key to launch the dashboard..."
read -n1 -s -p "  "

bash "$OUTPUT_DIR/operator-dashboard.sh"

echo
echo "  ======================================================"
echo "   EXERCISE COMPLETE"
echo "  ======================================================"
echo
echo "   Your Operator Dashboard lives at:"
echo "     $OUTPUT_DIR/operator-dashboard.sh"
echo
echo "   Copy it to your desktop for daily use."
echo "   Now run verify.sh to complete Phase 2."
echo

rm -rf "$TEMP_DIR"

read -p "  Press Enter to continue..."
exit 0
