# Module 3.3 Hints — Write It Right

## Level 1 — General Direction

- The MCP server and Ollama must both be running. MCP handles the vault search; Ollama generates the draft text.
- Module 3.1 should be completed first so the AI has vault context to pull from. Drafts still work without it, but they'll be generic.
- `draft_create` does the writing. `draft_search` finds past drafts. Two tools, two jobs.
- The more specific your prompt, the better the draft. "Email to reschedule my July appointment with Dr. Martinez" beats "email about appointment."
- Draft generation takes 30-60 seconds — the AI is searching your vault AND writing. Be patient.

## Level 2 — Specific Guidance

- **"Could not generate draft"**: Ollama is likely not running or has no model loaded. Check: `curl http://localhost:11434/api/tags` — you should see at least one model listed.
- **"draft_create returned empty content"**: The model might have timed out. Try again — sometimes the first call after a cold start takes longer. If it keeps failing, check Ollama logs.
- **"Draft search returned no results"**: Drafts may not have been saved to the searchable collection. This depends on how the MCP server handles draft storage. Verify.bat gives you a pass either way.
- **Draft doesn't include personal details**: Your vault might be empty or the prompt wasn't specific enough. Add vault documents via Module 3.1, then retry with a more targeted prompt.
- **Draft is too long/short**: The AI follows the draft_type format. "email" produces longer, structured output. "message" produces short, casual output. Pick the type that matches what you need.
- **"vault_context_used" not in response**: Some MCP server versions don't include this field. Verify.bat falls back to checking if the draft has substantial content instead.

## Level 3 — The Answer

Complete sequence to get everything working:

**Step 1: Verify prerequisites**
```
:: Check MCP server
python shared\utils\mcp-call.py system_health

:: Check vault has documents
python shared\utils\mcp-call.py vault_list_categories
```

**Step 2: Run the exercise**
```
cd phases\phase-3-everyday\module-3.3-write-it-right
exercise.bat
```
Watch for green PASS lines on each task. Draft generation takes a moment.

**Step 3: Run verification**
```
verify.bat
```

**If draft_create keeps failing**, test the pieces separately:
```
:: Test Ollama directly
curl http://localhost:11434/api/generate -d "{\"model\":\"llama3.2:3b\",\"prompt\":\"Write a short email.\",\"stream\":false}"

:: Test vault search (for context)
python shared\utils\mcp-call.py vault_search "{\"query\":\"medical\"}"

:: Test draft creation
python shared\utils\mcp-call.py draft_create "{\"prompt\":\"Write a thank you note\",\"draft_type\":\"general\"}"
```

**Manual draft creation:**
```
python shared\utils\mcp-call.py draft_create "{\"prompt\":\"Your prompt here\",\"draft_type\":\"email\",\"use_vault_context\":true}"
```
