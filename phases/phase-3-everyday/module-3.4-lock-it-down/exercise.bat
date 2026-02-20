@echo off
setlocal enabledelayedexpansion
title Phase 3.4 // Lock It Down
color 0C

echo.
echo  ============================================================
echo       MODULE 3.4: LOCK IT DOWN
echo       Security awareness and digital hygiene
echo  ============================================================
echo.

REM ============================================================
REM PREFLIGHT
REM ============================================================
echo  [PREFLIGHT] Checking services...
curl -s http://localhost:8080/v1/.well-known/ready >nul 2>&1
if errorlevel 1 (
    echo  ^!ERROR: Weaviate is not running.
    pause
    exit /b 1
)
curl -s http://localhost:11434/api/tags >nul 2>&1
if errorlevel 1 (
    echo  ^!ERROR: Ollama is not running.
    pause
    exit /b 1
)
echo  [OK] Services ready.
echo.

REM ============================================================
REM STEP 1: Create SecurityLog collection
REM ============================================================
echo  [1/4] Creating SecurityLog collection...

python -c "
import urllib.request, json

try:
    req = urllib.request.Request('http://localhost:8080/v1/schema/SecurityLog')
    urllib.request.urlopen(req)
    print('  SecurityLog already exists - skipping creation')
except urllib.error.HTTPError:
    schema = {
        'class': 'SecurityLog',
        'description': 'Security check results and digital hygiene logs',
        'vectorizer': 'text2vec-ollama',
        'moduleConfig': {
            'text2vec-ollama': {
                'apiEndpoint': 'http://localhost:11434',
                'model': 'nomic-embed-text'
            }
        },
        'properties': [
            {'name': 'checkName', 'dataType': ['text'], 'description': 'Name of the security check'},
            {'name': 'result', 'dataType': ['text'], 'description': 'Check result details'},
            {'name': 'riskLevel', 'dataType': ['text'], 'description': 'Risk: safe, caution, warning'},
            {'name': 'details', 'dataType': ['text'], 'description': 'Detailed findings'},
            {'name': 'timestamp', 'dataType': ['text'], 'description': 'When the check was run'}
        ]
    }
    data = json.dumps(schema).encode('utf-8')
    req = urllib.request.Request(
        'http://localhost:8080/v1/schema',
        data=data,
        headers={'Content-Type': 'application/json'},
        method='POST'
    )
    urllib.request.urlopen(req)
    print('  SecurityLog collection created!')
"

if errorlevel 1 (
    echo  ^!ERROR: Failed to create SecurityLog collection.
    pause
    exit /b 1
)
echo  [OK] SecurityLog ready.
echo.

REM ============================================================
REM STEP 2: Run process check
REM ============================================================
echo  [2/4] Checking running processes...
echo.

python -c "
import subprocess, json, urllib.request, datetime

timestamp = datetime.datetime.now().strftime('%%Y-%%m-%%d %%H:%%M:%%S')

# Get process list using tasklist (standard Windows CMD)
try:
    result = subprocess.run(['tasklist', '/FO', 'CSV', '/NH'], capture_output=True, text=True, timeout=10)
    lines = [l.strip() for l in result.stdout.strip().split('\n') if l.strip()]
except FileNotFoundError:
    # On Linux, use ps instead
    result = subprocess.run(['ps', 'aux', '--no-headers'], capture_output=True, text=True, timeout=10)
    lines = [l.strip() for l in result.stdout.strip().split('\n') if l.strip()]

process_count = len(lines)

# Known safe processes (common Windows and Linux)
known_safe = [
    'system', 'svchost', 'csrss', 'wininit', 'winlogon', 'explorer',
    'dwm', 'taskhostw', 'sihost', 'ctfmon', 'conhost', 'cmd',
    'python', 'ollama', 'docker', 'weaviate', 'curl', 'node',
    'systemd', 'sshd', 'bash', 'init', 'kworker', 'containerd'
]

# Known caution processes (not bad but worth knowing about)
known_caution = [
    'chrome', 'msedge', 'firefox', 'teams', 'slack', 'discord',
    'onedrive', 'dropbox', 'googledrive', 'icloud', 'skype',
    'zoom', 'spotify', 'steam'
]

safe_count = 0
caution_count = 0
unknown_count = 0
unknown_list = []

for line in lines:
    line_lower = line.lower()
    is_safe = any(s in line_lower for s in known_safe)
    is_caution = any(c in line_lower for c in known_caution)
    if is_safe:
        safe_count += 1
    elif is_caution:
        caution_count += 1
    else:
        unknown_count += 1
        # Extract process name
        if '\"' in line:
            name = line.split('\"')[1] if '\"' in line else line[:30]
        else:
            name = line.split()[0] if line.split() else line[:30]
        if name not in unknown_list and len(unknown_list) < 10:
            unknown_list.append(name)

print(f'  Total processes: {process_count}')
print(f'  [SAFE]    Known system/app processes: {safe_count}')
print(f'  [CAUTION] Cloud/network apps running: {caution_count}')
print(f'  [INFO]    Other processes: {unknown_count}')
if unknown_list:
    print(f'  Unknown processes (first 10):')
    for p in unknown_list[:10]:
        print(f'    - {p}')

risk = 'safe'
if caution_count > 5:
    risk = 'caution'
if unknown_count > process_count * 0.5:
    risk = 'warning'

# Save to SecurityLog
log_entry = {
    'checkName': 'Running Processes Check',
    'result': f'{process_count} processes: {safe_count} safe, {caution_count} caution, {unknown_count} other',
    'riskLevel': risk,
    'details': f'Unknown processes: {\", \".join(unknown_list[:10])}' if unknown_list else 'All processes identified',
    'timestamp': timestamp
}
data = json.dumps(log_entry).encode('utf-8')
req = urllib.request.Request(
    'http://localhost:8080/v1/objects?class=SecurityLog',
    data=data,
    headers={'Content-Type': 'application/json'},
    method='POST'
)
urllib.request.urlopen(req)
print(f'  Risk level: {risk.upper()}')
print(f'  Logged to SecurityLog.')
"

echo.

REM ============================================================
REM STEP 3: Run network check
REM ============================================================
echo  [3/4] Checking network connections...
echo.

python -c "
import subprocess, json, urllib.request, datetime

timestamp = datetime.datetime.now().strftime('%%Y-%%m-%%d %%H:%%M:%%S')

# Get network connections
try:
    result = subprocess.run(['netstat', '-n'], capture_output=True, text=True, timeout=10)
    lines = [l.strip() for l in result.stdout.strip().split('\n') if l.strip()]
except FileNotFoundError:
    try:
        result = subprocess.run(['ss', '-tuln'], capture_output=True, text=True, timeout=10)
        lines = [l.strip() for l in result.stdout.strip().split('\n') if l.strip()]
    except:
        lines = ['No network tool available']

# Count connection types
established = sum(1 for l in lines if 'ESTABLISHED' in l.upper() or 'ESTAB' in l.upper())
listening = sum(1 for l in lines if 'LISTEN' in l.upper())
total = len([l for l in lines if any(s in l.upper() for s in ['TCP', 'UDP', 'ESTABLISHED', 'LISTEN', 'ESTAB'])])

# Check for known safe ports
safe_ports = ['8080', '11434', '3000', '9000', '22', '53', '443', '80', '4200']
connections_detail = []
for l in lines:
    parts = l.split()
    for p in parts:
        if ':' in p:
            port = p.split(':')[-1]
            if port.isdigit():
                connections_detail.append(port)

print(f'  Active connections: {total}')
print(f'  Established: {established}')
print(f'  Listening: {listening}')

known_ports = set()
unknown_ports = set()
for port in connections_detail:
    if port in safe_ports:
        known_ports.add(port)
    elif port.isdigit() and int(port) < 49152:
        unknown_ports.add(port)

if known_ports:
    print(f'  Known service ports: {sorted(known_ports)}')
if unknown_ports:
    print(f'  Other listening ports: {sorted(list(unknown_ports)[:10])}')

risk = 'safe'
if established > 20:
    risk = 'caution'

# Save to SecurityLog
log_entry = {
    'checkName': 'Network Connections Check',
    'result': f'{total} connections: {established} established, {listening} listening',
    'riskLevel': risk,
    'details': f'Known ports: {sorted(known_ports)}, Other ports: {sorted(list(unknown_ports)[:10])}',
    'timestamp': timestamp
}
data = json.dumps(log_entry).encode('utf-8')
req = urllib.request.Request(
    'http://localhost:8080/v1/objects?class=SecurityLog',
    data=data,
    headers={'Content-Type': 'application/json'},
    method='POST'
)
urllib.request.urlopen(req)
print(f'  Risk level: {risk.upper()}')
print(f'  Logged to SecurityLog.')
"

echo.

REM ============================================================
REM STEP 4: Digital hygiene checklist
REM ============================================================
echo  [4/4] Digital Hygiene Checklist
echo  ============================================================
echo.
echo   Answer honestly - this stays on YOUR machine:
echo.

python -c "
import json, urllib.request, datetime

timestamp = datetime.datetime.now().strftime('%%Y-%%m-%%d %%H:%%M:%%S')

checks = [
    {
        'question': 'Do you use different passwords for important accounts?',
        'safe': 'Good - unique passwords per account',
        'risk': 'Reused passwords are the #1 cause of account breaches'
    },
    {
        'question': 'Is Windows Update (or system updates) turned on?',
        'safe': 'Good - automatic updates protect you',
        'risk': 'Unpatched systems are vulnerable to known exploits'
    },
    {
        'question': 'Do you check email sender addresses before clicking links?',
        'safe': 'Good - phishing awareness is critical',
        'risk': 'Phishing emails are the #1 way hackers get in'
    },
    {
        'question': 'Do you know what apps have access to your camera/microphone?',
        'safe': 'Good - permission awareness matters',
        'risk': 'Apps can access your camera and mic without visible indicators'
    },
    {
        'question': 'Is your home WiFi password-protected (not the default)?',
        'safe': 'Good - default passwords are publicly known',
        'risk': 'Default WiFi passwords are listed online for every router model'
    }
]

safe_count = 0
risk_count = 0
details = []

for i, check in enumerate(checks, 1):
    print(f'  {i}. {check[\"question\"]}')
    # In batch, we auto-score as informational
    details.append(f'{check[\"question\"]} - {check[\"safe\"]} / Risk: {check[\"risk\"]}')
    print(f'     YES = {check[\"safe\"]}')
    print(f'     NO  = {check[\"risk\"]}')
    print()

# Save hygiene checklist as a single log entry
log_entry = {
    'checkName': 'Digital Hygiene Checklist',
    'result': f'5 hygiene questions reviewed',
    'riskLevel': 'caution',
    'details': ' | '.join(details),
    'timestamp': timestamp
}
data = json.dumps(log_entry).encode('utf-8')
req = urllib.request.Request(
    'http://localhost:8080/v1/objects?class=SecurityLog',
    data=data,
    headers={'Content-Type': 'application/json'},
    method='POST'
)
urllib.request.urlopen(req)
print('  Hygiene checklist logged to SecurityLog.')
"

echo.
echo  ============================================================
echo       SECURITY CHECK COMPLETE
echo  ============================================================
echo.
echo   YOUR RESULTS:
echo   - Process check logged
echo   - Network check logged
echo   - Digital hygiene reviewed
echo   All results stored in YOUR SecurityLog vault.
echo.
echo   SECURITY REMINDER:
echo   You just learned what's running on your machine and who
echo   it talks to. Most people never check. Now you know HOW.
echo   Run this periodically — like a health checkup for your PC.
echo.
echo   Next: Module 3.5 — Daily Briefing
echo   (Personal journal and daily planner)
echo.
pause
exit /b 0
