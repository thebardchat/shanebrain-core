@echo off
setlocal enabledelayedexpansion
title ShaneBrain // COMPUTER B (Cluster Node)
color 0B

echo.
echo  ============================================================
echo       SHANEBRAIN CLUSTER NODE B
echo  ============================================================
echo.
echo   Role: Secondary Ollama node for load balancing
echo   Head: Computer A (192.168.100.1)
echo   This: Computer B (192.168.100.2)
echo.

REM ============================================================
REM PREFLIGHT: Check network share
REM ============================================================
echo  [PREFLIGHT] Checking connection to Computer A...
if exist "Z:\shanebrain-core" (
    echo  [OK] Z: drive connected to Computer A
) else (
    echo  ^!WARNING: Z: drive not mapped. Reconnecting...
    net use Z: \\192.168.100.1\ShaneBrain /persistent:yes
    if errorlevel 1 (
        echo  ^!ERROR: Could not connect to Computer A
        echo  Make sure Computer A is running and sharing is enabled.
        pause
        exit /b 1
    )
    echo  [OK] Z: drive reconnected
)

REM ============================================================
REM Check RAM
REM ============================================================
echo.
echo  [1/2] Checking available RAM...
for /f "tokens=2 delims==" %%A in ('wmic OS get FreePhysicalMemory /value') do set FreeRAM=%%A
set /a FreeRAM_MB=%FreeRAM:~0,-3%

if %FreeRAM_MB% LSS 800 (
    echo  ^!ERROR: Only %FreeRAM_MB% MB free. Need at least 800 MB.
    pause
    exit /b 1
)
echo  [OK] RAM: %FreeRAM_MB% MB free

REM ============================================================
REM Start Ollama (for cluster load balancing)
REM ============================================================
echo.
echo  [2/2] Starting Ollama server...
set OLLAMA_HOST=0.0.0.0:11434
set OLLAMA_ORIGINS=*

REM Check if model exists locally, if not pull it
ollama list | findstr /i "shanebrain-3b" >nul 2>&1
if errorlevel 1 (
    echo        Model not found. Pulling shanebrain-3b...
    echo        (This may take a few minutes on first run)
    ollama pull llama3.2:1b
    echo        Creating shanebrain-3b from llama3.2:1b...
    
    REM Create a simple modelfile for Computer B
    echo FROM llama3.2:1b > %TEMP%\shanebrain.modelfile
    echo PARAMETER temperature 0.3 >> %TEMP%\shanebrain.modelfile
    echo SYSTEM "You are ShaneBrain, Shane's AI assistant. Be brief and direct." >> %TEMP%\shanebrain.modelfile
    ollama create shanebrain-3b -f %TEMP%\shanebrain.modelfile
    del %TEMP%\shanebrain.modelfile
)

echo.
echo  ============================================================
echo       COMPUTER B ONLINE - CLUSTER NODE
echo  ============================================================
echo.
echo   Ollama:     http://192.168.100.2:11434
echo   Status:     Ready for load balancing
echo   Model:      shanebrain-3b:latest
echo.
echo   Computer A can now route requests here!
echo.
echo   To test: curl http://192.168.100.2:11434/api/tags
echo.
echo  ============================================================
echo.
echo   Press Ctrl+C to stop Ollama, or close this window.
echo.

ollama serve

pause
