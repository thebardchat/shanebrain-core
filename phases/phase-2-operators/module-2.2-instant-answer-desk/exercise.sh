#!/usr/bin/env bash
# Error handling is done per-command

# ============================================================
# MODULE 2.2 EXERCISE: The Instant Answer Desk
# Goal: Build an interactive Q&A tool with source citations
#       and confidence scoring using BusinessDoc collection
# Time: ~15 minutes
# RAM impact: ~300MB beyond Ollama + Weaviate baseline
# Prerequisite: Module 2.1 (BusinessDoc class with documents)
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/output"
TEMP_DIR="/tmp/module-2.2"

echo
echo "  ======================================================"
echo "   MODULE 2.2 EXERCISE: The Instant Answer Desk"
echo "  ======================================================"
echo
echo "   Build a Q&A tool with source citations. Two tasks."
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

# Check BusinessDoc exists (prerequisite from 2.1)
curl -s http://localhost:8080/v1/schema 2>/dev/null | grep -qi "BusinessDoc"
if [ $? -ne 0 ]; then
    echo -e "  \e[91m   ✗ BusinessDoc class not found. Complete Module 2.1 first.\e[0m"
    read -p "  Press Enter to continue..."
    exit 1
fi
echo -e "  \e[92m   ✓ BusinessDoc class exists (Module 2.1 complete)\e[0m"
echo

mkdir -p "$TEMP_DIR"
mkdir -p "$OUTPUT_DIR"

# ============================================================
# TASK 1: Generate the Answer Desk tool
# ============================================================
echo "  ------------------------------------------------------"
echo
echo "  [TASK 1/2] Generate the Answer Desk launcher"
echo
echo "   Creating answer-desk.sh — your business Q&A tool..."
echo

cat > "$OUTPUT_DIR/answer-desk.sh" << 'ANSWER_DESK_EOF'
#!/usr/bin/env bash
# Error handling is done per-command

TEMP_DIR="/tmp/answer-desk"
mkdir -p "$TEMP_DIR"

echo
echo "  ======================================================"
echo "   THE INSTANT ANSWER DESK"
echo "   Ask anything about your business. Get cited answers."
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
echo -e "  \e[92m   Systems online. Ready for questions.\e[0m"
echo

while true; do
    echo "  ------------------------------------------------------"
    read -p "  Question (Q to quit): " Q
    if [[ "${Q,,}" == "q" ]]; then break; fi
    if [ -z "$Q" ]; then continue; fi
    echo

    # Search and answer with citations
    python3 -c "
import json,urllib.request,sys
q=r'''$Q'''
emb_data=json.dumps({'model':'llama3.2:1b','prompt':q}).encode()
emb_req=urllib.request.Request('http://localhost:11434/api/embeddings',data=emb_data,headers={'Content-Type':'application/json'})
emb_resp=json.loads(urllib.request.urlopen(emb_req).read())
vec=emb_resp.get('embedding',[])
query='{Get{BusinessDoc(nearVector:{vector:'+json.dumps(vec)+'},limit:3){title content category _additional{distance}}}}'
gql_data=json.dumps({'query':query}).encode()
gql_req=urllib.request.Request('http://localhost:8080/v1/graphql',data=gql_data,headers={'Content-Type':'application/json'})
gql_resp=json.loads(urllib.request.urlopen(gql_req).read())
docs=gql_resp.get('data',{}).get('Get',{}).get('BusinessDoc',[])
ctx_parts=[]
src_parts=[]
conf='HIGH'
for i,d in enumerate(docs):
    dist=float(d.get('_additional',{}).get('distance',1.0))
    ctx_parts.append('[Document '+str(i+1)+': '+d.get('title','')+' ('+d.get('category','')+')] '+d.get('content',''))
    src_parts.append(d.get('title','')+'['+d.get('category','')+'] dist='+str(round(dist,3)))
    if dist>0.8: conf='LOW'
    elif dist>0.5 and conf!='LOW': conf='MODERATE'
ctx='\n\n'.join(ctx_parts)
prompt='You are a business assistant. Answer using ONLY the documents below. Cite which document(s) you used. If the answer is not in the documents, say: I do not have that information.\n\n'+ctx+'\n\nQUESTION: '+q+'\nANSWER:'
data=json.dumps({'model':'llama3.2:1b','prompt':prompt,'stream':False}).encode()
req=urllib.request.Request('http://localhost:11434/api/generate',data=data,headers={'Content-Type':'application/json'})
resp=json.loads(urllib.request.urlopen(req).read())
ans=resp.get('response','No response.')
print(ans)
print()
print('   --- Sources ---')
for s in src_parts: print('   '+s)
print('   Confidence: '+conf)
" 2>/dev/null

    echo
done

echo
echo "   Answer Desk closed. Keep your docs updated."
rm -rf "$TEMP_DIR"
exit 0
ANSWER_DESK_EOF

chmod +x "$OUTPUT_DIR/answer-desk.sh"

if [ -f "$OUTPUT_DIR/answer-desk.sh" ]; then
    echo -e "  \e[92m   ✓ answer-desk.sh created in output folder\e[0m"
else
    echo -e "  \e[91m   ✗ Failed to create answer-desk.sh\e[0m"
    read -p "  Press Enter to continue..."
    exit 1
fi

echo
echo "   The Answer Desk is a standalone tool you can use daily."
echo "   Run ./answer-desk.sh anytime you need quick answers."
echo
echo "   Press any key to test it now..."
read -n1 -s -p "  "
echo
echo

# ============================================================
# TASK 2: Test the Answer Desk
# ============================================================
echo "  ------------------------------------------------------"
echo
echo "  [TASK 2/2] Test your Answer Desk"
echo
echo "   Try these questions to test source citations:"
echo "     - \"What do we charge per hour?\""
echo "     - \"What's the cancellation policy?\""
echo "     - \"Do we work weekends?\""
echo "     - \"How do we handle a new job?\""
echo
echo "   Notice: Each answer shows source documents and confidence."
echo "   Type Q when done testing."
echo

# Run the Answer Desk directly (inline version for testing)
while true; do
    echo "  ------------------------------------------------------"
    read -p "  Question (Q to quit): " USER_Q

    if [[ "${USER_Q,,}" == "q" ]]; then break; fi
    if [ -z "$USER_Q" ]; then continue; fi

    echo
    echo "   Searching business documents..."

    python3 -c "
import json,urllib.request
q=r'''$USER_Q'''
emb_data=json.dumps({'model':'llama3.2:1b','prompt':q}).encode()
emb_req=urllib.request.Request('http://localhost:11434/api/embeddings',data=emb_data,headers={'Content-Type':'application/json'})
emb_resp=json.loads(urllib.request.urlopen(emb_req).read())
vec=emb_resp.get('embedding',[])
query='{Get{BusinessDoc(nearVector:{vector:'+json.dumps(vec)+'},limit:3){title content category _additional{distance}}}}'
gql_data=json.dumps({'query':query}).encode()
gql_req=urllib.request.Request('http://localhost:8080/v1/graphql',data=gql_data,headers={'Content-Type':'application/json'})
gql_resp=json.loads(urllib.request.urlopen(gql_req).read())
docs=gql_resp.get('data',{}).get('Get',{}).get('BusinessDoc',[])
ctx_parts=[]
src_parts=[]
for i,d in enumerate(docs):
    ctx_parts.append('[Doc '+str(i+1)+': '+d.get('title','')+' ('+d.get('category','')+')] '+d.get('content',''))
    src_parts.append(d.get('title','')+'['+d.get('category','')+'] dist='+str(round(float(d.get('_additional',{}).get('distance',1.0)),3)))
ctx='\n\n'.join(ctx_parts)
prompt='You are a business assistant. Answer using ONLY the documents below. Cite which document you used. If the answer is not in the documents, say so.\n\n'+ctx+'\n\nQUESTION: '+q+'\nANSWER:'
data=json.dumps({'model':'llama3.2:1b','prompt':prompt,'stream':False}).encode()
req=urllib.request.Request('http://localhost:11434/api/generate',data=data,headers={'Content-Type':'application/json'})
resp=json.loads(urllib.request.urlopen(req).read())
print(resp.get('response','No response.'))
print()
print('   --- Sources ---')
for s in src_parts: print('   '+s)
" 2>/dev/null

    echo
done

# ============================================================
echo
echo "  ======================================================"
echo "   EXERCISE COMPLETE"
echo "  ======================================================"
echo
echo "   Your Answer Desk is built and tested. It lives at:"
echo "     $OUTPUT_DIR/answer-desk.sh"
echo
echo "   Use it daily. Add more docs to your business-docs"
echo "   folder in Module 2.1 to make it smarter."
echo
echo "   Now run verify.sh to confirm everything passed."
echo

# Cleanup temp files
rm -rf "$TEMP_DIR"

read -p "  Press Enter to continue..."
exit 0
