@echo off
setlocal enabledelayedexpansion
title Module 3.5 Verify

:: ============================================================
:: MODULE 3.5 VERIFICATION — Daily Briefing
:: Checks: MCP reachable, DailyNote entries, search works,
::         briefing generates, briefing has real text
:: Returns: ERRORLEVEL 0 = PASS, 1 = FAIL
:: ============================================================

set "PASS_COUNT=0"
set "FAIL_COUNT=0"
set "TOTAL_CHECKS=5"
set "MCP_CALL=%~dp0..\..\..\shared\utils\mcp-call.py"
set "TEMP_DIR=%TEMP%\module-3.5-verify"
set "PROGRESS_FILE=%~dp0..\..\..\..\progress\user-progress.json"

if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%"

echo.
echo  ======================================================
echo   MODULE 3.5 VERIFICATION — Daily Briefing
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

:: --- CHECK 2: DailyNote has >= 3 entries ---
echo  [CHECK 2/%TOTAL_CHECKS%] DailyNote collection has at least 3 entries
python -c "import json; d=json.load(open(r'%TEMP_DIR%\health.json')); cols=d.get('collections',{}); count=cols.get('DailyNote',0); print(count)" > "%TEMP_DIR%\note_count.txt" 2>nul
set /p NOTE_COUNT=<"%TEMP_DIR%\note_count.txt"

if !NOTE_COUNT! GEQ 3 (
    echo  [92m   PASS: DailyNote has !NOTE_COUNT! entries[0m
    set /a PASS_COUNT+=1
) else (
    echo  [91m   FAIL: DailyNote has only !NOTE_COUNT! entries (need at least 3)[0m
    echo          Fix: Run exercise.bat to add journal, todo, and reminder entries
    set /a FAIL_COUNT+=1
)
echo.

:: --- CHECK 3: daily_note_search returns results ---
echo  [CHECK 3/%TOTAL_CHECKS%] daily_note_search returns results
python "%MCP_CALL%" daily_note_search "{\"query\":\"work tasks estimate\"}" > "%TEMP_DIR%\search_result.json" 2>nul
if %errorlevel% EQU 0 (
    python -c "import json; d=json.load(open(r'%TEMP_DIR%\search_result.json')); results=d.get('results',d.get('notes',[])); has=len(results)>0 if isinstance(results,list) else bool(results); err=d.get('error',''); print('OK' if has and not err else 'EMPTY')" > "%TEMP_DIR%\search_status.txt" 2>nul
    set /p SEARCH_STATUS=<"%TEMP_DIR%\search_status.txt"
    if "!SEARCH_STATUS!"=="OK" (
        echo  [92m   PASS: daily_note_search returned results[0m
        set /a PASS_COUNT+=1
    ) else (
        echo  [91m   FAIL: daily_note_search returned no results[0m
        echo          Fix: Run exercise.bat first to add notes, then search will find them
        set /a FAIL_COUNT+=1
    )
) else (
    echo  [91m   FAIL: daily_note_search call failed[0m
    echo          Fix: Check MCP server status
    set /a FAIL_COUNT+=1
)
echo.

:: --- CHECK 4: daily_briefing returns a briefing ---
echo  [CHECK 4/%TOTAL_CHECKS%] daily_briefing generates a briefing
python "%MCP_CALL%" daily_briefing > "%TEMP_DIR%\briefing.json" 2>nul
if %errorlevel% EQU 0 (
    echo  [92m   PASS: daily_briefing returned a response[0m
    set /a PASS_COUNT+=1
) else (
    echo  [91m   FAIL: daily_briefing call failed[0m
    echo          Fix: Make sure Ollama is running and has a model loaded
    set /a FAIL_COUNT+=1
)
echo.

:: --- CHECK 5: Briefing contains actual text (not error) ---
echo  [CHECK 5/%TOTAL_CHECKS%] Briefing contains actual content
python -c "import json; d=json.load(open(r'%TEMP_DIR%\briefing.json')); text=d.get('briefing',d.get('text',d.get('response',''))); has_text=len(str(text).strip())>20; has_error='error' in str(d).lower()[:100]; print('OK' if has_text and not has_error else 'EMPTY')" > "%TEMP_DIR%\briefing_status.txt" 2>nul
set /p BRIEFING_STATUS=<"%TEMP_DIR%\briefing_status.txt"

if "%BRIEFING_STATUS%"=="OK" (
    echo  [92m   PASS: Briefing contains real content[0m
    set /a PASS_COUNT+=1
) else (
    echo  [91m   FAIL: Briefing is empty or contains an error[0m
    echo          Fix: Ollama may need time to load. Wait 30 seconds and re-run verify.bat
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
    echo  [92m   Module 3.5 — Daily Briefing: COMPLETE[0m
    echo.
    echo  [92m   You proved:[0m
    echo  [92m   + Journal entries with mood tags[0m
    echo  [92m   + Todos tracked by your AI[0m
    echo  [92m   + Reminders stored for the future[0m
    echo  [92m   + AI-generated daily briefings work[0m
    echo.
    echo   Your AI is now your personal dispatcher.
    echo   Five minutes a day keeps the chaos away.
    echo.
    echo   Next: Module 3.6 — Digital Footprint
    echo  ======================================================

    :: --- Update progress ---
    if exist "!PROGRESS_FILE!" (
        echo   {"module": "3.5", "status": "completed", "timestamp": "%date% %time%"} >> "!PROGRESS_FILE!.log"
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
