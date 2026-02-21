@echo off
setlocal enabledelayedexpansion
title Module 3.5 Exercise — Daily Briefing

:: ============================================================
:: MODULE 3.5 EXERCISE: Daily Briefing
:: Goal: Journal, add todos/reminders, get AI daily briefing
:: Time: ~15 minutes
:: Prerequisites: None
:: ============================================================

set "MCP_CALL=%~dp0..\..\..\shared\utils\mcp-call.py"
set "TEMP_DIR=%TEMP%\module-3.5"

echo.
echo  ======================================================
echo   MODULE 3.5 EXERCISE: Daily Briefing
echo  ======================================================
echo.
echo   You're about to build a daily journaling habit with
echo   your AI. Add notes, todos, reminders — then let the
echo   AI read it all and brief you.
echo.
echo  ------------------------------------------------------
echo.

:: --- PRE-FLIGHT: MCP Server ---
echo  [PRE-FLIGHT] Checking MCP server...
echo.

python "%MCP_CALL%" system_health > "%TEMP_DIR%\preflight.json" 2>nul
if %errorlevel% NEQ 0 (
    echo  [91m   X MCP server not reachable at localhost:8100[0m
    echo     Fix: Make sure the MCP server container is running.
    echo     Run: shared\utils\mcp-health-check.bat
    pause
    exit /b 1
)
echo  [92m   OK — MCP server responding[0m
echo.

if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%"

:: ============================================================
:: TASK 1: Add a Journal Entry
:: ============================================================
echo  ------------------------------------------------------
echo.
echo  [TASK 1/4] Add a Journal Entry
echo.
echo   A journal entry records what happened or how you feel.
echo   Think of it like a quick note at the end of the day:
echo   "Finished the Henderson foundation. Crew worked clean."
echo.
echo   We'll add one with a mood tag — grateful or focused.
echo.

python "%MCP_CALL%" daily_note_add "{\"content\":\"Solid day of work. Got the morning tasks done early and had time to plan ahead. The system is coming together and the crew is in a good rhythm.\",\"note_type\":\"journal\",\"mood\":\"focused\"}" > "%TEMP_DIR%\journal_result.json" 2>nul

if %errorlevel% EQU 0 (
    echo  [92m   OK — Journal entry added with mood: focused[0m
) else (
    echo  [91m   FAIL — Could not add journal entry[0m
    echo     Check hints.md for troubleshooting.
)
echo.

:: ============================================================
:: TASK 2: Add a Todo
:: ============================================================
echo  ------------------------------------------------------
echo.
echo  [TASK 2/4] Add a Todo
echo.
echo   Todos are tasks that need doing. Your AI stores them
echo   and includes them in your daily briefing. Like writing
echo   on the job board before you leave the shop.
echo.

python "%MCP_CALL%" daily_note_add "{\"content\":\"Send the revised estimate to the Martinez project by Wednesday. Include the updated material costs and the 10 percent contingency.\",\"note_type\":\"todo\"}" > "%TEMP_DIR%\todo_result.json" 2>nul

if %errorlevel% EQU 0 (
    echo  [92m   OK — Todo added[0m
) else (
    echo  [91m   FAIL — Could not add todo[0m
    echo     Check hints.md for troubleshooting.
)
echo.

:: ============================================================
:: TASK 3: Add a Reminder
:: ============================================================
echo  ------------------------------------------------------
echo.
echo  [TASK 3/4] Add a Reminder
echo.
echo   Reminders are future-facing notes. Things you need
echo   to remember but don't need to act on today. Like
echo   sticking a note on the dashboard of the truck.
echo.

python "%MCP_CALL%" daily_note_add "{\"content\":\"Truck inspection is due next month. Call the shop and schedule it before the end of the week so we do not get caught off guard.\",\"note_type\":\"reminder\"}" > "%TEMP_DIR%\reminder_result.json" 2>nul

if %errorlevel% EQU 0 (
    echo  [92m   OK — Reminder added[0m
) else (
    echo  [91m   FAIL — Could not add reminder[0m
    echo     Check hints.md for troubleshooting.
)
echo.

:: ============================================================
:: TASK 4: Generate a Daily Briefing
:: ============================================================
echo  ------------------------------------------------------
echo.
echo  [TASK 4/4] Generate Your Daily Briefing
echo.
echo   Now the payoff. Your AI reads everything you just
echo   wrote — journal, todo, reminder — and generates a
echo   summary. Like a dispatcher reading the board and
echo   giving you the morning rundown.
echo.
echo   This calls Ollama, so give it a moment...
echo.

python "%MCP_CALL%" daily_briefing > "%TEMP_DIR%\briefing_result.json" 2>nul

if %errorlevel% EQU 0 (
    echo  [92m   OK — Daily briefing generated[0m
    echo.
    echo   --- YOUR BRIEFING ---
    echo.
    python -c "import json; d=json.load(open(r'%TEMP_DIR%\briefing_result.json')); text=d.get('briefing',d.get('text',str(d))); print(text[:1000])" 2>nul
    echo.
    echo   --- END BRIEFING ---
) else (
    echo  [91m   FAIL — Could not generate briefing[0m
    echo     Ollama may need time to load. Try again in 30 seconds.
    echo     Check hints.md for troubleshooting.
)
echo.

:: ============================================================
:: EXERCISE COMPLETE
:: ============================================================
echo  ======================================================
echo   EXERCISE COMPLETE
echo  ======================================================
echo.
echo   You just:
echo     1. Logged a journal entry with a mood tag
echo     2. Added a todo for your AI to track
echo     3. Set a reminder for the future
echo     4. Got an AI-generated daily briefing
echo.
echo   This is a habit worth building. Five minutes a day
echo   and your AI becomes a dispatcher who never forgets.
echo.
echo   Now run verify.bat to confirm everything stuck.
echo.

if exist "%TEMP_DIR%" rd /s /q "%TEMP_DIR%" 2>nul

pause
endlocal
exit /b 0
