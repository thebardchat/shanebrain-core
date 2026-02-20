@echo off
setlocal enabledelayedexpansion
title Verify 3.6 // Digital Footprint
color 0E

echo  [VERIFY] Module 3.6 - Digital Footprint
echo.

curl -s http://localhost:8080/v1/.well-known/ready >nul 2>&1
if errorlevel 1 (
    echo  [FAIL] Weaviate is not running.
    exit /b 1
)

python -c "
import urllib.request, json, sys

# Check PrivacyAudit collection
try:
    req = urllib.request.Request('http://localhost:8080/v1/schema/PrivacyAudit')
    resp = urllib.request.urlopen(req)
    schema = json.loads(resp.read())
    props = [p['name'] for p in schema.get('properties', [])]
    required = ['auditType', 'finding', 'risk', 'recommendation', 'timestamp']
    missing = [r for r in required if r not in props]
    if missing:
        print(f'  [FAIL] Missing properties: {missing}')
        sys.exit(1)
    print('  [OK] PrivacyAudit collection exists with correct schema')
except urllib.error.HTTPError:
    print('  [FAIL] PrivacyAudit collection does not exist')
    sys.exit(1)

# Check audit entries
req = urllib.request.Request(
    'http://localhost:8080/v1/graphql',
    data=json.dumps({
        'query': '{ Aggregate { PrivacyAudit { meta { count } } } }'
    }).encode('utf-8'),
    headers={'Content-Type': 'application/json'},
    method='POST'
)
resp = urllib.request.urlopen(req)
result = json.loads(resp.read())
count = result['data']['Aggregate']['PrivacyAudit'][0]['meta']['count']
if count >= 3:
    print(f'  [OK] {count} audit findings stored')
else:
    print(f'  [FAIL] Only {count} findings (need at least 3)')
    sys.exit(1)

# Check audit types
req = urllib.request.Request(
    'http://localhost:8080/v1/graphql',
    data=json.dumps({
        'query': '{ Get { PrivacyAudit { auditType } } }'
    }).encode('utf-8'),
    headers={'Content-Type': 'application/json'},
    method='POST'
)
resp = urllib.request.urlopen(req)
result = json.loads(resp.read())
types = set(d['auditType'] for d in result['data']['Get']['PrivacyAudit'])
print(f'  [OK] Audit types: {sorted(types)}')

print()
print('  Module 3.6 VERIFIED - Digital Footprint is working!')
"

if errorlevel 1 (
    echo.
    echo  [FAIL] Module 3.6 verification failed.
    exit /b 1
)

echo.
echo  [PASS] Module 3.6 complete!
exit /b 0
