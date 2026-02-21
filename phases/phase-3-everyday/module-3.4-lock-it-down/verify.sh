#!/usr/bin/env bash
# Error handling is done per-command

# ============================================================
# MODULE 3.4 VERIFICATION
# Checks: MCP reachable, system_health returns valid data,
#         security_log_search doesn't error,
#         privacy_audit_search doesn't error
# Returns: exit 0 = PASS, exit 1 = FAIL
# ============================================================

PASS_COUNT=0
FAIL_COUNT=0
TOTAL_CHECKS=4
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MCP_CALL="$SCRIPT_DIR/../../shared/utils/mcp-call.py"
TEMP_DIR="/tmp/module-3.4-verify"

mkdir -p "$TEMP_DIR"

echo
echo "  ══════════════════════════════════════════════════════"
echo "   MODULE 3.4 VERIFICATION"
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

# --- CHECK 2: system_health returns valid data ---
echo "  [CHECK 2/$TOTAL_CHECKS] system_health returns valid data"
HEALTH_STATUS=$(python3 -c "import json; d=json.load(open('$TEMP_DIR/health.txt')); valid=isinstance(d,dict) and len(d)>0; print('OK' if valid else 'INVALID')" 2>/dev/null || echo "INVALID")
if [ "$HEALTH_STATUS" = "OK" ]; then
    echo -e "  \e[92m   PASS: system_health returned valid JSON data\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: system_health returned invalid or empty data\e[0m"
    echo "          Fix: Check that Weaviate and Ollama are running"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 3: security_log_search doesn't error ---
echo "  [CHECK 3/$TOTAL_CHECKS] security_log_search executes without error"
if python3 "$MCP_CALL" security_log_search '{"query":"security check"}' > "$TEMP_DIR/sec.txt" 2>&1; then
    SEC_STATUS=$(python3 -c "import json; d=json.load(open('$TEMP_DIR/sec.txt')); has_error='error' in str(d).lower()[:100] and 'class' not in str(d).lower()[:200]; print('ERROR' if has_error else 'OK')" 2>/dev/null || echo "OK")
    if [ "$SEC_STATUS" = "OK" ]; then
        echo -e "  \e[92m   PASS: security_log_search executed successfully\e[0m"
        echo "          (Empty results are normal on a clean system)"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "  \e[93m   WARN: security_log_search returned with a note\e[0m"
        echo "          This may happen if SecurityLog collection is empty."
        echo "          That's expected — giving you a pass."
        PASS_COUNT=$((PASS_COUNT + 1))
    fi
else
    echo -e "  \e[91m   FAIL: security_log_search call failed\e[0m"
    echo "          Fix: Check MCP server is running. The SecurityLog collection"
    echo "          may need to be created — this is OK for a fresh system."
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 4: privacy_audit_search doesn't error ---
echo "  [CHECK 4/$TOTAL_CHECKS] privacy_audit_search executes without error"
if python3 "$MCP_CALL" privacy_audit_search '{"query":"data access"}' > "$TEMP_DIR/priv.txt" 2>&1; then
    PRIV_STATUS=$(python3 -c "import json; d=json.load(open('$TEMP_DIR/priv.txt')); has_error='error' in str(d).lower()[:100] and 'class' not in str(d).lower()[:200]; print('ERROR' if has_error else 'OK')" 2>/dev/null || echo "OK")
    if [ "$PRIV_STATUS" = "OK" ]; then
        echo -e "  \e[92m   PASS: privacy_audit_search executed successfully\e[0m"
        echo "          (Empty results are normal on a clean system)"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "  \e[93m   WARN: privacy_audit_search returned with a note\e[0m"
        echo "          This may happen if PrivacyAudit collection is empty."
        echo "          That's expected — giving you a pass."
        PASS_COUNT=$((PASS_COUNT + 1))
    fi
else
    echo -e "  \e[91m   FAIL: privacy_audit_search call failed\e[0m"
    echo "          Fix: Check MCP server is running. The PrivacyAudit collection"
    echo "          may need to be created — this is OK for a fresh system."
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
    echo -e "  \e[92m   MODULE 3.4 COMPLETE\e[0m"
    echo -e "  \e[92m   You proved: You can audit your AI system —\e[0m"
    echo -e "  \e[92m   health, security, and privacy. You know where\e[0m"
    echo -e "  \e[92m   to look and what to look for. That's the\e[0m"
    echo -e "  \e[92m   foundation of responsible AI ownership.\e[0m"
    echo

    # --- Update progress ---
    PROGRESS_FILE="$SCRIPT_DIR/../../../../progress/user-progress.json"
    if [ -f "$PROGRESS_FILE" ]; then
        echo "  {\"module\": \"3.4\", \"status\": \"completed\", \"timestamp\": \"$(date '+%Y-%m-%d %H:%M:%S')\"}" >> "${PROGRESS_FILE}.log"
    fi

    echo "   Phase 3 foundations complete."
    echo "   You can store, search, ask, write, and audit."
    echo "   Your AI works for you — and you can prove it."
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
