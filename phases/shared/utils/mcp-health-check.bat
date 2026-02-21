@echo off
setlocal enabledelayedexpansion

:: ============================================================
:: MCP SERVER HEALTH CHECK
:: Checks ShaneBrain MCP server and displays system status
:: ============================================================

set "MCP_CALL=%~dp0mcp-call.py"
set "MCP_URL=http://localhost:8100/mcp"
set "TEMP_DIR=%TEMP%\mcp-health"
mkdir "%TEMP_DIR%" 2>nul

echo.
echo  ============================================
echo   ShaneBrain MCP Server Health Check
echo  ============================================
echo.

:: ---- CHECK 1: MCP Server Reachable ----
echo  [MCP SERVER]
curl -s -o nul -w "%%{http_code}" -X POST -H "Content-Type: application/json" -H "Accept: application/json, text/event-stream" -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2025-03-26\",\"capabilities\":{},\"clientInfo\":{\"name\":\"health-check\",\"version\":\"1.0\"}}}" "%MCP_URL%" > "%TEMP_DIR%\mcp_status.txt" 2>nul
set /p MCP_CODE=<"%TEMP_DIR%\mcp_status.txt"

if "%MCP_CODE%"=="200" (
    echo    [92m  OK — MCP server responding on port 8100[0m
) else (
    echo    [91m  DOWN — MCP server not reachable at %MCP_URL%[0m
    echo    [93m  Fix: cd weaviate-config ^&^& docker compose up -d mcp-server[0m
    rd /s /q "%TEMP_DIR%" 2>nul
    exit /b 1
)

:: ---- CHECK 2: System Health via MCP ----
echo.
echo  [SERVICES]
python "%MCP_CALL%" system_health > "%TEMP_DIR%\health.json" 2>nul

if !errorlevel! NEQ 0 (
    echo    [91m  Could not retrieve system health[0m
    rd /s /q "%TEMP_DIR%" 2>nul
    exit /b 1
)

:: Parse service statuses
python -c "import json; d=json.load(open(r'%TEMP_DIR%\health.json')); svcs=d.get('services',{}); [print(f'   {k:12s} {v[\"status\"]}') for k,v in svcs.items()]" 2>nul

echo.
echo  [COLLECTIONS]
python -c "import json; d=json.load(open(r'%TEMP_DIR%\health.json')); cols=d.get('collections',{}); total=0; [print(f'   {k:20s} {v:>5} objects') or total for k,v in cols.items()]; print(f'   {\"TOTAL\":20s} {sum(cols.values()):>5} objects')" 2>nul

echo.
echo  ============================================
echo    [92mMCP server is operational[0m
echo  ============================================
echo.

rd /s /q "%TEMP_DIR%" 2>nul
exit /b 0
