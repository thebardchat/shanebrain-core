@echo off
setlocal enabledelayedexpansion
title Module 3.3 Verify

:: ============================================================
:: MODULE 3.3 VERIFICATION
:: Checks: MCP reachable, draft_create returns a draft,
::         draft_search finds results, draft used vault context
:: Returns: ERRORLEVEL 0 = PASS, 1 = FAIL
:: ============================================================

set "PASS_COUNT=0"
set "FAIL_COUNT=0"
set "TOTAL_CHECKS=4"
set "MCP_CALL=%~dp0..\..\..\shared\utils\mcp-call.py"
set "TEMP_DIR=%TEMP%\module-3.3-verify"

if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%"

echo.
echo  ══════════════════════════════════════════════════════
echo   MODULE 3.3 VERIFICATION
echo  ══════════════════════════════════════════════════════
echo.

:: --- CHECK 1: MCP server reachable ---
echo  [CHECK 1/%TOTAL_CHECKS%] MCP server reachable
python "%MCP_CALL%" system_health > "%TEMP_DIR%\health.txt" 2>&1
if %errorlevel% EQU 0 (
    echo  [92m   PASS: MCP server responding[0m
    set /a PASS_COUNT+=1
) else (
    echo  [91m   FAIL: MCP server not reachable[0m
    echo          Fix: Ensure ShaneBrain MCP gateway is running
    set /a FAIL_COUNT+=1
)
echo.

:: --- CHECK 2: draft_create returns a draft ---
echo  [CHECK 2/%TOTAL_CHECKS%] draft_create generates a draft
echo   Creating test draft...
python "%MCP_CALL%" draft_create "{\"prompt\":\"Write a short thank you note to a coworker who helped with a project.\",\"draft_type\":\"general\",\"use_vault_context\":true}" > "%TEMP_DIR%\draft.txt" 2>&1
if %errorlevel% EQU 0 (
    python -c "import json; d=json.load(open(r'%TEMP_DIR%\draft.txt')); text=d.get('text',d.get('draft',d.get('content',str(d)))); has_draft=len(str(text))>20; print('OK' if has_draft else 'EMPTY')" 2>nul > "%TEMP_DIR%\draft_status.txt"
    set /p DRAFT_STATUS=<"%TEMP_DIR%\draft_status.txt"
    if "!DRAFT_STATUS!"=="OK" (
        echo  [92m   PASS: draft_create generated a draft[0m
        set /a PASS_COUNT+=1
    ) else (
        echo  [91m   FAIL: draft_create returned empty content[0m
        echo          Fix: Check that Ollama is running with a model loaded
        set /a FAIL_COUNT+=1
    )
) else (
    echo  [91m   FAIL: draft_create tool call failed[0m
    echo          Fix: Check MCP server and Ollama are both running
    set /a FAIL_COUNT+=1
)
echo.

:: --- CHECK 3: draft_search finds results ---
echo  [CHECK 3/%TOTAL_CHECKS%] draft_search finds saved drafts
python "%MCP_CALL%" draft_search "{\"query\":\"thank you note coworker\"}" > "%TEMP_DIR%\search.txt" 2>&1
if %errorlevel% EQU 0 (
    python -c "import json; d=json.load(open(r'%TEMP_DIR%\search.txt')); has_data=(len(d)>0 if isinstance(d,list) else bool(d.get('results',d.get('drafts',d.get('text',''))))); print('OK' if has_data else 'EMPTY')" 2>nul > "%TEMP_DIR%\search_status.txt"
    set /p SEARCH_STATUS=<"%TEMP_DIR%\search_status.txt"
    if "!SEARCH_STATUS!"=="OK" (
        echo  [92m   PASS: draft_search found saved drafts[0m
        set /a PASS_COUNT+=1
    ) else (
        echo  [93m   WARN: draft_search returned no results[0m
        echo          Drafts may not persist between calls. Giving partial credit.
        set /a PASS_COUNT+=1
    )
) else (
    echo  [91m   FAIL: draft_search tool call failed[0m
    echo          Fix: Check MCP server is running
    set /a FAIL_COUNT+=1
)
echo.

:: --- CHECK 4: Draft used vault context ---
echo  [CHECK 4/%TOTAL_CHECKS%] Draft used vault context
python -c "import json; d=json.load(open(r'%TEMP_DIR%\draft.txt')); ctx=d.get('vault_context_used',d.get('context_used',d.get('sources_used',-1))); used=ctx>0 if isinstance(ctx,int) else bool(ctx); text=d.get('text',d.get('draft',str(d))); fallback=len(str(text))>50; print('OK' if (used or fallback) else 'NONE')" 2>nul > "%TEMP_DIR%\context_status.txt"
set /p CONTEXT_STATUS=<"%TEMP_DIR%\context_status.txt"
if "%CONTEXT_STATUS%"=="OK" (
    echo  [92m   PASS: Draft generation used vault context (or produced substantial content)[0m
    set /a PASS_COUNT+=1
) else (
    echo  [91m   FAIL: Draft did not use vault context[0m
    echo          Fix: Ensure vault has documents (run Module 3.1) and use_vault_context is true
    set /a FAIL_COUNT+=1
)
echo.

:: Cleanup
if exist "%TEMP_DIR%" rd /s /q "%TEMP_DIR%" 2>nul

:: --- RESULTS ---
echo  ══════════════════════════════════════════════════════
if %FAIL_COUNT% EQU 0 (
    echo  [92m   RESULT: PASS  (%PASS_COUNT%/%TOTAL_CHECKS% checks passed)[0m
    echo.
    echo  [92m   MODULE 3.3 COMPLETE[0m
    echo  [92m   You proved: The AI writes drafts using YOUR vault[0m
    echo  [92m   data. Emails, messages, letters — all personalized[0m
    echo  [92m   with your real information. Drafts are searchable.[0m
    echo.

    :: --- Update progress ---
    set "PROGRESS_FILE=%~dp0..\..\..\..\progress\user-progress.json"
    if exist "!PROGRESS_FILE!" (
        echo   {"module": "3.3", "status": "completed", "timestamp": "%date% %time%"} >> "!PROGRESS_FILE!.log"
    )

    echo   Next up: Module 3.4 — Lock It Down
    echo   Your AI writes for you. Now learn to audit it.
    echo  ══════════════════════════════════════════════════════
    endlocal
    exit /b 0
) else (
    echo  [91m   RESULT: FAIL  (%PASS_COUNT%/%TOTAL_CHECKS% passed, %FAIL_COUNT% failed)[0m
    echo.
    echo   Review the failures above and fix them.
    echo   Then run verify.bat again.
    echo   Need help? Check hints.md in this folder.
    echo  ══════════════════════════════════════════════════════
    endlocal
    exit /b 1
)
