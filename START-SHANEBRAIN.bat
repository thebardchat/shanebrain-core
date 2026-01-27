@echo off
setlocal enabledelayedexpansion
title ShaneBrain // FULL STACK + CLUSTER
color 0A

echo.
echo  ============================================================
echo       SHANEBRAIN v6.3 // FULL STACK + LOAD BALANCER
echo  ============================================================
echo.
echo   NOTE: Start Computer B first for cluster mode!
echo         (If B is offline, all requests go to A)
echo.

set SHANEBRAIN_ROOT=D:\Angel_Cloud\shanebrain-core

REM ============================================================
REM PREFLIGHT: RAM CHECK
REM ============================================================
echo  [PREFLIGHT] Checking available RAM...
for /f "tokens=2 delims==" %%A in ('wmic OS get FreePhysicalMemory /value') do set FreeRAM=%%A
set /a FreeRAM_MB=%FreeRAM:~0,-3%

if %FreeRAM_MB% LSS 800 (
    echo.
    echo  ^!ERROR: Only %FreeRAM_MB% MB free. Need at least 800 MB.
    echo  Close Chrome/Edge and try again.
    pause
    exit /b 1
)
echo  [OK] RAM: %FreeRAM_MB% MB free

REM ============================================================
REM PREFLIGHT: Check Computer B
REM ============================================================
echo.
echo  [PREFLIGHT] Checking Computer B (192.168.100.2)...
curl -s --connect-timeout 2 http://192.168.100.2:11434/api/tags >nul 2>&1
if errorlevel 1 (
    echo  [INFO] Computer B is OFFLINE - running single-node mode
    set CLUSTER_MODE=0
) else (
    echo  [OK] Computer B is ONLINE - cluster mode enabled!
    set CLUSTER_MODE=1
)

REM ============================================================
REM STEP 1: Start Ollama (Computer A)
REM ============================================================
echo.
echo  [1/6] Starting Ollama server...
start "Ollama Server" cmd /c "set OLLAMA_HOST=0.0.0.0:11434 && set OLLAMA_ORIGINS=* && ollama serve"
echo        Waiting 10 seconds for Ollama...
ping -n 10 127.0.0.1 >nul

curl -s http://localhost:11434/api/tags >nul 2>&1
if errorlevel 1 (
    echo  ^!WARNING: Ollama may not be ready. Continuing...
) else (
    echo  [OK] Ollama ready - http://localhost:11434
)

REM ============================================================
REM STEP 2: Docker Desktop
REM ============================================================
echo.
echo  [2/6] Starting Docker Desktop...
if not exist "C:\Program Files\Docker\Docker\Docker Desktop.exe" (
    echo  ^!ERROR: Docker not found
    pause
    exit /b 1
)
start "" "C:\Program Files\Docker\Docker\Docker Desktop.exe"
echo        Waiting 45 seconds for Docker...
ping -n 45 127.0.0.1 >nul
echo  [OK] Docker started.

REM ============================================================
REM STEP 3: Weaviate
REM ============================================================
echo.
echo  [3/6] Starting Weaviate...
if not exist "%SHANEBRAIN_ROOT%\weaviate-config\docker-compose.yml" (
    echo  ^!ERROR: docker-compose.yml not found
    pause
    exit /b 1
)

cd /d "%SHANEBRAIN_ROOT%\weaviate-config"
docker-compose down >nul 2>&1
docker-compose up -d

if errorlevel 1 (
    echo  ^!ERROR: Weaviate failed. Is Docker running?
    pause
    exit /b 1
)

echo        Waiting 15 seconds for Weaviate...
ping -n 15 127.0.0.1 >nul

curl -s http://localhost:8080/v1/.well-known/ready >nul 2>&1
if errorlevel 1 (
    echo  ^!WARNING: Weaviate may not be ready yet.
) else (
    echo  [OK] Weaviate ready - http://localhost:8080
)

REM ============================================================
REM STEP 4: Load Balancer (background)
REM ============================================================
echo.
echo  [4/6] Starting Load Balancer...
if exist "%SHANEBRAIN_ROOT%\ollama_loadbalancer.py" (
    start "Load Balancer" cmd /c "cd /d %SHANEBRAIN_ROOT% && python ollama_loadbalancer.py"
    echo        Waiting 5 seconds for Load Balancer...
    ping -n 5 127.0.0.1 >nul
    
    curl -s http://localhost:8000/health >nul 2>&1
    if errorlevel 1 (
        echo  ^!WARNING: Load Balancer may not be ready
    ) else (
        echo  [OK] Load Balancer ready - http://localhost:8000/dashboard
    )
) else (
    echo  ^!WARNING: ollama_loadbalancer.py not found - using direct Ollama
)

REM ============================================================
REM STEP 5: Angel Arcade Bot (background)
REM ============================================================
echo.
echo  [5/6] Starting Angel Arcade bot...
if exist "%SHANEBRAIN_ROOT%\arcade\arcade_bot.py" (
    start "Angel Arcade" cmd /c "cd /d %SHANEBRAIN_ROOT%\arcade && python arcade_bot.py"
    echo  [OK] Angel Arcade starting in background
) else (
    echo  ^!WARNING: arcade_bot.py not found - skipping
)

REM ============================================================
REM STEP 6: ShaneBrain Discord Bot (foreground)
REM ============================================================
echo.
echo  [6/6] Starting ShaneBrain Discord Bot...
echo.
echo  ============================================================
echo       SHANEBRAIN ONLINE - CLUSTER MODE
echo  ============================================================
echo.
echo   Load Balancer: http://localhost:8000/dashboard
echo   Ollama A:      http://192.168.100.1:11434
if %CLUSTER_MODE%==1 (
echo   Ollama B:      http://192.168.100.2:11434 [ONLINE]
) else (
echo   Ollama B:      http://192.168.100.2:11434 [OFFLINE]
)
echo   Weaviate:      http://localhost:8080
echo   Model:         shanebrain-3b:latest
echo   Arcade:        Running in background
echo.
echo  ============================================================
echo.

if not exist "%SHANEBRAIN_ROOT%\bot\bot.py" (
    echo  ^!ERROR: bot.py not found
    pause
    exit /b 1
)

cd /d "%SHANEBRAIN_ROOT%\bot"

REM Use Load Balancer if available, otherwise direct Ollama
curl -s http://localhost:8000/health >nul 2>&1
if errorlevel 1 (
    echo  [INFO] Using direct Ollama (no load balancer)
    set OLLAMA_HOST=http://localhost:11434
) else (
    echo  [INFO] Using Load Balancer for cluster routing
    set OLLAMA_HOST=http://localhost:8000
)

python bot.py

if errorlevel 1 (
    echo.
    echo  ^!ERROR: Bot crashed. Check logs above.
)
pause