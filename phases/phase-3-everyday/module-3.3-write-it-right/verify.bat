@echo off
setlocal enabledelayedexpansion
title Verify 3.3 // Write It Right
color 0E

echo  [VERIFY] Module 3.3 - Write It Right
echo.

curl -s http://localhost:8080/v1/.well-known/ready >nul 2>&1
if errorlevel 1 (
    echo  [FAIL] Weaviate is not running.
    exit /b 1
)

python -c "
import urllib.request, json, sys

# Check PersonalDraft collection exists
try:
    req = urllib.request.Request('http://localhost:8080/v1/schema/PersonalDraft')
    resp = urllib.request.urlopen(req)
    schema = json.loads(resp.read())
    props = [p['name'] for p in schema.get('properties', [])]
    required = ['title', 'content', 'messageType', 'tone']
    missing = [r for r in required if r not in props]
    if missing:
        print(f'  [FAIL] Missing properties: {missing}')
        sys.exit(1)
    print('  [OK] PersonalDraft collection exists with correct schema')
except urllib.error.HTTPError:
    print('  [FAIL] PersonalDraft collection does not exist')
    sys.exit(1)

# Check draft count
req = urllib.request.Request(
    'http://localhost:8080/v1/graphql',
    data=json.dumps({
        'query': '{ Aggregate { PersonalDraft { meta { count } } } }'
    }).encode('utf-8'),
    headers={'Content-Type': 'application/json'},
    method='POST'
)
resp = urllib.request.urlopen(req)
result = json.loads(resp.read())
count = result['data']['Aggregate']['PersonalDraft'][0]['meta']['count']
if count >= 1:
    print(f'  [OK] {count} drafts stored')
else:
    print(f'  [FAIL] No drafts found - run exercise first')
    sys.exit(1)

print()
print('  Module 3.3 VERIFIED - Write It Right is working!')
"

if errorlevel 1 (
    echo.
    echo  [FAIL] Module 3.3 verification failed.
    exit /b 1
)

echo.
echo  [PASS] Module 3.3 complete!
exit /b 0
