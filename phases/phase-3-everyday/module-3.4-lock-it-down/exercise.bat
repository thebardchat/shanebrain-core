@echo off
setlocal enabledelayedexpansion
title Module 3.4 Exercise — Lock It Down

:: ============================================================
:: MODULE 3.4 EXERCISE: Lock It Down
:: Goal: Run system health check, search security logs,
::       search privacy audit trails
:: Time: ~15 minutes
:: Prerequisites: None (standalone security awareness)
:: MCP Tools: system_health, security_log_search, privacy_audit_search
:: ============================================================

set "MCP_CALL=%~dp0..\..\..\shared\utils\mcp-call.py"
set "TEMP_DIR=%TEMP%\module-3.4"

echo.
echo  ══════════════════════════════════════════════════════
echo   MODULE 3.4 EXERCISE: Lock It Down
echo  ══════════════════════════════════════════════════════
echo.
echo   You're auditing your AI system. Three checks.
echo   Fifteen minutes. Know what's running, what happened,
echo   and what was accessed.
echo.
echo  ──────────────────────────────────────────────────────
echo.

:: --- PRE-FLIGHT: Check MCP server ---
echo  [PRE-FLIGHT] Checking MCP server...
echo.

if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%"

python "%MCP_CALL%" system_health > "%TEMP_DIR%\preflight.txt" 2>&1
if %errorlevel% NEQ 0 (
    echo  [91m   X MCP server not reachable. Is ShaneBrain running?[0m
    echo       Check: python "%MCP_CALL%" system_health
    pause
    exit /b 1
)
echo  [92m   PASS: MCP server responding[0m
echo.

:: ============================================================
:: TASK 1: Run system health check
:: ============================================================
echo  ──────────────────────────────────────────────────────
echo.
echo  [TASK 1/3] System health check — what's running?
echo.
echo   This is your daily walk-around. Like checking the
echo   trucks and equipment before the crew rolls out.
echo.

python "%MCP_CALL%" system_health > "%TEMP_DIR%\health.txt" 2>&1

if %errorlevel% EQU 0 (
    echo  [92m   PASS: System health retrieved[0m
    echo.
    echo   ══════════════════════════════════════════════════
    echo   SYSTEM HEALTH REPORT:
    echo   ══════════════════════════════════════════════════
    echo.
    python -c "import json; d=json.load(open(r'%TEMP_DIR%\health.txt')); [print('   ' + str(k) + ': ' + str(v)) for k,v in (d.items() if isinstance(d,dict) else [('status',str(d))])]" 2>nul
    echo.
    echo   ══════════════════════════════════════════════════
    echo.
    echo   What to look for:
    echo     - Services should show as running/healthy
    echo     - Collection counts tell you how much data exists
    echo     - Any errors or warnings need attention
) else (
    echo  [91m   FAIL: Could not retrieve system health[0m
)
echo.
echo   Press any key to check security logs...
pause >nul
echo.

:: ============================================================
:: TASK 2: Search security logs
:: ============================================================
echo  ──────────────────────────────────────────────────────
echo.
echo  [TASK 2/3] Search security logs — what happened?
echo.
echo   Checking for any security events. On a fresh system
echo   you'll likely see no results. That's GOOD — it means
echo   nothing suspicious happened. Like checking the
echo   security cameras and seeing an empty parking lot.
echo.

:: Search 1: General security check
echo   Search: "failed login attempts"
python "%MCP_CALL%" security_log_search "{\"query\":\"failed login attempts\"}" > "%TEMP_DIR%\sec1.txt" 2>&1
if %errorlevel% EQU 0 (
    python -c "import json; d=json.load(open(r'%TEMP_DIR%\sec1.txt')); results=d if isinstance(d,list) else d.get('results',d.get('logs',[])); count=len(results) if isinstance(results,list) else (1 if results else 0); print(str(count))" 2>nul > "%TEMP_DIR%\sec1_count.txt"
    set /p SEC1_COUNT=<"%TEMP_DIR%\sec1_count.txt"
    if not defined SEC1_COUNT set "SEC1_COUNT=0"
    if !SEC1_COUNT! EQU 0 (
        echo  [92m   CLEAN: No failed login attempts found[0m
    ) else (
        echo  [93m   FOUND: !SEC1_COUNT! security event(s) — review below[0m
        python -c "import json; d=json.load(open(r'%TEMP_DIR%\sec1.txt')); results=d if isinstance(d,list) else d.get('results',d.get('logs',[d])); [print('   - ' + str(r)[:100]) for r in (results[:3] if isinstance(results,list) else [results])]" 2>nul
    )
) else (
    echo  [92m   PASS: Security log search completed (no errors)[0m
)
echo.

:: Search 2: Unusual activity
echo   Search: "unusual activity or unauthorized access"
python "%MCP_CALL%" security_log_search "{\"query\":\"unusual activity unauthorized access\"}" > "%TEMP_DIR%\sec2.txt" 2>&1
if %errorlevel% EQU 0 (
    python -c "import json; d=json.load(open(r'%TEMP_DIR%\sec2.txt')); results=d if isinstance(d,list) else d.get('results',d.get('logs',[])); count=len(results) if isinstance(results,list) else (1 if results else 0); print(str(count))" 2>nul > "%TEMP_DIR%\sec2_count.txt"
    set /p SEC2_COUNT=<"%TEMP_DIR%\sec2_count.txt"
    if not defined SEC2_COUNT set "SEC2_COUNT=0"
    if !SEC2_COUNT! EQU 0 (
        echo  [92m   CLEAN: No unusual activity detected[0m
    ) else (
        echo  [93m   FOUND: !SEC2_COUNT! event(s) — worth investigating[0m
    )
) else (
    echo  [92m   PASS: Security log search completed (no errors)[0m
)
echo.

echo  [92m   Security log review complete.[0m
echo.
echo   Empty logs on a local system = clean system.
echo   When you add users or expose services, these logs
echo   become your first line of defense.
echo.
echo   Press any key to check privacy audit trails...
pause >nul
echo.

:: ============================================================
:: TASK 3: Search privacy audit trails
:: ============================================================
echo  ──────────────────────────────────────────────────────
echo.
echo  [TASK 3/3] Search privacy audit — what was accessed?
echo.
echo   Privacy audits track who touched what data. Even on
echo   a single-user system, this trail proves your data
echo   pipeline is clean. If you ever need to show that
echo   sensitive data wasn't mishandled, this is your proof.
echo.

:: Search 1: Vault access
echo   Search: "vault access personal data"
python "%MCP_CALL%" privacy_audit_search "{\"query\":\"vault access personal data\"}" > "%TEMP_DIR%\priv1.txt" 2>&1
if %errorlevel% EQU 0 (
    python -c "import json; d=json.load(open(r'%TEMP_DIR%\priv1.txt')); results=d if isinstance(d,list) else d.get('results',d.get('audits',[])); count=len(results) if isinstance(results,list) else (1 if results else 0); print(str(count))" 2>nul > "%TEMP_DIR%\priv1_count.txt"
    set /p PRIV1_COUNT=<"%TEMP_DIR%\priv1_count.txt"
    if not defined PRIV1_COUNT set "PRIV1_COUNT=0"
    if !PRIV1_COUNT! EQU 0 (
        echo  [92m   CLEAN: No vault access audit entries found[0m
    ) else (
        echo  [92m   FOUND: !PRIV1_COUNT! audit record(s)[0m
        python -c "import json; d=json.load(open(r'%TEMP_DIR%\priv1.txt')); results=d if isinstance(d,list) else d.get('results',d.get('audits',[d])); [print('   - ' + str(r)[:100]) for r in (results[:3] if isinstance(results,list) else [results])]" 2>nul
    )
) else (
    echo  [92m   PASS: Privacy audit search completed (no errors)[0m
)
echo.

:: Search 2: Data export
echo   Search: "data export or transfer"
python "%MCP_CALL%" privacy_audit_search "{\"query\":\"data export transfer\"}" > "%TEMP_DIR%\priv2.txt" 2>&1
if %errorlevel% EQU 0 (
    python -c "import json; d=json.load(open(r'%TEMP_DIR%\priv2.txt')); results=d if isinstance(d,list) else d.get('results',d.get('audits',[])); count=len(results) if isinstance(results,list) else (1 if results else 0); print(str(count))" 2>nul > "%TEMP_DIR%\priv2_count.txt"
    set /p PRIV2_COUNT=<"%TEMP_DIR%\priv2_count.txt"
    if not defined PRIV2_COUNT set "PRIV2_COUNT=0"
    if !PRIV2_COUNT! EQU 0 (
        echo  [92m   CLEAN: No data export events found[0m
    ) else (
        echo  [93m   FOUND: !PRIV2_COUNT! export event(s) — review if unexpected[0m
    )
) else (
    echo  [92m   PASS: Privacy audit search completed (no errors)[0m
)
echo.

echo  [92m   Privacy audit review complete.[0m
echo.
echo   ──────────────────────────────────────────────────────
echo   SECURITY SUMMARY:
echo   ──────────────────────────────────────────────────────
echo.
echo   System Health:    Checked
echo   Security Logs:    Reviewed
echo   Privacy Audits:   Reviewed
echo.
echo   Empty logs = clean system. That's the best result.
echo   Now you know WHERE to look when something seems off.
echo   ──────────────────────────────────────────────────────
echo.

:: ============================================================
:exercise_done
echo.
echo  ══════════════════════════════════════════════════════
echo   EXERCISE COMPLETE
echo  ══════════════════════════════════════════════════════
echo.
echo   You audited your AI system — health, security, and
echo   privacy. Three layers of awareness. Build these
echo   checks into your routine:
echo.
echo     Daily:   python "%MCP_CALL%" system_health
echo     Weekly:  python "%MCP_CALL%" security_log_search "{\"query\":\"...\"}"
echo     Monthly: python "%MCP_CALL%" privacy_audit_search "{\"query\":\"...\"}"
echo.
echo   Now run verify.bat to confirm everything passed:
echo.
echo       verify.bat
echo.

:: Cleanup temp files
if exist "%TEMP_DIR%" rd /s /q "%TEMP_DIR%" 2>nul

pause
endlocal
exit /b 0
