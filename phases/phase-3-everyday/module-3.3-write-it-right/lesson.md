# Module 3.3: Write It Right

## What You'll Build
A personal writing assistant that drafts thank-you notes, school emails,
church letters, sympathy cards, and family updates — using YOUR personal
context from the vault so the messages sound like YOU, not a robot.

## Time: ~15 minutes

## Prerequisites
- Module 3.1 complete (PersonalDoc vault with data)
- Module 3.2 complete (vault Q&A working)
- Ollama running with a chat model
- Weaviate running on port 8080

## What You'll Learn
1. How to create message templates with different tones
2. How AI pulls personal context to personalize messages
3. How to store and retrieve your drafts
4. **Security lesson**: AI writing tools learn your style — keep it local

---

## The Security Lesson: Your Digital Voice

When you use Grammarly, ChatGPT, or Google Docs AI to write:
- The service learns HOW you write
- It knows your vocabulary, your tone, your patterns
- It can identify you by your writing style alone
- This is called a "writing fingerprint"

Companies building AI writing tools now have YOUR voice in their database.
They know you write "Hey y'all" instead of "Hello everyone." They know
you sign off with "God bless" instead of "Best regards."

**When your writing assistant runs locally:**
- Your writing style stays private
- No company profiles your communication patterns
- Your personal messages remain personal
- YOUR voice belongs to YOU

---

## Message Types

| Type | Use Case | Default Tone |
|------|----------|-------------|
| thankyou | Thank-you notes for gifts, help, kindness | warm |
| email | Emails to teachers, coaches, businesses | formal |
| letter | Church communications, formal letters | formal |
| card | Sympathy cards, birthday cards, get-well | warm |

## Tone Options

| Tone | Style | Example |
|------|-------|---------|
| warm | Friendly, personal, heartfelt | "We just wanted to say how much..." |
| formal | Professional, respectful, proper | "I am writing to express..." |
| casual | Relaxed, conversational, brief | "Hey! Just wanted to drop a note..." |

---

## How It Works

1. You pick a message type (thank-you, email, letter, card)
2. You pick a tone (warm, formal, casual)
3. You describe what the message is about
4. The AI pulls relevant context from your PersonalDoc vault
5. It drafts a personalized message
6. The draft is saved to a `PersonalDraft` collection for later use

---

## After the Exercise

You'll have a working writing assistant with saved drafts. Every message
it generates uses YOUR context — it knows your family members' names,
your style preferences, and your personal details because they're in
YOUR vault on YOUR machine.

Module 3.4 teaches you to LOCK DOWN your machine — understanding what's
running and keeping your digital life secure.
