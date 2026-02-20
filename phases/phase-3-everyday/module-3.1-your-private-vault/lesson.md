# Module 3.1: Your Private Vault

## What You'll Build
A personal knowledge base — your own private vault where you store family records,
recipes, medical notes, school info, and anything else that matters to your family.
All stored locally. No cloud. No accounts. Just YOUR data on YOUR machine.

## Time: ~15 minutes

## Prerequisites
- Phase 1 (Builders) complete
- Phase 2 (Operators) complete
- Ollama running with a model loaded
- Weaviate running on port 8080

## What You'll Learn
1. How to create a personal knowledge collection in Weaviate
2. How to store categorized personal documents
3. How to add family records, recipes, health notes, and more
4. **Security lesson**: Why personal data belongs on YOUR machine

---

## The Security Lesson: Your Data, Your Machine

Every time you type something into ChatGPT, Google Bard, or any cloud AI:
- That text goes to someone else's server
- It may be used to train their models
- You agreed to this in the Terms of Service nobody reads
- Your family's medical info, your recipes, your kids' school details — all of it

**Local AI is different.** When you run Ollama on your own machine:
- Your questions never leave your house
- No company stores your family data
- No Terms of Service to worry about
- YOU own it. Period.

This module builds your private vault — a place where your personal knowledge
lives on YOUR hard drive, searchable by YOUR local AI.

---

## How It Works

We create a Weaviate collection called `PersonalDoc` with these fields:
- **title** — What is this document? ("Grandma's Cornbread Recipe")
- **content** — The actual information
- **category** — One of: family, health, recipes, school, finance, general
- **source** — Where did this come from? ("Mom told me", "Doctor's office", etc.)

The exercise script will:
1. Create the PersonalDoc collection in Weaviate
2. Load sample documents across all categories
3. Show you how to add your own documents
4. Verify everything is stored and searchable

---

## Categories Explained

| Category | What Goes Here | Examples |
|----------|---------------|----------|
| family | Birthdays, anniversaries, family tree info | "Aunt Sarah's birthday is March 15" |
| health | Medical notes, allergies, medications | "Dad is allergic to penicillin" |
| recipes | Family recipes, cooking notes | "Grandma's cornbread — 2 cups cornmeal..." |
| school | School calendar, teacher contacts, activities | "Spring break starts March 20" |
| finance | Bills, account reminders (NOT passwords!) | "Car insurance renews in June" |
| general | Everything else | "WiFi password is on the fridge" |

**IMPORTANT:** Never store actual passwords, SSNs, or financial account numbers.
Store REMINDERS about where to find them, not the sensitive data itself.

---

## After the Exercise

Once you run the exercise, you'll have a working personal vault with sample data.
In Module 3.2, you'll learn to ASK your vault questions in plain English —
"When is Aunt Sarah's birthday?" and get instant answers.

Your vault. Your data. Your machine. Nobody else's.
