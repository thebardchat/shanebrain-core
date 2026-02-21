# Module 3.2 Hints — Ask Your Vault

## Level 1 — General Direction

- Module 3.1 must be completed first — your vault needs documents before you can ask it questions
- The MCP server, Ollama, and Weaviate all need to be running. MCP talks to both.
- `vault_search` finds documents. `chat_with_shanebrain` generates answers FROM those documents.
- If answers seem generic or unrelated, your vault documents may not cover that topic. Add more docs via Module 3.1.
- The interactive Q&A loop in Task 3 is optional for completion — Tasks 1 and 2 are what verify.bat checks

## Level 2 — Specific Guidance

- **"Vault is empty"**: You need to run Module 3.1 first. That module stores documents in your vault. Without documents, there's nothing to search or answer from.
- **"chat_with_shanebrain did not respond"**: This usually means Ollama isn't running. The MCP server handles vault search, but Ollama generates the actual answer. Check: `curl http://localhost:11434/api/tags`
- **"Response was empty or contained an error"**: The model might be loading. Ollama loads models into RAM on first use — give it 30 seconds and try again. On a Pi, the 3B model takes a moment.
- **Answers seem wrong**: RAG answers come from your vault documents. If you stored sample data from Module 3.1, the answers are based on those samples. Replace with real data for real answers.
- **"vault_search returned empty results"**: Try a broader query. If "medication" returns nothing, try "health" or "doctor." The semantic search finds related concepts, but it needs some overlap.

## Level 3 — The Answer

Complete sequence to get everything working:

**Step 1: Verify Module 3.1 completed**
```
cd phases\phase-3-everyday\module-3.1-your-private-vault
verify.bat
```
All checks should pass. If not, run that module's exercise.bat first.

**Step 2: Verify services**
```
python shared\utils\mcp-call.py system_health
```
Look for Weaviate and Ollama both showing healthy.

**Step 3: Run the exercise**
```
cd phases\phase-3-everyday\module-3.2-ask-your-vault
exercise.bat
```

**Step 4: Run verification**
```
verify.bat
```

**If chat_with_shanebrain keeps failing**, test Ollama directly:
```
curl http://localhost:11434/api/generate -d "{\"model\":\"llama3.2:3b\",\"prompt\":\"Hello\",\"stream\":false}"
```
If that fails, Ollama needs attention. If it works, the MCP server might need a restart.

**Manual test:**
```
python shared\utils\mcp-call.py vault_search "{\"query\":\"doctor appointment\"}"
python shared\utils\mcp-call.py chat_with_shanebrain "{\"message\":\"When is my next appointment?\"}"
```
