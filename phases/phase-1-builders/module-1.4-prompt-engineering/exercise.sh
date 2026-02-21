#!/usr/bin/env bash
# Error handling is done per-command

# ============================================================
# MODULE 1.4 EXERCISE: Prompt Engineering for Local Models
# Goal: Practice 5 techniques, compare good vs bad prompts,
#       see measurable difference in output quality
# Time: ~15 minutes
# RAM impact: Minimal — just Ollama inference calls
# ============================================================

TEMP_DIR="/tmp/prompt-eng-exercise"
mkdir -p "$TEMP_DIR"

echo
echo "  ══════════════════════════════════════════════════════"
echo "   MODULE 1.4 EXERCISE: Prompt Engineering for Local Models"
echo "  ══════════════════════════════════════════════════════"
echo
echo "   You'll run 5 prompt experiments. Each one demonstrates"
echo "   a technique by showing you the BEFORE and AFTER."
echo "   Watch how the same model gives wildly different answers"
echo "   based on how you ask."
echo
echo "  ──────────────────────────────────────────────────────"
echo

# --- PRE-FLIGHT ---
if ! curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
    echo -e "  \e[91m   ✗ Ollama is not running. Start it: sudo systemctl start ollama\e[0m"
    read -p "  Press Enter to continue..."
    exit 1
fi
if ! curl -s http://localhost:11434/api/tags 2>/dev/null | grep -qi "llama3.2:1b"; then
    echo -e "  \e[91m   ✗ Model llama3.2:1b not found. Run: ollama pull llama3.2:1b\e[0m"
    read -p "  Press Enter to continue..."
    exit 1
fi
echo -e "  \e[92m   ✓ Ollama running, model ready\e[0m"
echo

# ============================================================
# EXPERIMENT 1: Vague vs Specific
# ============================================================
echo "  ══════════════════════════════════════════════════════"
echo "   EXPERIMENT 1/5: Vague vs Specific"
echo "  ══════════════════════════════════════════════════════"
echo
echo "   ROUND A — Vague prompt:"
echo '   "Tell me about AI"'
echo
echo "   Sending to llama3.2:1b..."
echo

curl -s http://localhost:11434/api/generate -d '{"model":"llama3.2:1b","prompt":"Tell me about AI","stream":false,"options":{"temperature":0.3}}' > "$TEMP_DIR/exp1a.json" 2>&1
python3 -c "import json; r=json.load(open('$TEMP_DIR/exp1a.json')); print(r.get('response','')[:500])" 2>/dev/null
echo
echo -e "  \e[93m   ↑ Notice: probably long, unfocused, maybe inaccurate.\e[0m"
echo
echo "   ──────────────────────────────────────────────────────"
echo
echo "   ROUND B — Specific prompt:"
echo '   "Define artificial intelligence in exactly 2 sentences.'
echo '    Use language a 10th grader would understand."'
echo
echo "   Sending..."
echo

curl -s http://localhost:11434/api/generate -d '{"model":"llama3.2:1b","prompt":"Define artificial intelligence in exactly 2 sentences. Use language a 10th grader would understand.","stream":false,"options":{"temperature":0.3}}' > "$TEMP_DIR/exp1b.json" 2>&1
python3 -c "import json; r=json.load(open('$TEMP_DIR/exp1b.json')); print(r.get('response','')[:500])" 2>/dev/null
echo
echo -e "  \e[92m   ↑ Tighter. Clearer. Same model. Better prompt.\e[0m"
echo
echo "   Press any key for Experiment 2..."
read -n1 -s ; echo
echo

# ============================================================
# EXPERIMENT 2: System Prompts
# ============================================================
echo "  ══════════════════════════════════════════════════════"
echo "   EXPERIMENT 2/5: System Prompt Effect"
echo "  ══════════════════════════════════════════════════════"
echo
echo "   ROUND A — No system prompt:"
echo '   "What is a vector database?"'
echo
echo "   Sending..."
echo

curl -s http://localhost:11434/api/generate -d '{"model":"llama3.2:1b","prompt":"What is a vector database?","stream":false,"options":{"temperature":0.3}}' > "$TEMP_DIR/exp2a.json" 2>&1
python3 -c "import json; r=json.load(open('$TEMP_DIR/exp2a.json')); print(r.get('response','')[:500])" 2>/dev/null
echo
echo "   ──────────────────────────────────────────────────────"
echo
echo "   ROUND B — With system prompt:"
echo '   System: "You are a concise technical assistant. Answer in'
echo '   3 sentences or fewer. Use plain English. If you do not'
echo '   know, say so."'
echo
echo "   Sending..."
echo

curl -s http://localhost:11434/api/generate -d '{"model":"llama3.2:1b","system":"You are a concise technical assistant. Answer in 3 sentences or fewer. Use plain English. If you do not know, say so.","prompt":"What is a vector database?","stream":false,"options":{"temperature":0.3}}' > "$TEMP_DIR/exp2b.json" 2>&1
python3 -c "import json; r=json.load(open('$TEMP_DIR/exp2b.json')); print(r.get('response','')[:500])" 2>/dev/null
echo
echo -e "  \e[92m   ↑ System prompts constrain the model. Shorter. Focused.\e[0m"
echo
echo "   Press any key for Experiment 3..."
read -n1 -s ; echo
echo

# ============================================================
# EXPERIMENT 3: Temperature Comparison
# ============================================================
echo "  ══════════════════════════════════════════════════════"
echo "   EXPERIMENT 3/5: Temperature — Precision vs Creativity"
echo "  ══════════════════════════════════════════════════════"
echo
echo "   Same prompt, two temperatures. Watch what changes."
echo
echo "   ROUND A — Temperature 0.0 (deterministic):"
echo '   "Write a one-sentence tagline for a local AI company."'
echo
echo "   Sending..."
echo

curl -s http://localhost:11434/api/generate -d '{"model":"llama3.2:1b","prompt":"Write a one-sentence tagline for a local AI company called Angel Cloud.","stream":false,"options":{"temperature":0.0}}' > "$TEMP_DIR/exp3a.json" 2>&1
python3 -c "import json; r=json.load(open('$TEMP_DIR/exp3a.json')); print(r.get('response','')[:300])" 2>/dev/null
echo
echo "   ──────────────────────────────────────────────────────"
echo
echo "   ROUND B — Temperature 0.8 (creative):"
echo "   Same prompt."
echo
echo "   Sending..."
echo

curl -s http://localhost:11434/api/generate -d '{"model":"llama3.2:1b","prompt":"Write a one-sentence tagline for a local AI company called Angel Cloud.","stream":false,"options":{"temperature":0.8}}' > "$TEMP_DIR/exp3b.json" 2>&1
python3 -c "import json; r=json.load(open('$TEMP_DIR/exp3b.json')); print(r.get('response','')[:300])" 2>/dev/null
echo
echo -e "  \e[92m   ↑ Temperature 0 = safe/predictable. 0.8 = varied/creative.\e[0m"
echo -e "  \e[92m     For RAG, use 0-0.3. For content, use 0.6-0.8.\e[0m"
echo
echo "   Press any key for Experiment 4..."
read -n1 -s ; echo
echo

# ============================================================
# EXPERIMENT 4: Few-Shot Prompting
# ============================================================
echo "  ══════════════════════════════════════════════════════"
echo "   EXPERIMENT 4/5: Few-Shot — Teach by Example"
echo "  ══════════════════════════════════════════════════════"
echo
echo "   ROUND A — Zero-shot (no examples):"
echo '   "Classify this text as POSITIVE, NEGATIVE, or NEUTRAL:'
echo '    Angel Cloud makes local AI accessible to everyone."'
echo
echo "   Sending..."
echo

curl -s http://localhost:11434/api/generate -d '{"model":"llama3.2:1b","prompt":"Classify this text as POSITIVE, NEGATIVE, or NEUTRAL:\nAngel Cloud makes local AI accessible to everyone.","stream":false,"options":{"temperature":0.0}}' > "$TEMP_DIR/exp4a.json" 2>&1
python3 -c "import json; r=json.load(open('$TEMP_DIR/exp4a.json')); print(r.get('response','')[:300])" 2>/dev/null
echo
echo "   ──────────────────────────────────────────────────────"
echo
echo "   ROUND B — Few-shot (3 examples first):"
echo
echo "   Sending..."
echo

curl -s http://localhost:11434/api/generate -d '{"model":"llama3.2:1b","prompt":"Classify each text as POSITIVE, NEGATIVE, or NEUTRAL. Respond with only the classification label.\n\nText: The food was amazing and the service was fast.\nClassification: POSITIVE\n\nText: I waited 45 minutes and the order was wrong.\nClassification: NEGATIVE\n\nText: The weather today is cloudy with a chance of rain.\nClassification: NEUTRAL\n\nText: Angel Cloud makes local AI accessible to everyone.\nClassification:","stream":false,"options":{"temperature":0.0}}' > "$TEMP_DIR/exp4b.json" 2>&1
python3 -c "import json; r=json.load(open('$TEMP_DIR/exp4b.json')); print(r.get('response','')[:300])" 2>/dev/null
echo
echo -e "  \e[92m   ↑ Few-shot: The model follows the PATTERN you showed it.\e[0m"
echo -e "  \e[92m     Cleaner output, correct format, higher accuracy.\e[0m"
echo
echo "   Press any key for Experiment 5..."
read -n1 -s ; echo
echo

# ============================================================
# EXPERIMENT 5: Chain of Thought
# ============================================================
echo "  ══════════════════════════════════════════════════════"
echo "   EXPERIMENT 5/5: Chain of Thought — Think Step by Step"
echo "  ══════════════════════════════════════════════════════"
echo
echo "   ROUND A — Direct question:"
echo '   "What is 15% of 230?"'
echo
echo "   Sending..."
echo

curl -s http://localhost:11434/api/generate -d '{"model":"llama3.2:1b","prompt":"What is 15 percent of 230?","stream":false,"options":{"temperature":0.0}}' > "$TEMP_DIR/exp5a.json" 2>&1
python3 -c "import json; r=json.load(open('$TEMP_DIR/exp5a.json')); print(r.get('response','')[:400])" 2>/dev/null
echo
echo "   ──────────────────────────────────────────────────────"
echo
echo "   ROUND B — With chain of thought:"
echo '   "What is 15% of 230? Think step by step before giving'
echo '    the final answer."'
echo
echo "   Sending..."
echo

curl -s http://localhost:11434/api/generate -d '{"model":"llama3.2:1b","prompt":"What is 15 percent of 230? Think step by step before giving the final answer.","stream":false,"options":{"temperature":0.0}}' > "$TEMP_DIR/exp5b.json" 2>&1
python3 -c "import json; r=json.load(open('$TEMP_DIR/exp5b.json')); print(r.get('response','')[:500])" 2>/dev/null
echo
echo -e "  \e[92m   ↑ Chain of thought forces the model to SHOW its work.\e[0m"
echo -e "  \e[92m     More steps visible = higher chance of correct answer.\e[0m"
echo

# ============================================================
# BONUS: Write your own prompt
# ============================================================
echo "  ══════════════════════════════════════════════════════"
echo "   BONUS: Write Your Own Prompt"
echo "  ══════════════════════════════════════════════════════"
echo
echo "   Try your own prompt using any technique you just learned."
echo "   Type a prompt and hit Enter to send it to llama3.2:1b."
echo "   Type Q to finish."
echo

while true; do
    read -p "  Your prompt (Q to quit): " CUSTOM_PROMPT

    if [[ "${CUSTOM_PROMPT,,}" == "q" ]]; then
        break
    fi
    if [ -z "$CUSTOM_PROMPT" ]; then
        continue
    fi

    echo
    echo "   Sending to llama3.2:1b (temp 0.3)..."
    echo

    curl -s http://localhost:11434/api/generate -d "{\"model\":\"llama3.2:1b\",\"prompt\":$(python3 -c "import json; print(json.dumps('''$CUSTOM_PROMPT'''))"),\"stream\":false,\"options\":{\"temperature\":0.3}}" > "$TEMP_DIR/custom.json" 2>&1
    python3 -c "import json; r=json.load(open('$TEMP_DIR/custom.json')); print(r.get('response','No response.')[:600])" 2>/dev/null
    echo
done

echo
echo "  ══════════════════════════════════════════════════════"
echo "   EXERCISE COMPLETE"
echo "  ══════════════════════════════════════════════════════"
echo
echo "   You tested 5 prompt engineering techniques and saw"
echo "   the difference each one makes on a 1b model."
echo
echo "   Now run verify.sh to confirm:"
echo
echo "       ./verify.sh"
echo

# Cleanup
rm -rf "$TEMP_DIR" 2>/dev/null

read -p "  Press Enter to continue..."
exit 0
