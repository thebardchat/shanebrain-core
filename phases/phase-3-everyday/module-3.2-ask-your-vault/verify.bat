@echo off
setlocal enabledelayedexpansion
title Verify 3.2 // Ask Your Vault
color 0E

echo  [VERIFY] Module 3.2 - Ask Your Vault
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

REM Verify vault Q&A works
python -c "
import urllib.request, json, sys

# Test semantic search
query = {
    'query': '{Get{PersonalDoc(nearText:{concepts:[\"birthday\"]},limit:1){title content category _additional{certainty}}}}'
}
req = urllib.request.Request(
    'http://localhost:8080/v1/graphql',
    data=json.dumps(query).encode('utf-8'),
    headers={'Content-Type': 'application/json'},
    method='POST'
)
resp = urllib.request.urlopen(req)
result = json.loads(resp.read())
docs = result['data']['Get']['PersonalDoc']

if not docs:
    print('  [FAIL] Semantic search returned no results')
    sys.exit(1)

cert = docs[0].get('_additional', {}).get('certainty', 0)
if cert < 0.5:
    print(f'  [WARN] Low certainty: {cert:.0%}')

print(f'  [OK] Semantic search works - found: {docs[0][\"title\"]} ({cert:.0%})')

# Test Ollama can generate
data = json.dumps({
    'model': 'llama3.2:3b',
    'prompt': 'Say OK in one word.',
    'stream': False,
    'options': {'num_predict': 10}
}).encode('utf-8')
req = urllib.request.Request(
    'http://localhost:11434/api/generate',
    data=data,
    headers={'Content-Type': 'application/json'},
    method='POST'
)
resp = urllib.request.urlopen(req)
result = json.loads(resp.read())
if result.get('response'):
    print('  [OK] Ollama generation works')
else:
    print('  [FAIL] Ollama returned empty response')
    sys.exit(1)

print()
print('  Module 3.2 VERIFIED - Ask Your Vault is working!')
"

if errorlevel 1 (
    echo.
    echo  [FAIL] Module 3.2 verification failed.
    exit /b 1
)

echo.
echo  [PASS] Module 3.2 complete!
exit /b 0
