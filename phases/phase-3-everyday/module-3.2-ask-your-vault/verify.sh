#!/usr/bin/env bash
# Error handling is done per-command

# ============================================================
# MODULE 3.2 VERIFICATION
# Checks: MCP reachable, vault has docs, vault_search returns
#         results, chat_with_shanebrain responds, response
#         contains actual content (not error)
# Returns: exit 0 = PASS, exit 1 = FAIL
# ============================================================

PASS_COUNT=0
FAIL_COUNT=0
TOTAL_CHECKS=5
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MCP_CALL="$SCRIPT_DIR/../../shared/utils/mcp-call.py"
TEMP_DIR="/tmp/module-3.2-verify"

mkdir -p "$TEMP_DIR"

echo
echo "  ══════════════════════════════════════════════════════"
echo "   MODULE 3.2 VERIFICATION"
echo "  ══════════════════════════════════════════════════════"
echo

# --- CHECK 1: MCP server reachable ---
echo "  [CHECK 1/$TOTAL_CHECKS] MCP server reachable"
if python3 "$MCP_CALL" system_health > "$TEMP_DIR/health.txt" 2>&1; then
    echo -e "  \e[92m   PASS: MCP server responding\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: MCP server not reachable\e[0m"
    echo "          Fix: Ensure ShaneBrain MCP gateway is running"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 2: Vault has documents ---
echo "  [CHECK 2/$TOTAL_CHECKS] Vault contains documents"
python3 "$MCP_CALL" vault_list_categories > "$TEMP_DIR/categories.txt" 2>&1
DOC_COUNT=$(python3 -c "import json; d=json.load(open('$TEMP_DIR/categories.txt')); total=sum(v for v in d.values() if isinstance(v,int)) if isinstance(d,dict) else len(d) if isinstance(d,list) else 0; print(total)" 2>/dev/null || echo "0")
if [ -z "$DOC_COUNT" ]; then DOC_COUNT=0; fi
if [ "$DOC_COUNT" -ge 1 ] 2>/dev/null; then
    echo -e "  \e[92m   PASS: Vault contains $DOC_COUNT document(s)\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: Vault is empty\e[0m"
    echo "          Fix: Run Module 3.1 exercise.sh first to add documents"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 3: vault_search returns results ---
echo "  [CHECK 3/$TOTAL_CHECKS] Vault search returns results"
if python3 "$MCP_CALL" vault_search '{"query":"personal information"}' > "$TEMP_DIR/search.txt" 2>&1; then
    SEARCH_STATUS=$(python3 -c "import json; d=json.load(open('$TEMP_DIR/search.txt')); has_data=(len(d)>0 if isinstance(d,list) else bool(d.get('results',d.get('documents',d.get('text',''))))); print('OK' if has_data else 'EMPTY')" 2>/dev/null || echo "EMPTY")
    if [ "$SEARCH_STATUS" = "OK" ]; then
        echo -e "  \e[92m   PASS: Vault search returned results\e[0m"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "  \e[91m   FAIL: Vault search returned empty results\e[0m"
        echo "          Fix: Ensure vault has documents (run Module 3.1 first)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    echo -e "  \e[91m   FAIL: vault_search tool call failed\e[0m"
    echo "          Fix: Check MCP server is running"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 4: chat_with_shanebrain responds ---
echo "  [CHECK 4/$TOTAL_CHECKS] chat_with_shanebrain generates a response"
echo '   Asking: "What information do you have about me?"'
if python3 "$MCP_CALL" chat_with_shanebrain '{"message":"What information do you have about me?"}' > "$TEMP_DIR/chat.txt" 2>&1; then
    echo -e "  \e[92m   PASS: chat_with_shanebrain responded\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: chat_with_shanebrain did not respond\e[0m"
    echo "          Fix: Check that Ollama is running (it generates the answers)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 5: Response contains actual content (not error) ---
echo "  [CHECK 5/$TOTAL_CHECKS] Response contains actual content"
CONTENT_STATUS=$(python3 -c "import json; d=json.load(open('$TEMP_DIR/chat.txt')); text=d.get('text',d.get('response',str(d))); has_content=len(text)>20 and 'error' not in text.lower()[:50]; print('OK' if has_content else 'ERROR')" 2>/dev/null || echo "ERROR")
if [ "$CONTENT_STATUS" = "OK" ]; then
    echo -e "  \e[92m   PASS: Response contains substantive content\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: Response was empty or contained an error\e[0m"
    echo "          Fix: Check Ollama is running and has a model loaded"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# Cleanup
rm -rf "$TEMP_DIR"

# --- RESULTS ---
echo "  ══════════════════════════════════════════════════════"
if [ "$FAIL_COUNT" -eq 0 ]; then
    echo -e "  \e[92m   RESULT: PASS  ($PASS_COUNT/$TOTAL_CHECKS checks passed)\e[0m"
    echo
    echo -e "  \e[92m   MODULE 3.2 COMPLETE\e[0m"
    echo -e "  \e[92m   You proved: Your vault answers real questions.\e[0m"
    echo -e "  \e[92m   RAG retrieves your documents and generates\e[0m"
    echo -e "  \e[92m   grounded answers — no guessing, no internet.\e[0m"
    echo

    # --- Update progress ---
    PROGRESS_FILE="$SCRIPT_DIR/../../../../progress/user-progress.json"
    if [ -f "$PROGRESS_FILE" ]; then
        echo "  {\"module\": \"3.2\", \"status\": \"completed\", \"timestamp\": \"$(date '+%Y-%m-%d %H:%M:%S')\"}" >> "${PROGRESS_FILE}.log"
    fi

    echo "   Next up: Module 3.3 — Write It Right"
    echo "   Your vault answers questions. Now make it write for you."
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
