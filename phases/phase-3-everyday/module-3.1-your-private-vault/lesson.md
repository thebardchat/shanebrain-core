# Module 3.1 — Your Private Vault

## WHAT YOU'LL BUILD

A personal document vault powered by AI. By the end of this module, you'll store medical info, work references, and family notes in your AI vault — then search them by meaning, not keywords.

Think of it like a safe deposit box, except you can ask it questions. "What was my doctor's recommendation?" pulls up the right document instantly, even if you never used the word "recommendation" when you stored it.

---

## WHO THIS IS FOR

Anyone with important personal documents scattered across phones, folders, and filing cabinets. Parents tracking medical records. Workers keeping references handy. People who want their private info organized and searchable — without handing it to a cloud company.

---

## KEY TERMS

- **Personal Vault**: Your private document store inside the AI system. Documents go in as text, get embedded as vectors, and become searchable by meaning. Like a filing cabinet that reads everything you put in it.

- **vault_add**: The MCP tool that stores a document in your vault. You give it content, a category (medical, work, personal, financial, legal), and an optional title. It handles the rest.

- **vault_search**: Searches your vault by meaning. Ask "blood pressure medication" and it finds your doctor's note even if it says "hypertension treatment." That's semantic search doing its job.

- **vault_list_categories**: Shows you what categories exist in your vault and how many documents each one has. Like checking which drawers in your filing cabinet have stuff in them.

- **Category**: A label you put on each document — medical, work, personal, financial, legal. Lets you narrow searches later. "Search my medical docs for allergy info" instead of searching everything.

---

## THE LESSON

### Step 1: Understand what goes in the vault

Your vault stores any text-based personal information. Good candidates:

- **Medical**: Doctor's notes, medication lists, allergy info, insurance details
- **Work**: Performance reviews, certifications, reference letters, project notes
- **Personal**: Emergency contacts, family info, important dates, personal goals
- **Financial**: Account summaries, budget notes, tax info (not passwords or account numbers)
- **Legal**: Contract summaries, warranty info, legal contacts

**Keep it focused.** One topic per document works best. "Mom's medication list" is better than "everything about mom."

### Step 2: Store documents with vault_add

Each vault entry needs two things:
- **content**: The actual text of your document
- **category**: What type it is (medical, work, personal, etc.)

Optional but helpful:
- **title**: A short name like "Dr. Smith Visit - January 2026"
- **tags**: Comma-separated labels for extra filtering

The system embeds your document using the same AI model that powers search. Once stored, it's findable by meaning.

### Step 3: Search your vault semantically

This is where it gets useful. With `vault_search`, you type a question or topic in plain English:
- "What medications am I taking?" finds your medication list
- "Work performance feedback" finds your review documents
- "Emergency contacts for the kids" finds your family notes

You can also filter by category — search only medical docs, only work docs, etc.

### Step 4: Check your vault's organization

`vault_list_categories` shows you what's in your vault at a glance. If you stored a medical doc, a work doc, and a personal doc, you'll see three categories with their counts. Helps you know what's covered and what's missing.

---

## THE PATTERN

```
YOUR INFO  →  CATEGORIZE  →  STORE  →  SEARCH
 (text)      (medical/work)  (vault)   (semantic)
```

This is the same embed-and-search pattern from Phase 2, but now it's YOUR personal data instead of business docs. Same engine, different fuel.

---

## WHAT YOU PROVED

- You can store personal documents in a private AI vault
- Semantic search finds documents by meaning, not just keywords
- Category tags keep your vault organized
- Your data stays local — never leaves your machine
- You built the foundation for asking questions (Module 3.2), generating drafts (Module 3.3), and auditing access (Module 3.4)

**Next:** Run `exercise.bat` to load your private vault.
