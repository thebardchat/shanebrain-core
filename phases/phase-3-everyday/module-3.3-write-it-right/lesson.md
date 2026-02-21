# Module 3.3 — Write It Right

## WHAT YOU'LL BUILD

An AI writing assistant that drafts emails and messages using YOUR vault as context. Instead of writing from scratch, the AI pulls your personal data — names, details, history — and writes drafts that sound like they came from someone who knows your situation.

Module 3.2 taught the AI to answer questions. Now it writes for you. Like handing your notes to a sharp office manager and saying "draft me a reply to this."

---

## WHO THIS IS FOR

Anyone who writes emails, messages, or letters and wishes they had a first draft ready. Business owners replying to clients. Parents writing notes to schools. Workers sending updates to supervisors. If you spend time staring at a blank screen, this module cuts that time in half.

---

## KEY TERMS

- **draft_create**: The MCP tool that generates a writing draft. You give it a prompt (what to write about), a type (email, message, post, letter, general), and it produces a draft. Optionally pulls context from your vault to make the draft personal and specific.

- **draft_search**: Searches your saved drafts by meaning. Wrote an email last week about scheduling? Search "scheduling" and find it, even if the subject line was different.

- **Draft Type**: The format of writing you want. Types include:
  - `email` — formal structure with subject, greeting, body, sign-off
  - `message` — casual, short, text-message style
  - `post` — social media or announcement format
  - `letter` — formal letter structure
  - `general` — free-form, no specific format

- **Vault Context**: When `draft_create` runs, it can search your vault for relevant information and weave it into the draft. Writing an email about your work performance? It pulls your review document. That's vault context at work.

---

## THE LESSON

### Step 1: Understand context-aware drafting

Regular AI writing tools generate generic text. "Write an email about a doctor's appointment" gives you a template. Boring. Useless.

Context-aware drafting is different. The AI:
1. Reads your prompt ("Write an email to reschedule my checkup")
2. Searches your vault for related documents (finds your medical notes)
3. Pulls specific details (Dr. Martinez, Valley Health Clinic, July appointment)
4. Writes a draft with YOUR details already filled in

The result reads like you wrote it, because it used your information.

### Step 2: Create an email draft

The `draft_create` tool takes:
- **prompt**: What you want written. Be specific. "Email to my doctor's office to reschedule my July appointment to August" beats "email about appointment."
- **draft_type**: Set to "email" for proper email formatting
- **use_vault_context**: Leave this true (default) to pull from your vault

The more specific your prompt, the better the draft. Like giving instructions to a new hire — "pour the footer for lot 12" works better than "go do concrete stuff."

### Step 3: Create a message draft

Messages are shorter and more casual than emails. Same tool, different type:
- **draft_type**: Set to "message" for text/chat style
- The AI keeps it brief and conversational
- Vault context still applies — personal details get woven in

### Step 4: Search your saved drafts

Every draft you create gets saved and becomes searchable. Use `draft_search` to find past drafts by topic. Wrote a client email last month? Search "client proposal" and pull it up. Modify and resend instead of starting from scratch.

---

## THE PATTERN

```
PROMPT  →  SEARCH VAULT  →  PULL CONTEXT  →  GENERATE DRAFT
 (text)    (vault docs)     (relevant info)   (draft_create)
```

Same RAG pipeline from Module 3.2, but the output is a polished draft instead of a Q&A answer. Retrieval powers everything.

---

## WHAT YOU PROVED

- You can generate personalized email drafts with vault context
- The AI pulls your real details (names, dates, specifics) into drafts
- Different draft types (email, message) produce different formats
- Saved drafts are searchable — write once, find forever
- Context-aware writing beats generic templates every time

**Next:** Run `exercise.bat` to start writing with AI assistance.
