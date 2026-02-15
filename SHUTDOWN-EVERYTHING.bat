@echo off
setlocal enabledelayedexpansion
title ShaneBrain // SAFE SHUTDOWN
color 0C

echo.
echo  ============================================================
echo       SHANEBRAIN SAFE SHUTDOWN
echo  ============================================================
echo.
echo   Stopping all services in reverse order...
echo.

set SHANEBRAIN_ROOT=D:\Angel_Cloud\shanebrain-core

REM ============================================================
REM STEP 1: Stop Discord Bots
REM ============================================================
echo  [1/6] Stopping Discord bots...
taskkill /FI "WINDOWTITLE eq *bot.py*" /F >nul 2>&1
taskkill /FI "WINDOWTITLE eq *arcade_bot.py*" /F >nul 2>&1
echo  [OK] Discord bots stopped

REM ============================================================
REM STEP 2: Stop Load Balancer
REM ============================================================
echo  [2/6] Stopping Load Balancer...
taskkill /FI "WINDOWTITLE eq *ollama_loadbalancer.py*" /F >nul 2>&1
echo  [OK] Load Balancer stopped

REM ============================================================
REM STEP 3: Shutdown Raspberry Pi (if online)
REM ============================================================
echo  [3/6] Checking Raspberry Pi...
curl -s --connect-timeout 2 http://10.0.0.42:11434/api/tags >nul 2>&1
if errorlevel 1 (
    echo  [INFO] Raspberry Pi already offline
) else (
    echo  [INFO] Shutting down Raspberry Pi safely...
    python -c "import paramiko; ssh = paramiko.SSHClient(); ssh.set_missing_host_key_policy(paramiko.AutoAddHostPolicy()); ssh.connect('10.0.0.42', username='shane', password=open('bot/.env').read().split('PI_PASSWORD=')[1].split()[0]); ssh.exec_command('sudo shutdown -h now'); ssh.close()" >nul 2>&1
    if errorlevel 1 (
        echo  [WARNING] Could not shutdown Pi automatically
        echo            Please manually shutdown: ssh shane@10.0.0.42 'sudo shutdown now'
    ) else (
        echo  [OK] Pi shutdown command sent
    )
)

REM ============================================================
REM STEP 4: Stop Weaviate
REM ============================================================
echo  [4/6] Stopping Weaviate...
cd /d "%SHANEBRAIN_ROOT%\weaviate-config"
docker-compose down >nul 2>&1
if errorlevel 1 (
    echo  [WARNING] Weaviate may not have stopped cleanly
) else (
    echo  [OK] Weaviate stopped
)

REM ============================================================
REM STEP 5: Stop Ollama
REM ============================================================
echo  [5/6] Stopping Ollama...
taskkill /IM ollama.exe /F >nul 2>&1
if errorlevel 1 (
    echo  [INFO] Ollama was not running
) else (
    echo  [OK] Ollama stopped
)

REM ============================================================
REM STEP 6: Stop Docker Desktop (optional)
REM ============================================================
echo  [6/6] Stopping Docker Desktop...
taskkill /IM "Docker Desktop.exe" /F >nul 2>&1
if errorlevel 1 (
    echo  [INFO] Docker was not running
) else (
    echo  [OK] Docker stopped
)

REM ============================================================
REM FINAL STATUS
REM ============================================================
echo.
echo  ============================================================
echo       SHUTDOWN COMPLETE
echo  ============================================================
echo.
echo   All services stopped safely:
echo   - Discord bots stopped
echo   - Load balancer stopped
echo   - Raspberry Pi shutdown initiated
echo   - Weaviate stopped
echo   - Ollama stopped
echo   - Docker Desktop stopped
echo.
echo   Computer B: Manual shutdown required if running
echo              (Use START-COMPUTER-B.bat window or Ctrl+C)
echo.
echo   Raspberry Pi: Wait 30 seconds before unplugging
echo.
echo  ============================================================
echo.
pause