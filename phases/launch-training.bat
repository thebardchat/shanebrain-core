@echo off
setlocal enabledelayedexpansion
title ShaneBrain Training Phases
color 0E

echo.
echo  ============================================================
echo       SHANEBRAIN TRAINING PHASES
echo       Local AI Education System
echo  ============================================================
echo.

REM ============================================================
REM PREFLIGHT: Check environment
REM ============================================================
echo  [PREFLIGHT] Checking environment...

python --version >nul 2>&1
if errorlevel 1 (
    echo  ^!ERROR: Python is not installed or not in PATH.
    pause
    exit /b 1
)
echo  [OK] Python found.

curl -s http://localhost:8080/v1/.well-known/ready >nul 2>&1
if errorlevel 1 (
    echo  [WARN] Weaviate not running - some modules will not work
) else (
    echo  [OK] Weaviate ready.
)

curl -s http://localhost:11434/api/tags >nul 2>&1
if errorlevel 1 (
    echo  [WARN] Ollama not running - some modules will not work
) else (
    echo  [OK] Ollama ready.
)

REM Validate config
python -c "import json; json.load(open('config.json'))" >nul 2>&1
if errorlevel 1 (
    echo  [WARN] config.json not found or invalid
) else (
    echo  [OK] config.json valid.
)

echo.

REM ============================================================
REM PROGRESS TRACKING
REM ============================================================
echo  [PROGRESS] Checking Phase 3 completion...
echo.

python -c "
import urllib.request, json

collections = {
    '3.1 Your Private Vault': 'PersonalDoc',
    '3.2 Ask Your Vault': None,
    '3.3 Write It Right': 'PersonalDraft',
    '3.4 Lock It Down': 'SecurityLog',
    '3.5 Daily Briefing': 'DailyNote',
    '3.6 Digital Footprint': 'PrivacyAudit',
    '3.7 Family Dashboard': None
}

complete = 0
total = 7

for module, coll in collections.items():
    if coll is None:
        # Check by running verify or checking dependent collections
        if '3.2' in module:
            # 3.2 uses PersonalDoc - check if Q&A works
            try:
                req = urllib.request.Request('http://localhost:8080/v1/schema/PersonalDoc')
                urllib.request.urlopen(req)
                status = '[*]'
                complete += 1
            except:
                status = '[ ]'
        elif '3.7' in module:
            # 3.7 needs all others
            status = '[*]' if complete >= 6 else '[ ]'
            if complete >= 6:
                complete += 1
        else:
            status = '[ ]'
    else:
        try:
            req = urllib.request.Request(f'http://localhost:8080/v1/schema/{coll}')
            urllib.request.urlopen(req)
            req2 = urllib.request.Request(
                'http://localhost:8080/v1/graphql',
                data=json.dumps({'query': '{ Aggregate { ' + coll + ' { meta { count } } } }'}).encode('utf-8'),
                headers={'Content-Type': 'application/json'},
                method='POST'
            )
            resp = urllib.request.urlopen(req2)
            result = json.loads(resp.read())
            count = result['data']['Aggregate'][coll][0]['meta']['count']
            if count > 0:
                status = '[*]'
                complete += 1
            else:
                status = '[-]'
        except:
            status = '[ ]'

    print(f'  {status} {module}')

pct = int(complete / total * 100)
bar_fill = '#' * (pct // 5)
bar_empty = '.' * (20 - pct // 5)
print()
print(f'  Phase 3: [{bar_fill}{bar_empty}] {pct}%% ({complete}/{total} modules)')
" 2>nul

echo.

REM ============================================================
REM MAIN MENU
REM ============================================================
:MAIN_MENU
echo  ============================================================
echo       TRAINING MENU
echo  ============================================================
echo.
echo   Phase 1: BUILDERS (coming soon)
echo   Phase 2: OPERATORS (coming soon)
echo.
echo   Phase 3: EVERYDAY USERS
echo     1.  Module 3.1 - Your Private Vault     (15 min)
echo     2.  Module 3.2 - Ask Your Vault          (15 min)
echo     3.  Module 3.3 - Write It Right          (15 min)
echo     4.  Module 3.4 - Lock It Down            (20 min)
echo     5.  Module 3.5 - Daily Briefing          (15 min)
echo     6.  Module 3.6 - Digital Footprint       (20 min)
echo     7.  Module 3.7 - Family Dashboard        (15 min)
echo.
echo   Utilities:
echo     V.  Verify a module
echo     P.  Show progress
echo     Q.  Quit
echo.

set "MCHOICE="
set /p "MCHOICE=  Choose: "

if /i "!MCHOICE!"=="Q" goto EXIT_TRAINING
if /i "!MCHOICE!"=="P" (
    echo.
    goto MAIN_MENU
)
if /i "!MCHOICE!"=="V" goto VERIFY_MENU

if "!MCHOICE!"=="1" (
    call "%~dp0phase-3-everyday\module-3.1-your-private-vault\exercise.bat"
    goto MAIN_MENU
)
if "!MCHOICE!"=="2" (
    call "%~dp0phase-3-everyday\module-3.2-ask-your-vault\exercise.bat"
    goto MAIN_MENU
)
if "!MCHOICE!"=="3" (
    call "%~dp0phase-3-everyday\module-3.3-write-it-right\exercise.bat"
    goto MAIN_MENU
)
if "!MCHOICE!"=="4" (
    call "%~dp0phase-3-everyday\module-3.4-lock-it-down\exercise.bat"
    goto MAIN_MENU
)
if "!MCHOICE!"=="5" (
    call "%~dp0phase-3-everyday\module-3.5-daily-briefing\exercise.bat"
    goto MAIN_MENU
)
if "!MCHOICE!"=="6" (
    call "%~dp0phase-3-everyday\module-3.6-digital-footprint\exercise.bat"
    goto MAIN_MENU
)
if "!MCHOICE!"=="7" (
    call "%~dp0phase-3-everyday\module-3.7-family-dashboard\exercise.bat"
    goto MAIN_MENU
)

echo  Invalid choice.
echo.
goto MAIN_MENU

REM ============================================================
REM VERIFY MENU
REM ============================================================
:VERIFY_MENU
echo.
echo  Which module to verify?
echo    1-7 for Phase 3 modules, or B to go back
echo.
set "VCHOICE="
set /p "VCHOICE=  Module number: "

if /i "!VCHOICE!"=="B" goto MAIN_MENU

if "!VCHOICE!"=="1" call "%~dp0phase-3-everyday\module-3.1-your-private-vault\verify.bat"
if "!VCHOICE!"=="2" call "%~dp0phase-3-everyday\module-3.2-ask-your-vault\verify.bat"
if "!VCHOICE!"=="3" call "%~dp0phase-3-everyday\module-3.3-write-it-right\verify.bat"
if "!VCHOICE!"=="4" call "%~dp0phase-3-everyday\module-3.4-lock-it-down\verify.bat"
if "!VCHOICE!"=="5" call "%~dp0phase-3-everyday\module-3.5-daily-briefing\verify.bat"
if "!VCHOICE!"=="6" call "%~dp0phase-3-everyday\module-3.6-digital-footprint\verify.bat"
if "!VCHOICE!"=="7" call "%~dp0phase-3-everyday\module-3.7-family-dashboard\verify.bat"

echo.
goto MAIN_MENU

:EXIT_TRAINING
echo.
echo  ============================================================
echo       TRAINING SESSION ENDED
echo  ============================================================
echo.
echo   Your progress is saved in Weaviate.
echo   Come back anytime — run launch-training.bat to continue.
echo.
pause
exit /b 0
