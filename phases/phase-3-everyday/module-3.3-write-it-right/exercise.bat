@echo off
setlocal enabledelayedexpansion
title Phase 3.3 // Write It Right
color 0E

echo.
echo  ============================================================
echo       MODULE 3.3: WRITE IT RIGHT
echo       Personal writing assistant
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
REM STEP 1: Create PersonalDraft collection
REM ============================================================
echo  [1/3] Creating PersonalDraft collection...

python -c "
import urllib.request, json

try:
    req = urllib.request.Request('http://localhost:8080/v1/schema/PersonalDraft')
    urllib.request.urlopen(req)
    print('  PersonalDraft already exists - skipping creation')
except urllib.error.HTTPError:
    schema = {
        'class': 'PersonalDraft',
        'description': 'Personal writing drafts - thank you notes, emails, letters, cards',
        'vectorizer': 'text2vec-ollama',
        'moduleConfig': {
            'text2vec-ollama': {
                'apiEndpoint': 'http://localhost:11434',
                'model': 'nomic-embed-text'
            }
        },
        'properties': [
            {'name': 'title', 'dataType': ['text'], 'description': 'Draft title'},
            {'name': 'content', 'dataType': ['text'], 'description': 'Draft content'},
            {'name': 'messageType', 'dataType': ['text'], 'description': 'Type: thankyou, email, letter, card'},
            {'name': 'tone', 'dataType': ['text'], 'description': 'Tone: warm, formal, casual'}
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
    print('  PersonalDraft collection created!')
"

if errorlevel 1 (
    echo  ^!ERROR: Failed to create PersonalDraft collection.
    pause
    exit /b 1
)
echo  [OK] PersonalDraft ready.
echo.

REM ============================================================
REM STEP 2: Generate demo drafts
REM ============================================================
echo  [2/3] Generating sample drafts using your vault context...
echo.

python -c "
import urllib.request, json, time

def search_vault(concept, limit=2):
    query = {
        'query': '{Get{PersonalDoc(nearText:{concepts:[\"' + concept + '\"]},limit:' + str(limit) + '){title content category}}}'
    }
    req = urllib.request.Request(
        'http://localhost:8080/v1/graphql',
        data=json.dumps(query).encode('utf-8'),
        headers={'Content-Type': 'application/json'},
        method='POST'
    )
    resp = urllib.request.urlopen(req)
    result = json.loads(resp.read())
    docs = result.get('data', {}).get('Get', {}).get('PersonalDoc', [])
    return '\n'.join(f\"{d['title']}: {d['content']}\" for d in docs) if docs else ''

def generate_draft(msg_type, tone, description, context):
    tone_guide = {
        'warm': 'Write in a warm, heartfelt, personal tone. Use first person.',
        'formal': 'Write in a professional, respectful tone. Be proper but not stiff.',
        'casual': 'Write in a relaxed, conversational tone. Keep it brief and friendly.'
    }
    prompt = f'''Write a {msg_type} with a {tone} tone.
{tone_guide.get(tone, '')}
Description: {description}
Personal context (use if relevant): {context}
Keep it under 150 words. Do not include subject lines unless it is an email.
Just write the message body.'''

    data = json.dumps({
        'model': 'llama3.2:3b',
        'prompt': prompt,
        'stream': False,
        'options': {'temperature': 0.7, 'num_predict': 300}
    }).encode('utf-8')
    req = urllib.request.Request(
        'http://localhost:11434/api/generate',
        data=data,
        headers={'Content-Type': 'application/json'},
        method='POST'
    )
    resp = urllib.request.urlopen(req)
    return json.loads(resp.read())['response'].strip()

def save_draft(title, content, msg_type, tone):
    data = json.dumps({
        'title': title,
        'content': content,
        'messageType': msg_type,
        'tone': tone
    }).encode('utf-8')
    req = urllib.request.Request(
        'http://localhost:8080/v1/objects?class=PersonalDraft',
        data=data,
        headers={'Content-Type': 'application/json'},
        method='POST'
    )
    urllib.request.urlopen(req)

demos = [
    {
        'type': 'thankyou',
        'tone': 'warm',
        'desc': 'Thank Aunt Sarah for the birthday gift she sent for the kids',
        'search': 'Aunt Sarah birthday family'
    },
    {
        'type': 'email',
        'tone': 'formal',
        'desc': 'Email to teacher about upcoming parent-teacher conference scheduling',
        'search': 'school calendar teacher conference'
    },
    {
        'type': 'card',
        'tone': 'warm',
        'desc': 'Get-well card for Uncle Mike who had surgery',
        'search': 'Uncle Mike family'
    }
]

for demo in demos:
    print(f'  Drafting: {demo[\"type\"]} ({demo[\"tone\"]}) - {demo[\"desc\"][:50]}...')
    context = search_vault(demo['search'])
    draft = generate_draft(demo['type'], demo['tone'], demo['desc'], context)
    title = f'{demo[\"type\"].title()} - {demo[\"desc\"][:40]}'
    save_draft(title, draft, demo['type'], demo['tone'])
    print(f'  ---')
    # Show first 3 lines of draft
    lines = draft.split('\n')[:3]
    for line in lines:
        if line.strip():
            print(f'  | {line.strip()[:70]}')
    print(f'  | ...')
    print(f'  Saved as: {title}')
    print()
    time.sleep(1)

print(f'  Generated and saved {len(demos)} drafts.')
"

if errorlevel 1 (
    echo  ^!WARNING: Some drafts may have failed.
)
echo  [OK] Demo drafts generated.
echo.

REM ============================================================
REM STEP 3: Interactive writing mode
REM ============================================================
echo  [3/3] Interactive writing assistant
echo  ============================================================
echo.

:WRITE_MENU
echo   Message Types:
echo     1. Thank-you note
echo     2. Email
echo     3. Letter
echo     4. Card
echo     5. Quit
echo.
set "CHOICE="
set /p "CHOICE=  Pick a type (1-5): "
if "!CHOICE!"=="5" goto WRITE_DONE
if "!CHOICE!"=="" goto WRITE_MENU

if "!CHOICE!"=="1" set "MSG_TYPE=thankyou"
if "!CHOICE!"=="2" set "MSG_TYPE=email"
if "!CHOICE!"=="3" set "MSG_TYPE=letter"
if "!CHOICE!"=="4" set "MSG_TYPE=card"

echo.
echo   Tone:
echo     1. Warm (friendly, heartfelt)
echo     2. Formal (professional, respectful)
echo     3. Casual (relaxed, brief)
echo.
set "TONE_CHOICE="
set /p "TONE_CHOICE=  Pick a tone (1-3): "
if "!TONE_CHOICE!"=="1" set "TONE=warm"
if "!TONE_CHOICE!"=="2" set "TONE=formal"
if "!TONE_CHOICE!"=="3" set "TONE=casual"

echo.
set "DESC="
set /p "DESC=  Describe the message: "
echo.
echo  Generating draft...

python -c "
import urllib.request, json

msg_type = '!MSG_TYPE!'
tone = '!TONE!'
desc = '''!DESC!'''

# Search vault for context
query = {
    'query': '{Get{PersonalDoc(nearText:{concepts:[\"' + desc.replace('\"', '').replace(\"'\", '') + '\"]},limit:2){title content}}}'
}
req = urllib.request.Request(
    'http://localhost:8080/v1/graphql',
    data=json.dumps(query).encode('utf-8'),
    headers={'Content-Type': 'application/json'},
    method='POST'
)
resp = urllib.request.urlopen(req)
result = json.loads(resp.read())
docs = result.get('data', {}).get('Get', {}).get('PersonalDoc', [])
context = '\n'.join(f\"{d['title']}: {d['content']}\" for d in docs) if docs else 'No personal context available.'

tone_guide = {
    'warm': 'warm, heartfelt, personal',
    'formal': 'professional, respectful, proper',
    'casual': 'relaxed, conversational, brief'
}
prompt = f'''Write a {msg_type} with a {tone_guide.get(tone, tone)} tone.
Description: {desc}
Personal context: {context}
Keep it under 150 words.'''

data = json.dumps({
    'model': 'llama3.2:3b',
    'prompt': prompt,
    'stream': False,
    'options': {'temperature': 0.7, 'num_predict': 300}
}).encode('utf-8')
req = urllib.request.Request(
    'http://localhost:11434/api/generate',
    data=data,
    headers={'Content-Type': 'application/json'},
    method='POST'
)
resp = urllib.request.urlopen(req)
draft = json.loads(resp.read())['response'].strip()

print()
print('  ---- DRAFT ----')
for line in draft.split('\n'):
    print(f'  {line}')
print('  ---- END ----')

# Save draft
save_data = json.dumps({
    'title': f'{msg_type.title()} - {desc[:40]}',
    'content': draft,
    'messageType': msg_type,
    'tone': tone
}).encode('utf-8')
req = urllib.request.Request(
    'http://localhost:8080/v1/objects?class=PersonalDraft',
    data=save_data,
    headers={'Content-Type': 'application/json'},
    method='POST'
)
urllib.request.urlopen(req)
print()
print('  Draft saved to PersonalDraft vault.')
"
echo.
goto WRITE_MENU

:WRITE_DONE
echo.
echo  ============================================================
echo       WRITING ASSISTANT COMPLETE
echo  ============================================================
echo.
echo   SECURITY REMINDER:
echo   Cloud writing tools like Grammarly learn your writing style.
echo   They build a profile of HOW you communicate. Your local AI
echo   keeps your digital voice private. No one else has your
echo   writing fingerprint.
echo.
echo   Next: Module 3.4 — Lock It Down
echo   (Security awareness and digital hygiene)
echo.
pause
exit /b 0
