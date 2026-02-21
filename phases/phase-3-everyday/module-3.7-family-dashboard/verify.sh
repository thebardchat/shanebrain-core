#!/usr/bin/env bash
# Error handling is done per-command

# ============================================================
# MODULE 3.7 VERIFICATION — PHASE 3 CAPSTONE
# Checks: MCP reachable, system_health OK, search_knowledge,
#         get_top_friends, vault_search, chat_with_shanebrain
# Returns: exit 0 = PASS, exit 1 = FAIL
# ============================================================

PASS_COUNT=0
FAIL_COUNT=0
TOTAL_CHECKS=6
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MCP_CALL="$SCRIPT_DIR/../../shared/utils/mcp-call.py"
TEMP_DIR="/tmp/module-3.7-verify"
PROGRESS_FILE="$SCRIPT_DIR/../../../../progress/user-progress.json"

mkdir -p "$TEMP_DIR"

echo
echo "  ======================================================"
echo "   MODULE 3.7 VERIFICATION — PHASE 3 CAPSTONE"
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

# --- CHECK 2: system_health shows services and collections ---
echo "  [CHECK 2/$TOTAL_CHECKS] system_health returns valid data"
HEALTH_STATUS=$(python3 -c "import json; d=json.load(open('$TEMP_DIR/health.json')); cols=d.get('collections',{}); svcs=d.get('services',{}); ok=len(cols)>0 and len(svcs)>0; print('OK' if ok else 'EMPTY')" 2>/dev/null || echo "EMPTY")

if [ "$HEALTH_STATUS" = "OK" ]; then
    echo -e "  \e[92m   PASS: system_health returned services and collections\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: system_health returned incomplete data\e[0m"
    echo "          Fix: Check that Weaviate and Ollama are running"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 3: search_knowledge returns results ---
echo "  [CHECK 3/$TOTAL_CHECKS] search_knowledge returns results"
if python3 "$MCP_CALL" search_knowledge '{"query":"family values"}' > "$TEMP_DIR/knowledge.json" 2>/dev/null; then
    KNOW_STATUS=$(python3 -c "import json; d=json.load(open('$TEMP_DIR/knowledge.json')); results=d.get('results',d.get('knowledge',[])); has=len(results)>0 if isinstance(results,list) else bool(results); err=d.get('error',''); print('OK' if has and not err else 'EMPTY')" 2>/dev/null || echo "EMPTY")
    if [ "$KNOW_STATUS" = "OK" ]; then
        echo -e "  \e[92m   PASS: search_knowledge returned results\e[0m"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "  \e[91m   FAIL: search_knowledge returned no results\e[0m"
        echo "          Fix: LegacyKnowledge collection may be empty"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    echo -e "  \e[91m   FAIL: search_knowledge call failed\e[0m"
    echo "          Fix: Check MCP server status"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 4: get_top_friends returns results ---
echo "  [CHECK 4/$TOTAL_CHECKS] get_top_friends returns results"
if python3 "$MCP_CALL" get_top_friends > "$TEMP_DIR/friends.json" 2>/dev/null; then
    FRIEND_STATUS=$(python3 -c "import json; d=json.load(open('$TEMP_DIR/friends.json')); friends=d.get('friends',d.get('results',[])); has=len(friends)>0 if isinstance(friends,list) else bool(friends); err=d.get('error',''); print('OK' if has and not err else 'EMPTY')" 2>/dev/null || echo "EMPTY")
    if [ "$FRIEND_STATUS" = "OK" ]; then
        echo -e "  \e[92m   PASS: get_top_friends returned profiles\e[0m"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "  \e[91m   FAIL: get_top_friends returned no profiles\e[0m"
        echo "          Fix: FriendProfile collection needs entries. Add friend profiles via MCP"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    echo -e "  \e[91m   FAIL: get_top_friends call failed\e[0m"
    echo "          Fix: Check MCP server status"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 5: vault_search returns results ---
echo "  [CHECK 5/$TOTAL_CHECKS] vault_search returns results"
if python3 "$MCP_CALL" vault_search '{"query":"personal documents"}' > "$TEMP_DIR/vault.json" 2>/dev/null; then
    VAULT_STATUS=$(python3 -c "import json; d=json.load(open('$TEMP_DIR/vault.json')); results=d.get('results',d.get('documents',[])); has=len(results)>0 if isinstance(results,list) else bool(results); err=d.get('error',''); print('OK' if has and not err else 'EMPTY')" 2>/dev/null || echo "EMPTY")
    if [ "$VAULT_STATUS" = "OK" ]; then
        echo -e "  \e[92m   PASS: vault_search returned documents\e[0m"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "  \e[91m   FAIL: vault_search returned no documents\e[0m"
        echo "          Fix: Complete Module 3.1 to add vault documents first"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    echo -e "  \e[91m   FAIL: vault_search call failed\e[0m"
    echo "          Fix: Check MCP server status"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 6: chat_with_shanebrain generates a response ---
echo "  [CHECK 6/$TOTAL_CHECKS] chat_with_shanebrain generates a response"
echo "   Talking to your AI... (this may take a moment)"
if python3 "$MCP_CALL" chat_with_shanebrain '{"message":"What do you know about me?"}' > "$TEMP_DIR/chat.json" 2>/dev/null; then
    CHAT_STATUS=$(python3 -c "import json; d=json.load(open('$TEMP_DIR/chat.json')); text=d.get('response',d.get('text',d.get('message',''))); has=len(str(text).strip())>20; err='error' in str(d).lower()[:100]; print('OK' if has and not err else 'EMPTY')" 2>/dev/null || echo "EMPTY")
    if [ "$CHAT_STATUS" = "OK" ]; then
        echo -e "  \e[92m   PASS: chat_with_shanebrain generated a response\e[0m"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "  \e[91m   FAIL: chat_with_shanebrain returned empty or error\e[0m"
        echo "          Fix: Ollama may need time to load. Wait 30 seconds and retry"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    echo -e "  \e[91m   FAIL: chat_with_shanebrain call failed\e[0m"
    echo "          Fix: Make sure Ollama is running and has a model loaded"
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
    echo -e "  \e[92m   ██████╗ ██╗  ██╗ █████╗ ███████╗███████╗    ██████╗ \e[0m"
    echo -e "  \e[92m   ██╔══██╗██║  ██║██╔══██╗██╔════╝██╔════╝    ╚════██╗\e[0m"
    echo -e "  \e[92m   ██████╔╝███████║███████║███████╗█████╗       █████╔╝\e[0m"
    echo -e "  \e[92m   ██╔═══╝ ██╔══██║██╔══██║╚════██║██╔══╝       ╚═══██╗\e[0m"
    echo -e "  \e[92m   ██║     ██║  ██║██║  ██║███████║███████╗    ██████╔╝\e[0m"
    echo -e "  \e[92m   ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝    ╚═════╝ \e[0m"
    echo
    echo -e "  \e[92m    ██████╗ ██████╗ ███╗   ███╗██████╗ ██╗     ███████╗████████╗███████╗\e[0m"
    echo -e "  \e[92m   ██╔════╝██╔═══██╗████╗ ████║██╔══██╗██║     ██╔════╝╚══██╔══╝██╔════╝\e[0m"
    echo -e "  \e[92m   ██║     ██║   ██║██╔████╔██║██████╔╝██║     █████╗     ██║   █████╗  \e[0m"
    echo -e "  \e[92m   ██║     ██║   ██║██║╚██╔╝██║██╔═══╝ ██║     ██╔══╝     ██║   ██╔══╝  \e[0m"
    echo -e "  \e[92m   ╚██████╗╚██████╔╝██║ ╚═╝ ██║██║     ███████╗███████╗   ██║   ███████╗\e[0m"
    echo -e "  \e[92m    ╚═════╝ ╚═════╝ ╚═╝     ╚═╝╚═╝     ╚══════╝╚══════╝   ╚═╝   ╚══════╝\e[0m"
    echo
    echo -e "  \e[92m   PHASE 3 COMPLETE\e[0m"
    echo -e "  \e[92m   STATUS: EVERYDAY USER\e[0m"
    echo
    echo -e "  \e[92m   You proved:\e[0m"
    echo -e "  \e[92m   + Store documents in a private vault\e[0m"
    echo -e "  \e[92m   + Answer questions from personal data\e[0m"
    echo -e "  \e[92m   + Write drafts with vault context\e[0m"
    echo -e "  \e[92m   + Lock down with security controls\e[0m"
    echo -e "  \e[92m   + Journal daily with AI briefings\e[0m"
    echo -e "  \e[92m   + Audit your digital footprint\e[0m"
    echo -e "  \e[92m   + Map your relationship network\e[0m"
    echo -e "  \e[92m   + Converse with your personal AI\e[0m"
    echo
    echo "   Phase 1 made you a BUILDER."
    echo "   Phase 2 made you an OPERATOR."
    echo "   Phase 3 made you an EVERYDAY USER."
    echo
    echo "   Your AI runs on your hardware, holds your data,"
    echo "   and answers to you. Nobody else."
    echo
    echo "   Next: Phase 4 — LEGACY"
    echo "   Build something that outlasts you."
    echo "  ======================================================"

    # --- Update progress ---
    if [ -f "$PROGRESS_FILE" ]; then
        echo "  {\"module\": \"3.7\", \"status\": \"completed\", \"phase\": \"3\", \"timestamp\": \"$(date '+%Y-%m-%d %H:%M:%S')\"}" >> "${PROGRESS_FILE}.log"
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
