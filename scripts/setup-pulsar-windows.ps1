# ============================================================
# ShaneBrain Network Setup - Windows (pulsar00100)
# Run as Administrator in PowerShell
# ============================================================

Write-Host "╔══════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  ShaneBrain Windows Setup            ║" -ForegroundColor Cyan
Write-Host "║  pulsar00100 hardening + tools       ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Check admin
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "[ERROR] Run this as Administrator!" -ForegroundColor Red
    exit 1
}

# --- FIREWALL HARDENING ---
Write-Host "[1/5] Configuring Windows Firewall..." -ForegroundColor Yellow

# Enable firewall on all profiles
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True

# Allow Tailscale subnet
New-NetFirewallRule -DisplayName "Tailscale Full Access" -Direction Inbound -RemoteAddress 100.64.0.0/10 -Action Allow -ErrorAction SilentlyContinue

# Allow LAN access to common ports
New-NetFirewallRule -DisplayName "LAN SSH" -Direction Inbound -RemoteAddress 192.168.0.0/16 -LocalPort 22 -Protocol TCP -Action Allow -ErrorAction SilentlyContinue

# Block everything else inbound (default deny)
Set-NetFirewallProfile -Profile Public -DefaultInboundAction Block
Write-Host "[OK] Firewall configured" -ForegroundColor Green

# --- INSTALL TOOLS VIA WINGET ---
Write-Host "[2/5] Installing tools via winget..." -ForegroundColor Yellow

# Install OpenSSH Server (so Pi can reach this machine)
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 -ErrorAction SilentlyContinue
Start-Service sshd -ErrorAction SilentlyContinue
Set-Service -Name sshd -StartupType Automatic -ErrorAction SilentlyContinue
Write-Host "[OK] OpenSSH Server enabled" -ForegroundColor Green

# Install monitoring/dev tools
$tools = @(
    "Microsoft.WindowsTerminal",
    "Git.Git",
    "Python.Python.3.12",
    "GnuWin32.Grep"
)

foreach ($tool in $tools) {
    Write-Host "  Installing $tool..." -ForegroundColor DarkGray
    winget install --id $tool --accept-source-agreements --accept-package-agreements --silent 2>$null
}
Write-Host "[OK] Dev tools installed" -ForegroundColor Green

# --- ENABLE AUTO-UPDATES ---
Write-Host "[3/5] Configuring auto-updates..." -ForegroundColor Yellow
$AutoUpdate = (New-Object -ComObject Microsoft.Update.AutoUpdate)
$AutoUpdate.EnableService()
Write-Host "[OK] Auto-updates enabled" -ForegroundColor Green

# --- INSTALL GLANCES (Python) ---
Write-Host "[4/5] Installing Glances system monitor..." -ForegroundColor Yellow
pip install glances 2>$null
Write-Host "[OK] Glances installed (run with: glances)" -ForegroundColor Green

# --- TAILSCALE CHECK ---
Write-Host "[5/5] Checking Tailscale..." -ForegroundColor Yellow
$ts = Get-Process tailscaled -ErrorAction SilentlyContinue
if ($ts) {
    Write-Host "[OK] Tailscale is running" -ForegroundColor Green
} else {
    Write-Host "[WARN] Tailscale not detected. Install from https://tailscale.com/download" -ForegroundColor Yellow
}

# --- SUMMARY ---
Write-Host ""
Write-Host "╔══════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║  Setup Complete!                     ║" -ForegroundColor Green
Write-Host "╠══════════════════════════════════════╣" -ForegroundColor Green
Write-Host "║  Firewall: Hardened                  ║" -ForegroundColor Green
Write-Host "║  SSH: Enabled                        ║" -ForegroundColor Green
Write-Host "║  Auto-updates: On                    ║" -ForegroundColor Green
Write-Host "║  Glances: Installed                  ║" -ForegroundColor Green
Write-Host "║  Tailscale: Check above              ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "Next: Copy this machine's SSH key to the Pi:" -ForegroundColor Cyan
Write-Host "  ssh-keygen -t ed25519" -ForegroundColor White
Write-Host "  ssh-copy-id shanebrain@100.67.120.6" -ForegroundColor White
