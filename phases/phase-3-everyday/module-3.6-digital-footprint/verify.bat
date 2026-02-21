@echo off
setlocal enabledelayedexpansion
title Module 3.6 Verify

:: ============================================================
:: MODULE 3.6 VERIFICATION — Digital Footprint
:: Checks: MCP reachable, system_health shows collections,
::         vault_list_categories returns data, search_knowledge
::         returns results
:: Returns: ERRORLEVEL 0 = PASS, 1 = FAIL
:: ============================================================

set "PASS_COUNT=0"
set "FAIL_COUNT=0"
set "TOTAL_CHECKS=4"
set "MCP_CALL=%~dp0..\..\..\shared\utils\mcp-call.py"
set "TEMP_DIR=%TEMP%\module-3.6-verify"
set "PROGRESS_FILE=%~dp0..\..\..\..\progress\user-progress.json"

if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%"

echo.
echo  ======================================================
echo   MODULE 3.6 VERIFICATION — Digital Footprint
echo  ======================================================
echo.

:: --- CHECK 1: MCP Server Reachable ---
echo  [CHECK 1/%TOTAL_CHECKS%] MCP server reachable
python "%MCP_CALL%" system_health > "%TEMP_DIR%\health.json" 2>nul
if %errorlevel% EQU 0 (
    echo  [92m   PASS: MCP server responding[0m
    set /a PASS_COUNT+=1
) else (
    echo  [91m   FAIL: MCP server not reachable[0m
    echo          Fix: Make sure the MCP server is running on port 8100
    set /a FAIL_COUNT+=1
)
echo.

:: --- CHECK 2: system_health shows collection counts ---
echo  [CHECK 2/%TOTAL_CHECKS%] system_health shows collection counts
python -c "import json; d=json.load(open(r'%TEMP_DIR%\health.json')); cols=d.get('collections',{}); print('OK' if len(cols)>0 else 'EMPTY')" > "%TEMP_DIR%\health_status.txt" 2>nul
set /p HEALTH_STATUS=<"%TEMP_DIR%\health_status.txt"

if "%HEALTH_STATUS%"=="OK" (
    echo  [92m   PASS: system_health returned collection data[0m
    python -c "import json; d=json.load(open(r'%TEMP_DIR%\health.json')); cols=d.get('collections',{}); total=sum(cols.values()); print(f'          {len(cols)} collections, {total} total objects')" 2>nul
    set /a PASS_COUNT+=1
) else (
    echo  [91m   FAIL: system_health returned no collection data[0m
    echo          Fix: Weaviate may be starting up. Wait 30 seconds and retry
    set /a FAIL_COUNT+=1
)
echo.

:: --- CHECK 3: vault_list_categories returns data ---
echo  [CHECK 3/%TOTAL_CHECKS%] vault_list_categories returns category data
python "%MCP_CALL%" vault_list_categories > "%TEMP_DIR%\categories.json" 2>nul
if %errorlevel% EQU 0 (
    python -c "import json; d=json.load(open(r'%TEMP_DIR%\categories.json')); cats=d.get('categories',d); has_data=len(cats)>0 if isinstance(cats,(dict,list)) else bool(cats); print('OK' if has_data else 'EMPTY')" > "%TEMP_DIR%\cat_status.txt" 2>nul
    set /p CAT_STATUS=<"%TEMP_DIR%\cat_status.txt"
    if "!CAT_STATUS!"=="OK" (
        echo  [92m   PASS: vault_list_categories returned data[0m
        set /a PASS_COUNT+=1
    ) else (
        echo  [91m   FAIL: vault_list_categories returned empty[0m
        echo          Fix: Complete Module 3.1 first to add vault documents
        set /a FAIL_COUNT+=1
    )
) else (
    echo  [91m   FAIL: vault_list_categories call failed[0m
    echo          Fix: Check MCP server status
    set /a FAIL_COUNT+=1
)
echo.

:: --- CHECK 4: search_knowledge returns results ---
echo  [CHECK 4/%TOTAL_CHECKS%] search_knowledge returns results
python "%MCP_CALL%" search_knowledge "{\"query\":\"family values\"}" > "%TEMP_DIR%\knowledge.json" 2>nul
if %errorlevel% EQU 0 (
    python -c "import json; d=json.load(open(r'%TEMP_DIR%\knowledge.json')); results=d.get('results',d.get('knowledge',[])); has=len(results)>0 if isinstance(results,list) else bool(results); err=d.get('error',''); print('OK' if has and not err else 'EMPTY')" > "%TEMP_DIR%\know_status.txt" 2>nul
    set /p KNOW_STATUS=<"%TEMP_DIR%\know_status.txt"
    if "!KNOW_STATUS!"=="OK" (
        echo  [92m   PASS: search_knowledge returned results[0m
        set /a PASS_COUNT+=1
    ) else (
        echo  [91m   FAIL: search_knowledge returned no results[0m
        echo          Fix: The LegacyKnowledge collection may be empty. Add knowledge entries first
        set /a FAIL_COUNT+=1
    )
) else (
    echo  [91m   FAIL: search_knowledge call failed[0m
    echo          Fix: Check MCP server status
    set /a FAIL_COUNT+=1
)
echo.

:: Cleanup
if exist "%TEMP_DIR%" rd /s /q "%TEMP_DIR%" 2>nul

:: --- RESULTS ---
echo  ======================================================
if %FAIL_COUNT% EQU 0 (
    echo.
    echo  [92m   RESULT: PASS  (%PASS_COUNT%/%TOTAL_CHECKS% checks passed)[0m
    echo.
    echo  [92m   Module 3.6 — Digital Footprint: COMPLETE[0m
    echo.
    echo  [92m   You proved:[0m
    echo  [92m   + System health gives full infrastructure visibility[0m
    echo  [92m   + Vault categories show data organization[0m
    echo  [92m   + Knowledge search reveals what the AI knows[0m
    echo  [92m   + You can audit your digital footprint anytime[0m
    echo.
    echo   Know your system. Trust your system.
    echo   Audit regularly — three calls, five minutes.
    echo.
    echo   Next: Module 3.7 — Family Dashboard (Capstone)
    echo  ======================================================

    :: --- Update progress ---
    if exist "!PROGRESS_FILE!" (
        echo   {"module": "3.6", "status": "completed", "timestamp": "%date% %time%"} >> "!PROGRESS_FILE!.log"
    )

    endlocal
    exit /b 0
) else (
    echo  [91m   RESULT: FAIL  (%PASS_COUNT%/%TOTAL_CHECKS% passed, %FAIL_COUNT% failed)[0m
    echo.
    echo   Review the failures above and fix them.
    echo   Then run verify.bat again.
    echo   Need help? Check hints.md in this folder.
    echo  ======================================================
    endlocal
    exit /b 1
)
