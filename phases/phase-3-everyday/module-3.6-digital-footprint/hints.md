# Module 3.6 Hints — Digital Footprint

## Level 1 — General Direction

- This module uses four MCP tools: `system_health`, `vault_list_categories`, `search_knowledge`, and `privacy_audit_search`
- The exercise maps your system, checks your vault organization, and finds your own knowledge entries
- You need Module 3.1 completed first — the vault needs to have data in it
- All tools are read-only in this module. You're auditing, not modifying
- If a collection shows zero objects, that just means you haven't used that feature yet

## Level 2 — Specific Guidance

- **"Cannot reach MCP server"**: MCP server must be running on port 8100. Run `shared\utils\mcp-health-check.bat` to check
- **"system_health shows no collections"**: Weaviate may be starting up. Wait 30 seconds and try again. Collections are created by earlier modules
- **"vault_list_categories returns empty"**: You need to complete Module 3.1 first. That module adds documents to your vault with categories
- **"search_knowledge returns nothing"**: Try broader search terms. If you haven't added knowledge entries via `add_knowledge`, there may not be entries with source "mcp". Try searching for "family" or other topics from the built-in knowledge
- **Verify fails on vault_list_categories**: Make sure Module 3.1's exercise has been completed. The vault needs at least one document stored

## Level 3 — The Answer

Complete sequence to pass verification:

**Step 1: Verify prerequisites**
```
:: Check Module 3.1 was completed
cd phases\phase-3-everyday\module-3.1-your-private-vault
verify.bat
:: If it fails, run exercise.bat first
```

**Step 2: Run the exercise**
```
cd phases\phase-3-everyday\module-3.6-digital-footprint
exercise.bat
```

The exercise will:
1. Call `system_health` and display all services and collections
2. Call `vault_list_categories` and show your vault organization
3. Call `search_knowledge` to find your own entries

**Step 3: If tools return empty results**
```
:: Check system health manually
python shared\utils\mcp-call.py system_health

:: Check vault categories manually
python shared\utils\mcp-call.py vault_list_categories

:: Search knowledge with a broad query
python shared\utils\mcp-call.py search_knowledge "{\"query\":\"family\"}"

:: If vault is empty, add a document first
python shared\utils\mcp-call.py vault_add "{\"content\":\"Test document for audit\",\"category\":\"personal\",\"title\":\"Audit Test\"}"
```

**Step 4: Verify**
```
verify.bat
```

**If verify fails on search_knowledge**: The search just needs to return any results. Try different queries — "family", "work", "values". The LegacyKnowledge collection has built-in content from the RAG.md and WISDOM-CORE.md files.
