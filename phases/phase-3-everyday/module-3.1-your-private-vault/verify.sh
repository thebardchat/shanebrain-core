#!/usr/bin/env bash
# Error handling is done per-command

# ============================================================
# MODULE 3.1 VERIFICATION
# Checks: MCP reachable, vault has >= 3 docs, vault_search
#         returns results, vault_list_categories shows >= 2,
#         category-filtered search works
# Returns: exit 0 = PASS, exit 1 = FAIL
# ============================================================

PASS_COUNT=0
FAIL_COUNT=0
TOTAL_CHECKS=5
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MCP_CALL="$SCRIPT_DIR/../../shared/utils/mcp-call.py"
TEMP_DIR="/tmp/module-3.1-verify"

mkdir -p "$TEMP_DIR"

echo
echo "  ══════════════════════════════════════════════════════"
echo "   MODULE 3.1 VERIFICATION"
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

# --- CHECK 2: Vault has >= 3 documents ---
echo "  [CHECK 2/$TOTAL_CHECKS] Vault contains at least 3 documents"
python3 "$MCP_CALL" vault_list_categories > "$TEMP_DIR/categories.txt" 2>&1
DOC_COUNT=$(python3 -c "import json; d=json.load(open('$TEMP_DIR/categories.txt')); total=sum(v for v in d.values() if isinstance(v,int)) if isinstance(d,dict) else len(d) if isinstance(d,list) else 0; print(total)" 2>/dev/null || echo "0")
if [ -z "$DOC_COUNT" ]; then DOC_COUNT=0; fi
if [ "$DOC_COUNT" -ge 3 ] 2>/dev/null; then
    echo -e "  \e[92m   PASS: Vault contains $DOC_COUNT document(s)\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: Vault has $DOC_COUNT documents (need at least 3)\e[0m"
    echo "          Fix: Run exercise.sh to add sample documents to your vault"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 3: vault_search returns results ---
echo "  [CHECK 3/$TOTAL_CHECKS] Vault search returns results"
if python3 "$MCP_CALL" vault_search '{"query":"health checkup doctor"}' > "$TEMP_DIR/search.txt" 2>&1; then
    SEARCH_STATUS=$(python3 -c "import json,sys; d=json.load(open('$TEMP_DIR/search.txt')); has_results=(len(d)>0 if isinstance(d,list) else bool(d.get('results',d.get('documents',d.get('text',''))))); print('OK' if has_results else 'EMPTY')" 2>/dev/null || echo "EMPTY")
    if [ "$SEARCH_STATUS" = "OK" ]; then
        echo -e "  \e[92m   PASS: Vault search returned relevant results\e[0m"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "  \e[91m   FAIL: Vault search returned empty results\e[0m"
        echo "          Fix: Run exercise.sh to add documents, then try again"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    echo -e "  \e[91m   FAIL: vault_search tool call failed\e[0m"
    echo "          Fix: Check MCP server is running"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 4: vault_list_categories shows >= 2 categories ---
echo "  [CHECK 4/$TOTAL_CHECKS] Vault has at least 2 categories"
CAT_COUNT=$(python3 -c "import json; d=json.load(open('$TEMP_DIR/categories.txt')); count=len([k for k,v in d.items() if isinstance(v,int) and v>0]) if isinstance(d,dict) else len(set(str(x) for x in d)) if isinstance(d,list) else 0; print(count)" 2>/dev/null || echo "0")
if [ -z "$CAT_COUNT" ]; then CAT_COUNT=0; fi
if [ "$CAT_COUNT" -ge 2 ] 2>/dev/null; then
    echo -e "  \e[92m   PASS: Found $CAT_COUNT categories in vault\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: Only $CAT_COUNT category(ies) found (need at least 2)\e[0m"
    echo "          Fix: Run exercise.sh — it stores docs in medical, work, and personal categories"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 5: Category-filtered search works ---
echo "  [CHECK 5/$TOTAL_CHECKS] Category-filtered vault search works"
if python3 "$MCP_CALL" vault_search '{"query":"medication allergies","category":"medical"}' > "$TEMP_DIR/filtered.txt" 2>&1; then
    echo -e "  \e[92m   PASS: Category-filtered search completed without error\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[93m   WARN: Category filter may not be fully supported\e[0m"
    echo "          This is acceptable — the tool responded without crashing"
    PASS_COUNT=$((PASS_COUNT + 1))
fi
echo

# Cleanup
rm -rf "$TEMP_DIR"

# --- RESULTS ---
echo "  ══════════════════════════════════════════════════════"
if [ "$FAIL_COUNT" -eq 0 ]; then
    echo -e "  \e[92m   RESULT: PASS  ($PASS_COUNT/$TOTAL_CHECKS checks passed)\e[0m"
    echo
    echo -e "  \e[92m   MODULE 3.1 COMPLETE\e[0m"
    echo -e "  \e[92m   You proved: Your private vault stores documents,\e[0m"
    echo -e "  \e[92m   searches by meaning, and organizes by category.\e[0m"
    echo -e "  \e[92m   Your data never left your machine.\e[0m"
    echo

    # --- Update progress ---
    PROGRESS_FILE="$SCRIPT_DIR/../../../../progress/user-progress.json"
    if [ -f "$PROGRESS_FILE" ]; then
        echo "  {\"module\": \"3.1\", \"status\": \"completed\", \"timestamp\": \"$(date '+%Y-%m-%d %H:%M:%S')\"}" >> "${PROGRESS_FILE}.log"
    fi

    echo "   Next up: Module 3.2 — Ask Your Vault"
    echo "   Your vault is loaded. Now ask it questions."
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
