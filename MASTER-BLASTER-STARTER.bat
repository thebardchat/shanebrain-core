@echo off
setlocal enabledelayedexpansion
title ShaneBrain // MASTER BLASTER LAUNCHER
color 0E

echo.
echo  ============================================================
echo       SHANEBRAIN MASTER BLASTER LAUNCHER v2.0
echo  ============================================================
echo.
echo   NOTE: Primary server is now Raspberry Pi 5 (shanebrain-1)
echo   This launcher is for the Windows desktop (pulsar00100)
echo   Pi runs all core services 24/7 at 100.67.120.6
echo.

set SHANEBRAIN_ROOT=D:\Angel_Cloud\shanebrain-core

REM ============================================================
REM PREFLIGHT: RAM CHECK
REM ============================================================
echo  [PREFLIGHT] Checking available RAM...
for /f "tokens=2 delims==" %%A in ('wmic OS get FreePhysicalMemory /value') do set FreeRAM=%%A
set /a FreeRAM_MB=%FreeRAM:~0,-3%

if %FreeRAM_MB% LSS 1500 (
    echo.
    echo  !WARNING: Only %FreeRAM_MB% MB free. Recommended: 1500+ MB
    echo  Close Chrome/Edge for better performance.
    echo.
    pause
)
echo  [OK] RAM: %FreeRAM_MB% MB free

REM ============================================================
REM NODE STATUS CHECK
REM ============================================================
echo.
echo  [PREFLIGHT] Checking cluster nodes...

REM Check Raspberry Pi (primary server)
curl -s --connect-timeout 5 http://100.67.120.6:11434/api/tags >nul 2>&1
if errorlevel 1 (
    echo  [WARN] Raspberry Pi: OFFLINE (via Tailscale)
    curl -s --connect-timeout 2 http://10.0.0.42:11434/api/tags >nul 2>&1
    if errorlevel 1 (
        echo  [WARN] Raspberry Pi: OFFLINE (via LAN too)
        set NODE_PI=0
    ) else (
        echo  [OK] Raspberry Pi: ONLINE via LAN (10.0.0.42)
        set NODE_PI=1
    )
) else (
    echo  [OK] Raspberry Pi: ONLINE via Tailscale (100.67.120.6)
    set NODE_PI=1
)

REM ============================================================
REM STEP 1: Start Ollama (Windows - Secondary node)
REM ============================================================
echo.
echo  [1/4] Starting Ollama on Windows (Secondary)...
start "Ollama (Secondary)" cmd /c "set OLLAMA_HOST=0.0.0.0:11434 && set OLLAMA_ORIGINS=* && ollama serve"
echo        Waiting 10 seconds for Ollama...
ping -n 10 127.0.0.1 >nul

curl -s http://localhost:11434/api/tags >nul 2>&1
if errorlevel 1 (
    echo  !WARNING: Ollama failed to start locally
) else (
    echo  [OK] Ollama ready (local): http://localhost:11434
)

REM ============================================================
REM STEP 2: Docker Desktop
REM ============================================================
echo.
echo  [2/4] Starting Docker Desktop...
if not exist "C:\Program Files\Docker\Docker\Docker Desktop.exe" (
    echo  [SKIP] Docker Desktop not installed
    goto :skip_docker
)
start "" "C:\Program Files\Docker\Docker\Docker Desktop.exe"
echo        Waiting 45 seconds for Docker...
ping -n 45 127.0.0.1 >nul
echo  [OK] Docker started

REM Start Weaviate if config exists locally
if exist "%SHANEBRAIN_ROOT%\weaviate-config\docker-compose.yml" (
    echo  [2b/4] Starting local Weaviate...
    cd /d "%SHANEBRAIN_ROOT%\weaviate-config"
    docker-compose up -d
    echo        Waiting 15 seconds for Weaviate...
    ping -n 15 127.0.0.1 >nul
    echo  [OK] Local Weaviate started
)

:skip_docker

REM ============================================================
REM STEP 3: Angel Arcade Bot (background)
REM ============================================================
echo.
echo  [3/4] Starting Angel Arcade bot...
if exist "%SHANEBRAIN_ROOT%\arcade\arcade_bot.py" (
    start "Angel Arcade" cmd /c "cd /d %SHANEBRAIN_ROOT%\arcade && python arcade_bot.py"
    echo  [OK] Angel Arcade starting in background
) else (
    echo  [SKIP] arcade_bot.py not found locally
)

REM ============================================================
REM STEP 4: ShaneBrain Discord Bot (foreground)
REM ============================================================
echo.
echo  [4/4] Starting ShaneBrain Discord Bot...
echo.
echo  ============================================================
echo       SHANEBRAIN CLUSTER STATUS
echo  ============================================================
echo.
echo   PRIMARY:
if %NODE_PI%==1 (
echo     Pi 5:         http://100.67.120.6:11434 [ONLINE]
) else (
echo     Pi 5:         http://100.67.120.6:11434 [OFFLINE]
)
echo.
echo   SECONDARY (this machine):
echo     Ollama:       http://localhost:11434
echo     Weaviate:     http://localhost:8080 (if Docker running)
echo.
echo   PI SERVICES (24/7):
echo     Weaviate:     http://100.67.120.6:8080
echo     Open WebUI:   http://100.67.120.6:3000
echo     Portainer:    http://100.67.120.6:9000
echo     Glances:      http://100.67.120.6:61208
echo     Social Bot:   Running (systemd)
echo     Discord Bot:  Running (Pi primary)
echo     Arcade Bot:   Running (Pi primary)
echo.
echo   TAILSCALE NETWORK:
echo     shanebrain-1: 100.67.120.6  (Pi 5 - primary)
echo     pulsar00100:  100.81.70.117 (this machine)
echo     iphone-13:    100.86.68.38  (mobile)
echo.
echo  ============================================================
echo.

if not exist "%SHANEBRAIN_ROOT%\bot\bot.py" (
    echo  [INFO] bot.py not found locally.
    echo  [INFO] Discord bot runs on the Pi now. SSH in:
    echo         ssh shanebrain@100.67.120.6
    pause
    exit /b 0
)

cd /d "%SHANEBRAIN_ROOT%\bot"
set OLLAMA_HOST=http://localhost:11434

python bot.py

if errorlevel 1 (
    echo.
    echo  !ERROR: Bot crashed. Check logs above.
)
pause
