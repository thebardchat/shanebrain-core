@echo off
setlocal enabledelayedexpansion
title Module 3.7 Verify — Phase 3 Capstone

:: ============================================================
:: MODULE 3.7 VERIFICATION — PHASE 3 CAPSTONE
:: Checks: MCP reachable, system_health OK, search_knowledge,
::         get_top_friends, vault_search, chat_with_shanebrain
:: Returns: ERRORLEVEL 0 = PASS, 1 = FAIL
:: ============================================================

set "PASS_COUNT=0"
set "FAIL_COUNT=0"
set "TOTAL_CHECKS=6"
set "MCP_CALL=%~dp0..\..\..\shared\utils\mcp-call.py"
set "TEMP_DIR=%TEMP%\module-3.7-verify"
set "PROGRESS_FILE=%~dp0..\..\..\..\progress\user-progress.json"

if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%"

echo.
echo  ======================================================
echo   MODULE 3.7 VERIFICATION — PHASE 3 CAPSTONE
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

:: --- CHECK 2: system_health shows services and collections ---
echo  [CHECK 2/%TOTAL_CHECKS%] system_health returns valid data
python -c "import json; d=json.load(open(r'%TEMP_DIR%\health.json')); cols=d.get('collections',{}); svcs=d.get('services',{}); ok=len(cols)>0 and len(svcs)>0; print('OK' if ok else 'EMPTY')" > "%TEMP_DIR%\health_status.txt" 2>nul
set /p HEALTH_STATUS=<"%TEMP_DIR%\health_status.txt"

if "%HEALTH_STATUS%"=="OK" (
    echo  [92m   PASS: system_health returned services and collections[0m
    set /a PASS_COUNT+=1
) else (
    echo  [91m   FAIL: system_health returned incomplete data[0m
    echo          Fix: Check that Weaviate and Ollama are running
    set /a FAIL_COUNT+=1
)
echo.

:: --- CHECK 3: search_knowledge returns results ---
echo  [CHECK 3/%TOTAL_CHECKS%] search_knowledge returns results
python "%MCP_CALL%" search_knowledge "{\"query\":\"family values\"}" > "%TEMP_DIR%\knowledge.json" 2>nul
if %errorlevel% EQU 0 (
    python -c "import json; d=json.load(open(r'%TEMP_DIR%\knowledge.json')); results=d.get('results',d.get('knowledge',[])); has=len(results)>0 if isinstance(results,list) else bool(results); err=d.get('error',''); print('OK' if has and not err else 'EMPTY')" > "%TEMP_DIR%\know_status.txt" 2>nul
    set /p KNOW_STATUS=<"%TEMP_DIR%\know_status.txt"
    if "!KNOW_STATUS!"=="OK" (
        echo  [92m   PASS: search_knowledge returned results[0m
        set /a PASS_COUNT+=1
    ) else (
        echo  [91m   FAIL: search_knowledge returned no results[0m
        echo          Fix: LegacyKnowledge collection may be empty
        set /a FAIL_COUNT+=1
    )
) else (
    echo  [91m   FAIL: search_knowledge call failed[0m
    echo          Fix: Check MCP server status
    set /a FAIL_COUNT+=1
)
echo.

:: --- CHECK 4: get_top_friends returns results ---
echo  [CHECK 4/%TOTAL_CHECKS%] get_top_friends returns results
python "%MCP_CALL%" get_top_friends > "%TEMP_DIR%\friends.json" 2>nul
if %errorlevel% EQU 0 (
    python -c "import json; d=json.load(open(r'%TEMP_DIR%\friends.json')); friends=d.get('friends',d.get('results',[])); has=len(friends)>0 if isinstance(friends,list) else bool(friends); err=d.get('error',''); print('OK' if has and not err else 'EMPTY')" > "%TEMP_DIR%\friend_status.txt" 2>nul
    set /p FRIEND_STATUS=<"%TEMP_DIR%\friend_status.txt"
    if "!FRIEND_STATUS!"=="OK" (
        echo  [92m   PASS: get_top_friends returned profiles[0m
        set /a PASS_COUNT+=1
    ) else (
        echo  [91m   FAIL: get_top_friends returned no profiles[0m
        echo          Fix: FriendProfile collection needs entries. Add friend profiles via MCP
        set /a FAIL_COUNT+=1
    )
) else (
    echo  [91m   FAIL: get_top_friends call failed[0m
    echo          Fix: Check MCP server status
    set /a FAIL_COUNT+=1
)
echo.

:: --- CHECK 5: vault_search returns results ---
echo  [CHECK 5/%TOTAL_CHECKS%] vault_search returns results
python "%MCP_CALL%" vault_search "{\"query\":\"personal documents\"}" > "%TEMP_DIR%\vault.json" 2>nul
if %errorlevel% EQU 0 (
    python -c "import json; d=json.load(open(r'%TEMP_DIR%\vault.json')); results=d.get('results',d.get('documents',[])); has=len(results)>0 if isinstance(results,list) else bool(results); err=d.get('error',''); print('OK' if has and not err else 'EMPTY')" > "%TEMP_DIR%\vault_status.txt" 2>nul
    set /p VAULT_STATUS=<"%TEMP_DIR%\vault_status.txt"
    if "!VAULT_STATUS!"=="OK" (
        echo  [92m   PASS: vault_search returned documents[0m
        set /a PASS_COUNT+=1
    ) else (
        echo  [91m   FAIL: vault_search returned no documents[0m
        echo          Fix: Complete Module 3.1 to add vault documents first
        set /a FAIL_COUNT+=1
    )
) else (
    echo  [91m   FAIL: vault_search call failed[0m
    echo          Fix: Check MCP server status
    set /a FAIL_COUNT+=1
)
echo.

:: --- CHECK 6: chat_with_shanebrain generates a response ---
echo  [CHECK 6/%TOTAL_CHECKS%] chat_with_shanebrain generates a response
echo   Talking to your AI... (this may take a moment)
python "%MCP_CALL%" chat_with_shanebrain "{\"message\":\"What do you know about me?\"}" > "%TEMP_DIR%\chat.json" 2>nul
if %errorlevel% EQU 0 (
    python -c "import json; d=json.load(open(r'%TEMP_DIR%\chat.json')); text=d.get('response',d.get('text',d.get('message',''))); has=len(str(text).strip())>20; err='error' in str(d).lower()[:100]; print('OK' if has and not err else 'EMPTY')" > "%TEMP_DIR%\chat_status.txt" 2>nul
    set /p CHAT_STATUS=<"%TEMP_DIR%\chat_status.txt"
    if "!CHAT_STATUS!"=="OK" (
        echo  [92m   PASS: chat_with_shanebrain generated a response[0m
        set /a PASS_COUNT+=1
    ) else (
        echo  [91m   FAIL: chat_with_shanebrain returned empty or error[0m
        echo          Fix: Ollama may need time to load. Wait 30 seconds and retry
        set /a FAIL_COUNT+=1
    )
) else (
    echo  [91m   FAIL: chat_with_shanebrain call failed[0m
    echo          Fix: Make sure Ollama is running and has a model loaded
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
    echo  [92m   ██████╗ ██╗  ██╗ █████╗ ███████╗███████╗    ██████╗ [0m
    echo  [92m   ██╔══██╗██║  ██║██╔══██╗██╔════╝██╔════╝    ╚════██╗[0m
    echo  [92m   ██████╔╝███████║███████║███████╗█████╗       █████╔╝[0m
    echo  [92m   ██╔═══╝ ██╔══██║██╔══██║╚════██║██╔══╝       ╚═══██╗[0m
    echo  [92m   ██║     ██║  ██║██║  ██║███████║███████╗    ██████╔╝[0m
    echo  [92m   ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝    ╚═════╝ [0m
    echo.
    echo  [92m    ██████╗ ██████╗ ███╗   ███╗██████╗ ██╗     ███████╗████████╗███████╗[0m
    echo  [92m   ██╔════╝██╔═══██╗████╗ ████║██╔══██╗██║     ██╔════╝╚══██╔══╝██╔════╝[0m
    echo  [92m   ██║     ██║   ██║██╔████╔██║██████╔╝██║     █████╗     ██║   █████╗  [0m
    echo  [92m   ██║     ██║   ██║██║╚██╔╝██║██╔═══╝ ██║     ██╔══╝     ██║   ██╔══╝  [0m
    echo  [92m   ╚██████╗╚██████╔╝██║ ╚═╝ ██║██║     ███████╗███████╗   ██║   ███████╗[0m
    echo  [92m    ╚═════╝ ╚═════╝ ╚═╝     ╚═╝╚═╝     ╚══════╝╚══════╝   ╚═╝   ╚══════╝[0m
    echo.
    echo  [92m   PHASE 3 COMPLETE[0m
    echo  [92m   STATUS: EVERYDAY USER[0m
    echo.
    echo  [92m   You proved:[0m
    echo  [92m   + Store documents in a private vault[0m
    echo  [92m   + Answer questions from personal data[0m
    echo  [92m   + Write drafts with vault context[0m
    echo  [92m   + Lock down with security controls[0m
    echo  [92m   + Journal daily with AI briefings[0m
    echo  [92m   + Audit your digital footprint[0m
    echo  [92m   + Map your relationship network[0m
    echo  [92m   + Converse with your personal AI[0m
    echo.
    echo   Phase 1 made you a BUILDER.
    echo   Phase 2 made you an OPERATOR.
    echo   Phase 3 made you an EVERYDAY USER.
    echo.
    echo   Your AI runs on your hardware, holds your data,
    echo   and answers to you. Nobody else.
    echo.
    echo   Next: Phase 4 — LEGACY
    echo   Build something that outlasts you.
    echo  ======================================================

    :: --- Update progress ---
    if exist "!PROGRESS_FILE!" (
        echo   {"module": "3.7", "status": "completed", "phase": "3", "timestamp": "%date% %time%"} >> "!PROGRESS_FILE!.log"
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
