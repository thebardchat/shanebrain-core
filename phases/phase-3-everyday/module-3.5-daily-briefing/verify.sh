#!/usr/bin/env bash
# Error handling is done per-command

# ============================================================
# MODULE 3.5 VERIFICATION — Daily Briefing
# Checks: MCP reachable, DailyNote entries, search works,
#         briefing generates, briefing has real text
# Returns: exit 0 = PASS, exit 1 = FAIL
# ============================================================

PASS_COUNT=0
FAIL_COUNT=0
TOTAL_CHECKS=5
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MCP_CALL="$SCRIPT_DIR/../../shared/utils/mcp-call.py"
TEMP_DIR="/tmp/module-3.5-verify"
PROGRESS_FILE="$SCRIPT_DIR/../../../../progress/user-progress.json"

mkdir -p "$TEMP_DIR"

echo
echo "  ======================================================"
echo "   MODULE 3.5 VERIFICATION — Daily Briefing"
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

# --- CHECK 2: DailyNote has >= 3 entries ---
echo "  [CHECK 2/$TOTAL_CHECKS] DailyNote collection has at least 3 entries"
NOTE_COUNT=$(python3 -c "import json; d=json.load(open('$TEMP_DIR/health.json')); cols=d.get('collections',{}); count=cols.get('DailyNote',0); print(count)" 2>/dev/null || echo "0")
if [ -z "$NOTE_COUNT" ]; then NOTE_COUNT=0; fi

if [ "$NOTE_COUNT" -ge 3 ] 2>/dev/null; then
    echo -e "  \e[92m   PASS: DailyNote has $NOTE_COUNT entries\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: DailyNote has only $NOTE_COUNT entries (need at least 3)\e[0m"
    echo "          Fix: Run exercise.sh to add journal, todo, and reminder entries"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 3: daily_note_search returns results ---
echo "  [CHECK 3/$TOTAL_CHECKS] daily_note_search returns results"
if python3 "$MCP_CALL" daily_note_search '{"query":"work tasks estimate"}' > "$TEMP_DIR/search_result.json" 2>/dev/null; then
    SEARCH_STATUS=$(python3 -c "import json; d=json.load(open('$TEMP_DIR/search_result.json')); results=d.get('results',d.get('notes',[])); has=len(results)>0 if isinstance(results,list) else bool(results); err=d.get('error',''); print('OK' if has and not err else 'EMPTY')" 2>/dev/null || echo "EMPTY")
    if [ "$SEARCH_STATUS" = "OK" ]; then
        echo -e "  \e[92m   PASS: daily_note_search returned results\e[0m"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "  \e[91m   FAIL: daily_note_search returned no results\e[0m"
        echo "          Fix: Run exercise.sh first to add notes, then search will find them"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    echo -e "  \e[91m   FAIL: daily_note_search call failed\e[0m"
    echo "          Fix: Check MCP server status"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 4: daily_briefing returns a briefing ---
echo "  [CHECK 4/$TOTAL_CHECKS] daily_briefing generates a briefing"
if python3 "$MCP_CALL" daily_briefing > "$TEMP_DIR/briefing.json" 2>/dev/null; then
    echo -e "  \e[92m   PASS: daily_briefing returned a response\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: daily_briefing call failed\e[0m"
    echo "          Fix: Make sure Ollama is running and has a model loaded"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 5: Briefing contains actual text (not error) ---
echo "  [CHECK 5/$TOTAL_CHECKS] Briefing contains actual content"
BRIEFING_STATUS=$(python3 -c "import json; d=json.load(open('$TEMP_DIR/briefing.json')); text=d.get('briefing',d.get('text',d.get('response',''))); has_text=len(str(text).strip())>20; has_error='error' in str(d).lower()[:100]; print('OK' if has_text and not has_error else 'EMPTY')" 2>/dev/null || echo "EMPTY")

if [ "$BRIEFING_STATUS" = "OK" ]; then
    echo -e "  \e[92m   PASS: Briefing contains real content\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: Briefing is empty or contains an error\e[0m"
    echo "          Fix: Ollama may need time to load. Wait 30 seconds and re-run verify.sh"
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
    echo -e "  \e[92m   Module 3.5 — Daily Briefing: COMPLETE\e[0m"
    echo
    echo -e "  \e[92m   You proved:\e[0m"
    echo -e "  \e[92m   + Journal entries with mood tags\e[0m"
    echo -e "  \e[92m   + Todos tracked by your AI\e[0m"
    echo -e "  \e[92m   + Reminders stored for the future\e[0m"
    echo -e "  \e[92m   + AI-generated daily briefings work\e[0m"
    echo
    echo "   Your AI is now your personal dispatcher."
    echo "   Five minutes a day keeps the chaos away."
    echo
    echo "   Next: Module 3.6 — Digital Footprint"
    echo "  ======================================================"

    # --- Update progress ---
    if [ -f "$PROGRESS_FILE" ]; then
        echo "  {\"module\": \"3.5\", \"status\": \"completed\", \"timestamp\": \"$(date '+%Y-%m-%d %H:%M:%S')\"}" >> "${PROGRESS_FILE}.log"
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
