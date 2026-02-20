# Module 3.5: Daily Briefing

## What You'll Build
A personal journal and daily summary tool. Write journal entries, to-do lists,
reminders, and reflections — then have your local AI generate a daily briefing
from your recent notes. Like a personal assistant that reads your notebook.

## Time: ~15 minutes

## Prerequisites
- Module 3.1 complete (PersonalDoc vault)
- Module 3.2 complete (vault Q&A)
- Ollama running
- Weaviate running on port 8080

## What You'll Learn
1. How to create a daily note-taking system
2. How AI summarizes your recent notes into a daily briefing
3. How to search past entries by date or topic
4. **Security lesson**: Your journal contains your life — keep it local

---

## The Security Lesson: Your Journal, Your Life

Think about what goes in a journal:
- What you're worried about
- Your health concerns
- Family conflicts
- Financial stress
- Your hopes and dreams

Cloud journaling apps (Day One, Google Keep, Apple Notes with sync) store
all of this on company servers. Their employees CAN access it. Their AI
CAN train on it. Data breaches CAN expose it.

**Your local journal stays local.** On your hard drive. Under your roof.
Nobody else's server. Nobody else's backup. Just yours.

---

## Note Types

| Type | Purpose | Example |
|------|---------|---------|
| journal | Free-form daily writing | "Today was a good day. Got the truck fixed..." |
| todo | Task lists | "Pick up groceries, call insurance, fix fence" |
| reminder | Time-sensitive notes | "Tommy's science project due Friday" |
| reflection | End-of-day thinking | "Grateful for family dinner tonight..." |

---

## How It Works

1. You write a daily note (journal, todo, reminder, or reflection)
2. It's saved to the `DailyNote` collection with today's date
3. You can search past entries by topic or date
4. The AI generates a daily briefing summarizing recent notes
5. Everything stays local — your thoughts never leave your machine

---

## After the Exercise

You'll have a working journal with sample entries and a daily briefing generator.
Use it daily — even a quick to-do list or one-sentence reflection builds a
searchable record of your life that only YOU can access.

Module 3.6 audits your digital footprint — how much data you're giving away.
