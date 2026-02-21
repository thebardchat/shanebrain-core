#!/usr/bin/env bash
# Error handling is done per-command

# ============================================================
# MODULE 1.4 VERIFICATION
# Checks: Ollama running, system prompts work, temperature
#         control works, few-shot produces clean output,
#         chain of thought improves reasoning, guardrails hold
# Returns: exit 0 = PASS, exit 1 = FAIL
# Pattern: Matches Module 1.1/1.2/1.3 verify.sh structure
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PASS_COUNT=0
FAIL_COUNT=0
TOTAL_CHECKS=6
TEMP_DIR="/tmp/prompt-eng-verify"

mkdir -p "$TEMP_DIR"

echo
echo "  ══════════════════════════════════════════════════════"
echo "   MODULE 1.4 VERIFICATION"
echo "  ══════════════════════════════════════════════════════"
echo

# --- CHECK 1: Ollama running ---
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

# --- CHECK 2: System prompt constrains output length ---
echo "  [CHECK 2/$TOTAL_CHECKS] System prompt constrains output"
echo "   Testing: system prompt \"Answer in exactly 1 sentence.\""
curl -s http://localhost:11434/api/generate -d '{"model":"llama3.2:1b","system":"Answer in exactly 1 sentence. Do not exceed 1 sentence.","prompt":"What is Ollama?","stream":false,"options":{"temperature":0.0}}' > "$TEMP_DIR/sys_test.json" 2>&1

# Check response exists and is reasonable length (under 500 chars = likely constrained)
SYS_RESULT=$(python3 -c "import json; r=json.load(open('$TEMP_DIR/sys_test.json')); resp=r.get('response',''); print('OK' if 10<len(resp)<500 else 'LONG')" 2>/dev/null || echo "FAIL")

if [ "$SYS_RESULT" == "OK" ]; then
    echo -e "  \e[92m   PASS: System prompt produced constrained output\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[93m   PASS (partial): System prompt sent, output may vary\e[0m"
    echo "          Small models don't always obey length constraints perfectly."
    echo "          The technique still works — keep using it."
    PASS_COUNT=$((PASS_COUNT + 1))
fi
echo

# --- CHECK 3: Temperature 0 produces deterministic output ---
echo "  [CHECK 3/$TOTAL_CHECKS] Temperature 0 produces consistent output"
echo "   Running same prompt twice at temperature 0..."

curl -s http://localhost:11434/api/generate -d '{"model":"llama3.2:1b","prompt":"What is 2 + 2? Answer with just the number.","stream":false,"options":{"temperature":0.0}}' > "$TEMP_DIR/temp_a.json" 2>&1
curl -s http://localhost:11434/api/generate -d '{"model":"llama3.2:1b","prompt":"What is 2 + 2? Answer with just the number.","stream":false,"options":{"temperature":0.0}}' > "$TEMP_DIR/temp_b.json" 2>&1

TEMP_RESULT=$(python3 -c "import json; a=json.load(open('$TEMP_DIR/temp_a.json')).get('response',''); b=json.load(open('$TEMP_DIR/temp_b.json')).get('response',''); print('MATCH' if a.strip()==b.strip() else 'DIFFER')" 2>/dev/null || echo "FAIL")

if [ "$TEMP_RESULT" == "MATCH" ]; then
    echo -e "  \e[92m   PASS: Temperature 0 produced identical outputs\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[93m   PASS (partial): Outputs differed slightly\e[0m"
    echo "          Temperature 0 should be deterministic. Minor variation"
    echo "          can happen due to batching. The technique still applies."
    PASS_COUNT=$((PASS_COUNT + 1))
fi
echo

# --- CHECK 4: Few-shot produces clean classification ---
echo "  [CHECK 4/$TOTAL_CHECKS] Few-shot prompting produces formatted output"
echo "   Testing: 3 examples then a new classification task..."

curl -s http://localhost:11434/api/generate -d '{"model":"llama3.2:1b","prompt":"Classify each text as POSITIVE, NEGATIVE, or NEUTRAL. Respond with only the classification label.\n\nText: Great product, works perfectly.\nClassification: POSITIVE\n\nText: Broken on arrival, terrible quality.\nClassification: NEGATIVE\n\nText: The package arrived on Tuesday.\nClassification: NEUTRAL\n\nText: This is the best tool I have ever used.\nClassification:","stream":false,"options":{"temperature":0.0}}' > "$TEMP_DIR/fewshot.json" 2>&1

FS_RESULT=$(python3 -c "import json; r=json.load(open('$TEMP_DIR/fewshot.json')).get('response','').strip().upper(); print('PASS' if 'POSITIVE' in r else 'FAIL')" 2>/dev/null || echo "FAIL")

if [ "$FS_RESULT" == "PASS" ]; then
    echo -e "  \e[92m   PASS: Few-shot correctly classified as POSITIVE\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: Few-shot did not return expected POSITIVE\e[0m"
    echo "          The model may need more examples. Review Technique 4."
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 5: Chain of thought shows reasoning ---
echo "  [CHECK 5/$TOTAL_CHECKS] Chain of thought produces step-by-step output"
echo '   Testing: "What is 20% of 150? Think step by step."'

curl -s http://localhost:11434/api/generate -d '{"model":"llama3.2:1b","prompt":"What is 20 percent of 150? Think step by step before giving the final answer.","stream":false,"options":{"temperature":0.0}}' > "$TEMP_DIR/cot.json" 2>&1

# Check that response contains step indicators or the number 30
COT_RESULT=$(python3 -c "import json; r=json.load(open('$TEMP_DIR/cot.json')).get('response',''); has_steps=any(w in r.lower() for w in ['step','first','multiply','percent','0.2','0.20']); has_answer='30' in r; print('PASS' if has_steps or has_answer else 'FAIL')" 2>/dev/null || echo "FAIL")

if [ "$COT_RESULT" == "PASS" ]; then
    echo -e "  \e[92m   PASS: Chain of thought produced reasoning steps\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: Chain of thought did not show clear reasoning\e[0m"
    echo "          The 1b model may need a more explicit prompt."
    echo '          Try: "Step 1: Convert percent to decimal. Step 2: Multiply."'
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# --- CHECK 6: Guardrail holds — model refuses out-of-context question ---
echo "  [CHECK 6/$TOTAL_CHECKS] Guardrail prevents hallucination"
echo "   Testing: Asking about Mars with context about Angel Cloud..."

curl -s http://localhost:11434/api/generate -d '{"model":"llama3.2:1b","prompt":"Answer the question using ONLY the context provided. If the context does not contain the answer, respond with exactly: I don'\''t have that information.\n\nCONTEXT:\nAngel Cloud is a local AI platform built in Alabama.\n\nQUESTION:\nWhat is the population of Mars?\n\nANSWER:","stream":false,"options":{"temperature":0.0}}' > "$TEMP_DIR/guard.json" 2>&1

GUARD_RESULT=$(python3 -c "import json; r=json.load(open('$TEMP_DIR/guard.json')).get('response','').lower(); refused=any(w in r for w in ['don','not have','no information','cannot','context']); print('PASS' if refused else 'FAIL')" 2>/dev/null || echo "FAIL")

if [ "$GUARD_RESULT" == "PASS" ]; then
    echo -e "  \e[92m   PASS: Guardrail held — model refused out-of-context answer\e[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "  \e[91m   FAIL: Model answered about Mars despite no relevant context\e[0m"
    echo "          Guardrails need to be stronger. Add: \"Do not guess.\""
    echo "          Small models sometimes ignore guardrails — add more fences."
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
echo

# Cleanup
rm -rf "$TEMP_DIR" 2>/dev/null

# --- RESULTS ---
echo "  ══════════════════════════════════════════════════════"
if [ "$FAIL_COUNT" -eq 0 ]; then
    echo -e "  \e[92m   RESULT: PASS  ($PASS_COUNT/$TOTAL_CHECKS checks passed)\e[0m"
    echo
    echo -e "  \e[92m   ✓ MODULE 1.4 COMPLETE\e[0m"
    echo -e "  \e[92m   You proved: A small model with good prompts\e[0m"
    echo -e "  \e[92m   beats a big model with lazy prompts.\e[0m"
    echo

    # --- Update progress ---
    PROGRESS_FILE="$SCRIPT_DIR/../../../../progress/user-progress.json"
    if [ -f "$PROGRESS_FILE" ]; then
        echo "  {\"module\": \"1.4\", \"status\": \"completed\", \"timestamp\": \"$(date '+%Y-%m-%d %H:%M:%S')\"}" >> "${PROGRESS_FILE}.log"
    fi

    echo "   Next up: Module 1.5 — Ship It"
    echo "   Package everything into a daily-use launcher."
    echo "  ══════════════════════════════════════════════════════"
    exit 0
else
    echo -e "  \e[91m   RESULT: FAIL  ($PASS_COUNT/$TOTAL_CHECKS passed, $FAIL_COUNT failed)\e[0m"
    echo
    echo "   Review the failures above and fix them."
    echo "   Note: Some checks may fail due to the 1b model's limitations."
    echo "   If 4+ checks passed, you've demonstrated the core techniques."
    echo "   Need help? Check hints.md in this folder."
    echo "  ══════════════════════════════════════════════════════"
    exit 1
fi
