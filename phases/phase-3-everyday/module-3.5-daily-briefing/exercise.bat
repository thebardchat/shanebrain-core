@echo off
setlocal enabledelayedexpansion
title Phase 3.5 // Daily Briefing
color 0E

echo.
echo  ============================================================
echo       MODULE 3.5: DAILY BRIEFING
echo       Personal journal and daily summary
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
REM STEP 1: Create DailyNote collection
REM ============================================================
echo  [1/4] Creating DailyNote collection...

python -c "
import urllib.request, json

try:
    req = urllib.request.Request('http://localhost:8080/v1/schema/DailyNote')
    urllib.request.urlopen(req)
    print('  DailyNote already exists - skipping creation')
except urllib.error.HTTPError:
    schema = {
        'class': 'DailyNote',
        'description': 'Personal journal entries, to-dos, reminders, and reflections',
        'vectorizer': 'text2vec-ollama',
        'moduleConfig': {
            'text2vec-ollama': {
                'apiEndpoint': 'http://localhost:11434',
                'model': 'nomic-embed-text'
            }
        },
        'properties': [
            {'name': 'title', 'dataType': ['text'], 'description': 'Note title'},
            {'name': 'content', 'dataType': ['text'], 'description': 'Note content'},
            {'name': 'noteType', 'dataType': ['text'], 'description': 'Type: journal, todo, reminder, reflection'},
            {'name': 'date', 'dataType': ['text'], 'description': 'Date of the note (YYYY-MM-DD)'}
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
    print('  DailyNote collection created!')
"

if errorlevel 1 (
    echo  ^!ERROR: Failed to create DailyNote collection.
    pause
    exit /b 1
)
echo  [OK] DailyNote ready.
echo.

REM ============================================================
REM STEP 2: Load sample journal entries
REM ============================================================
echo  [2/4] Loading sample journal entries...

python -c "
import urllib.request, json, datetime, time

today = datetime.date.today()
yesterday = today - datetime.timedelta(days=1)
two_days_ago = today - datetime.timedelta(days=2)

notes = [
    {
        'title': 'Morning thoughts',
        'content': 'Woke up early today. Coffee on the porch watching the sunrise. Need to remember to call the insurance company about the truck. Kids have practice at 4pm. Feeling good about this week.',
        'noteType': 'journal',
        'date': str(today)
    },
    {
        'title': 'Today to-do list',
        'content': 'Call State Farm about truck claim. Pick up groceries - milk, bread, eggs, ground beef. Fix the back fence gate latch. Help Tommy with science project. Oil change on the car.',
        'noteType': 'todo',
        'date': str(today)
    },
    {
        'title': 'Science project deadline',
        'content': 'Tommy science project due this Friday. Needs poster board and markers from Walmart. Topic is the solar system. He has most of the research done, just needs to put it together.',
        'noteType': 'reminder',
        'date': str(today)
    },
    {
        'title': 'Yesterday journal',
        'content': 'Good day at work. Dispatched 14 loads, no breakdowns. Stopped by Mama house on the way home. She made cornbread and butter beans. Kids were happy to see grandma. Tiffany had dinner ready when we got back.',
        'noteType': 'journal',
        'date': str(yesterday)
    },
    {
        'title': 'Yesterday to-do',
        'content': 'Finished the invoice for Johnson job. Ordered new tires for truck 7. Called about the fence estimate - $450 for materials. Picked up dog food and cat litter.',
        'noteType': 'todo',
        'date': str(yesterday)
    },
    {
        'title': 'Evening reflection',
        'content': 'Grateful for a calm evening. Family dinner together, no phones at the table. Kai helped clear the dishes without being asked. Small things matter. Tomorrow: focus on the insurance call and getting Tommy supplies.',
        'noteType': 'reflection',
        'date': str(yesterday)
    },
    {
        'title': 'Weekend plans',
        'content': 'Saturday: church in the morning, then family lunch at Cracker Barrel. Sunday: work on the fence if weather holds. Gavin and Angel might come over for dinner Sunday evening.',
        'noteType': 'journal',
        'date': str(two_days_ago)
    },
    {
        'title': 'Bill reminders',
        'content': 'Electric bill due the 25th. Internet bill on auto-pay. Need to check if car insurance payment went through. Mortgage is set.',
        'noteType': 'reminder',
        'date': str(two_days_ago)
    }
]

success = 0
for note in notes:
    data = json.dumps(note).encode('utf-8')
    req = urllib.request.Request(
        'http://localhost:8080/v1/objects?class=DailyNote',
        data=data,
        headers={'Content-Type': 'application/json'},
        method='POST'
    )
    try:
        urllib.request.urlopen(req)
        success += 1
        print(f'  + [{note[\"noteType\"]:10s}] {note[\"title\"]} ({note[\"date\"]})')
    except Exception as e:
        print(f'  ! Failed: {note[\"title\"]} - {e}')
    time.sleep(0.5)

print(f'  Loaded {success}/{len(notes)} entries')
"

echo  [OK] Sample entries loaded.
echo.

REM ============================================================
REM STEP 3: Generate daily briefing
REM ============================================================
echo  [3/4] Generating your daily briefing...
echo.

python -c "
import urllib.request, json, datetime

today = str(datetime.date.today())

# Get all recent notes
query = {
    'query': '{Get{DailyNote(limit:20){title content noteType date}}}'
}
req = urllib.request.Request(
    'http://localhost:8080/v1/graphql',
    data=json.dumps(query).encode('utf-8'),
    headers={'Content-Type': 'application/json'},
    method='POST'
)
resp = urllib.request.urlopen(req)
result = json.loads(resp.read())
notes = result['data']['Get']['DailyNote']

# Build context from recent notes
context = ''
for n in notes:
    context += f\"\"\"[{n['noteType'].upper()}] {n['title']} ({n['date']}): {n['content']}\n\n\"\"\"

prompt = f'''You are a helpful personal assistant. Generate a concise daily briefing
based on these recent journal entries. Include:
1. Top priorities for today (from to-dos and reminders)
2. Key upcoming events
3. A brief reflection or encouragement based on journal entries

Keep it under 200 words. Be warm and practical.

Recent notes:
{context}

Today is {today}.

Daily Briefing:'''

data = json.dumps({
    'model': 'llama3.2:3b',
    'prompt': prompt,
    'stream': False,
    'options': {'temperature': 0.5, 'num_predict': 400}
}).encode('utf-8')
req = urllib.request.Request(
    'http://localhost:11434/api/generate',
    data=data,
    headers={'Content-Type': 'application/json'},
    method='POST'
)
resp = urllib.request.urlopen(req)
briefing = json.loads(resp.read())['response'].strip()

print('  ============================================')
print(f'  DAILY BRIEFING - {today}')
print('  ============================================')
for line in briefing.split('\n'):
    print(f'  {line}')
print('  ============================================')
"

echo.

REM ============================================================
REM STEP 4: Interactive journal mode
REM ============================================================
echo  [4/4] Interactive journal - add your own entries
echo         Type 'quit' to exit, 'briefing' for daily summary
echo  ============================================================
echo.

:JOURNAL_MENU
echo   Note types:
echo     1. Journal (free-form)
echo     2. To-do list
echo     3. Reminder
echo     4. Reflection
echo     5. Search past entries
echo     6. Generate briefing
echo     7. Quit
echo.
set "JCHOICE="
set /p "JCHOICE=  Choice (1-7): "
if "!JCHOICE!"=="7" goto JOURNAL_DONE
if "!JCHOICE!"=="" goto JOURNAL_MENU

if "!JCHOICE!"=="1" set "NOTE_TYPE=journal"
if "!JCHOICE!"=="2" set "NOTE_TYPE=todo"
if "!JCHOICE!"=="3" set "NOTE_TYPE=reminder"
if "!JCHOICE!"=="4" set "NOTE_TYPE=reflection"

if "!JCHOICE!"=="5" (
    set "SEARCH="
    set /p "SEARCH=  Search for: "
    python -c "
import urllib.request, json
search = '''!SEARCH!'''
query = {
    'query': '{Get{DailyNote(nearText:{concepts:[\"' + search.replace('\"', '').replace(\"'\", '') + '\"]},limit:5){title content noteType date _additional{certainty}}}}'
}
req = urllib.request.Request(
    'http://localhost:8080/v1/graphql',
    data=json.dumps(query).encode('utf-8'),
    headers={'Content-Type': 'application/json'},
    method='POST'
)
resp = urllib.request.urlopen(req)
result = json.loads(resp.read())
notes = result['data']['Get']['DailyNote']
if not notes:
    print('  No matching entries found.')
else:
    for n in notes:
        cert = n.get('_additional', {}).get('certainty', 0)
        print(f'  [{n[\"noteType\"]:10s}] {n[\"title\"]} ({n[\"date\"]}) - {cert:.0%%} match')
        print(f'  {n[\"content\"][:80]}...')
        print()
"
    echo.
    goto JOURNAL_MENU
)

if "!JCHOICE!"=="6" (
    echo  Generating briefing...
    python -c "
import urllib.request, json, datetime
today = str(datetime.date.today())
query = {'query': '{Get{DailyNote(limit:20){title content noteType date}}}'}
req = urllib.request.Request('http://localhost:8080/v1/graphql', data=json.dumps(query).encode('utf-8'), headers={'Content-Type': 'application/json'}, method='POST')
resp = urllib.request.urlopen(req)
notes = json.loads(resp.read())['data']['Get']['DailyNote']
context = '\n'.join(f\"[{n['noteType']}] {n['title']} ({n['date']}): {n['content']}\" for n in notes)
prompt = f'Generate a brief daily summary from these notes. Top priorities, upcoming events, encouragement. Under 150 words.\n\nNotes:\n{context}\n\nToday: {today}\n\nBriefing:'
data = json.dumps({'model': 'llama3.2:3b', 'prompt': prompt, 'stream': False, 'options': {'temperature': 0.5, 'num_predict': 300}}).encode('utf-8')
req = urllib.request.Request('http://localhost:11434/api/generate', data=data, headers={'Content-Type': 'application/json'}, method='POST')
resp = urllib.request.urlopen(req)
briefing = json.loads(resp.read())['response'].strip()
print()
for line in briefing.split('\n'):
    print(f'  {line}')
print()
"
    echo.
    goto JOURNAL_MENU
)

echo.
set "TITLE="
set /p "TITLE=  Title: "
set "CONTENT="
set /p "CONTENT=  Content: "

python -c "
import urllib.request, json, datetime
data = json.dumps({
    'title': '''!TITLE!''',
    'content': '''!CONTENT!''',
    'noteType': '!NOTE_TYPE!',
    'date': str(datetime.date.today())
}).encode('utf-8')
req = urllib.request.Request(
    'http://localhost:8080/v1/objects?class=DailyNote',
    data=data,
    headers={'Content-Type': 'application/json'},
    method='POST'
)
urllib.request.urlopen(req)
print(f'  Saved: [!NOTE_TYPE!] !TITLE!')
"
echo.
goto JOURNAL_MENU

:JOURNAL_DONE
echo.
echo  ============================================================
echo       DAILY BRIEFING COMPLETE
echo  ============================================================
echo.
echo   SECURITY REMINDER:
echo   Your journal entries contain your thoughts, worries, plans,
echo   and reflections. Cloud journal apps store all of this on
echo   someone else's server. YOUR journal stays on YOUR machine.
echo   Your thoughts are yours alone.
echo.
echo   Next: Module 3.6 — Digital Footprint
echo   (Privacy audit and digital footprint awareness)
echo.
pause
exit /b 0
