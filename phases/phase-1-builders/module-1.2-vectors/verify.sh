#!/usr/bin/env bash
# Error handling is done per-command

# ============================================================
# MODULE 1.2 VERIFICATION
# Checks: Weaviate running, schema exists, document stored,
#         embedding API works, GraphQL search responds
# Returns: exit 0 = PASS, exit 1 = FAIL
# Pattern: Matches Module 1.1 verify.sh structure
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PASS_COUNT=0
FAIL_COUNT=0
TOTAL_CHECKS=5

echo
echo "  ══════════════════════════════════════════════════════"
echo "   MODULE 1.2 VERIFICATION"
echo "  ══════════════════════════════════════════════════════"
echo

# --- CHECK 1: Weaviate server running ---
echo "  [CHECK 1/$TOTAL_CHECKS] Weaviate server running"
if curl -s http://localhost:8080/v1/.well-known/ready >/dev/null 2>&1; then
    echo -e "  \e[92m   PASS: Weaviate responding on localhost:8080\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: Weaviate not responding\e[0m"
    echo "          Fix: Start Weaviate via Docker or binary"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 2: Document class exists in schema ---
echo "  [CHECK 2/$TOTAL_CHECKS] \"Document\" class in schema"
WV_SCHEMA=$(curl -s http://localhost:8080/v1/schema 2>/dev/null)
if echo "$WV_SCHEMA" | grep -qi "Document"; then
    echo -e "  \e[92m   PASS: \"Document\" class found in Weaviate schema\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: \"Document\" class not found\e[0m"
    echo "          Fix: Create schema with the curl command from the lesson"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 3: At least one document stored ---
echo "  [CHECK 3/$TOTAL_CHECKS] Document objects stored in Weaviate"
WV_OBJECTS=$(curl -s "http://localhost:8080/v1/objects?class=Document&limit=1" 2>/dev/null)
if echo "$WV_OBJECTS" | grep -qi "title"; then
    echo -e "  \e[92m   PASS: At least one Document object stored\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: No Document objects found in Weaviate\e[0m"
    echo "          Fix: Store a document with an embedding (Task 3 in exercise)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 4: Ollama embedding API responds ---
echo "  [CHECK 4/$TOTAL_CHECKS] Ollama embedding API functional"
EMB_HTTP=$(curl -s -o /tmp/emb_response.txt -w "%{http_code}" http://localhost:11434/api/embeddings -d '{"model":"llama3.2:1b","prompt":"test"}' 2>&1)

if [ "$EMB_HTTP" == "200" ]; then
    # Verify we actually got an embedding back
    if grep -qi "embedding" /tmp/emb_response.txt 2>/dev/null; then
        echo -e "  \e[92m   PASS: Ollama returned embedding vector (HTTP 200)\e[0m"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "  \e[91m   FAIL: Ollama returned 200 but no embedding data\e[0m"
        echo "          Fix: Ensure llama3.2:1b supports embeddings"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    echo -e "  \e[91m   FAIL: Ollama embedding API returned HTTP $EMB_HTTP\e[0m"
    echo "          Fix: Ensure Ollama is running and model is pulled"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
rm -f /tmp/emb_response.txt
echo

# --- CHECK 5: GraphQL search endpoint responds ---
echo "  [CHECK 5/$TOTAL_CHECKS] Weaviate GraphQL search endpoint"
GQL_HTTP=$(curl -s -o /tmp/gql_response.txt -w "%{http_code}" -X POST http://localhost:8080/v1/graphql -H "Content-Type: application/json" -d '{"query":"{Get{Document(limit:1){title content}}}"}' 2>&1)
rm -f /tmp/gql_response.txt

if [ "$GQL_HTTP" == "200" ]; then
    echo -e "  \e[92m   PASS: GraphQL endpoint responding (HTTP 200)\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: GraphQL endpoint returned HTTP $GQL_HTTP\e[0m"
    echo "          Fix: Weaviate may need restart, or schema may be missing"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- RESULTS ---
echo "  ══════════════════════════════════════════════════════"
if [ "$FAIL_COUNT" -eq 0 ]; then
    echo -e "  \e[92m   RESULT: PASS  ($PASS_COUNT/$TOTAL_CHECKS checks passed)\e[0m"
    echo
    echo -e "  \e[92m   ✓ MODULE 1.2 COMPLETE\e[0m"
    echo -e "  \e[92m   You proved: Your AI has a memory.\e[0m"
    echo

    # --- Update progress ---
    PROGRESS_FILE="$SCRIPT_DIR/../../../../progress/user-progress.json"
    if [ -f "$PROGRESS_FILE" ]; then
        echo "  {\"module\": \"1.2\", \"status\": \"completed\", \"timestamp\": \"$(date '+%Y-%m-%d %H:%M:%S')\"}" >> "${PROGRESS_FILE}.log"
    fi

    echo "   Next up: Module 1.3 — Build Your Brain"
    echo "   Voice + Memory = RAG pipeline. Let's connect them."
    echo "  ══════════════════════════════════════════════════════"
    exit 0
else
    echo -e "  \e[91m   RESULT: FAIL  ($PASS_COUNT/$TOTAL_CHECKS passed, $FAIL_COUNT failed)\e[0m"
    echo
    echo "   Review the failures above and fix them."
    echo "   Then run verify.sh again."
    echo "   Need help? Check hints.md in this folder."
    echo "  ══════════════════════════════════════════════════════"
    exit 1
fi
