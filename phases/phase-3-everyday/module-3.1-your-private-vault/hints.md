# Module 3.1 Hints — Your Private Vault

## Level 1 — General Direction

- The MCP server must be running before you start. All vault tools talk to ShaneBrain through MCP.
- The exercise creates sample documents automatically — you don't need to write anything yourself
- Three document types get stored: medical, work, and personal. Each goes into a different category.
- If vault_search returns nothing, it usually means no documents have been stored yet
- Category filtering is a bonus feature — if it doesn't work, the main search still will

## Level 2 — Specific Guidance

- **"MCP server not reachable"**: The ShaneBrain gateway needs to be running. Check with: `python shared\utils\mcp-call.py system_health`
- **"Could not store document"**: The vault_add call failed. Check that the MCP server is up and Weaviate is running behind it. The MCP server handles the connection to Weaviate for you.
- **"Vault has 0 documents"**: The exercise didn't store anything. Run exercise.bat again and watch for errors during TASK 1. If vault_add fails, the MCP server logs will tell you why.
- **"Search returned empty results"**: Documents may not have embedded correctly. Try running exercise.bat again — sometimes the first attempt hits a cold model.
- **"Only 1 category found"**: One or more vault_add calls may have failed. Check the exercise output — each document should show a green PASS line.
- **Category filter not working**: Some versions of vault_search don't support the category parameter. That's OK for this module — verify.bat gives you a pass either way.

## Level 3 — The Answer

Complete sequence to get everything working:

**Step 1: Verify the MCP server**
```
python shared\utils\mcp-call.py system_health
```
You should see JSON with service status. If you get a connection error, start the ShaneBrain services first.

**Step 2: Run the exercise**
```
cd phases\phase-3-everyday\module-3.1-your-private-vault
exercise.bat
```
Watch for three green PASS lines during TASK 1. Each one means a document was stored.

**Step 3: Run verification**
```
verify.bat
```
All 5 checks should pass.

**If you need to start fresh**, you can add documents manually:
```
python shared\utils\mcp-call.py vault_add "{\"content\":\"Your text here\",\"category\":\"medical\",\"title\":\"My Doc\"}"
```

**Adding your own documents:**
1. Use vault_add with your real content
2. Pick a category: medical, work, personal, financial, legal
3. Give it a clear title so you recognize it later
4. Search with vault_search to verify it's findable
