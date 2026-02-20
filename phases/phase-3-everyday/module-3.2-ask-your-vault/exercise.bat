@echo off
setlocal enabledelayedexpansion
title Phase 3.2 // Ask Your Vault
color 0E

echo.
echo  ============================================================
echo       MODULE 3.2: ASK YOUR VAULT
echo       Personal Q^&A from your knowledge base
echo  ============================================================
echo.

REM ============================================================
REM PREFLIGHT: Check services
REM ============================================================
echo  [PREFLIGHT] Checking Weaviate...
curl -s http://localhost:8080/v1/.well-known/ready >nul 2>&1
if errorlevel 1 (
    echo  ^!ERROR: Weaviate is not running.
    pause
    exit /b 1
)
echo  [OK] Weaviate is ready.

echo  [PREFLIGHT] Checking Ollama...
curl -s http://localhost:11434/api/tags >nul 2>&1
if errorlevel 1 (
    echo  ^!ERROR: Ollama is not running.
    pause
    exit /b 1
)
echo  [OK] Ollama is ready.

REM Check PersonalDoc exists
echo  [PREFLIGHT] Checking PersonalDoc vault...
python -c "
import urllib.request, json, sys
try:
    req = urllib.request.Request('http://localhost:8080/v1/schema/PersonalDoc')
    urllib.request.urlopen(req)
    print('  [OK] PersonalDoc vault found')
except:
    print('  [FAIL] PersonalDoc not found. Run Module 3.1 first.')
    sys.exit(1)
"
if errorlevel 1 (
    pause
    exit /b 1
)
echo.

REM ============================================================
REM STEP 1: Demo queries against the vault
REM ============================================================
echo  [1/2] Running demo queries against your vault...
echo.

python -c "
import urllib.request, json

def search_vault(question, limit=3):
    \"\"\"Search PersonalDoc using semantic similarity.\"\"\"
    query = {
        'query': '{Get{PersonalDoc(nearText:{concepts:[\"' + question.replace('\"', '') + '\"]},limit:' + str(limit) + '){title content category source _additional{certainty}}}}'
    }
    req = urllib.request.Request(
        'http://localhost:8080/v1/graphql',
        data=json.dumps(query).encode('utf-8'),
        headers={'Content-Type': 'application/json'},
        method='POST'
    )
    resp = urllib.request.urlopen(req)
    result = json.loads(resp.read())
    return result['data']['Get']['PersonalDoc']

def ask_ollama(question, context):
    \"\"\"Ask Ollama to answer using vault context.\"\"\"
    prompt = f'''You are a helpful family assistant. Answer the question using ONLY the provided context.
If the answer is not in the context, say \"I don't have that in the vault.\"
Keep answers brief and helpful. Cite which document the answer came from.

Context:
{context}

Question: {question}

Answer:'''

    data = json.dumps({
        'model': 'llama3.2:3b',
        'prompt': prompt,
        'stream': False,
        'options': {'temperature': 0.3, 'num_predict': 200}
    }).encode('utf-8')
    req = urllib.request.Request(
        'http://localhost:11434/api/generate',
        data=data,
        headers={'Content-Type': 'application/json'},
        method='POST'
    )
    resp = urllib.request.urlopen(req)
    result = json.loads(resp.read())
    return result['response'].strip()

demo_questions = [
    'When is Aunt Sarah birthday?',
    'What is Dad allergic to?',
    'How do you make Grandma cornbread?',
    'When is spring break?',
    'What vet does the dog see?'
]

for q in demo_questions:
    print(f'  Q: {q}')
    docs = search_vault(q)
    if docs:
        context = ''
        sources = []
        for d in docs:
            context += f\"\"\"Title: {d['title']}\nContent: {d['content']}\nCategory: {d['category']}\n\n\"\"\"
            cert = d.get('_additional', {}).get('certainty', 0)
            sources.append(f\"{d['title']} [{d['category']}] ({cert:.0%} match)\")
        answer = ask_ollama(q, context)
        print(f'  A: {answer}')
        print(f'  Sources: {sources[0]}')
    else:
        print('  A: No matching documents found in vault.')
    print()
"

if errorlevel 1 (
    echo  ^!WARNING: Some queries may have failed. Check Ollama model availability.
)

REM ============================================================
REM STEP 2: Interactive Q&A mode
REM ============================================================
echo.
echo  [2/2] Interactive mode - Ask your vault anything!
echo         Type 'quit' to exit.
echo  ============================================================
echo.

:ASK_LOOP
set "QUESTION="
set /p "QUESTION=  Your question: "
if /i "!QUESTION!"=="quit" goto DONE
if "!QUESTION!"=="" goto ASK_LOOP

python -c "
import urllib.request, json

question = '''!QUESTION!'''

# Search vault
query = {
    'query': '{Get{PersonalDoc(nearText:{concepts:[\"' + question.replace('\"', '').replace(\"'\", '') + '\"]},limit:3){title content category source _additional{certainty}}}}'
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
    print('  No matching documents found.')
else:
    context = ''
    for d in docs:
        context += f\"\"\"Title: {d['title']}\nContent: {d['content']}\n\n\"\"\"

    prompt = f'''You are a helpful family assistant. Answer using ONLY the context below.
If the answer is not in the context, say so. Be brief.

Context:
{context}

Question: {question}

Answer:'''

    data = json.dumps({
        'model': 'llama3.2:3b',
        'prompt': prompt,
        'stream': False,
        'options': {'temperature': 0.3, 'num_predict': 200}
    }).encode('utf-8')
    req = urllib.request.Request(
        'http://localhost:11434/api/generate',
        data=data,
        headers={'Content-Type': 'application/json'},
        method='POST'
    )
    resp = urllib.request.urlopen(req)
    answer = json.loads(resp.read())['response'].strip()
    print(f'  A: {answer}')
    cert = docs[0].get('_additional', {}).get('certainty', 0)
    print(f'  Source: {docs[0][\"title\"]} [{docs[0][\"category\"]}] ({cert:.0%} match)')
"
echo.
goto ASK_LOOP

:DONE
echo.
echo  ============================================================
echo       VAULT Q^&A SESSION COMPLETE
echo  ============================================================
echo.
echo   SECURITY REMINDER:
echo   Every question you just asked stayed on YOUR machine.
echo   No cloud service logged your queries. No company knows
echo   what you asked about your family, health, or finances.
echo   That's the power of local AI.
echo.
echo   Next: Module 3.3 — Write It Right
echo   (Personal writing assistant)
echo.
pause
exit /b 0
