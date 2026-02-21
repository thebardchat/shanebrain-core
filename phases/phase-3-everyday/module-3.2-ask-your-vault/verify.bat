@echo off
setlocal enabledelayedexpansion
title Module 3.2 Verify

:: ============================================================
:: MODULE 3.2 VERIFICATION
:: Checks: MCP reachable, vault has docs, vault_search returns
::         results, chat_with_shanebrain responds, response
::         contains actual content (not error)
:: Returns: ERRORLEVEL 0 = PASS, 1 = FAIL
:: ============================================================

set "PASS_COUNT=0"
set "FAIL_COUNT=0"
set "TOTAL_CHECKS=5"
set "MCP_CALL=%~dp0..\..\..\shared\utils\mcp-call.py"
set "TEMP_DIR=%TEMP%\module-3.2-verify"

if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%"

echo.
echo  ══════════════════════════════════════════════════════
echo   MODULE 3.2 VERIFICATION
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

:: --- CHECK 2: Vault has documents ---
echo  [CHECK 2/%TOTAL_CHECKS%] Vault contains documents
python "%MCP_CALL%" vault_list_categories > "%TEMP_DIR%\categories.txt" 2>&1
python -c "import json; d=json.load(open(r'%TEMP_DIR%\categories.txt')); total=sum(v for v in d.values() if isinstance(v,int)) if isinstance(d,dict) else len(d) if isinstance(d,list) else 0; print(total)" 2>nul > "%TEMP_DIR%\doc_count.txt"
set /p DOC_COUNT=<"%TEMP_DIR%\doc_count.txt"
if not defined DOC_COUNT set "DOC_COUNT=0"
if %DOC_COUNT% GEQ 1 (
    echo  [92m   PASS: Vault contains %DOC_COUNT% document(s)[0m
    set /a PASS_COUNT+=1
) else (
    echo  [91m   FAIL: Vault is empty[0m
    echo          Fix: Run Module 3.1 exercise.bat first to add documents
    set /a FAIL_COUNT+=1
)
echo.

:: --- CHECK 3: vault_search returns results ---
echo  [CHECK 3/%TOTAL_CHECKS%] Vault search returns results
python "%MCP_CALL%" vault_search "{\"query\":\"personal information\"}" > "%TEMP_DIR%\search.txt" 2>&1
if %errorlevel% EQU 0 (
    python -c "import json; d=json.load(open(r'%TEMP_DIR%\search.txt')); has_data=(len(d)>0 if isinstance(d,list) else bool(d.get('results',d.get('documents',d.get('text',''))))); print('OK' if has_data else 'EMPTY')" 2>nul > "%TEMP_DIR%\search_status.txt"
    set /p SEARCH_STATUS=<"%TEMP_DIR%\search_status.txt"
    if "!SEARCH_STATUS!"=="OK" (
        echo  [92m   PASS: Vault search returned results[0m
        set /a PASS_COUNT+=1
    ) else (
        echo  [91m   FAIL: Vault search returned empty results[0m
        echo          Fix: Ensure vault has documents (run Module 3.1 first)
        set /a FAIL_COUNT+=1
    )
) else (
    echo  [91m   FAIL: vault_search tool call failed[0m
    echo          Fix: Check MCP server is running
    set /a FAIL_COUNT+=1
)
echo.

:: --- CHECK 4: chat_with_shanebrain responds ---
echo  [CHECK 4/%TOTAL_CHECKS%] chat_with_shanebrain generates a response
echo   Asking: "What information do you have about me?"
python "%MCP_CALL%" chat_with_shanebrain "{\"message\":\"What information do you have about me?\"}" > "%TEMP_DIR%\chat.txt" 2>&1
if %errorlevel% EQU 0 (
    echo  [92m   PASS: chat_with_shanebrain responded[0m
    set /a PASS_COUNT+=1
) else (
    echo  [91m   FAIL: chat_with_shanebrain did not respond[0m
    echo          Fix: Check that Ollama is running (it generates the answers)
    set /a FAIL_COUNT+=1
)
echo.

:: --- CHECK 5: Response contains actual content (not error) ---
echo  [CHECK 5/%TOTAL_CHECKS%] Response contains actual content
python -c "import json; d=json.load(open(r'%TEMP_DIR%\chat.txt')); text=d.get('text',d.get('response',str(d))); has_content=len(text)>20 and 'error' not in text.lower()[:50]; print('OK' if has_content else 'ERROR')" 2>nul > "%TEMP_DIR%\content_status.txt"
set /p CONTENT_STATUS=<"%TEMP_DIR%\content_status.txt"
if "%CONTENT_STATUS%"=="OK" (
    echo  [92m   PASS: Response contains substantive content[0m
    set /a PASS_COUNT+=1
) else (
    echo  [91m   FAIL: Response was empty or contained an error[0m
    echo          Fix: Check Ollama is running and has a model loaded
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
    echo  [92m   MODULE 3.2 COMPLETE[0m
    echo  [92m   You proved: Your vault answers real questions.[0m
    echo  [92m   RAG retrieves your documents and generates[0m
    echo  [92m   grounded answers — no guessing, no internet.[0m
    echo.

    :: --- Update progress ---
    set "PROGRESS_FILE=%~dp0..\..\..\..\progress\user-progress.json"
    if exist "!PROGRESS_FILE!" (
        echo   {"module": "3.2", "status": "completed", "timestamp": "%date% %time%"} >> "!PROGRESS_FILE!.log"
    )

    echo   Next up: Module 3.3 — Write It Right
    echo   Your vault answers questions. Now make it write for you.
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
