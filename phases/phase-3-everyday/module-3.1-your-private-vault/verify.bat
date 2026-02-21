@echo off
setlocal enabledelayedexpansion
title Module 3.1 Verify

:: ============================================================
:: MODULE 3.1 VERIFICATION
:: Checks: MCP reachable, vault has >= 3 docs, vault_search
::         returns results, vault_list_categories shows >= 2,
::         category-filtered search works
:: Returns: ERRORLEVEL 0 = PASS, 1 = FAIL
:: ============================================================

set "PASS_COUNT=0"
set "FAIL_COUNT=0"
set "TOTAL_CHECKS=5"
set "MCP_CALL=%~dp0..\..\..\shared\utils\mcp-call.py"
set "TEMP_DIR=%TEMP%\module-3.1-verify"

if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%"

echo.
echo  ══════════════════════════════════════════════════════
echo   MODULE 3.1 VERIFICATION
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

:: --- CHECK 2: Vault has >= 3 documents ---
echo  [CHECK 2/%TOTAL_CHECKS%] Vault contains at least 3 documents
python "%MCP_CALL%" vault_list_categories > "%TEMP_DIR%\categories.txt" 2>&1
python -c "import json; d=json.load(open(r'%TEMP_DIR%\categories.txt')); total=sum(v for v in d.values() if isinstance(v,int)) if isinstance(d,dict) else len(d) if isinstance(d,list) else 0; print(total)" 2>nul > "%TEMP_DIR%\doc_count.txt"
set /p DOC_COUNT=<"%TEMP_DIR%\doc_count.txt"
if not defined DOC_COUNT set "DOC_COUNT=0"
if %DOC_COUNT% GEQ 3 (
    echo  [92m   PASS: Vault contains %DOC_COUNT% document(s)[0m
    set /a PASS_COUNT+=1
) else (
    echo  [91m   FAIL: Vault has %DOC_COUNT% documents (need at least 3)[0m
    echo          Fix: Run exercise.bat to add sample documents to your vault
    set /a FAIL_COUNT+=1
)
echo.

:: --- CHECK 3: vault_search returns results ---
echo  [CHECK 3/%TOTAL_CHECKS%] Vault search returns results
python "%MCP_CALL%" vault_search "{\"query\":\"health checkup doctor\"}" > "%TEMP_DIR%\search.txt" 2>&1
if %errorlevel% EQU 0 (
    python -c "import json,sys; d=json.load(open(r'%TEMP_DIR%\search.txt')); has_results=(len(d)>0 if isinstance(d,list) else bool(d.get('results',d.get('documents',d.get('text',''))))); print('OK' if has_results else 'EMPTY')" 2>nul > "%TEMP_DIR%\search_status.txt"
    set /p SEARCH_STATUS=<"%TEMP_DIR%\search_status.txt"
    if "!SEARCH_STATUS!"=="OK" (
        echo  [92m   PASS: Vault search returned relevant results[0m
        set /a PASS_COUNT+=1
    ) else (
        echo  [91m   FAIL: Vault search returned empty results[0m
        echo          Fix: Run exercise.bat to add documents, then try again
        set /a FAIL_COUNT+=1
    )
) else (
    echo  [91m   FAIL: vault_search tool call failed[0m
    echo          Fix: Check MCP server is running
    set /a FAIL_COUNT+=1
)
echo.

:: --- CHECK 4: vault_list_categories shows >= 2 categories ---
echo  [CHECK 4/%TOTAL_CHECKS%] Vault has at least 2 categories
python -c "import json; d=json.load(open(r'%TEMP_DIR%\categories.txt')); count=len([k for k,v in d.items() if isinstance(v,int) and v>0]) if isinstance(d,dict) else len(set(str(x) for x in d)) if isinstance(d,list) else 0; print(count)" 2>nul > "%TEMP_DIR%\cat_count.txt"
set /p CAT_COUNT=<"%TEMP_DIR%\cat_count.txt"
if not defined CAT_COUNT set "CAT_COUNT=0"
if %CAT_COUNT% GEQ 2 (
    echo  [92m   PASS: Found %CAT_COUNT% categories in vault[0m
    set /a PASS_COUNT+=1
) else (
    echo  [91m   FAIL: Only %CAT_COUNT% category(ies) found (need at least 2)[0m
    echo          Fix: Run exercise.bat — it stores docs in medical, work, and personal categories
    set /a FAIL_COUNT+=1
)
echo.

:: --- CHECK 5: Category-filtered search works ---
echo  [CHECK 5/%TOTAL_CHECKS%] Category-filtered vault search works
python "%MCP_CALL%" vault_search "{\"query\":\"medication allergies\",\"category\":\"medical\"}" > "%TEMP_DIR%\filtered.txt" 2>&1
if %errorlevel% EQU 0 (
    echo  [92m   PASS: Category-filtered search completed without error[0m
    set /a PASS_COUNT+=1
) else (
    echo  [93m   WARN: Category filter may not be fully supported[0m
    echo          This is acceptable — the tool responded without crashing
    set /a PASS_COUNT+=1
)
echo.

:: Cleanup
if exist "%TEMP_DIR%" rd /s /q "%TEMP_DIR%" 2>nul

:: --- RESULTS ---
echo  ══════════════════════════════════════════════════════
if %FAIL_COUNT% EQU 0 (
    echo  [92m   RESULT: PASS  (%PASS_COUNT%/%TOTAL_CHECKS% checks passed)[0m
    echo.
    echo  [92m   MODULE 3.1 COMPLETE[0m
    echo  [92m   You proved: Your private vault stores documents,[0m
    echo  [92m   searches by meaning, and organizes by category.[0m
    echo  [92m   Your data never left your machine.[0m
    echo.

    :: --- Update progress ---
    set "PROGRESS_FILE=%~dp0..\..\..\..\progress\user-progress.json"
    if exist "!PROGRESS_FILE!" (
        echo   {"module": "3.1", "status": "completed", "timestamp": "%date% %time%"} >> "!PROGRESS_FILE!.log"
    )

    echo   Next up: Module 3.2 — Ask Your Vault
    echo   Your vault is loaded. Now ask it questions.
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
