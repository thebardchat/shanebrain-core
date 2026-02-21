@echo off
setlocal enabledelayedexpansion
title Module 3.7 Exercise — Family Dashboard (Capstone)

:: ============================================================
:: MODULE 3.7 EXERCISE: Family Dashboard (Phase 3 Capstone)
:: Goal: Build a complete view of your personal AI system —
::       services, knowledge, relationships, and live chat
:: Time: ~20 minutes
:: Prerequisites: Modules 3.1, 3.5
:: ============================================================

set "MCP_CALL=%~dp0..\..\..\shared\utils\mcp-call.py"
set "TEMP_DIR=%TEMP%\module-3.7"

echo.
echo  ======================================================
echo   MODULE 3.7 EXERCISE: Family Dashboard
echo   Phase 3 Capstone
echo  ======================================================
echo.
echo   This is it. Everything you built across Phase 3
echo   comes together in one exercise. Four tasks. Full
echo   picture of your personal AI system.
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
:: TASK 1: System Overview
:: ============================================================
echo  ------------------------------------------------------
echo.
echo  [TASK 1/4] System Overview — Full Infrastructure Check
echo.
echo   Every morning, the foreman checks the yard before the
echo   crew rolls out. Services running? Equipment ready?
echo   Materials stocked? This is that check for your AI.
echo.

python "%MCP_CALL%" system_health > "%TEMP_DIR%\health.json" 2>nul

if %errorlevel% EQU 0 (
    echo  [92m   OK — System health retrieved[0m
    echo.
    echo   +--------------------------------------------------+
    echo   ^|  SYSTEM STATUS                                    ^|
    echo   +--------------------------------------------------+
    echo.
    echo   SERVICES:
    python -c "import json; d=json.load(open(r'%TEMP_DIR%\health.json')); svcs=d.get('services',{}); [print(f'     {k:15s} {v[\"status\"] if isinstance(v,dict) else v}') for k,v in svcs.items()]" 2>nul
    echo.
    echo   COLLECTIONS:
    python -c "import json; d=json.load(open(r'%TEMP_DIR%\health.json')); cols=d.get('collections',{}); [print(f'     {k:20s} {v:>5} objects') for k,v in cols.items()]; print(); print(f'     {\"TOTAL\":20s} {sum(cols.values()):>5} objects')" 2>nul
    echo.
    echo   +--------------------------------------------------+
) else (
    echo  [91m   FAIL — Could not retrieve system health[0m
    echo     Check hints.md for troubleshooting.
)
echo.

:: ============================================================
:: TASK 2: Knowledge Check
:: ============================================================
echo  ------------------------------------------------------
echo.
echo  [TASK 2/4] Knowledge Check — What Does Your AI Know?
echo.
echo   Search for "family" and see what comes back. This is
echo   what your AI draws from when you ask it questions
echo   about the people and things that matter most.
echo.

python "%MCP_CALL%" search_knowledge "{\"query\":\"family\"}" > "%TEMP_DIR%\knowledge.json" 2>nul

if %errorlevel% EQU 0 (
    echo  [92m   OK — Knowledge search returned results[0m
    echo.
    echo   +--------------------------------------------------+
    echo   ^|  KNOWLEDGE: "family"                              ^|
    echo   +--------------------------------------------------+
    echo.
    python -c "import json; d=json.load(open(r'%TEMP_DIR%\knowledge.json')); results=d.get('results',d.get('knowledge',[])); entries=results if isinstance(results,list) else [results]; [print(f'     [{e.get(\"category\",\"general\")}] {str(e.get(\"content\",e.get(\"text\",\"\")))[:100]}...') for e in entries[:5]]" 2>nul
    echo.
    echo   +--------------------------------------------------+
) else (
    echo  [91m   FAIL — Could not search knowledge base[0m
    echo     Check hints.md for troubleshooting.
)
echo.

:: ============================================================
:: TASK 3: Social View
:: ============================================================
echo  ------------------------------------------------------
echo.
echo  [TASK 3/4] Social View — Your Relationship Network
echo.
echo   Your AI tracks the people in your life. Friend
echo   profiles with context and connection strength.
echo   This is who your AI knows about.
echo.

python "%MCP_CALL%" get_top_friends > "%TEMP_DIR%\friends.json" 2>nul

if %errorlevel% EQU 0 (
    echo  [92m   OK — Friend profiles retrieved[0m
    echo.
    echo   +--------------------------------------------------+
    echo   ^|  RELATIONSHIP NETWORK                             ^|
    echo   +--------------------------------------------------+
    echo.
    python -c "import json; d=json.load(open(r'%TEMP_DIR%\friends.json')); friends=d.get('friends',d.get('results',[])); entries=friends if isinstance(friends,list) else [friends]; [print(f'     {e.get(\"name\",\"Unknown\"):20s} strength: {e.get(\"relationship_strength\",e.get(\"strength\",\"?\"))}') for e in entries[:10] if isinstance(e,dict)]" 2>nul
    echo.
    echo   +--------------------------------------------------+
    echo.
    echo   Your AI remembers the people you told it about.
    echo   The more context you give, the better it serves you.
) else (
    echo  [93m   WARNING — Could not retrieve friend profiles[0m
    echo     FriendProfile collection may be empty. That's OK
    echo     for now — you can add profiles later.
)
echo.

:: ============================================================
:: TASK 4: Personal AI Conversation
:: ============================================================
echo  ------------------------------------------------------
echo.
echo  [TASK 4/4] Talk to Your AI — The Final Proof
echo.
echo   This is the moment. You're going to ask your AI to
echo   summarize what it knows about you and your system.
echo   It will search its knowledge, pull context from your
echo   vault, and generate a real response.
echo.
echo   Give it a moment — Ollama is thinking...
echo.

python "%MCP_CALL%" chat_with_shanebrain "{\"message\":\"Give me a summary of what you know about me and my system. What data do you have, what can you help me with, and what should I focus on next?\"}" > "%TEMP_DIR%\chat.json" 2>nul

if %errorlevel% EQU 0 (
    echo  [92m   OK — ShaneBrain responded[0m
    echo.
    echo   +--------------------------------------------------+
    echo   ^|  YOUR AI SAYS:                                    ^|
    echo   +--------------------------------------------------+
    echo.
    python -c "import json; d=json.load(open(r'%TEMP_DIR%\chat.json')); text=d.get('response',d.get('text',d.get('message',str(d)))); print('    ',text[:800])" 2>nul
    echo.
    echo   +--------------------------------------------------+
) else (
    echo  [91m   FAIL — Could not chat with ShaneBrain[0m
    echo     Ollama may need time to load. Try again in 30 seconds.
    echo     Check hints.md for troubleshooting.
)
echo.

:: ============================================================
:: PHASE 3 COMPLETE BANNER
:: ============================================================
echo.
echo  [92m  ======================================================[0m
echo  [92m  ======================================================[0m
echo.
echo  [92m   ██████╗ ██╗  ██╗ █████╗ ███████╗███████╗    ██████╗ [0m
echo  [92m   ██╔══██╗██║  ██║██╔══██╗██╔════╝██╔════╝    ╚════██╗[0m
echo  [92m   ██████╔╝███████║███████║███████╗█████╗       █████╔╝[0m
echo  [92m   ██╔═══╝ ██╔══██║██╔══██║╚════██║██╔══╝       ╚═══██╗[0m
echo  [92m   ██║     ██║  ██║██║  ██║███████║███████╗    ██████╔╝[0m
echo  [92m   ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝    ╚═════╝ [0m
echo.
echo  [92m    ██████╗ ██████╗ ███╗   ███╗██████╗ ██╗     ███████╗████████╗███████╗[0m
echo  [92m   ██╔════╝██╔═══██╗████╗ ████║██╔══██╗██║     ██╔════╝╚══██╔══╝██╔════╝[0m
echo  [92m   ██║     ██║   ██║██╔████╔██║██████╔╝██║     █████╗     ██║   █████╗  [0m
echo  [92m   ██║     ██║   ██║██║╚██╔╝██║██╔═══╝ ██║     ██╔══╝     ██║   ██╔══╝  [0m
echo  [92m   ╚██████╗╚██████╔╝██║ ╚═╝ ██║██║     ███████╗███████╗   ██║   ███████╗[0m
echo  [92m    ╚═════╝ ╚═════╝ ╚═╝     ╚═╝╚═╝     ╚══════╝╚══════╝   ╚═╝   ╚══════╝[0m
echo.
echo  [92m  ======================================================[0m
echo  [92m  ======================================================[0m
echo.
echo   You did it. Phase 3 is complete.
echo.
echo   Here's what you built — a personal AI that:
echo.
echo     [92m+[0m Stores your documents in a private vault
echo     [92m+[0m Answers questions from your personal data
echo     [92m+[0m Writes drafts using your context
echo     [92m+[0m Locks down with security and privacy controls
echo     [92m+[0m Journals your days and generates briefings
echo     [92m+[0m Audits its own data footprint
echo     [92m+[0m Knows your people and your story
echo     [92m+[0m Talks to you about your life
echo.
echo   Phase 1 made you a BUILDER.
echo   Phase 2 made you an OPERATOR.
echo   Phase 3 made you an EVERYDAY USER.
echo.
echo   Your AI is no longer a project. It's a tool you use
echo   every day — like a truck, a phone, or a good foreman.
echo   It runs on YOUR hardware. It holds YOUR data. It
echo   answers to YOU.
echo.
echo   Next: Phase 4 — LEGACY
echo   Build something that outlasts you.
echo.
echo   Now run verify.bat to lock in your completion.
echo.

if exist "%TEMP_DIR%" rd /s /q "%TEMP_DIR%" 2>nul

pause
endlocal
exit /b 0
