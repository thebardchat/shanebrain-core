@echo off
setlocal enabledelayedexpansion
title Verify 3.4 // Lock It Down
color 0E

echo  [VERIFY] Module 3.4 - Lock It Down
echo.

curl -s http://localhost:8080/v1/.well-known/ready >nul 2>&1
if errorlevel 1 (
    echo  [FAIL] Weaviate is not running.
    exit /b 1
)

python -c "
import urllib.request, json, sys

# Check SecurityLog collection exists
try:
    req = urllib.request.Request('http://localhost:8080/v1/schema/SecurityLog')
    resp = urllib.request.urlopen(req)
    schema = json.loads(resp.read())
    props = [p['name'] for p in schema.get('properties', [])]
    required = ['checkName', 'result', 'riskLevel', 'details', 'timestamp']
    missing = [r for r in required if r not in props]
    if missing:
        print(f'  [FAIL] Missing properties: {missing}')
        sys.exit(1)
    print('  [OK] SecurityLog collection exists with correct schema')
except urllib.error.HTTPError:
    print('  [FAIL] SecurityLog collection does not exist')
    sys.exit(1)

# Check log entries
req = urllib.request.Request(
    'http://localhost:8080/v1/graphql',
    data=json.dumps({
        'query': '{ Aggregate { SecurityLog { meta { count } } } }'
    }).encode('utf-8'),
    headers={'Content-Type': 'application/json'},
    method='POST'
)
resp = urllib.request.urlopen(req)
result = json.loads(resp.read())
count = result['data']['Aggregate']['SecurityLog'][0]['meta']['count']
if count >= 1:
    print(f'  [OK] {count} security log entries found')
else:
    print(f'  [FAIL] No security logs found - run exercise first')
    sys.exit(1)

# Check we have process or network checks
req = urllib.request.Request(
    'http://localhost:8080/v1/graphql',
    data=json.dumps({
        'query': '{ Get { SecurityLog { checkName riskLevel } } }'
    }).encode('utf-8'),
    headers={'Content-Type': 'application/json'},
    method='POST'
)
resp = urllib.request.urlopen(req)
result = json.loads(resp.read())
checks = [d['checkName'] for d in result['data']['Get']['SecurityLog']]
print(f'  [OK] Checks performed: {checks}')

print()
print('  Module 3.4 VERIFIED - Lock It Down is working!')
"

if errorlevel 1 (
    echo.
    echo  [FAIL] Module 3.4 verification failed.
    exit /b 1
)

echo.
echo  [PASS] Module 3.4 complete!
exit /b 0
