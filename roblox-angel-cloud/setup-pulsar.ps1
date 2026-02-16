# ============================================================================
# Angel Cloud: Pulsar00100 One-Time Setup
# Run this ONCE in PowerShell as Administrator on Pulsar00100
# After this, the Pi can SSH in and manage everything remotely
# ============================================================================

Write-Host "`n=== Angel Cloud: Pulsar00100 Setup ===" -ForegroundColor Cyan
Write-Host "This will set up SSH, Rojo, Roblox Studio, and everything needed.`n"

# 1. Install Roblox Studio
Write-Host "[1/6] Installing Roblox Studio..." -ForegroundColor Yellow
$studioInstaller = "$env:TEMP\RobloxStudioLauncherBeta.exe"
if (-not (Test-Path "$env:LOCALAPPDATA\Roblox\Versions\*\RobloxStudioBeta.exe")) {
    Invoke-WebRequest -Uri "https://setup.rbxcdn.com/RobloxStudioLauncherBeta.exe" -OutFile $studioInstaller
    Start-Process -FilePath $studioInstaller -Wait
    Remove-Item $studioInstaller -Force 2>$null
    Write-Host "  Roblox Studio installed. You may need to sign in on first launch." -ForegroundColor Green
} else {
    Write-Host "  Roblox Studio already installed." -ForegroundColor Green
}

# 2. Enable OpenSSH Server
Write-Host "[2/6] Enabling OpenSSH Server..." -ForegroundColor Yellow
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 2>$null
Start-Service sshd
Set-Service -Name sshd -StartupType Automatic
# Allow SSH through Windows Firewall
New-NetFirewallRule -Name "OpenSSH-Server" -DisplayName "OpenSSH Server (TCP 22)" -Direction Inbound -Protocol TCP -LocalPort 22 -Action Allow 2>$null
Write-Host "  SSH Server enabled and set to auto-start." -ForegroundColor Green

# 3. Download and install Rojo CLI
Write-Host "[3/6] Installing Rojo CLI..." -ForegroundColor Yellow
$rojoDir = "$env:LOCALAPPDATA\Rojo"
New-Item -ItemType Directory -Path $rojoDir -Force | Out-Null
$rojoUrl = "https://github.com/rojo-rbx/rojo/releases/latest/download/rojo-7.6.1-windows-x86_64.zip"
$rojoZip = "$env:TEMP\rojo.zip"
Invoke-WebRequest -Uri $rojoUrl -OutFile $rojoZip
Expand-Archive -Path $rojoZip -DestinationPath $rojoDir -Force
Remove-Item $rojoZip

# Add to PATH if not already there
$currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($currentPath -notlike "*$rojoDir*") {
    [Environment]::SetEnvironmentVariable("PATH", "$currentPath;$rojoDir", "User")
}
Write-Host "  Rojo installed to $rojoDir" -ForegroundColor Green

# 4. Download Rojo Studio Plugin
Write-Host "[4/6] Installing Rojo Studio Plugin..." -ForegroundColor Yellow
$pluginDir = "$env:LOCALAPPDATA\Roblox\Plugins"
New-Item -ItemType Directory -Path $pluginDir -Force | Out-Null
$pluginUrl = "https://github.com/rojo-rbx/rojo/releases/latest/download/Rojo.rbxm"
Invoke-WebRequest -Uri $pluginUrl -OutFile "$pluginDir\Rojo.rbxm"
Write-Host "  Rojo plugin installed to $pluginDir" -ForegroundColor Green

# 5. Test SSH is working
Write-Host "[5/6] Verifying SSH..." -ForegroundColor Yellow
$sshStatus = Get-Service sshd
if ($sshStatus.Status -eq "Running") {
    Write-Host "  SSH is running. Pi can now connect at 100.81.70.117:22" -ForegroundColor Green
} else {
    Write-Host "  WARNING: SSH did not start. Try: Start-Service sshd" -ForegroundColor Red
}

# 6. Summary
Write-Host "`n[6/6] Setup Complete!" -ForegroundColor Yellow
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Next steps:" -ForegroundColor White
Write-Host "  1. Open Roblox Studio and sign in (if first time)"
Write-Host "  2. Game Settings -> Security -> Enable HTTP Requests"
Write-Host "  3. The Pi handles everything else via SSH"
Write-Host ""
Write-Host "Pi Rojo server: 100.67.120.6:34872" -ForegroundColor Cyan
Write-Host "In Studio: Plugins -> Rojo -> Connect -> 100.67.120.6:34872" -ForegroundColor Cyan
Write-Host "============================================`n"
