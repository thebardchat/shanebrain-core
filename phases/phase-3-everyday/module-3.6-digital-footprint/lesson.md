# Module 3.6 — Digital Footprint

## WHAT YOU'LL BUILD

A personal data audit of your AI system. You'll map out exactly what data your AI holds, where it lives, how it's organized, and what you've taught it. By the end, you'll know your digital footprint inside your own system — like walking through a warehouse and counting every box on every shelf.

---

## WHO THIS IS FOR

Anyone who has been feeding data into their AI system across Phases 1-3 and wants to understand the full picture. If you've ever wondered "what does my AI actually know about me?" — this module answers that question with hard numbers, not guesses.

---

## KEY TERMS

- **Digital Footprint**: The total picture of what data exists in your AI system. How many collections, how many objects in each, what categories your vault uses, what knowledge you've stored. It's the difference between knowing you have "some stuff" and knowing you have "47 medical docs, 12 work references, and 8 journal entries."

- **system_health**: The MCP tool that shows you everything running under the hood. Service status (Ollama, Weaviate, Gateway), collection names, and object counts. Like popping the hood and checking every fluid level at once.

- **vault_list_categories**: Shows the categories in your personal vault and how many documents sit in each one. Think of it as checking which drawers in your filing cabinet have folders and which are empty.

- **search_knowledge**: Searches the LegacyKnowledge collection — the AI's general knowledge base. When you search for entries with a specific source like "mcp", you're finding everything YOU personally taught the system.

- **Privacy Audit**: The practice of regularly checking what data your AI holds and whether it should still be there. Like going through your filing cabinet once a quarter and shredding what you don't need.

---

## THE LESSON

### Know What Your AI Knows

Most people who use AI tools have no idea what data is stored, where it lives, or how to check. They trust and hope. You're going to verify.

This matters because:
- Data you forgot about is still data
- Categories without documents are blind spots
- Collections with zero objects mean features that aren't working
- Knowing your footprint lets you clean up, expand, or lock down with confidence

### The System Health Map

When you call `system_health`, you get back a map of your entire AI infrastructure:

```
SERVICES
  Ollama:    running (port 11434)
  Weaviate:  running (port 8080)
  Gateway:   running (port 4200)

COLLECTIONS
  LegacyKnowledge:   184 objects
  Conversation:       59 objects
  FriendProfile:       5 objects
  PersonalDoc:        12 objects
  DailyNote:           8 objects
```

Each collection is a bucket of data. Each object is a document, a note, a profile, or a conversation entry. The numbers tell you what's full and what's empty.

### Your Vault Categories

`vault_list_categories` drills into your personal vault specifically. It tells you how your documents are organized:

```
medical:     4 documents
work:        3 documents
personal:    2 documents
financial:   1 document
legal:       0 documents
```

Empty categories aren't failures — they're opportunities. No legal docs stored? Maybe you should add your insurance policy. No financial records? Maybe your tax info belongs there.

### What You've Taught the AI

The knowledge base holds what you've explicitly taught your AI through the `add_knowledge` tool. Searching for your own entries shows you what the AI "knows" because you told it — not what it came with.

This is the difference between a new hire's training manual (built-in knowledge) and the notes you added to their binder (your knowledge). Both matter, but knowing which is which matters more.

### The Audit Habit

Smart operators audit their systems. A concrete company doesn't just pour — they inventory their materials, check their equipment, and know what's on every truck. Your AI system deserves the same discipline.

Run this audit monthly:
1. `system_health` — Are all services up? Any collections suspiciously empty?
2. `vault_list_categories` — Does the organization still make sense?
3. `search_knowledge` — Is the AI's knowledge current and accurate?

Three calls. Five minutes. Full visibility.

---

## WHAT YOU PROVED

- You can map your entire AI system with a single MCP call
- Collection counts reveal what's working and what's unused
- Vault categories show how your personal data is organized
- Searching your own knowledge entries shows what you've taught the AI
- Regular audits keep your AI system healthy and trustworthy

**Next:** Run `exercise.bat` to audit your digital footprint.
