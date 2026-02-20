@echo off
setlocal enabledelayedexpansion
title Phase 3.6 // Digital Footprint
color 0D

echo.
echo  ============================================================
echo       MODULE 3.6: DIGITAL FOOTPRINT
echo       Privacy audit and footprint awareness
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
REM STEP 1: Create PrivacyAudit collection
REM ============================================================
echo  [1/4] Creating PrivacyAudit collection...

python -c "
import urllib.request, json

try:
    req = urllib.request.Request('http://localhost:8080/v1/schema/PrivacyAudit')
    urllib.request.urlopen(req)
    print('  PrivacyAudit already exists - skipping creation')
except urllib.error.HTTPError:
    schema = {
        'class': 'PrivacyAudit',
        'description': 'Privacy audit findings, recommendations, and footprint analysis',
        'vectorizer': 'text2vec-ollama',
        'moduleConfig': {
            'text2vec-ollama': {
                'apiEndpoint': 'http://localhost:11434',
                'model': 'nomic-embed-text'
            }
        },
        'properties': [
            {'name': 'auditType', 'dataType': ['text'], 'description': 'Audit category'},
            {'name': 'finding', 'dataType': ['text'], 'description': 'What was found'},
            {'name': 'risk', 'dataType': ['text'], 'description': 'Risk level: low, medium, high'},
            {'name': 'recommendation', 'dataType': ['text'], 'description': 'Recommended action'},
            {'name': 'timestamp', 'dataType': ['text'], 'description': 'When the audit was performed'}
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
    print('  PrivacyAudit collection created!')
"

if errorlevel 1 (
    echo  ^!ERROR: Failed to create PrivacyAudit collection.
    pause
    exit /b 1
)
echo  [OK] PrivacyAudit ready.
echo.

REM ============================================================
REM STEP 2: Cloud accounts audit
REM ============================================================
echo  [2/4] Cloud accounts and data sharing audit...
echo.

python -c "
import urllib.request, json, datetime

timestamp = datetime.datetime.now().strftime('%%Y-%%m-%%d %%H:%%M:%%S')

# Common cloud services most people use
services = {
    'Google (Gmail, Maps, YouTube, Drive)': {
        'data': 'Email, search history, location history, documents, photos, YouTube watch history',
        'risk': 'high',
        'tip': 'Go to myaccount.google.com/data-and-privacy to see and delete what Google stores'
    },
    'Facebook / Meta (Facebook, Instagram, WhatsApp)': {
        'data': 'Posts, photos, messages, friend lists, location check-ins, ad preferences, facial recognition data',
        'risk': 'high',
        'tip': 'Use Settings > Privacy Checkup to limit what others see. Download your data to see what Facebook has'
    },
    'Amazon (Shopping, Alexa, Prime Video)': {
        'data': 'Purchase history, browsing history, voice recordings (Alexa), viewing habits',
        'risk': 'medium',
        'tip': 'Delete Alexa voice history regularly. Review and delete browsing history in your account'
    },
    'Microsoft (Windows, Office, OneDrive, Outlook)': {
        'data': 'Documents, emails, login history, device activity, Cortana queries',
        'risk': 'medium',
        'tip': 'Go to account.microsoft.com/privacy to view and clear activity data'
    },
    'Apple (iCloud, Siri, App Store)': {
        'data': 'Photos, messages, health data, location, Siri queries, app purchases',
        'risk': 'medium',
        'tip': 'Review iCloud settings. Apple collects less than Google but still stores significant data'
    },
    'Social Media (TikTok, Twitter/X, Snapchat)': {
        'data': 'Posts, messages, viewing habits, contacts, location, device info',
        'risk': 'high',
        'tip': 'Review privacy settings on each platform. Assume everything posted is permanent and public'
    }
}

print('  CLOUD ACCOUNTS AUDIT')
print('  ====================')
print()

score_deductions = 0
findings = []

for service, info in services.items():
    risk_symbol = {'low': '[.]', 'medium': '[!]', 'high': '[X]'}[info['risk']]
    print(f'  {risk_symbol} {service}')
    print(f'      Data they have: {info[\"data\"][:70]}...')
    print(f'      Action: {info[\"tip\"][:70]}...')
    print()

    if info['risk'] == 'high':
        score_deductions += 15
    elif info['risk'] == 'medium':
        score_deductions += 10

    # Save each finding
    entry = {
        'auditType': 'cloud_accounts',
        'finding': f'{service}: stores {info[\"data\"]}',
        'risk': info['risk'],
        'recommendation': info['tip'],
        'timestamp': timestamp
    }
    data = json.dumps(entry).encode('utf-8')
    req = urllib.request.Request(
        'http://localhost:8080/v1/objects?class=PrivacyAudit',
        data=data,
        headers={'Content-Type': 'application/json'},
        method='POST'
    )
    urllib.request.urlopen(req)

print(f'  Logged {len(services)} cloud account findings.')
"

echo.

REM ============================================================
REM STEP 3: Privacy score and recommendations
REM ============================================================
echo  [3/4] Generating privacy score and recommendations...
echo.

python -c "
import urllib.request, json, datetime

timestamp = datetime.datetime.now().strftime('%%Y-%%m-%%d %%H:%%M:%%S')

# Privacy assessment questions with scoring
assessments = [
    {
        'category': 'Password Hygiene',
        'good': 'Use unique passwords + a password manager',
        'bad': 'Reuse passwords across sites',
        'risk_if_bad': 'high',
        'points': 15
    },
    {
        'category': 'Two-Factor Authentication',
        'good': '2FA enabled on email and banking',
        'bad': 'No 2FA on important accounts',
        'risk_if_bad': 'high',
        'points': 15
    },
    {
        'category': 'Social Media Privacy Settings',
        'good': 'Profiles set to private or friends-only',
        'bad': 'Everything is public by default',
        'risk_if_bad': 'medium',
        'points': 10
    },
    {
        'category': 'Location Sharing',
        'good': 'Location off except when needed',
        'bad': 'Location always on for all apps',
        'risk_if_bad': 'medium',
        'points': 10
    },
    {
        'category': 'Software Updates',
        'good': 'Auto-updates enabled',
        'bad': 'Updates delayed or ignored',
        'risk_if_bad': 'medium',
        'points': 10
    },
    {
        'category': 'Children Online Safety',
        'good': 'Parental controls + conversations about safety',
        'bad': 'No oversight of children online activity',
        'risk_if_bad': 'high',
        'points': 15
    },
    {
        'category': 'Public WiFi Usage',
        'good': 'Avoid sensitive tasks on public WiFi or use VPN',
        'bad': 'Banking and shopping on coffee shop WiFi',
        'risk_if_bad': 'medium',
        'points': 10
    },
    {
        'category': 'Email Link Awareness',
        'good': 'Check sender address before clicking links',
        'bad': 'Click links in emails without checking',
        'risk_if_bad': 'high',
        'points': 15
    }
]

print('  PRIVACY SCORE BREAKDOWN')
print('  =======================')
print()
print('  Category                     Best Practice                      Points')
print('  -------                      -------------                      ------')

total_possible = 0
for a in assessments:
    total_possible += a['points']
    risk_label = {'low': 'LOW ', 'medium': 'MED ', 'high': 'HIGH'}[a['risk_if_bad']]
    print(f'  [{risk_label}] {a[\"category\"]:28s} {a[\"good\"][:35]:35s} +{a[\"points\"]}')

# Start with perfect score, show what good practices earn
print()
print(f'  Maximum possible score: {total_possible}/100')
print()
print('  Each category above represents points you EARN by following')
print('  the best practice. Review each one honestly.')
print()

# Save overall assessment
entry = {
    'auditType': 'privacy_score',
    'finding': f'Privacy assessment covers {len(assessments)} categories worth {total_possible} total points',
    'risk': 'medium',
    'recommendation': 'Review each category honestly. Focus on HIGH risk items first: passwords, 2FA, phishing awareness, children safety.',
    'timestamp': timestamp
}
data = json.dumps(entry).encode('utf-8')
req = urllib.request.Request(
    'http://localhost:8080/v1/objects?class=PrivacyAudit',
    data=data,
    headers={'Content-Type': 'application/json'},
    method='POST'
)
urllib.request.urlopen(req)
print('  Assessment saved to PrivacyAudit.')
"

echo.

REM ============================================================
REM STEP 4: Family privacy checklist
REM ============================================================
echo  [4/4] Family Privacy Checklist
echo  ============================================================
echo.

python -c "
import urllib.request, json, datetime

timestamp = datetime.datetime.now().strftime('%%Y-%%m-%%d %%H:%%M:%%S')

checklist = [
    {
        'item': 'Talk to kids about what not to share online',
        'detail': 'Full name, school name, address, phone number, photos showing house/car. Teach them: if grandma shouldnt see it, dont post it.',
        'audience': 'Parents with kids of any age'
    },
    {
        'item': 'Review privacy settings on kids devices',
        'detail': 'Check location sharing, app permissions, who can message them. Most devices have parental controls built in — use them.',
        'audience': 'Parents with kids who have devices'
    },
    {
        'item': 'Google yourself and your kids',
        'detail': 'Search your full name in quotes. See what comes up. Remove what you can. This is what strangers see about your family.',
        'audience': 'Everyone'
    },
    {
        'item': 'Check what apps have camera and microphone access',
        'detail': 'On phones: Settings > Privacy > Camera/Microphone. Remove access for apps that dont need it.',
        'audience': 'Everyone with a smartphone'
    },
    {
        'item': 'Set up a family password manager',
        'detail': 'Even the free built-in ones (Apple Keychain, Chrome passwords) are better than reusing passwords. One strong master password.',
        'audience': 'Whole family'
    },
    {
        'item': 'Discuss phishing as a family',
        'detail': 'Show examples of fake emails and texts. Teach: never click links from unknown senders. When in doubt, go directly to the website.',
        'audience': 'Everyone, especially teens'
    }
]

print('  FAMILY PRIVACY CHECKLIST')
print('  ========================')
print()

for i, item in enumerate(checklist, 1):
    print(f'  {i}. {item[\"item\"]}')
    print(f'     {item[\"detail\"][:75]}')
    print(f'     For: {item[\"audience\"]}')
    print()

# Save family checklist
entry = {
    'auditType': 'family_checklist',
    'finding': f'Family privacy checklist with {len(checklist)} action items for protecting family online presence',
    'risk': 'medium',
    'recommendation': 'Work through checklist items with family. Start with item 1 (talking to kids) and item 3 (Google yourself).',
    'timestamp': timestamp
}
data = json.dumps(entry).encode('utf-8')
req = urllib.request.Request(
    'http://localhost:8080/v1/objects?class=PrivacyAudit',
    data=data,
    headers={'Content-Type': 'application/json'},
    method='POST'
)
urllib.request.urlopen(req)
print('  Family checklist saved to PrivacyAudit.')
"

echo.
echo  ============================================================
echo       DIGITAL FOOTPRINT AUDIT COMPLETE
echo  ============================================================
echo.
echo   YOUR AUDIT:
echo   - Cloud accounts reviewed and logged
echo   - Privacy score assessment complete
echo   - Family privacy checklist generated
echo   All findings stored in YOUR PrivacyAudit vault.
echo.
echo   SECURITY REMINDER:
echo   Your digital footprint is bigger than you think. But now
echo   you can SEE it. Start with the highest-risk items first:
echo   passwords, 2FA, and teaching your kids about online safety.
echo   Small steps add up to real protection.
echo.
echo   Next: Module 3.7 — The Family Dashboard
echo   (Capstone: all Phase 3 tools in one launcher)
echo.
pause
exit /b 0
