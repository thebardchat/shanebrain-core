#!/usr/bin/env bash
# Error handling is done per-command

# ============================================================
# MODULE 1.1 EXERCISE: Your First Local LLM
# Goal: Confirm Ollama works, model is pulled, and API responds
# Time: ~10 minutes
# RAM impact: Minimal — just Ollama inference on 1b model
# ============================================================

echo
echo "  ══════════════════════════════════════════════════════"
echo "   MODULE 1.1 EXERCISE: Your First Local LLM"
echo "  ══════════════════════════════════════════════════════"
echo
echo "   Complete these 3 tasks. Each one builds on the last."
echo "   When you're done, run verify.sh to check your work."
echo
echo "  ──────────────────────────────────────────────────────"
echo

# --- TASK 1: Verify Ollama is running ---
echo "  [TASK 1/3] Verify Ollama is running"
echo
echo "   Ollama should be running as a systemd service."
echo "   Check with: systemctl status ollama"
echo
echo "   If it's not running: sudo systemctl start ollama"
echo "   Then come back here and press any key."
echo
read -n1 -s -p "  Press any key to continue..." ; echo
echo "   Checking Ollama..."
if ! curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
    echo -e "  \e[91m   ✗ Ollama is not responding on localhost:11434\e[0m"
    echo "     Start it with: sudo systemctl start ollama"
    echo "     Then re-run this exercise."
    read -p "  Press Enter to continue..."
    exit 1
fi
echo -e "  \e[92m   ✓ Ollama is running.\e[0m"
echo

# --- TASK 2: Pull the model ---
echo "  ──────────────────────────────────────────────────────"
echo
echo "  [TASK 2/3] Pull llama3.2:1b"
echo
echo "   Run this command in your terminal:"
echo
echo "       ollama pull llama3.2:1b"
echo
echo "   Wait for \"success\" then press any key here."
echo
read -n1 -s -p "  Press any key to continue..." ; echo
echo "   Checking for model..."
if ! curl -s http://localhost:11434/api/tags 2>/dev/null | grep -qi "llama3.2:1b"; then
    echo -e "  \e[91m   ✗ Model llama3.2:1b not found.\e[0m"
    echo "     Run: ollama pull llama3.2:1b"
    echo "     Then come back and press any key."
    read -n1 -s -p "  Press any key to continue..." ; echo
    if ! curl -s http://localhost:11434/api/tags 2>/dev/null | grep -qi "llama3.2:1b"; then
        echo -e "  \e[91m   ✗ Still not found. Review the lesson and try again.\e[0m"
        read -p "  Press Enter to continue..."
        exit 1
    fi
fi
echo -e "  \e[92m   ✓ Model llama3.2:1b is available.\e[0m"
echo

# --- TASK 3: Make an API call ---
echo "  ──────────────────────────────────────────────────────"
echo
echo "  [TASK 3/3] Make your first API inference"
echo
echo "   Run this exact command (copy-paste it):"
echo
echo '       curl http://localhost:11434/api/generate -d '"'"'{"model":"llama3.2:1b","prompt":"Say hello in exactly 5 words","stream":false}'"'"
echo
echo "   You should see a JSON response with the model's answer."
echo "   Press any key when you've done it."
echo
read -n1 -s -p "  Press any key to continue..." ; echo

# Quick validation — we make the call ourselves to confirm the pipeline works
echo "   Verifying API is responsive..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:11434/api/generate -d '{"model":"llama3.2:1b","prompt":"test","stream":false}' 2>&1)

if [ "$HTTP_CODE" == "200" ]; then
    echo -e "  \e[92m   ✓ API inference working. Your local AI is live.\e[0m"
else
    echo -e "  \e[93m   ⚠ Got HTTP $HTTP_CODE. The API might be busy. Try again in a moment.\e[0m"
fi

echo
echo "  ══════════════════════════════════════════════════════"
echo "   EXERCISE COMPLETE"
echo "  ══════════════════════════════════════════════════════"
echo
echo "   Now run verify.sh to confirm everything passed."
echo "   From this module's folder, run:"
echo
echo "       ./verify.sh"
echo
read -p "  Press Enter to continue..."
exit 0
