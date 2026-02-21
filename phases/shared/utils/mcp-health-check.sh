#!/usr/bin/env bash
set -e

# ============================================================
# MCP SERVER HEALTH CHECK (Linux)
# Checks ShaneBrain MCP server and displays system status
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MCP_CALL="$SCRIPT_DIR/mcp-call.py"
MCP_URL="http://localhost:8100/mcp"
TEMP_DIR="/tmp/mcp-health"
mkdir -p "$TEMP_DIR"

echo ""
echo "  ============================================"
echo "   ShaneBrain MCP Server Health Check"
echo "  ============================================"
echo ""

# ---- CHECK 1: MCP Server Reachable ----
echo "  [MCP SERVER]"
MCP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"health-check","version":"1.0"}}}' \
    "$MCP_URL" 2>/dev/null || echo "000")

if [ "$MCP_CODE" = "200" ]; then
    echo -e "    \e[92m  OK — MCP server responding on port 8100\e[0m"
else
    echo -e "    \e[91m  DOWN — MCP server not reachable at $MCP_URL\e[0m"
    echo -e "    \e[93m  Fix: cd weaviate-config && docker compose up -d mcp-server\e[0m"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# ---- CHECK 2: System Health via MCP ----
echo ""
echo "  [SERVICES]"

set +e
python3 "$MCP_CALL" system_health > "$TEMP_DIR/health.json" 2>/dev/null
HEALTH_RESULT=$?
set -e

if [ "$HEALTH_RESULT" -ne 0 ]; then
    echo -e "    \e[91m  Could not retrieve system health\e[0m"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Parse service statuses
python3 -c "
import json
d = json.load(open('$TEMP_DIR/health.json'))
svcs = d.get('services', {})
for k, v in svcs.items():
    status = v['status'] if isinstance(v, dict) else v
    print(f'   {k:12s} {status}')
" 2>/dev/null || echo "    (could not parse service status)"

echo ""
echo "  [COLLECTIONS]"
python3 -c "
import json
d = json.load(open('$TEMP_DIR/health.json'))
cols = d.get('collections', {})
for k, v in cols.items():
    print(f'   {k:20s} {v:>5} objects')
print(f\"   {'TOTAL':20s} {sum(cols.values()):>5} objects\")
" 2>/dev/null || echo "    (could not parse collection data)"

echo ""
echo "  ============================================"
echo -e "    \e[92mMCP server is operational\e[0m"
echo "  ============================================"
echo ""

rm -rf "$TEMP_DIR"
exit 0
