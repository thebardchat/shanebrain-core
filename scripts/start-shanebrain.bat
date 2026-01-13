@echo off
REM =============================================================================
REM ShaneBrain Core - Main Launcher (Windows)
REM =============================================================================
REM
REM This script starts the ShaneBrain ecosystem:
REM - Checks Docker status
REM - Starts Weaviate (if not running)
REM - Starts MongoDB (if not running)
REM - Loads environment variables
REM - Provides interactive menu
REM
REM Usage: Double-click or run from command line
REM
REM Author: Shane Brazelton
REM =============================================================================

setlocal enabledelayedexpansion

REM Set title
title ShaneBrain Core Launcher

REM Colors (using ANSI if supported)
set "GREEN=[92m"
set "RED=[91m"
set "YELLOW=[93m"
set "BLUE=[94m"
set "NC=[0m"

REM Configuration
set "SHANEBRAIN_ROOT=%~dp0.."
set "ENV_FILE=%SHANEBRAIN_ROOT%\.env"
set "WEAVIATE_DIR=%SHANEBRAIN_ROOT%\weaviate-config"

echo.
echo %BLUE%============================================================%NC%
echo %BLUE%         ShaneBrain Core - Local AI Infrastructure          %NC%
echo %BLUE%============================================================%NC%
echo.

REM =============================================================================
REM Load Environment Variables
REM =============================================================================
:load_env
echo [*] Loading environment variables...

if exist "%ENV_FILE%" (
    for /f "usebackq tokens=1,* delims==" %%a in ("%ENV_FILE%") do (
        set "line=%%a"
        if not "!line:~0,1!"=="#" (
            if not "!line!"=="" (
                set "%%a=%%b"
            )
        )
    )
    echo %GREEN%[OK]%NC% Environment loaded from .env
) else (
    echo %YELLOW%[!]%NC% No .env file found. Using defaults.
    echo     Run: python scripts\setup_credentials.py
)

REM =============================================================================
REM Check Docker
REM =============================================================================
:check_docker
echo [*] Checking Docker...

docker info >nul 2>&1
if errorlevel 1 (
    echo %RED%[ERROR]%NC% Docker is not running!
    echo.
    echo Please start Docker Desktop and try again.
    echo.
    pause
    exit /b 1
)
echo %GREEN%[OK]%NC% Docker is running

REM =============================================================================
REM Check/Start Weaviate
REM =============================================================================
:check_weaviate
echo [*] Checking Weaviate...

docker ps --filter "name=shanebrain-weaviate" --format "{{.Status}}" | findstr "Up" >nul 2>&1
if errorlevel 1 (
    echo %YELLOW%[!]%NC% Weaviate not running. Starting...
    cd /d "%WEAVIATE_DIR%"
    docker-compose up -d

    REM Wait for Weaviate to be ready
    echo [*] Waiting for Weaviate to be ready...
    timeout /t 10 /nobreak >nul

    REM Check if ready
    curl -s http://localhost:8080/v1/.well-known/ready >nul 2>&1
    if errorlevel 1 (
        echo %YELLOW%[!]%NC% Weaviate still starting. Check logs with: docker-compose logs -f
    ) else (
        echo %GREEN%[OK]%NC% Weaviate started successfully
    )
) else (
    echo %GREEN%[OK]%NC% Weaviate is running
)

cd /d "%SHANEBRAIN_ROOT%"

REM =============================================================================
REM Status Dashboard
REM =============================================================================
:status_dashboard
echo.
echo %BLUE%--- System Status ---%NC%
echo.

REM Check Weaviate
curl -s http://localhost:8080/v1/.well-known/ready >nul 2>&1
if errorlevel 1 (
    echo   Weaviate:  %RED%OFFLINE%NC%
) else (
    echo   Weaviate:  %GREEN%ONLINE%NC% (localhost:8080)
)

REM Check MongoDB (if local)
REM MongoDB check would go here

REM Check planning files
if exist "%SHANEBRAIN_ROOT%\planning-system\active-projects\task_plan.md" (
    echo   Planning:  %GREEN%Active project found%NC%
) else (
    echo   Planning:  %YELLOW%No active project%NC%
)

echo.

REM =============================================================================
REM Audio Hack - Glitch Echo Mode
REM =============================================================================
echo [6/6] Booting Audio Hack - Glitch Echo Mode...
python -c "import pygame; pygame.mixer.init(); sound = pygame.mixer.Sound('distorted_yell.wav'); sound.play()" 2>nul
if errorlevel 1 (
    echo %YELLOW%[!]%NC% Audio hack skipped - pip install pygame and add distorted_yell.wav
)

REM =============================================================================
REM Main Menu
REM =============================================================================
:main_menu
echo %BLUE%--- Main Menu ---%NC%
echo.
echo   [1] Start Angel Cloud
echo   [2] Resume Last Project
echo   [3] New Project
echo   [4] Open Planning Files
echo   [5] System Health Check
echo   [6] Backup Data
echo   [7] Stop Services
echo   [8] Exit
echo.
set /p choice="Select option: "

if "%choice%"=="1" goto start_angel_cloud
if "%choice%"=="2" goto resume_project
if "%choice%"=="3" goto new_project
if "%choice%"=="4" goto open_planning
if "%choice%"=="5" goto health_check
if "%choice%"=="6" goto backup
if "%choice%"=="7" goto stop_services
if "%choice%"=="8" goto exit_launcher

echo %RED%Invalid option%NC%
goto main_menu

REM =============================================================================
REM Menu Actions
REM =============================================================================

:start_angel_cloud
echo.
echo [*] Starting Angel Cloud...
echo     This will launch the Angel Cloud mental wellness interface.
echo.
REM Would start Angel Cloud application here
echo %YELLOW%[!]%NC% Angel Cloud not yet implemented. Use ShaneBrain agent instead.
echo     Run: python langchain-chains\shanebrain_agent.py
pause
goto main_menu

:resume_project
echo.
echo [*] Looking for last project...
if exist "%SHANEBRAIN_ROOT%\planning-system\active-projects\task_plan.md" (
    echo %GREEN%[OK]%NC% Found active project
    type "%SHANEBRAIN_ROOT%\planning-system\active-projects\task_plan.md" | more
    echo.
    echo To continue, load these planning files in your Claude session.
) else (
    echo %YELLOW%[!]%NC% No active project found.
    echo     Create one from templates in planning-system\templates\
)
pause
goto main_menu

:new_project
echo.
echo [*] Creating new project...
echo.
echo Available templates:
echo   [1] Angel Cloud (mental wellness)
echo   [2] ShaneBrain Legacy (digital legacy)
echo   [3] Pulsar Security (blockchain)
echo   [4] LogiBot (dispatch automation)
echo.
set /p template_choice="Select template: "

set "template_name="
if "%template_choice%"=="1" set "template_name=angel-cloud-template.md"
if "%template_choice%"=="2" set "template_name=shanebrain-legacy-template.md"
if "%template_choice%"=="3" set "template_name=pulsar-security-template.md"
if "%template_choice%"=="4" set "template_name=logibot-template.md"

if not "%template_name%"=="" (
    copy "%SHANEBRAIN_ROOT%\planning-system\templates\%template_name%" "%SHANEBRAIN_ROOT%\planning-system\active-projects\task_plan.md"
    echo %GREEN%[OK]%NC% Created new project from %template_name%
    echo     Edit: planning-system\active-projects\task_plan.md
) else (
    echo %RED%Invalid selection%NC%
)
pause
goto main_menu

:open_planning
echo.
echo [*] Opening planning directory...
start "" "%SHANEBRAIN_ROOT%\planning-system\active-projects"
goto main_menu

:health_check
echo.
echo [*] Running health check...
python "%SHANEBRAIN_ROOT%\scripts\health_check.py"
pause
goto main_menu

:backup
echo.
echo [*] Running backup...
call "%SHANEBRAIN_ROOT%\scripts\backup.sh"
pause
goto main_menu

:stop_services
echo.
echo [*] Stopping services...
cd /d "%WEAVIATE_DIR%"
docker-compose down
echo %GREEN%[OK]%NC% Services stopped
cd /d "%SHANEBRAIN_ROOT%"
pause
goto main_menu

:exit_launcher
echo.
echo %GREEN%Goodbye! Remember: Progress, not perfection.%NC%
echo.
timeout /t 2 /nobreak >nul
exit /b 0
