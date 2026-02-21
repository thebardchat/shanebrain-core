# Module 3.7 Hints — Family Dashboard (Capstone)

## Level 1 — General Direction

- This capstone uses six MCP tools: `system_health`, `search_knowledge`, `get_top_friends`, `vault_search`, `daily_note_search`, and `chat_with_shanebrain`
- Prerequisites: Modules 3.1 and 3.5 must be complete (vault data and daily notes)
- The exercise runs four tasks that build a complete view of your AI system
- The final task — chatting with ShaneBrain — calls Ollama and needs processing time
- Verification checks six things, so make sure all prior modules are done

## Level 2 — Specific Guidance

- **"Cannot reach MCP server"**: MCP server must be running on port 8100. Run `shared\utils\mcp-health-check.bat`
- **"system_health fails"**: This is the first check — if it fails, nothing else will work. Fix the MCP connection first
- **"search_knowledge returns nothing"**: Try different queries. The LegacyKnowledge collection has content about family, faith, values, and technical topics. If you haven't added any knowledge, the built-in content should still return results for "family"
- **"get_top_friends returns empty"**: FriendProfile collection needs entries. If no friend profiles exist, add one: `python mcp-call.py vault_add "{\"content\":\"...\",...}"`
- **"vault_search returns nothing"**: Complete Module 3.1 first. The vault needs documents stored before search can find anything
- **"chat_with_shanebrain fails"**: This requires Ollama to be running with a loaded model. The chat tool does RAG — it searches knowledge, then generates via Ollama. Give it up to 60 seconds
- **"chat_with_shanebrain returns empty"**: Ollama may have timed out. Check `system_health` for Ollama status. Try running the chat manually with a simpler prompt

## Level 3 — The Answer

Complete sequence to pass verification:

**Step 1: Verify prerequisites**
```
:: Module 3.1 — vault data
cd phases\phase-3-everyday\module-3.1-your-private-vault
verify.bat

:: Module 3.5 — daily notes
cd ..\module-3.5-daily-briefing
verify.bat
```

**Step 2: Run the capstone exercise**
```
cd phases\phase-3-everyday\module-3.7-family-dashboard
exercise.bat
```

**Step 3: If individual tasks fail**
```
:: System health
python shared\utils\mcp-call.py system_health

:: Knowledge search
python shared\utils\mcp-call.py search_knowledge "{\"query\":\"family\"}"

:: Top friends
python shared\utils\mcp-call.py get_top_friends

:: Vault search
python shared\utils\mcp-call.py vault_search "{\"query\":\"personal documents\"}"

:: Chat
python shared\utils\mcp-call.py chat_with_shanebrain "{\"message\":\"What do you know about me?\"}"
```

**Step 4: If get_top_friends is empty**
The FriendProfile collection needs entries. Earlier modules or direct MCP calls populate it. If truly empty, verification will still pass the other 5 checks — but to get full marks, friend profiles need to exist.

**Step 5: Verify**
```
verify.bat
```

**After completing Phase 3:**
You now have a personal AI system that stores documents, writes drafts, journals, audits itself, tracks relationships, and converses with you. Phase 4 — LEGACY — is where you build something that outlasts you.
