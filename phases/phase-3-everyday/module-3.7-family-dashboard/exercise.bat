@echo off
setlocal enabledelayedexpansion
title Phase 3.7 // The Family Dashboard
color 0B

echo.
echo  ============================================================
echo       THE FAMILY DASHBOARD
echo       Your Personal AI Toolkit
echo  ============================================================
echo.

REM ============================================================
REM SYSTEM HEALTH CHECK
REM ============================================================
echo  [HEALTH CHECK]
echo.

set HEALTH_OK=1

echo  Checking Weaviate...
curl -s http://localhost:8080/v1/.well-known/ready >nul 2>&1
if errorlevel 1 (
    echo  [DOWN] Weaviate is NOT running
    set HEALTH_OK=0
) else (
    echo  [UP]   Weaviate - http://localhost:8080
)

echo  Checking Ollama...
curl -s http://localhost:11434/api/tags >nul 2>&1
if errorlevel 1 (
    echo  [DOWN] Ollama is NOT running
    set HEALTH_OK=0
) else (
    echo  [UP]   Ollama  - http://localhost:11434
)

if !HEALTH_OK!==0 (
    echo.
    echo  ^!WARNING: Some services are down. Tools may not work fully.
)

echo.

REM ============================================================
REM VAULT STATS
REM ============================================================
echo  [VAULT STATS]
echo.

python -c "
import urllib.request, json

collections = ['PersonalDoc', 'PersonalDraft', 'SecurityLog', 'DailyNote', 'PrivacyAudit']
total = 0

for coll in collections:
    try:
        req = urllib.request.Request(
            'http://localhost:8080/v1/graphql',
            data=json.dumps({
                'query': '{ Aggregate { ' + coll + ' { meta { count } } } }'
            }).encode('utf-8'),
            headers={'Content-Type': 'application/json'},
            method='POST'
        )
        resp = urllib.request.urlopen(req)
        result = json.loads(resp.read())
        count = result['data']['Aggregate'][coll][0]['meta']['count']
        total += count
        bar = '#' * min(count, 30)
        print(f'  {coll:20s} {bar} ({count})')
    except:
        print(f'  {coll:20s} [not created yet]')

print(f'  {\"\":20s} -----')
print(f'  {\"TOTAL\":20s} {total} objects in your vaults')
"

echo.
echo  ============================================================
echo       FAMILY DASHBOARD MENU
echo  ============================================================
echo.

:DASHBOARD_MENU
echo   Personal AI Tools:
echo     1. Your Private Vault   (add/view personal documents)
echo     2. Ask Your Vault       (personal Q^&A)
echo     3. Write It Right       (writing assistant)
echo     4. Lock It Down         (security check)
echo     5. Daily Briefing       (journal + daily summary)
echo     6. Digital Footprint    (privacy audit)
echo.
echo   System:
echo     7. Refresh health check
echo     8. Show vault stats
echo     9. Exit dashboard
echo.

set "DCHOICE="
set /p "DCHOICE=  Choose (1-9): "

if "!DCHOICE!"=="1" (
    echo.
    echo  Launching Your Private Vault...
    call "%~dp0..\module-3.1-your-private-vault\exercise.bat"
    echo.
    goto DASHBOARD_MENU
)

if "!DCHOICE!"=="2" (
    echo.
    echo  Launching Ask Your Vault...
    call "%~dp0..\module-3.2-ask-your-vault\exercise.bat"
    echo.
    goto DASHBOARD_MENU
)

if "!DCHOICE!"=="3" (
    echo.
    echo  Launching Write It Right...
    call "%~dp0..\module-3.3-write-it-right\exercise.bat"
    echo.
    goto DASHBOARD_MENU
)

if "!DCHOICE!"=="4" (
    echo.
    echo  Launching Lock It Down...
    call "%~dp0..\module-3.4-lock-it-down\exercise.bat"
    echo.
    goto DASHBOARD_MENU
)

if "!DCHOICE!"=="5" (
    echo.
    echo  Launching Daily Briefing...
    call "%~dp0..\module-3.5-daily-briefing\exercise.bat"
    echo.
    goto DASHBOARD_MENU
)

if "!DCHOICE!"=="6" (
    echo.
    echo  Launching Digital Footprint...
    call "%~dp0..\module-3.6-digital-footprint\exercise.bat"
    echo.
    goto DASHBOARD_MENU
)

if "!DCHOICE!"=="7" (
    echo.
    echo  [HEALTH CHECK]
    curl -s http://localhost:8080/v1/.well-known/ready >nul 2>&1
    if errorlevel 1 (echo  [DOWN] Weaviate) else (echo  [UP]   Weaviate)
    curl -s http://localhost:11434/api/tags >nul 2>&1
    if errorlevel 1 (echo  [DOWN] Ollama) else (echo  [UP]   Ollama)
    echo.
    goto DASHBOARD_MENU
)

if "!DCHOICE!"=="8" (
    echo.
    python -c "
import urllib.request, json
collections = ['PersonalDoc', 'PersonalDraft', 'SecurityLog', 'DailyNote', 'PrivacyAudit']
total = 0
for coll in collections:
    try:
        req = urllib.request.Request('http://localhost:8080/v1/graphql', data=json.dumps({'query': '{ Aggregate { ' + coll + ' { meta { count } } } }'}).encode('utf-8'), headers={'Content-Type': 'application/json'}, method='POST')
        resp = urllib.request.urlopen(req)
        result = json.loads(resp.read())
        count = result['data']['Aggregate'][coll][0]['meta']['count']
        total += count
        print(f'  {coll:20s} {count} objects')
    except:
        print(f'  {coll:20s} [not created]')
print(f'  Total: {total} objects')
"
    echo.
    goto DASHBOARD_MENU
)

if "!DCHOICE!"=="9" goto DASHBOARD_EXIT

echo  Invalid choice. Try 1-9.
echo.
goto DASHBOARD_MENU

:DASHBOARD_EXIT
echo.
echo  ============================================================
echo       PHASE 3 COMPLETE: EVERYDAY USERS
echo  ============================================================
echo.
echo   Congratulations! You've built a complete personal AI toolkit:
echo.
echo     Your Private Vault   - Family knowledge base
echo     Ask Your Vault       - Personal Q^&A
echo     Write It Right       - Writing assistant
echo     Lock It Down         - Security awareness
echo     Daily Briefing       - Journal + planner
echo     Digital Footprint    - Privacy audit
echo     Family Dashboard     - This launcher
echo.
echo   FINAL SECURITY REMINDER:
echo   Everything you just built runs on YOUR machine.
echo   No subscriptions. No accounts. No data leaving your house.
echo   Your family's AI is truly yours.
echo.
echo   Welcome to the future of personal AI.
echo.
pause
exit /b 0
