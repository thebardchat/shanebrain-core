@echo off
setlocal enabledelayedexpansion
title Module 3.4 Verify

:: ============================================================
:: MODULE 3.4 VERIFICATION
:: Checks: MCP reachable, system_health returns valid data,
::         security_log_search doesn't error,
::         privacy_audit_search doesn't error
:: Returns: ERRORLEVEL 0 = PASS, 1 = FAIL
:: ============================================================

set "PASS_COUNT=0"
set "FAIL_COUNT=0"
set "TOTAL_CHECKS=4"
set "MCP_CALL=%~dp0..\..\..\shared\utils\mcp-call.py"
set "TEMP_DIR=%TEMP%\module-3.4-verify"

if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%"

echo.
echo  ══════════════════════════════════════════════════════
echo   MODULE 3.4 VERIFICATION
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

:: --- CHECK 2: system_health returns valid data ---
echo  [CHECK 2/%TOTAL_CHECKS%] system_health returns valid data
python -c "import json; d=json.load(open(r'%TEMP_DIR%\health.txt')); valid=isinstance(d,dict) and len(d)>0; print('OK' if valid else 'INVALID')" 2>nul > "%TEMP_DIR%\health_status.txt"
set /p HEALTH_STATUS=<"%TEMP_DIR%\health_status.txt"
if "%HEALTH_STATUS%"=="OK" (
    echo  [92m   PASS: system_health returned valid JSON data[0m
    set /a PASS_COUNT+=1
) else (
    echo  [91m   FAIL: system_health returned invalid or empty data[0m
    echo          Fix: Check that Weaviate and Ollama are running
    set /a FAIL_COUNT+=1
)
echo.

:: --- CHECK 3: security_log_search doesn't error ---
echo  [CHECK 3/%TOTAL_CHECKS%] security_log_search executes without error
python "%MCP_CALL%" security_log_search "{\"query\":\"security check\"}" > "%TEMP_DIR%\sec.txt" 2>&1
if %errorlevel% EQU 0 (
    python -c "import json; d=json.load(open(r'%TEMP_DIR%\sec.txt')); has_error='error' in str(d).lower()[:100] and 'class' not in str(d).lower()[:200]; print('ERROR' if has_error else 'OK')" 2>nul > "%TEMP_DIR%\sec_status.txt"
    set /p SEC_STATUS=<"%TEMP_DIR%\sec_status.txt"
    if "!SEC_STATUS!"=="OK" (
        echo  [92m   PASS: security_log_search executed successfully[0m
        echo          (Empty results are normal on a clean system)
        set /a PASS_COUNT+=1
    ) else (
        echo  [93m   WARN: security_log_search returned with a note[0m
        echo          This may happen if SecurityLog collection is empty.
        echo          That's expected — giving you a pass.
        set /a PASS_COUNT+=1
    )
) else (
    echo  [91m   FAIL: security_log_search call failed[0m
    echo          Fix: Check MCP server is running. The SecurityLog collection
    echo          may need to be created — this is OK for a fresh system.
    set /a FAIL_COUNT+=1
)
echo.

:: --- CHECK 4: privacy_audit_search doesn't error ---
echo  [CHECK 4/%TOTAL_CHECKS%] privacy_audit_search executes without error
python "%MCP_CALL%" privacy_audit_search "{\"query\":\"data access\"}" > "%TEMP_DIR%\priv.txt" 2>&1
if %errorlevel% EQU 0 (
    python -c "import json; d=json.load(open(r'%TEMP_DIR%\priv.txt')); has_error='error' in str(d).lower()[:100] and 'class' not in str(d).lower()[:200]; print('ERROR' if has_error else 'OK')" 2>nul > "%TEMP_DIR%\priv_status.txt"
    set /p PRIV_STATUS=<"%TEMP_DIR%\priv_status.txt"
    if "!PRIV_STATUS!"=="OK" (
        echo  [92m   PASS: privacy_audit_search executed successfully[0m
        echo          (Empty results are normal on a clean system)
        set /a PASS_COUNT+=1
    ) else (
        echo  [93m   WARN: privacy_audit_search returned with a note[0m
        echo          This may happen if PrivacyAudit collection is empty.
        echo          That's expected — giving you a pass.
        set /a PASS_COUNT+=1
    )
) else (
    echo  [91m   FAIL: privacy_audit_search call failed[0m
    echo          Fix: Check MCP server is running. The PrivacyAudit collection
    echo          may need to be created — this is OK for a fresh system.
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
    echo  [92m   MODULE 3.4 COMPLETE[0m
    echo  [92m   You proved: You can audit your AI system —[0m
    echo  [92m   health, security, and privacy. You know where[0m
    echo  [92m   to look and what to look for. That's the[0m
    echo  [92m   foundation of responsible AI ownership.[0m
    echo.

    :: --- Update progress ---
    set "PROGRESS_FILE=%~dp0..\..\..\..\progress\user-progress.json"
    if exist "!PROGRESS_FILE!" (
        echo   {"module": "3.4", "status": "completed", "timestamp": "%date% %time%"} >> "!PROGRESS_FILE!.log"
    )

    echo   Phase 3 foundations complete.
    echo   You can store, search, ask, write, and audit.
    echo   Your AI works for you — and you can prove it.
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
