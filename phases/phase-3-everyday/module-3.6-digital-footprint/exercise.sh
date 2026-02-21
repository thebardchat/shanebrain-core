#!/usr/bin/env bash
# Error handling is done per-command

# ============================================================
# MODULE 3.6 EXERCISE: Digital Footprint
# Goal: Audit your AI system — map collections, vault
#       categories, and your own knowledge entries
# Time: ~15 minutes
# Prerequisites: Module 3.1 (vault needs data)
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MCP_CALL="$SCRIPT_DIR/../../shared/utils/mcp-call.py"
TEMP_DIR="/tmp/module-3.6"

echo
echo "  ======================================================"
echo "   MODULE 3.6 EXERCISE: Digital Footprint"
echo "  ======================================================"
echo
echo "   Time to pop the hood. You're going to map exactly"
echo "   what your AI knows, where the data lives, and how"
echo "   it's organized. No guessing. Hard numbers."
echo
echo "  ------------------------------------------------------"
echo

# --- PRE-FLIGHT: MCP Server ---
echo "  [PRE-FLIGHT] Checking MCP server..."
echo

mkdir -p "$TEMP_DIR"

python3 "$MCP_CALL" system_health > "$TEMP_DIR/preflight.json" 2>/dev/null || {
    echo -e "  \e[91m   X MCP server not reachable at localhost:8100\e[0m"
    echo "     Fix: Make sure the MCP server container is running."
    echo "     Run: shared/utils/mcp-health-check.sh"
    read -p "  Press Enter to continue..."
    exit 1
}
echo -e "  \e[92m   OK — MCP server responding\e[0m"
echo

# ============================================================
# TASK 1: System Health — Map All Collections
# ============================================================
echo "  ------------------------------------------------------"
echo
echo "  [TASK 1/3] System Health — Map Your AI Infrastructure"
echo
echo "   Like checking every gauge on the truck dashboard."
echo "   Services, collections, object counts — the full picture."
echo

python3 "$MCP_CALL" system_health > "$TEMP_DIR/health.json" 2>/dev/null

if [ $? -eq 0 ]; then
    echo -e "  \e[92m   OK — System health retrieved\e[0m"
    echo
    echo "   --- SERVICES ---"
    python3 -c "import json; d=json.load(open('$TEMP_DIR/health.json')); svcs=d.get('services',{}); [print(f'     {k:15s} {v[\"status\"] if isinstance(v,dict) else v}') for k,v in svcs.items()]" 2>/dev/null
    echo
    echo "   --- COLLECTIONS ---"
    python3 -c "import json; d=json.load(open('$TEMP_DIR/health.json')); cols=d.get('collections',{}); [print(f'     {k:20s} {v:>5} objects') for k,v in cols.items()]; print(f'     {\"TOTAL\":20s} {sum(cols.values()):>5} objects')" 2>/dev/null
    echo
    echo "   Those numbers are your digital footprint. Every object"
    echo "   is a piece of data your AI can access and reason about."
else
    echo -e "  \e[91m   FAIL — Could not retrieve system health\e[0m"
    echo "     Check hints.md for troubleshooting."
fi
echo

# ============================================================
# TASK 2: Vault Categories — How Your Data Is Organized
# ============================================================
echo "  ------------------------------------------------------"
echo
echo "  [TASK 2/3] Vault Categories — Check Your Filing System"
echo
echo "   Your personal vault organizes documents by category."
echo "   This shows you which drawers have folders and which"
echo "   are empty. Empty is not bad — it's an opportunity."
echo

python3 "$MCP_CALL" vault_list_categories > "$TEMP_DIR/categories.json" 2>/dev/null

if [ $? -eq 0 ]; then
    echo -e "  \e[92m   OK — Vault categories retrieved\e[0m"
    echo
    echo "   --- VAULT CATEGORIES ---"
    python3 -c "import json; d=json.load(open('$TEMP_DIR/categories.json')); cats=d.get('categories',d); [print(f'     {k:15s} {v:>3} documents') if isinstance(v,(int,float)) else print(f'     {k:15s} {v}') for k,v in (cats.items() if isinstance(cats,dict) else [(str(i),c) for i,c in enumerate(cats)])]" 2>/dev/null
    echo
    echo "   Think about what's missing. No medical docs? No legal"
    echo "   records? Those are blind spots you can fill."
else
    echo -e "  \e[91m   FAIL — Could not retrieve vault categories\e[0m"
    echo "     Make sure Module 3.1 has been completed first."
    echo "     Check hints.md for troubleshooting."
fi
echo

# ============================================================
# TASK 3: Search Your Own Knowledge Entries
# ============================================================
echo "  ------------------------------------------------------"
echo
echo "  [TASK 3/3] Knowledge Search — What Have You Taught the AI?"
echo
echo "   The knowledge base has built-in content AND things you"
echo "   added yourself. This search finds entries related to"
echo "   your life — what the AI knows because you told it."
echo

python3 "$MCP_CALL" search_knowledge '{"query":"family values work"}' > "$TEMP_DIR/knowledge.json" 2>/dev/null

if [ $? -eq 0 ]; then
    echo -e "  \e[92m   OK — Knowledge search returned results\e[0m"
    echo
    echo "   --- KNOWLEDGE ENTRIES (top 3) ---"
    python3 -c "import json; d=json.load(open('$TEMP_DIR/knowledge.json')); results=d.get('results',d.get('knowledge',[])); entries=results if isinstance(results,list) else [results]; [print(f'     [{e.get(\"category\",\"general\")}] {str(e.get(\"content\",e.get(\"text\",\"\")))[:120]}...') for e in entries[:3]]" 2>/dev/null
    echo
    echo "   That's what your AI pulls from when you ask it questions."
    echo "   The more you teach it, the better it knows you."
else
    echo -e "  \e[91m   FAIL — Could not search knowledge base\e[0m"
    echo "     Check hints.md for troubleshooting."
fi
echo

# ============================================================
# EXERCISE COMPLETE
# ============================================================
echo "  ======================================================"
echo "   EXERCISE COMPLETE"
echo "  ======================================================"
echo
echo "   You just audited your digital footprint:"
echo "     1. Mapped all services and collections"
echo "     2. Checked your vault organization"
echo "     3. Found what you've taught the AI"
echo
echo "   Smart operators audit their systems regularly."
echo "   Run this check monthly — three calls, five minutes,"
echo "   full visibility."
echo
echo "   Now run verify.sh to confirm the audit."
echo

rm -rf "$TEMP_DIR"

read -p "  Press Enter to continue..."
exit 0
