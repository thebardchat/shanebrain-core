@echo off
setlocal enabledelayedexpansion
title Verify 3.5 // Daily Briefing
color 0E

echo  [VERIFY] Module 3.5 - Daily Briefing
echo.

curl -s http://localhost:8080/v1/.well-known/ready >nul 2>&1
if errorlevel 1 (
    echo  [FAIL] Weaviate is not running.
    exit /b 1
)

python -c "
import urllib.request, json, sys

# Check DailyNote collection
try:
    req = urllib.request.Request('http://localhost:8080/v1/schema/DailyNote')
    resp = urllib.request.urlopen(req)
    schema = json.loads(resp.read())
    props = [p['name'] for p in schema.get('properties', [])]
    required = ['title', 'content', 'noteType', 'date']
    missing = [r for r in required if r not in props]
    if missing:
        print(f'  [FAIL] Missing properties: {missing}')
        sys.exit(1)
    print('  [OK] DailyNote collection exists with correct schema')
except urllib.error.HTTPError:
    print('  [FAIL] DailyNote collection does not exist')
    sys.exit(1)

# Check note count
req = urllib.request.Request(
    'http://localhost:8080/v1/graphql',
    data=json.dumps({
        'query': '{ Aggregate { DailyNote { meta { count } } } }'
    }).encode('utf-8'),
    headers={'Content-Type': 'application/json'},
    method='POST'
)
resp = urllib.request.urlopen(req)
result = json.loads(resp.read())
count = result['data']['Aggregate']['DailyNote'][0]['meta']['count']
if count >= 3:
    print(f'  [OK] {count} journal entries found')
else:
    print(f'  [FAIL] Only {count} entries (need at least 3)')
    sys.exit(1)

# Check note types
req = urllib.request.Request(
    'http://localhost:8080/v1/graphql',
    data=json.dumps({
        'query': '{ Get { DailyNote { noteType } } }'
    }).encode('utf-8'),
    headers={'Content-Type': 'application/json'},
    method='POST'
)
resp = urllib.request.urlopen(req)
result = json.loads(resp.read())
types = set(d['noteType'] for d in result['data']['Get']['DailyNote'])
if len(types) >= 2:
    print(f'  [OK] Note types found: {sorted(types)}')
else:
    print(f'  [FAIL] Only {len(types)} note type(s) found (need at least 2)')
    sys.exit(1)

print()
print('  Module 3.5 VERIFIED - Daily Briefing is working!')
"

if errorlevel 1 (
    echo.
    echo  [FAIL] Module 3.5 verification failed.
    exit /b 1
)

echo.
echo  [PASS] Module 3.5 complete!
exit /b 0
