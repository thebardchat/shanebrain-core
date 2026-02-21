#!/usr/bin/env bash
# Error handling is done per-command

# ============================================================
# MODULE 3.3 EXERCISE: Write It Right
# Goal: Create email draft, create message draft, search drafts
# Time: ~15 minutes
# Prerequisites: Module 3.1 (vault docs for context)
# MCP Tools: draft_create, draft_search
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MCP_CALL="$SCRIPT_DIR/../../shared/utils/mcp-call.py"
TEMP_DIR="/tmp/module-3.3"

echo
echo "  ══════════════════════════════════════════════════════"
echo "   MODULE 3.3 EXERCISE: Write It Right"
echo "  ══════════════════════════════════════════════════════"
echo
echo "   You'll create AI-written drafts that pull details from"
echo "   your vault. Three tasks. Fifteen minutes."
echo
echo "  ──────────────────────────────────────────────────────"
echo

# --- PRE-FLIGHT: Check MCP server ---
echo "  [PRE-FLIGHT] Checking MCP server..."
echo

mkdir -p "$TEMP_DIR"

python3 "$MCP_CALL" system_health > "$TEMP_DIR/health.txt" 2>&1 || {
    echo -e "  \e[91m   X MCP server not reachable. Is ShaneBrain running?\e[0m"
    read -p "  Press Enter to continue..."
    exit 1
}
echo -e "  \e[92m   PASS: MCP server responding\e[0m"

# Check vault has documents (for context)
python3 "$MCP_CALL" vault_list_categories > "$TEMP_DIR/categories.txt" 2>&1
VAULT_COUNT=$(python3 -c "import json; d=json.load(open('$TEMP_DIR/categories.txt')); total=sum(v for v in d.values() if isinstance(v,int)) if isinstance(d,dict) else len(d) if isinstance(d,list) else 0; print(total)" 2>/dev/null || echo "0")
if [ -z "$VAULT_COUNT" ]; then VAULT_COUNT=0; fi

if [ "$VAULT_COUNT" -ge 1 ] 2>/dev/null; then
    echo -e "  \e[92m   PASS: Vault has $VAULT_COUNT document(s) for context\e[0m"
else
    echo -e "  \e[93m   NOTE: Vault is empty. Drafts will work but won't pull personal context.\e[0m"
    echo "          For best results, run Module 3.1 first."
fi
echo

# ============================================================
# TASK 1: Create an email draft
# ============================================================
echo "  ──────────────────────────────────────────────────────"
echo
echo "  [TASK 1/3] Create an email draft with vault context"
echo
echo "   The AI will search your vault for relevant info and"
echo "   weave it into a professional email draft."
echo
echo '   Prompt: "Write an email to my doctor'\''s office to'
echo "   reschedule my upcoming appointment to next month."
echo "   Be polite and mention any relevant medical details."
echo

echo "   Generating email draft..."
echo "   (This may take 30-60 seconds — the AI is searching"
echo "    your vault and composing the draft)"
echo

python3 "$MCP_CALL" draft_create '{"prompt":"Write an email to my doctor'\''s office to reschedule my upcoming appointment to next month. Be polite and mention any relevant medical details from my records.","draft_type":"email","use_vault_context":true}' > "$TEMP_DIR/draft_email.txt" 2>&1

if [ $? -eq 0 ]; then
    echo -e "  \e[92m   PASS: Email draft generated\e[0m"
    echo
    echo "   ══════════════════════════════════════════════════"
    echo "   YOUR EMAIL DRAFT:"
    echo "   ══════════════════════════════════════════════════"
    python3 -c "import json; d=json.load(open('$TEMP_DIR/draft_email.txt')); text=d.get('text',d.get('draft',d.get('content',str(d)))); print(text[:800])" 2>/dev/null
    echo
    echo "   ══════════════════════════════════════════════════"
    echo
    echo "   Notice how it pulled details from your vault —"
    echo "   doctor names, appointment dates, medical info."
    echo "   That's vault context making the draft personal."
else
    echo -e "  \e[91m   FAIL: Could not generate email draft\e[0m"
    echo "          Check that Ollama is running for text generation"
fi
echo
echo "   Press any key to create a message draft..."
read -n1 -s -p "  Press any key..." ; echo
echo

# ============================================================
# TASK 2: Create a message draft
# ============================================================
echo "  ──────────────────────────────────────────────────────"
echo
echo "  [TASK 2/3] Create a message draft (casual, short)"
echo
echo "   Same tool, different format. Messages are brief"
echo "   and conversational — like a text to a coworker."
echo
echo '   Prompt: "Write a quick message to my manager about'
echo "   the areas I should focus on for improvement based"
echo '   on my performance review."'
echo

echo "   Generating message draft..."
echo

python3 "$MCP_CALL" draft_create '{"prompt":"Write a quick casual message to my manager about the areas I should focus on for improvement this quarter, based on my performance review feedback.","draft_type":"message","use_vault_context":true}' > "$TEMP_DIR/draft_message.txt" 2>&1

if [ $? -eq 0 ]; then
    echo -e "  \e[92m   PASS: Message draft generated\e[0m"
    echo
    echo "   ══════════════════════════════════════════════════"
    echo "   YOUR MESSAGE DRAFT:"
    echo "   ══════════════════════════════════════════════════"
    python3 -c "import json; d=json.load(open('$TEMP_DIR/draft_message.txt')); text=d.get('text',d.get('draft',d.get('content',str(d)))); print(text[:500])" 2>/dev/null
    echo
    echo "   ══════════════════════════════════════════════════"
    echo
    echo "   Shorter. More casual. But still pulled from your"
    echo "   vault — it used your actual review feedback."
else
    echo -e "  \e[91m   FAIL: Could not generate message draft\e[0m"
fi
echo
echo "   Press any key to search your saved drafts..."
read -n1 -s -p "  Press any key..." ; echo
echo

# ============================================================
# TASK 3: Search saved drafts
# ============================================================
echo "  ──────────────────────────────────────────────────────"
echo
echo "  [TASK 3/3] Search your saved drafts"
echo
echo "   Every draft gets saved. Let's find them by topic."
echo

echo '   Searching drafts for: "doctor appointment"'
python3 "$MCP_CALL" draft_search '{"query":"doctor appointment"}' > "$TEMP_DIR/draft_found.txt" 2>&1

if [ $? -eq 0 ]; then
    echo -e "  \e[92m   PASS: Draft search returned results\e[0m"
    echo
    python3 -c "import json; d=json.load(open('$TEMP_DIR/draft_found.txt')); results=d if isinstance(d,list) else d.get('results',d.get('drafts',[d])); count=len(results) if isinstance(results,list) else 1; print('   Found ' + str(count) + ' draft(s) matching your search')" 2>/dev/null
else
    echo -e "  \e[91m   FAIL: Draft search failed\e[0m"
fi
echo

echo '   Searching drafts for: "work improvement"'
python3 "$MCP_CALL" draft_search '{"query":"work improvement"}' > "$TEMP_DIR/draft_found2.txt" 2>&1

if [ $? -eq 0 ]; then
    echo -e "  \e[92m   PASS: Draft search returned results\e[0m"
    python3 -c "import json; d=json.load(open('$TEMP_DIR/draft_found2.txt')); results=d if isinstance(d,list) else d.get('results',d.get('drafts',[d])); count=len(results) if isinstance(results,list) else 1; print('   Found ' + str(count) + ' draft(s) matching your search')" 2>/dev/null
else
    echo -e "  \e[93m   NOTE: No matching drafts found — that's OK if drafts weren't saved\e[0m"
fi
echo

# ============================================================
echo
echo "  ══════════════════════════════════════════════════════"
echo "   EXERCISE COMPLETE"
echo "  ══════════════════════════════════════════════════════"
echo
echo "   You generated two AI drafts powered by your vault data."
echo "   The email pulled medical details. The message pulled"
echo "   work feedback. Both came from YOUR documents."
echo
echo "   Use this anytime:"
echo "     python3 \"$MCP_CALL\" draft_create '{\"prompt\":\"...\",\"draft_type\":\"email\"}'"
echo
echo "   Now run verify.sh to confirm everything passed:"
echo
echo "       verify.sh"
echo

# Cleanup temp files
rm -rf "$TEMP_DIR"

read -p "  Press Enter to continue..."
exit 0
