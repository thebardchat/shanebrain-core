# Module 3.2: Ask Your Vault

## What You'll Build
A personal Q&A tool that lets you ask your vault questions in plain English.
"When is Aunt Sarah's birthday?" — and get an instant, sourced answer from
YOUR data, using YOUR local AI. No internet needed.

## Time: ~15 minutes

## Prerequisites
- Module 3.1 complete (PersonalDoc collection with data)
- Ollama running with a chat model (llama3.2:3b or similar)
- Weaviate running on port 8080

## What You'll Learn
1. How semantic search finds answers from your personal vault
2. How local AI generates answers using YOUR context
3. How source citations work ("from: recipes [family]")
4. **Security lesson**: Cloud AI reads your prompts — local AI doesn't

---

## The Security Lesson: Your Questions Reveal You

Think about what you'd ask a personal AI:
- "What medication does Dad take?"
- "What's our WiFi password?"
- "When does Tommy's EpiPen expire?"
- "How much is our car insurance?"

Every one of those questions, typed into a cloud AI service, tells that
company something intimate about your family. They know:
- Your dad has a medical condition
- Your child has allergies
- Your financial details
- Your home network information

**With local AI, those questions go nowhere.** They're processed on your
machine, answered from your vault, and forgotten. No logs on someone
else's server. No profile being built about your family.

---

## How It Works

1. You type a question in plain English
2. Weaviate searches your PersonalDoc vault using semantic similarity
3. The top matching documents become context
4. Ollama generates a natural answer using that context
5. Sources are cited so you know WHERE the answer came from

This is called **RAG** — Retrieval-Augmented Generation. It's the same
technique used by enterprise AI systems, but running on YOUR machine
for YOUR family's data.

---

## Example Queries

| Question | Expected Source |
|----------|---------------|
| "When is Aunt Sarah's birthday?" | Aunt Sarah Birthday [family] |
| "What's Dad allergic to?" | Dad Allergies and Medications [health] |
| "What's in Grandma's cornbread?" | Grandma Cornbread Recipe [recipes] |
| "When does school start back?" | School Calendar Spring 2026 [school] |
| "When is car insurance due?" | Car Insurance Reminder [finance] |
| "What vet does Buddy go to?" | Vet Info for Pets [general] |

---

## After the Exercise

You'll have a working personal Q&A system. Ask it anything about your
stored vault data and get sourced answers instantly.

In Module 3.3, you'll learn to WRITE with your vault's context —
personalized thank-you notes, emails, and letters that sound like YOU.
