@echo off
setlocal enabledelayedexpansion
title Verify 3.7 // The Family Dashboard
color 0E

echo  [VERIFY] Module 3.7 - The Family Dashboard
echo.

REM Check services
curl -s http://localhost:8080/v1/.well-known/ready >nul 2>&1
if errorlevel 1 (
    echo  [FAIL] Weaviate is not running.
    exit /b 1
)

curl -s http://localhost:11434/api/tags >nul 2>&1
if errorlevel 1 (
    echo  [FAIL] Ollama is not running.
    exit /b 1
)

REM Verify all Phase 3 collections exist
python -c "
import urllib.request, json, sys

collections = {
    'PersonalDoc': ['title', 'content', 'category', 'source'],
    'PersonalDraft': ['title', 'content', 'messageType', 'tone'],
    'SecurityLog': ['checkName', 'result', 'riskLevel', 'details', 'timestamp'],
    'DailyNote': ['title', 'content', 'noteType', 'date'],
    'PrivacyAudit': ['auditType', 'finding', 'risk', 'recommendation', 'timestamp']
}

all_ok = True
total_objects = 0

for coll, required_props in collections.items():
    try:
        req = urllib.request.Request(f'http://localhost:8080/v1/schema/{coll}')
        resp = urllib.request.urlopen(req)
        schema = json.loads(resp.read())
        props = [p['name'] for p in schema.get('properties', [])]
        missing = [r for r in required_props if r not in props]
        if missing:
            print(f'  [FAIL] {coll}: missing properties {missing}')
            all_ok = False
            continue

        # Get count
        req = urllib.request.Request(
            'http://localhost:8080/v1/graphql',
            data=json.dumps({
                'query': '{ Aggregate { ' + coll + ' { meta { count } } } }'
            }).encode('utf-8'),
            headers={'Content-Type': 'application/json'},
            method='POST'
        )
        resp = urllib.request.urlopen(req)
        result = json.loads(resp.read())
        count = result['data']['Aggregate'][coll][0]['meta']['count']
        total_objects += count

        if count > 0:
            print(f'  [OK] {coll}: {count} objects')
        else:
            print(f'  [WARN] {coll}: exists but empty (run module exercise)')

    except urllib.error.HTTPError:
        print(f'  [FAIL] {coll}: collection does not exist')
        all_ok = False

print()
print(f'  Total objects across all vaults: {total_objects}')

if not all_ok:
    print()
    print('  [FAIL] Not all collections are set up. Complete modules 3.1-3.6 first.')
    sys.exit(1)

if total_objects < 10:
    print('  [WARN] Low object count - run module exercises to populate vaults')

print()
print('  Module 3.7 VERIFIED - Family Dashboard is ready!')
print('  Phase 3: Everyday Users - COMPLETE!')
"

if errorlevel 1 (
    echo.
    echo  [FAIL] Module 3.7 verification failed.
    exit /b 1
)

echo.
echo  [PASS] Module 3.7 complete! Phase 3 finished!
exit /b 0
