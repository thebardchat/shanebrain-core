#!/usr/bin/env bash
# Error handling is done per-command

# ============================================================
# MODULE 1.1 VERIFICATION
# Checks: Ollama running, model available, API responds
# Returns: exit 0 = PASS, exit 1 = FAIL
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PASS_COUNT=0
FAIL_COUNT=0
TOTAL_CHECKS=3

echo
echo "  ══════════════════════════════════════════════════════"
echo "   MODULE 1.1 VERIFICATION"
echo "  ══════════════════════════════════════════════════════"
echo

# --- CHECK 1: Ollama server ---
echo "  [CHECK 1/$TOTAL_CHECKS] Ollama server running"
if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
    echo -e "  \e[92m   PASS: Ollama responding on localhost:11434\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: Ollama not responding\e[0m"
    echo "          Fix: Run \"sudo systemctl start ollama\""
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 2: Model pulled ---
echo "  [CHECK 2/$TOTAL_CHECKS] Model llama3.2:1b available"
if curl -s http://localhost:11434/api/tags 2>/dev/null | grep -qi "llama3.2:1b"; then
    echo -e "  \e[92m   PASS: llama3.2:1b found in local models\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: llama3.2:1b not found\e[0m"
    echo "          Fix: Run \"ollama pull llama3.2:1b\""
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 3: API inference works ---
echo "  [CHECK 3/$TOTAL_CHECKS] API inference functional"
HTTP_CODE=$(curl -s -o /tmp/verify_response.txt -w "%{http_code}" http://localhost:11434/api/generate -d '{"model":"llama3.2:1b","prompt":"Reply with only the word VERIFIED","stream":false}' 2>&1)
rm -f /tmp/verify_response.txt

if [ "$HTTP_CODE" == "200" ]; then
    echo -e "  \e[92m   PASS: API returned HTTP 200 — inference working\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: API returned HTTP $HTTP_CODE\e[0m"
    echo "          Fix: Ensure Ollama is running and model is pulled"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- RESULTS ---
echo "  ══════════════════════════════════════════════════════"
if [ "$FAIL_COUNT" -eq 0 ]; then
    echo -e "  \e[92m   RESULT: PASS  ($PASS_COUNT/$TOTAL_CHECKS checks passed)\e[0m"
    echo
    echo -e "  \e[92m   ✓ MODULE 1.1 COMPLETE\e[0m"
    echo -e "  \e[92m   You proved: Local AI runs on YOUR machine.\e[0m"
    echo

    # --- Update progress ---
    PROGRESS_FILE="$SCRIPT_DIR/../../../../progress/user-progress.json"
    if [ -f "$PROGRESS_FILE" ]; then
        echo "  {\"module\": \"1.1\", \"status\": \"completed\", \"timestamp\": \"$(date '+%Y-%m-%d %H:%M:%S')\"}" >> "${PROGRESS_FILE}.log"
    fi

    echo "   Next up: Module 1.2 — Vectors Made Simple"
    echo "   Your AI has a voice. Now let's give it a memory."
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
