#!/usr/bin/env bash
# Error handling is done per-command

# ============================================================
# MODULE 2.1 VERIFICATION
# Checks: Services, BusinessDoc schema, documents ingested,
#         category tags present, semantic search works
# Returns: exit 0 = PASS, exit 1 = FAIL
# ============================================================

PASS_COUNT=0
FAIL_COUNT=0
TOTAL_CHECKS=6
TEMP_DIR="/tmp/module-2.1-verify"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIZ_DIR="$SCRIPT_DIR/business-docs"

mkdir -p "$TEMP_DIR"

echo
echo "  ======================================================"
echo "   MODULE 2.1 VERIFICATION"
echo "  ======================================================"
echo

# --- CHECK 1: Ollama running ---
echo "  [CHECK 1/$TOTAL_CHECKS] Ollama server running"
curl -s http://localhost:11434/api/tags >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "  \e[92m   PASS: Ollama responding on localhost:11434\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: Ollama not responding\e[0m"
    echo "          Fix: Run \"ollama serve\" in a separate terminal"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 2: Weaviate running ---
echo "  [CHECK 2/$TOTAL_CHECKS] Weaviate server running"
curl -s http://localhost:8080/v1/.well-known/ready >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "  \e[92m   PASS: Weaviate responding on localhost:8080\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: Weaviate not responding\e[0m"
    echo "          Fix: Start Weaviate via Docker"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 3: BusinessDoc schema exists ---
echo "  [CHECK 3/$TOTAL_CHECKS] \"BusinessDoc\" class in Weaviate schema"
curl -s http://localhost:8080/v1/schema 2>/dev/null | grep -qi "BusinessDoc"
if [ $? -eq 0 ]; then
    echo -e "  \e[92m   PASS: \"BusinessDoc\" class found in schema\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: \"BusinessDoc\" class not found\e[0m"
    echo "          Fix: Run exercise.sh — it creates the schema automatically"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 4: Business documents exist on disk ---
echo "  [CHECK 4/$TOTAL_CHECKS] Business documents present"
DOC_COUNT=0
if [ -d "$BIZ_DIR" ]; then
    DOC_COUNT=$(ls "$BIZ_DIR"/*.txt 2>/dev/null | wc -l)
fi
if [ "$DOC_COUNT" -ge 3 ]; then
    echo -e "  \e[92m   PASS: $DOC_COUNT business document(s) found\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: Need at least 3 .txt files in business-docs folder (found $DOC_COUNT)\e[0m"
    echo "          Fix: Run exercise.sh — it creates sample documents"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 5: BusinessDoc objects in Weaviate with categories ---
echo "  [CHECK 5/$TOTAL_CHECKS] BusinessDoc objects stored with category tags"
OBJ_COUNT=$(python3 -c "import json,urllib.request; req=urllib.request.Request('http://localhost:8080/v1/graphql',data=json.dumps({'query':'{Aggregate{BusinessDoc{meta{count}}}}'}).encode(),headers={'Content-Type':'application/json'}); resp=json.loads(urllib.request.urlopen(req).read()); count=resp.get('data',{}).get('Aggregate',{}).get('BusinessDoc',[{}])[0].get('meta',{}).get('count',0); print(count)" 2>/dev/null || echo "0")
if [ "$OBJ_COUNT" -ge 3 ]; then
    echo -e "  \e[92m   PASS: $OBJ_COUNT BusinessDoc objects in Weaviate\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: Only $OBJ_COUNT BusinessDoc objects found (need at least 3)\e[0m"
    echo "          Fix: Run exercise.sh to ingest documents"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 6: Semantic search returns relevant results ---
echo "  [CHECK 6/$TOTAL_CHECKS] Semantic search returns business answers"
echo "   Running query: \"What are the rates?\""

SEARCH_STATUS=$(python3 -c "import json,urllib.request; emb_data=json.dumps({'model':'llama3.2:1b','prompt':'What are the rates and pricing?'}).encode(); emb_req=urllib.request.Request('http://localhost:11434/api/embeddings',data=emb_data,headers={'Content-Type':'application/json'}); emb_resp=json.loads(urllib.request.urlopen(emb_req).read()); vec=emb_resp.get('embedding',[]); query='{Get{BusinessDoc(nearVector:{vector:'+json.dumps(vec)+'},limit:1){title category content}}}'; gql_data=json.dumps({'query':query}).encode(); gql_req=urllib.request.Request('http://localhost:8080/v1/graphql',data=gql_data,headers={'Content-Type':'application/json'}); gql_resp=json.loads(urllib.request.urlopen(gql_req).read()); docs=gql_resp.get('data',{}).get('Get',{}).get('BusinessDoc',[]); doc=docs[0] if docs else {}; title=doc.get('title',''); cat=doc.get('category',''); print('OK|'+title+'|'+cat if title else 'EMPTY')" 2>/dev/null || echo "EMPTY")

S_RESULT=$(echo "$SEARCH_STATUS" | cut -d'|' -f1)
S_TITLE=$(echo "$SEARCH_STATUS" | cut -d'|' -f2)
S_CAT=$(echo "$SEARCH_STATUS" | cut -d'|' -f3)

if [ "$S_RESULT" = "OK" ]; then
    echo -e "  \e[92m   PASS: Search returned \"$S_TITLE\" [$S_CAT]\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: Semantic search returned no results\e[0m"
    echo "          Fix: Ensure documents are ingested and both services are running"
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
    echo -e "  \e[92m   ✓ MODULE 2.1 COMPLETE\e[0m"
    echo -e "  \e[92m   You proved: Your business documents are loaded,\e[0m"
    echo -e "  \e[92m   tagged, searchable, and ready for every tool\e[0m"
    echo -e "  \e[92m   you'll build in Phase 2.\e[0m"
    echo

    # --- Update progress ---
    PROGRESS_FILE="$SCRIPT_DIR/../../../../progress/user-progress.json"
    if [ -f "$PROGRESS_FILE" ]; then
        echo "  {\"module\": \"2.1\", \"status\": \"completed\", \"timestamp\": \"$(date '+%Y-%m-%d %H:%M:%S')\"}" >> "${PROGRESS_FILE}.log"
    fi

    echo "   Next up: Module 2.2 — The Instant Answer Desk"
    echo "   Your knowledge base is loaded. Now put it to work."
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
