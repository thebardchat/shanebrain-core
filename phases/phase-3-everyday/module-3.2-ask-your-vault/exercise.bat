@echo off
setlocal enabledelayedexpansion
title Module 3.2 Exercise — Ask Your Vault

:: ============================================================
:: MODULE 3.2 EXERCISE: Ask Your Vault
:: Goal: Search vault, ask ShaneBrain questions via RAG,
::       interactive Q&A loop
:: Time: ~15 minutes
:: Prerequisites: Module 3.1 (vault must have documents)
:: MCP Tools: vault_search, chat_with_shanebrain
:: ============================================================

set "MCP_CALL=%~dp0..\..\..\shared\utils\mcp-call.py"
set "TEMP_DIR=%TEMP%\module-3.2"

echo.
echo  ══════════════════════════════════════════════════════
echo   MODULE 3.2 EXERCISE: Ask Your Vault
echo  ══════════════════════════════════════════════════════
echo.
echo   You stored documents in Module 3.1. Now you'll ask
echo   questions and get answers backed by YOUR data.
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

:: Check vault has documents (prerequisite from 3.1)
python "%MCP_CALL%" vault_list_categories > "%TEMP_DIR%\categories.txt" 2>&1
python -c "import json; d=json.load(open(r'%TEMP_DIR%\categories.txt')); total=sum(v for v in d.values() if isinstance(v,int)) if isinstance(d,dict) else len(d) if isinstance(d,list) else 0; print(total)" 2>nul > "%TEMP_DIR%\count.txt"
set /p VAULT_COUNT=<"%TEMP_DIR%\count.txt"
if not defined VAULT_COUNT set "VAULT_COUNT=0"

if %VAULT_COUNT% LSS 1 (
    echo  [91m   X Vault is empty. Run Module 3.1 first to add documents.[0m
    echo       Your vault needs at least a few documents to answer questions.
    pause
    exit /b 1
)
echo  [92m   PASS: Vault has %VAULT_COUNT% document(s)[0m
echo.

:: ============================================================
:: TASK 1: Search vault for a specific topic
:: ============================================================
echo  ──────────────────────────────────────────────────────
echo.
echo  [TASK 1/3] Search your vault — see what the AI finds
echo.
echo   Before asking a full question, let's see what raw
echo   documents match a search. This is the "retrieval"
echo   step of RAG — finding the right context.
echo.

echo   Searching vault for: "health and medical information"
echo.
python "%MCP_CALL%" vault_search "{\"query\":\"health and medical information\"}" > "%TEMP_DIR%\search1.txt" 2>&1
if %errorlevel% EQU 0 (
    echo  [92m   PASS: Vault search returned results[0m
    echo.
    echo   Raw search results (what the AI sees as context):
    echo   ──────────────────────────────────────────────────
    python -c "import json; d=json.load(open(r'%TEMP_DIR%\search1.txt')); results=d if isinstance(d,list) else d.get('results',d.get('documents',[d])); [print('   - ' + str(r.get('title',r.get('content','')[:80]))) for r in (results[:3] if isinstance(results,list) else [results])]" 2>nul
    echo   ──────────────────────────────────────────────────
) else (
    echo  [91m   FAIL: Vault search failed[0m
    echo          Check that Module 3.1 completed successfully
)
echo.
echo   That's what the AI retrieves. Next, watch it turn
echo   those documents into a real answer.
echo.
echo   Press any key to ask ShaneBrain a question...
pause >nul
echo.

:: ============================================================
:: TASK 2: Ask ShaneBrain via RAG
:: ============================================================
echo  ──────────────────────────────────────────────────────
echo.
echo  [TASK 2/3] Ask ShaneBrain a question — watch RAG in action
echo.
echo   Same data. But now the AI reads the documents and
echo   gives you a synthesized answer, not a document dump.
echo.

echo   Question: "What did the doctor recommend at my last checkup?"
echo.
echo   Thinking...
python "%MCP_CALL%" chat_with_shanebrain "{\"message\":\"What did the doctor recommend at my last checkup?\"}" > "%TEMP_DIR%\chat1.txt" 2>&1
if %errorlevel% EQU 0 (
    echo  [92m   PASS: ShaneBrain responded[0m
    echo.
    echo   ShaneBrain's answer:
    echo   ══════════════════════════════════════════════════
    python -c "import json; d=json.load(open(r'%TEMP_DIR%\chat1.txt')); text=d.get('text',d.get('response',str(d))); print('   ' + text[:500])" 2>nul
    echo.
    echo   ══════════════════════════════════════════════════
    echo.
    echo   Compare this to the raw search results above.
    echo   Same source documents — but now it's a real answer.
) else (
    echo  [91m   FAIL: chat_with_shanebrain did not respond[0m
    echo          Check that Ollama is running for answer generation
)
echo.
echo   Press any key to try the interactive Q^&A loop...
pause >nul
echo.

:: ============================================================
:: TASK 3: Interactive Q&A loop
:: ============================================================
echo  ──────────────────────────────────────────────────────
echo.
echo  [TASK 3/3] Interactive Q^&A — ask your vault anything
echo.
echo   Type any question. ShaneBrain will search your vault
echo   and knowledge base, then give you an answer.
echo.
echo   Try questions like:
echo     - "When is my next appointment?"
echo     - "What are my strengths at work?"
echo     - "Who do I call in an emergency?"
echo     - "What should I work on this year?"
echo.

:qa_loop
echo  ──────────────────────────────────────────────────────
set /p "USER_QUESTION=  Your question (or Q to quit): "

if /i "%USER_QUESTION%"=="Q" goto exercise_done
if "%USER_QUESTION%"=="" goto qa_loop

echo.
echo   [Step 1/2] Searching your vault...
python "%MCP_CALL%" vault_search "{\"query\":\"%USER_QUESTION%\"}" > "%TEMP_DIR%\qa_search.txt" 2>&1

echo   [Step 2/2] Generating answer...
echo.
python "%MCP_CALL%" chat_with_shanebrain "{\"message\":\"%USER_QUESTION%\"}" > "%TEMP_DIR%\qa_answer.txt" 2>&1

if %errorlevel% EQU 0 (
    echo   ══════════════════════════════════════════════════
    python -c "import json; d=json.load(open(r'%TEMP_DIR%\qa_answer.txt')); text=d.get('text',d.get('response',str(d))); print('   ' + text[:600])" 2>nul
    echo.
    echo   ══════════════════════════════════════════════════
    echo  [92m   Answer generated from your vault + knowledge base[0m
) else (
    echo  [91m   Could not generate answer. Check services.[0m
)
echo.
goto qa_loop

:: ============================================================
:exercise_done
echo.
echo  ══════════════════════════════════════════════════════
echo   EXERCISE COMPLETE
echo  ══════════════════════════════════════════════════════
echo.
echo   You asked questions and got answers grounded in YOUR
echo   documents. That's RAG — retrieval-augmented generation.
echo   The AI didn't guess. It read your files and responded.
echo.
echo   The more documents you add to your vault (Module 3.1),
echo   the smarter these answers get. Like hiring someone
echo   and giving them your entire filing cabinet to study.
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
