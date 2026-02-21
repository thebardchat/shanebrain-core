#!/usr/bin/env bash
# Error handling is done per-command

# ============================================================
# MODULE 3.2 EXERCISE: Ask Your Vault
# Goal: Search vault, ask ShaneBrain questions via RAG,
#       interactive Q&A loop
# Time: ~15 minutes
# Prerequisites: Module 3.1 (vault must have documents)
# MCP Tools: vault_search, chat_with_shanebrain
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MCP_CALL="$SCRIPT_DIR/../../shared/utils/mcp-call.py"
TEMP_DIR="/tmp/module-3.2"

echo
echo "  ══════════════════════════════════════════════════════"
echo "   MODULE 3.2 EXERCISE: Ask Your Vault"
echo "  ══════════════════════════════════════════════════════"
echo
echo "   You stored documents in Module 3.1. Now you'll ask"
echo "   questions and get answers backed by YOUR data."
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

# Check vault has documents (prerequisite from 3.1)
python3 "$MCP_CALL" vault_list_categories > "$TEMP_DIR/categories.txt" 2>&1
VAULT_COUNT=$(python3 -c "import json; d=json.load(open('$TEMP_DIR/categories.txt')); total=sum(v for v in d.values() if isinstance(v,int)) if isinstance(d,dict) else len(d) if isinstance(d,list) else 0; print(total)" 2>/dev/null || echo "0")
if [ -z "$VAULT_COUNT" ]; then VAULT_COUNT=0; fi

if [ "$VAULT_COUNT" -lt 1 ] 2>/dev/null; then
    echo -e "  \e[91m   X Vault is empty. Run Module 3.1 first to add documents.\e[0m"
    echo "       Your vault needs at least a few documents to answer questions."
    read -p "  Press Enter to continue..."
    exit 1
fi
echo -e "  \e[92m   PASS: Vault has $VAULT_COUNT document(s)\e[0m"
echo

# ============================================================
# TASK 1: Search vault for a specific topic
# ============================================================
echo "  ──────────────────────────────────────────────────────"
echo
echo "  [TASK 1/3] Search your vault — see what the AI finds"
echo
echo "   Before asking a full question, let's see what raw"
echo "   documents match a search. This is the \"retrieval\""
echo "   step of RAG — finding the right context."
echo

echo '   Searching vault for: "health and medical information"'
echo
python3 "$MCP_CALL" vault_search '{"query":"health and medical information"}' > "$TEMP_DIR/search1.txt" 2>&1
if [ $? -eq 0 ]; then
    echo -e "  \e[92m   PASS: Vault search returned results\e[0m"
    echo
    echo "   Raw search results (what the AI sees as context):"
    echo "   ──────────────────────────────────────────────────"
    python3 -c "import json; d=json.load(open('$TEMP_DIR/search1.txt')); results=d if isinstance(d,list) else d.get('results',d.get('documents',[d])); [print('   - ' + str(r.get('title',r.get('content','')[:80]))) for r in (results[:3] if isinstance(results,list) else [results])]" 2>/dev/null
    echo "   ──────────────────────────────────────────────────"
else
    echo -e "  \e[91m   FAIL: Vault search failed\e[0m"
    echo "          Check that Module 3.1 completed successfully"
fi
echo
echo "   That's what the AI retrieves. Next, watch it turn"
echo "   those documents into a real answer."
echo
echo "   Press any key to ask ShaneBrain a question..."
read -n1 -s -p "  Press any key..." ; echo
echo

# ============================================================
# TASK 2: Ask ShaneBrain via RAG
# ============================================================
echo "  ──────────────────────────────────────────────────────"
echo
echo "  [TASK 2/3] Ask ShaneBrain a question — watch RAG in action"
echo
echo "   Same data. But now the AI reads the documents and"
echo "   gives you a synthesized answer, not a document dump."
echo

echo '   Question: "What did the doctor recommend at my last checkup?"'
echo
echo "   Thinking..."
python3 "$MCP_CALL" chat_with_shanebrain '{"message":"What did the doctor recommend at my last checkup?"}' > "$TEMP_DIR/chat1.txt" 2>&1
if [ $? -eq 0 ]; then
    echo -e "  \e[92m   PASS: ShaneBrain responded\e[0m"
    echo
    echo "   ShaneBrain's answer:"
    echo "   ══════════════════════════════════════════════════"
    python3 -c "import json; d=json.load(open('$TEMP_DIR/chat1.txt')); text=d.get('text',d.get('response',str(d))); print('   ' + text[:500])" 2>/dev/null
    echo
    echo "   ══════════════════════════════════════════════════"
    echo
    echo "   Compare this to the raw search results above."
    echo "   Same source documents — but now it's a real answer."
else
    echo -e "  \e[91m   FAIL: chat_with_shanebrain did not respond\e[0m"
    echo "          Check that Ollama is running for answer generation"
fi
echo
echo "   Press any key to try the interactive Q&A loop..."
read -n1 -s -p "  Press any key..." ; echo
echo

# ============================================================
# TASK 3: Interactive Q&A loop
# ============================================================
echo "  ──────────────────────────────────────────────────────"
echo
echo "  [TASK 3/3] Interactive Q&A — ask your vault anything"
echo
echo "   Type any question. ShaneBrain will search your vault"
echo "   and knowledge base, then give you an answer."
echo
echo "   Try questions like:"
echo '     - "When is my next appointment?"'
echo '     - "What are my strengths at work?"'
echo '     - "Who do I call in an emergency?"'
echo '     - "What should I work on this year?"'
echo

while true; do
    echo "  ──────────────────────────────────────────────────────"
    read -p "  Your question (or Q to quit): " USER_QUESTION

    if [ "${USER_QUESTION,,}" = "q" ]; then break; fi
    if [ -z "$USER_QUESTION" ]; then continue; fi

    echo
    echo "   [Step 1/2] Searching your vault..."
    python3 "$MCP_CALL" vault_search "{\"query\":\"$USER_QUESTION\"}" > "$TEMP_DIR/qa_search.txt" 2>&1

    echo "   [Step 2/2] Generating answer..."
    echo
    python3 "$MCP_CALL" chat_with_shanebrain "{\"message\":\"$USER_QUESTION\"}" > "$TEMP_DIR/qa_answer.txt" 2>&1

    if [ $? -eq 0 ]; then
        echo "   ══════════════════════════════════════════════════"
        python3 -c "import json; d=json.load(open('$TEMP_DIR/qa_answer.txt')); text=d.get('text',d.get('response',str(d))); print('   ' + text[:600])" 2>/dev/null
        echo
        echo "   ══════════════════════════════════════════════════"
        echo -e "  \e[92m   Answer generated from your vault + knowledge base\e[0m"
    else
        echo -e "  \e[91m   Could not generate answer. Check services.\e[0m"
    fi
    echo
done

# ============================================================
echo
echo "  ══════════════════════════════════════════════════════"
echo "   EXERCISE COMPLETE"
echo "  ══════════════════════════════════════════════════════"
echo
echo "   You asked questions and got answers grounded in YOUR"
echo "   documents. That's RAG — retrieval-augmented generation."
echo "   The AI didn't guess. It read your files and responded."
echo
echo "   The more documents you add to your vault (Module 3.1),"
echo "   the smarter these answers get. Like hiring someone"
echo "   and giving them your entire filing cabinet to study."
echo
echo "   Now run verify.sh to confirm everything passed:"
echo
echo "       verify.sh"
echo

# Cleanup temp files
rm -rf "$TEMP_DIR"

read -p "  Press Enter to continue..."
exit 0
