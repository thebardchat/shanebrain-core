#!/usr/bin/env bash
# Error handling is done per-command

# ============================================================
# MODULE 3.6 VERIFICATION — Digital Footprint
# Checks: MCP reachable, system_health shows collections,
#         vault_list_categories returns data, search_knowledge
#         returns results
# Returns: exit 0 = PASS, exit 1 = FAIL
# ============================================================

PASS_COUNT=0
FAIL_COUNT=0
TOTAL_CHECKS=4
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MCP_CALL="$SCRIPT_DIR/../../shared/utils/mcp-call.py"
TEMP_DIR="/tmp/module-3.6-verify"
PROGRESS_FILE="$SCRIPT_DIR/../../../../progress/user-progress.json"

mkdir -p "$TEMP_DIR"

echo
echo "  ======================================================"
echo "   MODULE 3.6 VERIFICATION — Digital Footprint"
echo "  ======================================================"
echo

# --- CHECK 1: MCP Server Reachable ---
echo "  [CHECK 1/$TOTAL_CHECKS] MCP server reachable"
if python3 "$MCP_CALL" system_health > "$TEMP_DIR/health.json" 2>/dev/null; then
    echo -e "  \e[92m   PASS: MCP server responding\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: MCP server not reachable\e[0m"
    echo "          Fix: Make sure the MCP server is running on port 8100"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 2: system_health shows collection counts ---
echo "  [CHECK 2/$TOTAL_CHECKS] system_health shows collection counts"
HEALTH_STATUS=$(python3 -c "import json; d=json.load(open('$TEMP_DIR/health.json')); cols=d.get('collections',{}); print('OK' if len(cols)>0 else 'EMPTY')" 2>/dev/null || echo "EMPTY")

if [ "$HEALTH_STATUS" = "OK" ]; then
    echo -e "  \e[92m   PASS: system_health returned collection data\e[0m"
    python3 -c "import json; d=json.load(open('$TEMP_DIR/health.json')); cols=d.get('collections',{}); total=sum(cols.values()); print(f'          {len(cols)} collections, {total} total objects')" 2>/dev/null
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: system_health returned no collection data\e[0m"
    echo "          Fix: Weaviate may be starting up. Wait 30 seconds and retry"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 3: vault_list_categories returns data ---
echo "  [CHECK 3/$TOTAL_CHECKS] vault_list_categories returns category data"
if python3 "$MCP_CALL" vault_list_categories > "$TEMP_DIR/categories.json" 2>/dev/null; then
    CAT_STATUS=$(python3 -c "import json; d=json.load(open('$TEMP_DIR/categories.json')); cats=d.get('categories',d); has_data=len(cats)>0 if isinstance(cats,(dict,list)) else bool(cats); print('OK' if has_data else 'EMPTY')" 2>/dev/null || echo "EMPTY")
    if [ "$CAT_STATUS" = "OK" ]; then
        echo -e "  \e[92m   PASS: vault_list_categories returned data\e[0m"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "  \e[91m   FAIL: vault_list_categories returned empty\e[0m"
        echo "          Fix: Complete Module 3.1 first to add vault documents"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    echo -e "  \e[91m   FAIL: vault_list_categories call failed\e[0m"
    echo "          Fix: Check MCP server status"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 4: search_knowledge returns results ---
echo "  [CHECK 4/$TOTAL_CHECKS] search_knowledge returns results"
if python3 "$MCP_CALL" search_knowledge '{"query":"family values"}' > "$TEMP_DIR/knowledge.json" 2>/dev/null; then
    KNOW_STATUS=$(python3 -c "import json; d=json.load(open('$TEMP_DIR/knowledge.json')); results=d.get('results',d.get('knowledge',[])); has=len(results)>0 if isinstance(results,list) else bool(results); err=d.get('error',''); print('OK' if has and not err else 'EMPTY')" 2>/dev/null || echo "EMPTY")
    if [ "$KNOW_STATUS" = "OK" ]; then
        echo -e "  \e[92m   PASS: search_knowledge returned results\e[0m"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "  \e[91m   FAIL: search_knowledge returned no results\e[0m"
        echo "          Fix: The LegacyKnowledge collection may be empty. Add knowledge entries first"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    echo -e "  \e[91m   FAIL: search_knowledge call failed\e[0m"
    echo "          Fix: Check MCP server status"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# Cleanup
rm -rf "$TEMP_DIR"

# --- RESULTS ---
echo "  ======================================================"
if [ "$FAIL_COUNT" -eq 0 ]; then
    echo
    echo -e "  \e[92m   RESULT: PASS  ($PASS_COUNT/$TOTAL_CHECKS checks passed)\e[0m"
    echo
    echo -e "  \e[92m   Module 3.6 — Digital Footprint: COMPLETE\e[0m"
    echo
    echo -e "  \e[92m   You proved:\e[0m"
    echo -e "  \e[92m   + System health gives full infrastructure visibility\e[0m"
    echo -e "  \e[92m   + Vault categories show data organization\e[0m"
    echo -e "  \e[92m   + Knowledge search reveals what the AI knows\e[0m"
    echo -e "  \e[92m   + You can audit your digital footprint anytime\e[0m"
    echo
    echo "   Know your system. Trust your system."
    echo "   Audit regularly — three calls, five minutes."
    echo
    echo "   Next: Module 3.7 — Family Dashboard (Capstone)"
    echo "  ======================================================"

    # --- Update progress ---
    if [ -f "$PROGRESS_FILE" ]; then
        echo "  {\"module\": \"3.6\", \"status\": \"completed\", \"timestamp\": \"$(date '+%Y-%m-%d %H:%M:%S')\"}" >> "${PROGRESS_FILE}.log"
    fi

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
