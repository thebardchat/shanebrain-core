@echo off
setlocal enabledelayedexpansion
title Phase 3.1 // Your Private Vault
color 0E

echo.
echo  ============================================================
echo       MODULE 3.1: YOUR PRIVATE VAULT
echo       Building your personal knowledge base
echo  ============================================================
echo.

REM ============================================================
REM PREFLIGHT: Check Weaviate
REM ============================================================
echo  [PREFLIGHT] Checking Weaviate connection...
curl -s http://localhost:8080/v1/.well-known/ready >nul 2>&1
if errorlevel 1 (
    echo  ^!ERROR: Weaviate is not running on port 8080.
    echo  Start Weaviate first, then try again.
    pause
    exit /b 1
)
echo  [OK] Weaviate is ready.

REM ============================================================
REM PREFLIGHT: Check Ollama
REM ============================================================
echo  [PREFLIGHT] Checking Ollama connection...
curl -s http://localhost:11434/api/tags >nul 2>&1
if errorlevel 1 (
    echo  ^!ERROR: Ollama is not running on port 11434.
    echo  Start Ollama first, then try again.
    pause
    exit /b 1
)
echo  [OK] Ollama is ready.
echo.

REM ============================================================
REM STEP 1: Create PersonalDoc collection
REM ============================================================
echo  [1/3] Creating PersonalDoc collection in Weaviate...

python -c "
import urllib.request, json

# Check if collection already exists
try:
    req = urllib.request.Request('http://localhost:8080/v1/schema/PersonalDoc')
    resp = urllib.request.urlopen(req)
    print('  PersonalDoc already exists - skipping creation')
except urllib.error.HTTPError:
    # Create the collection
    schema = {
        'class': 'PersonalDoc',
        'description': 'Personal knowledge vault - family records, recipes, health notes, and more',
        'vectorizer': 'text2vec-ollama',
        'moduleConfig': {
            'text2vec-ollama': {
                'apiEndpoint': 'http://localhost:11434',
                'model': 'nomic-embed-text'
            }
        },
        'properties': [
            {
                'name': 'title',
                'dataType': ['text'],
                'description': 'Document title'
            },
            {
                'name': 'content',
                'dataType': ['text'],
                'description': 'Document content'
            },
            {
                'name': 'category',
                'dataType': ['text'],
                'description': 'Category: family, health, recipes, school, finance, general'
            },
            {
                'name': 'source',
                'dataType': ['text'],
                'description': 'Where this info came from'
            }
        ]
    }
    data = json.dumps(schema).encode('utf-8')
    req = urllib.request.Request(
        'http://localhost:8080/v1/schema',
        data=data,
        headers={'Content-Type': 'application/json'},
        method='POST'
    )
    resp = urllib.request.urlopen(req)
    print('  PersonalDoc collection created successfully!')
"

if errorlevel 1 (
    echo  ^!ERROR: Failed to create PersonalDoc collection.
    echo  Check hints.md for troubleshooting.
    pause
    exit /b 1
)
echo  [OK] PersonalDoc collection ready.
echo.

REM ============================================================
REM STEP 2: Load sample personal documents
REM ============================================================
echo  [2/3] Loading sample personal documents...

python -c "
import urllib.request, json, time

docs = [
    {
        'title': 'Aunt Sarah Birthday',
        'content': 'Aunt Sarah was born on March 15, 1978. She likes yellow roses and dark chocolate. Her favorite restaurant is Olive Garden. She lives in Nashville, TN.',
        'category': 'family',
        'source': 'Mom told me at Christmas 2024'
    },
    {
        'title': 'Uncle Mike Anniversary',
        'content': 'Uncle Mike and Aunt Linda got married on June 22, 2001. They celebrate every year at the lake house. Their anniversary is always a big family cookout.',
        'category': 'family',
        'source': 'Family calendar'
    },
    {
        'title': 'Dad Allergies and Medications',
        'content': 'Dad is allergic to penicillin and sulfa drugs. He takes blood pressure medication (lisinopril 10mg) every morning. His doctor is Dr. Patterson at Valley Medical.',
        'category': 'health',
        'source': 'Dad told me after his checkup'
    },
    {
        'title': 'Kids Allergy Info',
        'content': 'Tommy has a mild peanut allergy - carry EpiPen. Emma has no known allergies. Both kids are up to date on vaccinations as of January 2026.',
        'category': 'health',
        'source': 'Pediatrician visit January 2026'
    },
    {
        'title': 'Grandma Cornbread Recipe',
        'content': 'Grandma cornbread: 2 cups self-rising cornmeal, 1 egg, 1.5 cups buttermilk, 2 tablespoons melted butter. Mix wet into dry. Pour into greased hot cast iron skillet. Bake 425 degrees for 20-25 minutes until golden brown. The secret is the hot skillet — preheat it in the oven.',
        'category': 'recipes',
        'source': 'Grandma showed me Thanksgiving 2023'
    },
    {
        'title': 'Family Chili Recipe',
        'content': 'Family chili: 2 lbs ground beef, 2 cans kidney beans, 1 can diced tomatoes, 1 can tomato sauce, 1 diced onion, 2 cloves garlic, 2 tbsp chili powder, 1 tsp cumin, salt and pepper. Brown beef with onion and garlic. Add everything else. Simmer 2 hours. Better the next day.',
        'category': 'recipes',
        'source': 'Mom recipe box'
    },
    {
        'title': 'School Calendar Spring 2026',
        'content': 'Spring break: March 16-20, 2026. Last day of school: May 22, 2026. Parent-teacher conferences: April 8-9. Science fair: April 15. Field day: May 15. Graduation ceremony: May 21 at 6pm in the gym.',
        'category': 'school',
        'source': 'School website September 2025'
    },
    {
        'title': 'Car Insurance Reminder',
        'content': 'Car insurance with State Farm renews every June 1. Agent is Bob Collins, phone 256-555-0142. Policy covers both vehicles. Last renewal was $1,847 for 6 months. Check for multi-policy discount.',
        'category': 'finance',
        'source': 'Insurance documents'
    },
    {
        'title': 'WiFi and Smart Home Info',
        'content': 'Home WiFi network name is BrazeltonFamily. Password is written on the sticker inside the kitchen cabinet above the microwave. Ring doorbell account uses the family email. Thermostat brand is Nest, connected to WiFi.',
        'category': 'general',
        'source': 'Home setup notes'
    },
    {
        'title': 'Vet Info for Pets',
        'content': 'Dog (Buddy) sees Dr. Harper at Mountain View Vet, phone 256-555-0198. Annual checkup in September. Buddy takes heartworm pill monthly (Heartgard). Cat (Whiskers) is indoor only, annual checkup in February.',
        'category': 'general',
        'source': 'Vet visit records'
    }
]

success = 0
for doc in docs:
    data = json.dumps(doc).encode('utf-8')
    req = urllib.request.Request(
        'http://localhost:8080/v1/objects?class=PersonalDoc',
        data=data,
        headers={'Content-Type': 'application/json'},
        method='POST'
    )
    try:
        resp = urllib.request.urlopen(req)
        success += 1
        print(f'  + {doc[\"title\"]} [{doc[\"category\"]}]')
    except Exception as e:
        print(f'  ! Failed: {doc[\"title\"]} - {e}')
    time.sleep(0.5)

print(f'  Loaded {success}/{len(docs)} documents')
"

if errorlevel 1 (
    echo  ^!ERROR: Failed to load sample documents.
    pause
    exit /b 1
)
echo  [OK] Sample documents loaded.
echo.

REM ============================================================
REM STEP 3: Verify and show summary
REM ============================================================
echo  [3/3] Verifying your Private Vault...

python -c "
import urllib.request, json

# Count total objects
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

# Count by category
categories = ['family', 'health', 'recipes', 'school', 'finance', 'general']
print(f'  Total documents in vault: {count}')
print()
for cat in categories:
    req = urllib.request.Request(
        'http://localhost:8080/v1/graphql',
        data=json.dumps({
            'query': '{ Aggregate { PersonalDoc(where: {path: [\"category\"], operator: Equal, valueText: \"' + cat + '\"}) { meta { count } } } }'
        }).encode('utf-8'),
        headers={'Content-Type': 'application/json'},
        method='POST'
    )
    resp = urllib.request.urlopen(req)
    result = json.loads(resp.read())
    cat_count = result['data']['Aggregate']['PersonalDoc'][0]['meta']['count']
    bar = '#' * cat_count
    print(f'  {cat:10s} {bar} ({cat_count})')
"

echo.
echo  ============================================================
echo       YOUR PRIVATE VAULT IS READY!
echo  ============================================================
echo.
echo   Your personal knowledge base is now running locally.
echo   10 sample documents across 6 categories.
echo.
echo   SECURITY REMINDER:
echo   This data lives on YOUR machine. No cloud service
echo   has access. No company is training AI on your family's
echo   medical records or recipes. That's the whole point.
echo.
echo   Next: Module 3.2 — Ask Your Vault
echo   (Query your vault in plain English)
echo.
pause
exit /b 0
