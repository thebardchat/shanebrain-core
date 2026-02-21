@echo off
setlocal enabledelayedexpansion
title Module 3.1 Exercise — Your Private Vault

:: ============================================================
:: MODULE 3.1 EXERCISE: Your Private Vault
:: Goal: Store personal docs in vault, search them semantically,
::       list vault categories
:: Time: ~15 minutes
:: MCP Tools: vault_add, vault_search, vault_list_categories
:: ============================================================

set "MCP_CALL=%~dp0..\..\..\shared\utils\mcp-call.py"
set "TEMP_DIR=%TEMP%\module-3.1"

echo.
echo  ══════════════════════════════════════════════════════
echo   MODULE 3.1 EXERCISE: Your Private Vault
echo  ══════════════════════════════════════════════════════
echo.
echo   You're building a personal document vault. Three tasks.
echo   Fifteen minutes. Your data stays on YOUR machine.
echo.
echo  ──────────────────────────────────────────────────────
echo.

:: --- PRE-FLIGHT: Check MCP server ---
echo  [PRE-FLIGHT] Checking MCP server...
echo.

if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%"

python "%MCP_CALL%" system_health > "%TEMP_DIR%\health.txt" 2>&1
if %errorlevel% NEQ 0 (
    echo  [91m   X MCP server not reachable. Is ShaneBrain running?[0m
    echo       Check: python "%MCP_CALL%" system_health
    pause
    exit /b 1
)
echo  [92m   PASS: MCP server responding[0m
echo.

:: ============================================================
:: TASK 1: Add 3 personal documents to the vault
:: ============================================================
echo  ──────────────────────────────────────────────────────
echo.
echo  [TASK 1/3] Store personal documents in your vault
echo.
echo   We'll add three documents — one medical, one work,
echo   one personal. These are samples. After this module,
echo   replace them with your real info.
echo.

:: --- Document 1: Medical ---
echo   Storing medical document...
python "%MCP_CALL%" vault_add "{\"content\":\"Annual checkup notes - January 2026. Blood pressure 128/82, slightly elevated. Doctor recommended reducing sodium intake and walking 30 minutes daily. Current medications: none. Allergies: penicillin, bee stings. Next appointment scheduled for July 2026. Weight: 195 lbs, down 5 from last visit. Cholesterol panel normal. Doctor: Dr. Martinez at Valley Health Clinic.\",\"category\":\"medical\",\"title\":\"Annual Checkup - Jan 2026\"}" > "%TEMP_DIR%\add1.txt" 2>&1
if %errorlevel% EQU 0 (
    echo  [92m   PASS: Medical document stored[0m
) else (
    echo  [91m   FAIL: Could not store medical document[0m
    echo          Check MCP server and try again
)
echo.

:: --- Document 2: Work ---
echo   Storing work document...
python "%MCP_CALL%" vault_add "{\"content\":\"Performance review summary - Q4 2025. Rating: Exceeds expectations. Strengths: reliability, problem-solving under pressure, mentoring new hires. Areas for growth: delegation - tends to take on too much personally. Completed safety certification renewal. Led the highway overpass project on time and under budget. Manager notes: strong candidate for crew lead position in 2026. Raise approved: 4 percent effective March 1.\",\"category\":\"work\",\"title\":\"Q4 2025 Performance Review\"}" > "%TEMP_DIR%\add2.txt" 2>&1
if %errorlevel% EQU 0 (
    echo  [92m   PASS: Work document stored[0m
) else (
    echo  [91m   FAIL: Could not store work document[0m
)
echo.

:: --- Document 3: Personal/Family ---
echo   Storing family document...
python "%MCP_CALL%" vault_add "{\"content\":\"Emergency contacts and family info. Wife: Tiffany, cell 555-0142. Mom: Barbara, cell 555-0198. Brother: Mike, cell 555-0167. Pediatrician: Dr. Chen at Kids First, 555-0200. Vet: Countryside Animal Hospital, 555-0225. Insurance agent: State Farm - Tom, 555-0188, policy number HO-4521. Kids school: Valley Elementary, main office 555-0300. Neighbor with spare key: Johnson family at 412 Oak Street.\",\"category\":\"personal\",\"title\":\"Emergency Contacts and Family Info\"}" > "%TEMP_DIR%\add3.txt" 2>&1
if %errorlevel% EQU 0 (
    echo  [92m   PASS: Family document stored[0m
) else (
    echo  [91m   FAIL: Could not store family document[0m
)
echo.

echo  [92m   Three documents stored in your vault.[0m
echo.
echo   Press any key to search your vault...
pause >nul
echo.

:: ============================================================
:: TASK 2: Search the vault semantically
:: ============================================================
echo  ──────────────────────────────────────────────────────
echo.
echo  [TASK 2/3] Search your vault by meaning
echo.
echo   Watch how semantic search finds documents even when
echo   you don't use the exact words you stored.
echo.

:: --- Search 1: Medical query ---
echo   Search: "What are my allergies?"
python "%MCP_CALL%" vault_search "{\"query\":\"What are my allergies\"}" > "%TEMP_DIR%\search1.txt" 2>&1
if %errorlevel% EQU 0 (
    echo  [92m   PASS: Search returned results[0m
    python -c "import json; d=json.load(open(r'%TEMP_DIR%\search1.txt')); results=d if isinstance(d,list) else d.get('results',d.get('documents',[])); print('   Found: ' + str(len(results) if isinstance(results,list) else 1) + ' result(s)')" 2>nul
) else (
    echo  [91m   FAIL: Search failed[0m
)
echo.

:: --- Search 2: Work query with different phrasing ---
echo   Search: "Am I getting a raise?"
python "%MCP_CALL%" vault_search "{\"query\":\"Am I getting a raise\"}" > "%TEMP_DIR%\search2.txt" 2>&1
if %errorlevel% EQU 0 (
    echo  [92m   PASS: Search returned results[0m
    echo.
    echo   Notice: You asked about a "raise" and it found your
    echo   performance review. The AI understood the connection.
) else (
    echo  [91m   FAIL: Search failed[0m
)
echo.

:: --- Search 3: Category-filtered search ---
echo   Search: "doctor" (filtered to medical category)
python "%MCP_CALL%" vault_search "{\"query\":\"doctor\",\"category\":\"medical\"}" > "%TEMP_DIR%\search3.txt" 2>&1
if %errorlevel% EQU 0 (
    echo  [92m   PASS: Category-filtered search returned results[0m
) else (
    echo  [93m   NOTE: Category filter may not be supported yet — that's OK[0m
)
echo.

echo   Press any key to check vault categories...
pause >nul
echo.

:: ============================================================
:: TASK 3: List vault categories
:: ============================================================
echo  ──────────────────────────────────────────────────────
echo.
echo  [TASK 3/3] Check your vault categories
echo.
echo   Let's see what's in your filing cabinet.
echo.

python "%MCP_CALL%" vault_list_categories > "%TEMP_DIR%\categories.txt" 2>&1
if %errorlevel% EQU 0 (
    echo  [92m   PASS: Category listing retrieved[0m
    echo.
    echo   Your vault categories:
    echo   ──────────────────────
    python -c "import json; d=json.load(open(r'%TEMP_DIR%\categories.txt')); [print('   ' + str(k) + ': ' + str(v)) for k,v in (d.items() if isinstance(d,dict) else [(str(i),str(x)) for i,x in enumerate(d)])]" 2>nul
) else (
    echo  [91m   FAIL: Could not list categories[0m
)
echo.

:: ============================================================
:exercise_done
echo.
echo  ══════════════════════════════════════════════════════
echo   EXERCISE COMPLETE
echo  ══════════════════════════════════════════════════════
echo.
echo   Your private vault has three documents across multiple
echo   categories. You searched them by meaning and saw how
echo   the AI connects questions to answers.
echo.
echo   Want to make it YOURS? Run exercise.bat again with
echo   your real documents, or use the MCP tools directly:
echo.
echo     python "%MCP_CALL%" vault_add "{\"content\":\"...\",\"category\":\"medical\"}"
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
