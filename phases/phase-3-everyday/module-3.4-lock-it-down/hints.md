# Module 3.4 Hints — Lock It Down

## Level 1 — General Direction

- This module has NO prerequisites — you can run it even without completing 3.1, 3.2, or 3.3
- All three tools (system_health, security_log_search, privacy_audit_search) just need the MCP server running
- Empty search results are NORMAL and EXPECTED. SecurityLog and PrivacyAudit collections may have zero entries on a fresh system.
- The point is learning WHERE to look, not finding problems. Clean logs are good logs.
- If the MCP server is running, all four verify checks should pass

## Level 2 — Specific Guidance

- **"MCP server not reachable"**: The ShaneBrain gateway needs to be running. This is the same check as every other module. Test with: `python shared\utils\mcp-call.py system_health`
- **"system_health returned invalid data"**: The MCP server responded but the data wasn't valid JSON. This usually means the server is starting up. Wait 10 seconds and try again.
- **"security_log_search call failed"**: The SecurityLog collection might not exist in Weaviate. On a fresh ShaneBrain install, it may need to be created. The MCP server should handle this automatically, but if not, the error message will say "class not found."
- **"privacy_audit_search call failed"**: Same as above but for the PrivacyAudit collection. These are optional collections that get created when the system starts logging events.
- **Results show errors about "class not found"**: This means the Weaviate collection doesn't exist yet. That's OK — verify.bat gives you a pass anyway, since the tool ran without crashing.
- **Want to see actual log entries?**: Try running other modules first (3.1, 3.2, 3.3) to generate some activity, then come back and search the audit trails again.

## Level 3 — The Answer

Complete sequence to get everything working:

**Step 1: Verify the MCP server**
```
python shared\utils\mcp-call.py system_health
```
You should see JSON with service status and collection counts. If you get a connection error, start ShaneBrain services.

**Step 2: Run the exercise**
```
cd phases\phase-3-everyday\module-3.4-lock-it-down
exercise.bat
```
All three tasks should show green PASS or CLEAN lines. Empty results are expected.

**Step 3: Run verification**
```
verify.bat
```
All 4 checks should pass.

**If security_log_search or privacy_audit_search fail with "class not found":**

The collections may not exist yet. You can create them manually, but it's not required for passing this module. The verify script gives you a pass if the tool runs without crashing, even if the collection is empty or missing.

**Quick audit commands for daily use:**
```
:: Health check (daily)
python shared\utils\mcp-call.py system_health

:: Security scan (weekly)
python shared\utils\mcp-call.py security_log_search "{\"query\":\"failed login\"}"
python shared\utils\mcp-call.py security_log_search "{\"query\":\"unauthorized\"}"

:: Privacy audit (monthly)
python shared\utils\mcp-call.py privacy_audit_search "{\"query\":\"data access\"}"
python shared\utils\mcp-call.py privacy_audit_search "{\"query\":\"export\"}"
```
