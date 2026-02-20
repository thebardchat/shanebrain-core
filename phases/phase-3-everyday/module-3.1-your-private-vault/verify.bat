@echo off
setlocal enabledelayedexpansion
title Verify 3.1 // Your Private Vault
color 0E

echo  [VERIFY] Module 3.1 - Your Private Vault
echo.

REM Check Weaviate is running
curl -s http://localhost:8080/v1/.well-known/ready >nul 2>&1
if errorlevel 1 (
    echo  [FAIL] Weaviate is not running.
    exit /b 1
)

REM Check PersonalDoc collection exists
python -c "
import urllib.request, json, sys

try:
    req = urllib.request.Request('http://localhost:8080/v1/schema/PersonalDoc')
    resp = urllib.request.urlopen(req)
    schema = json.loads(resp.read())
    props = [p['name'] for p in schema.get('properties', [])]
    required = ['title', 'content', 'category', 'source']
    missing = [r for r in required if r not in props]
    if missing:
        print(f'  [FAIL] Missing properties: {missing}')
        sys.exit(1)
    print('  [OK] PersonalDoc collection exists with correct schema')
except urllib.error.HTTPError:
    print('  [FAIL] PersonalDoc collection does not exist')
    sys.exit(1)

# Check document count
req = urllib.request.Request(
    'http://localhost:8080/v1/graphql',
    data=json.dumps({
        'query': '{ Aggregate { PersonalDoc { meta { count } } } }'
    }).encode('utf-8'),
    headers={'Content-Type': 'application/json'},
    method='POST'
)
resp = urllib.request.urlopen(req)
result = json.loads(resp.read())
count = result['data']['Aggregate']['PersonalDoc'][0]['meta']['count']
if count >= 5:
    print(f'  [OK] {count} documents stored in vault')
else:
    print(f'  [FAIL] Only {count} documents found (need at least 5)')
    sys.exit(1)

# Check categories exist
req = urllib.request.Request(
    'http://localhost:8080/v1/graphql',
    data=json.dumps({
        'query': '{ Get { PersonalDoc { category } } }'
    }).encode('utf-8'),
    headers={'Content-Type': 'application/json'},
    method='POST'
)
resp = urllib.request.urlopen(req)
result = json.loads(resp.read())
cats = set(d['category'] for d in result['data']['Get']['PersonalDoc'])
if len(cats) >= 3:
    print(f'  [OK] {len(cats)} categories found: {sorted(cats)}')
else:
    print(f'  [FAIL] Only {len(cats)} categories (need at least 3)')
    sys.exit(1)

print()
print('  Module 3.1 VERIFIED - Your Private Vault is working!')
"

if errorlevel 1 (
    echo.
    echo  [FAIL] Module 3.1 verification failed. Run exercise.bat first.
    exit /b 1
)

echo.
echo  [PASS] Module 3.1 complete!
exit /b 0
