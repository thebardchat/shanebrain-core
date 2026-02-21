@echo off
setlocal enabledelayedexpansion
title Module 3.3 Exercise — Write It Right

:: ============================================================
:: MODULE 3.3 EXERCISE: Write It Right
:: Goal: Create email draft, create message draft, search drafts
:: Time: ~15 minutes
:: Prerequisites: Module 3.1 (vault docs for context)
:: MCP Tools: draft_create, draft_search
:: ============================================================

set "MCP_CALL=%~dp0..\..\..\shared\utils\mcp-call.py"
set "TEMP_DIR=%TEMP%\module-3.3"

echo.
echo  ══════════════════════════════════════════════════════
echo   MODULE 3.3 EXERCISE: Write It Right
echo  ══════════════════════════════════════════════════════
echo.
echo   You'll create AI-written drafts that pull details from
echo   your vault. Three tasks. Fifteen minutes.
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
    pause
    exit /b 1
)
echo  [92m   PASS: MCP server responding[0m

:: Check vault has documents (for context)
python "%MCP_CALL%" vault_list_categories > "%TEMP_DIR%\categories.txt" 2>&1
python -c "import json; d=json.load(open(r'%TEMP_DIR%\categories.txt')); total=sum(v for v in d.values() if isinstance(v,int)) if isinstance(d,dict) else len(d) if isinstance(d,list) else 0; print(total)" 2>nul > "%TEMP_DIR%\count.txt"
set /p VAULT_COUNT=<"%TEMP_DIR%\count.txt"
if not defined VAULT_COUNT set "VAULT_COUNT=0"

if %VAULT_COUNT% GEQ 1 (
    echo  [92m   PASS: Vault has %VAULT_COUNT% document(s) for context[0m
) else (
    echo  [93m   NOTE: Vault is empty. Drafts will work but won't pull personal context.[0m
    echo          For best results, run Module 3.1 first.
)
echo.

:: ============================================================
:: TASK 1: Create an email draft
:: ============================================================
echo  ──────────────────────────────────────────────────────
echo.
echo  [TASK 1/3] Create an email draft with vault context
echo.
echo   The AI will search your vault for relevant info and
echo   weave it into a professional email draft.
echo.
echo   Prompt: "Write an email to my doctor's office to
echo   reschedule my upcoming appointment to next month.
echo   Be polite and mention any relevant medical details."
echo.

echo   Generating email draft...
echo   (This may take 30-60 seconds — the AI is searching
echo    your vault and composing the draft)
echo.

python "%MCP_CALL%" draft_create "{\"prompt\":\"Write an email to my doctor's office to reschedule my upcoming appointment to next month. Be polite and mention any relevant medical details from my records.\",\"draft_type\":\"email\",\"use_vault_context\":true}" > "%TEMP_DIR%\draft_email.txt" 2>&1

if %errorlevel% EQU 0 (
    echo  [92m   PASS: Email draft generated[0m
    echo.
    echo   ══════════════════════════════════════════════════
    echo   YOUR EMAIL DRAFT:
    echo   ══════════════════════════════════════════════════
    python -c "import json; d=json.load(open(r'%TEMP_DIR%\draft_email.txt')); text=d.get('text',d.get('draft',d.get('content',str(d)))); print(text[:800])" 2>nul
    echo.
    echo   ══════════════════════════════════════════════════
    echo.
    echo   Notice how it pulled details from your vault —
    echo   doctor names, appointment dates, medical info.
    echo   That's vault context making the draft personal.
) else (
    echo  [91m   FAIL: Could not generate email draft[0m
    echo          Check that Ollama is running for text generation
)
echo.
echo   Press any key to create a message draft...
pause >nul
echo.

:: ============================================================
:: TASK 2: Create a message draft
:: ============================================================
echo  ──────────────────────────────────────────────────────
echo.
echo  [TASK 2/3] Create a message draft (casual, short)
echo.
echo   Same tool, different format. Messages are brief
echo   and conversational — like a text to a coworker.
echo.
echo   Prompt: "Write a quick message to my manager about
echo   the areas I should focus on for improvement based
echo   on my performance review."
echo.

echo   Generating message draft...
echo.

python "%MCP_CALL%" draft_create "{\"prompt\":\"Write a quick casual message to my manager about the areas I should focus on for improvement this quarter, based on my performance review feedback.\",\"draft_type\":\"message\",\"use_vault_context\":true}" > "%TEMP_DIR%\draft_message.txt" 2>&1

if %errorlevel% EQU 0 (
    echo  [92m   PASS: Message draft generated[0m
    echo.
    echo   ══════════════════════════════════════════════════
    echo   YOUR MESSAGE DRAFT:
    echo   ══════════════════════════════════════════════════
    python -c "import json; d=json.load(open(r'%TEMP_DIR%\draft_message.txt')); text=d.get('text',d.get('draft',d.get('content',str(d)))); print(text[:500])" 2>nul
    echo.
    echo   ══════════════════════════════════════════════════
    echo.
    echo   Shorter. More casual. But still pulled from your
    echo   vault — it used your actual review feedback.
) else (
    echo  [91m   FAIL: Could not generate message draft[0m
)
echo.
echo   Press any key to search your saved drafts...
pause >nul
echo.

:: ============================================================
:: TASK 3: Search saved drafts
:: ============================================================
echo  ──────────────────────────────────────────────────────
echo.
echo  [TASK 3/3] Search your saved drafts
echo.
echo   Every draft gets saved. Let's find them by topic.
echo.

echo   Searching drafts for: "doctor appointment"
python "%MCP_CALL%" draft_search "{\"query\":\"doctor appointment\"}" > "%TEMP_DIR%\draft_found.txt" 2>&1

if %errorlevel% EQU 0 (
    echo  [92m   PASS: Draft search returned results[0m
    echo.
    python -c "import json; d=json.load(open(r'%TEMP_DIR%\draft_found.txt')); results=d if isinstance(d,list) else d.get('results',d.get('drafts',[d])); count=len(results) if isinstance(results,list) else 1; print('   Found ' + str(count) + ' draft(s) matching your search')" 2>nul
) else (
    echo  [91m   FAIL: Draft search failed[0m
)
echo.

echo   Searching drafts for: "work improvement"
python "%MCP_CALL%" draft_search "{\"query\":\"work improvement\"}" > "%TEMP_DIR%\draft_found2.txt" 2>&1

if %errorlevel% EQU 0 (
    echo  [92m   PASS: Draft search returned results[0m
    python -c "import json; d=json.load(open(r'%TEMP_DIR%\draft_found2.txt')); results=d if isinstance(d,list) else d.get('results',d.get('drafts',[d])); count=len(results) if isinstance(results,list) else 1; print('   Found ' + str(count) + ' draft(s) matching your search')" 2>nul
) else (
    echo  [93m   NOTE: No matching drafts found — that's OK if drafts weren't saved[0m
)
echo.

:: ============================================================
:exercise_done
echo.
echo  ══════════════════════════════════════════════════════
echo   EXERCISE COMPLETE
echo  ══════════════════════════════════════════════════════
echo.
echo   You generated two AI drafts powered by your vault data.
echo   The email pulled medical details. The message pulled
echo   work feedback. Both came from YOUR documents.
echo.
echo   Use this anytime:
echo     python "%MCP_CALL%" draft_create "{\"prompt\":\"...\",\"draft_type\":\"email\"}"
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
