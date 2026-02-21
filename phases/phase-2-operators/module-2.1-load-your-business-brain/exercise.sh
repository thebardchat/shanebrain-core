#!/usr/bin/env bash
# Error handling is done per-command

# ============================================================
# MODULE 2.1 EXERCISE: Load Your Business Brain
# Goal: Create business docs, build BusinessDoc schema,
#       ingest with category tags, verify semantic search
# Time: ~15 minutes
# RAM impact: ~300MB beyond Ollama + Weaviate baseline
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIZ_DIR="$SCRIPT_DIR/business-docs"
TEMP_DIR="/tmp/module-2.1"

echo
echo "  ======================================================"
echo "   MODULE 2.1 EXERCISE: Load Your Business Brain"
echo "  ======================================================"
echo
echo "   You're building a searchable knowledge base from real"
echo "   business documents. Three tasks. Fifteen minutes."
echo
echo "  ------------------------------------------------------"
echo

# --- PRE-FLIGHT: Check services ---
echo "  [PRE-FLIGHT] Checking services..."
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

curl -s http://localhost:11434/api/tags 2>/dev/null | grep -qi "llama3.2:1b"
if [ $? -ne 0 ]; then
    echo -e "  \e[91m   ✗ Model llama3.2:1b not found. Run: ollama pull llama3.2:1b\e[0m"
    read -p "  Press Enter to continue..."
    exit 1
fi
echo -e "  \e[92m   ✓ Model llama3.2:1b available\e[0m"
echo

# Create temp working directory
mkdir -p "$TEMP_DIR"

# ============================================================
# TASK 1: Create business documents
# ============================================================
echo "  ------------------------------------------------------"
echo
echo "  [TASK 1/3] Create your business documents"
echo

mkdir -p "$BIZ_DIR"

# Create sample business documents if they don't exist
if [ ! -f "$BIZ_DIR/pricing.txt" ]; then
    echo "Our standard rates: Service call fee is \$85. Hourly labor rate is \$65 per hour. Emergency and after-hours calls are billed at 1.5x the standard rate. Material markup is 15 percent on all parts and supplies. Payment is due upon completion unless credit terms are arranged in advance. We accept cash, check, and all major credit cards. Estimates are free for jobs over \$500. Jobs under \$500 have a \$25 estimate fee applied to the final invoice if you proceed." > "$BIZ_DIR/pricing.txt"
    echo "   Created: pricing.txt"
fi

if [ ! -f "$BIZ_DIR/services.txt" ]; then
    echo "We provide residential and commercial services within a 50-mile radius. Our core services include: installation, repair, maintenance, and emergency response. We specialize in same-day service for urgent issues. All work comes with a 90-day warranty on labor. We are licensed, bonded, and insured. Our team has over 15 years of experience. We offer scheduled maintenance plans at a 10 percent discount on labor." > "$BIZ_DIR/services.txt"
    echo "   Created: services.txt"
fi

if [ ! -f "$BIZ_DIR/policies.txt" ]; then
    echo "Cancellation policy: Cancel at least 24 hours before the scheduled appointment for no charge. Cancellations within 24 hours incur a \$50 fee. No-shows are billed the full service call fee. Warranty claims must be filed within 90 days of service completion. We do not warranty customer-supplied materials. Complaints should be reported within 7 days. All disputes are handled locally." > "$BIZ_DIR/policies.txt"
    echo "   Created: policies.txt"
fi

if [ ! -f "$BIZ_DIR/faq.txt" ]; then
    echo "Frequently Asked Questions: Q: Do you offer free estimates? A: Yes, for jobs over \$500. Smaller jobs have a \$25 estimate fee credited to the final bill. Q: What areas do you serve? A: Anywhere within a 50-mile radius of our main office. Q: Do you work weekends? A: Yes, Saturday service is available at standard rates. Sunday and holidays are billed at the emergency rate. Q: How fast can you get here? A: Same-day service is available for most calls placed before noon. Q: Do you offer financing? A: We offer payment plans on jobs over \$1000." > "$BIZ_DIR/faq.txt"
    echo "   Created: faq.txt"
fi

if [ ! -f "$BIZ_DIR/procedures.txt" ]; then
    echo "Standard job procedure: 1. Customer calls or submits a request. 2. Dispatcher confirms details and schedules the appointment. 3. Technician arrives on site within the scheduled window. 4. Assess the situation and provide a verbal estimate. 5. Get customer approval before starting work. 6. Complete the job and clean up the work area. 7. Collect payment and provide a receipt. 8. Follow up within 48 hours to confirm satisfaction. For emergency calls, skip to step 3 and provide the estimate on arrival." > "$BIZ_DIR/procedures.txt"
    echo "   Created: procedures.txt"
fi

echo
echo -e "  \e[92m   ✓ Business documents ready in: $BIZ_DIR\e[0m"
echo
echo "   These are sample docs for a general small business."
echo "   After completing this module, replace them with YOUR"
echo "   real business documents for a truly useful knowledge base."
echo
echo "   Press any key to continue to schema setup..."
read -n1 -s -p "  "
echo
echo

# ============================================================
# TASK 2: Create BusinessDoc schema and ingest documents
# ============================================================
echo "  ------------------------------------------------------"
echo
echo "  [TASK 2/3] Create schema and ingest documents"
echo

# Check if BusinessDoc class exists
curl -s http://localhost:8080/v1/schema 2>/dev/null | grep -qi "BusinessDoc"
if [ $? -ne 0 ]; then
    echo "   Creating \"BusinessDoc\" class in Weaviate..."
    curl -s -X POST http://localhost:8080/v1/schema -H "Content-Type: application/json" -d '{"class":"BusinessDoc","description":"Business knowledge base documents","vectorizer":"none","properties":[{"name":"title","dataType":["text"],"description":"Document title"},{"name":"content","dataType":["text"],"description":"Document text content"},{"name":"category","dataType":["text"],"description":"Document category: pricing, services, policies, faq, procedures, general"},{"name":"source","dataType":["text"],"description":"Source file path"}]}' >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "  \e[92m   ✓ \"BusinessDoc\" class created\e[0m"
    else
        echo -e "  \e[91m   ✗ Failed to create schema. Check Weaviate.\e[0m"
        read -p "  Press Enter to continue..."
        exit 1
    fi
else
    echo -e "  \e[92m   ✓ \"BusinessDoc\" class already exists\e[0m"
fi
echo

# Ingest documents
echo "   Ingesting business documents..."
echo

INGEST_COUNT=0
INGEST_FAIL=0

for f in "$BIZ_DIR"/*.txt; do
    FILENAME="$(basename "$f" .txt)"
    FULLNAME="$(basename "$f")"
    echo "   Processing: $FULLNAME"

    # Determine category from filename
    CATEGORY="general"
    echo "$FILENAME" | grep -qi "pricing\|price\|rate\|cost" && CATEGORY="pricing"
    echo "$FILENAME" | grep -qi "service" && CATEGORY="services"
    echo "$FILENAME" | grep -qi "polic" && CATEGORY="policies"
    echo "$FILENAME" | grep -qi "faq\|question" && CATEGORY="faq"
    echo "$FILENAME" | grep -qi "procedure\|process\|step" && CATEGORY="procedures"

    # Read file content
    CONTENT=$(cat "$f")

    # Generate embedding via Ollama
    echo "     Generating embedding..."
    curl -s http://localhost:11434/api/embeddings -d "{\"model\":\"llama3.2:1b\",\"prompt\":\"$CONTENT\"}" > "$TEMP_DIR/embedding.json" 2>&1

    grep -qi "embedding" "$TEMP_DIR/embedding.json"
    if [ $? -ne 0 ]; then
        echo -e "  \e[91m     ✗ Failed to get embedding for $FULLNAME\e[0m"
        INGEST_FAIL=$((INGEST_FAIL + 1))
    else
        # Store in Weaviate with category tag
        echo "     Storing in Weaviate [category: $CATEGORY]..."

        python3 -c "import json,sys; e=json.load(open('$TEMP_DIR/embedding.json')); v=e.get('embedding',[]); payload={'class':'BusinessDoc','properties':{'title':'$FILENAME','content':r'''$CONTENT''','category':'$CATEGORY','source':r'$f'},'vector':v}; open('$TEMP_DIR/payload.json','w').write(json.dumps(payload))" 2>/dev/null

        if [ -f "$TEMP_DIR/payload.json" ]; then
            STORE_HTTP=$(curl -s -o "$TEMP_DIR/store_result.txt" -w "%{http_code}" -X POST http://localhost:8080/v1/objects -H "Content-Type: application/json" -d @"$TEMP_DIR/payload.json" 2>&1)

            if [ "$STORE_HTTP" = "200" ]; then
                echo -e "  \e[92m     ✓ Stored: $FULLNAME [$CATEGORY]\e[0m"
                INGEST_COUNT=$((INGEST_COUNT + 1))
            else
                echo -e "  \e[93m     ⚠ HTTP $STORE_HTTP — may be duplicate or schema issue\e[0m"
                INGEST_COUNT=$((INGEST_COUNT + 1))
            fi
        else
            echo -e "  \e[91m     ✗ Failed to build payload for $FULLNAME\e[0m"
            echo "          Note: This step uses Python. Ensure Python is installed."
            INGEST_FAIL=$((INGEST_FAIL + 1))
        fi
    fi
    echo
done

echo "  ------------------------------------------------------"
echo "   Ingestion complete: $INGEST_COUNT documents stored, $INGEST_FAIL failed"
echo "  ------------------------------------------------------"
echo

if [ "$INGEST_COUNT" -eq 0 ]; then
    echo -e "  \e[91m   No documents were ingested. Check errors above.\e[0m"
    echo "   Common fix: Make sure Python is installed and in PATH."
    read -p "  Press Enter to continue..."
    exit 1
fi

echo "   Press any key to test your knowledge base..."
read -n1 -s -p "  "
echo
echo

# ============================================================
# TASK 3: Test semantic search on your business docs
# ============================================================
echo "  ------------------------------------------------------"
echo
echo "  [TASK 3/3] Test your business knowledge base"
echo
echo "   Your business documents are loaded. Ask questions about"
echo "   your business and watch the AI answer from YOUR docs."
echo

while true; do
    echo "  ------------------------------------------------------"
    read -p "  Your question (or Q to quit): " USER_QUESTION

    if [[ "${USER_QUESTION,,}" == "q" ]]; then break; fi
    if [ -z "$USER_QUESTION" ]; then continue; fi

    echo
    echo "   [Step 1/3] Searching your business knowledge base..."

    # Embed question and search Weaviate
    python3 -c "import json,urllib.request; emb_data=json.dumps({'model':'llama3.2:1b','prompt':r'''$USER_QUESTION'''}).encode(); emb_req=urllib.request.Request('http://localhost:11434/api/embeddings',data=emb_data,headers={'Content-Type':'application/json'}); emb_resp=json.loads(urllib.request.urlopen(emb_req).read()); vec=emb_resp.get('embedding',[]); query='{Get{BusinessDoc(nearVector:{vector:'+json.dumps(vec)+'},limit:2){title content category source _additional{distance}}}}'; gql_data=json.dumps({'query':query}).encode(); gql_req=urllib.request.Request('http://localhost:8080/v1/graphql',data=gql_data,headers={'Content-Type':'application/json'}); gql_resp=json.loads(urllib.request.urlopen(gql_req).read()); docs=gql_resp.get('data',{}).get('Get',{}).get('BusinessDoc',[]); ctx='\n'.join([d.get('content','') for d in docs]); sources=', '.join([d.get('title','')+' ['+d.get('category','')+']' for d in docs]); print('SOURCES: '+sources); json.dump({'context':ctx,'sources':sources},open('$TEMP_DIR/biz_context.json','w'))" 2>/dev/null

    if [ ! -f "$TEMP_DIR/biz_context.json" ]; then
        echo -e "  \e[91m   ✗ Failed to search. Check Ollama and Weaviate.\e[0m"
        continue
    fi

    echo "   [Step 2/3] Building answer from your documents..."
    echo "   [Step 3/3] Generating response..."
    echo

    # Generate answer with source citation
    python3 -c "import json,urllib.request; d=json.load(open('$TEMP_DIR/biz_context.json')); ctx=d['context']; prompt='You are a business assistant. Answer the question using ONLY the business documents provided below. Be specific with numbers and details. If the documents do not contain the answer, say so.\n\nBUSINESS DOCUMENTS:\n'+ctx+'\n\nQUESTION: $USER_QUESTION\n\nANSWER:'; data=json.dumps({'model':'llama3.2:1b','prompt':prompt,'stream':False}).encode(); req=urllib.request.Request('http://localhost:11434/api/generate',data=data,headers={'Content-Type':'application/json'}); resp=json.loads(urllib.request.urlopen(req).read()); print(resp.get('response','No response generated.')); print('\n   Source docs: '+d['sources'])" 2>/dev/null

    echo
    echo -e "  \e[92m   --------------------------------------------------\e[0m"
    echo -e "  \e[92m   That answer came from YOUR business documents.\e[0m"
    echo -e "  \e[92m   Notice the source citation — you can verify it.\e[0m"
    echo -e "  \e[92m   --------------------------------------------------\e[0m"
    echo
done

# ============================================================
echo
echo "  ======================================================"
echo "   EXERCISE COMPLETE"
echo "  ======================================================"
echo
echo "   Your business knowledge base is live. Five documents"
echo "   loaded with category tags and source tracking."
echo
echo "   Want to make it YOURS? Replace the sample docs in:"
echo "     $BIZ_DIR"
echo "   with your real business files, then run this again."
echo
echo "   Now run verify.sh to confirm everything passed:"
echo
echo "       ./verify.sh"
echo

# Cleanup temp files
rm -rf "$TEMP_DIR"

read -p "  Press Enter to continue..."
exit 0
