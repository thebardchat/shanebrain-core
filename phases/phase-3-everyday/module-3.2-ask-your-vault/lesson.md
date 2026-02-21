# Module 3.2 — Ask Your Vault

## WHAT YOU'LL BUILD

A question-answering system that pulls from YOUR vault and ShaneBrain's knowledge base. Instead of just searching documents, you'll ask real questions and get real answers — backed by your personal data.

In Module 3.1 you loaded the truck. Now you're driving it. The vault holds your info. ShaneBrain's RAG pipeline reads it, reasons about it, and gives you a straight answer. Like having a foreman who memorized every document in your filing cabinet.

---

## WHO THIS IS FOR

Anyone who finished Module 3.1 and wants more than search results. You want answers. "When is my next doctor's appointment?" not "Here's a document that mentions appointments." This module bridges the gap between storing data and actually using it.

---

## KEY TERMS

- **RAG (Retrieval-Augmented Generation)**: The AI searches your vault first, then uses what it finds to generate an answer. It doesn't make things up from thin air — it pulls from your actual documents. Retrieval first, generation second.

- **vault_search**: Same tool from Module 3.1. Finds relevant documents in your vault. Here, it's the retrieval step of RAG — the AI searches before it answers.

- **chat_with_shanebrain**: The full RAG pipeline in one call. It searches the knowledge base, pulls relevant context, and generates a response using the local AI model. One question in, one answer out.

- **Context Window**: How much text the AI can "see" at once when generating an answer. Your vault search results get stuffed into this window alongside your question. Focused documents work better because they don't waste space.

- **Grounded Response**: An answer that comes from actual data, not the model's general training. When ShaneBrain says "your appointment is in July," it's because your vault document says so — not because it guessed.

---

## THE LESSON

### Step 1: Search before you ask

Before using the full RAG pipeline, it helps to understand what's happening under the hood. When you ask ShaneBrain a question:

1. Your question gets embedded (turned into a vector)
2. The system searches your vault and knowledge base for relevant documents
3. Those documents get passed to the AI model as context
4. The model generates an answer using that context

This is why Module 3.1 matters. The better your vault documents, the better your answers.

### Step 2: Ask a direct question

Use `vault_search` first to see what documents match your query. Then use `chat_with_shanebrain` to get a full answer. Compare the two:

- `vault_search` gives you raw documents: "Annual checkup notes - January 2026. Blood pressure 128/82..."
- `chat_with_shanebrain` gives you an answer: "Your blood pressure was 128/82, which is slightly elevated. Your doctor recommended..."

Same source data. But one is a document dump, the other is a useful response.

### Step 3: Ask follow-up questions

The real power shows up when you ask questions you wouldn't think to search for:

- "Should I be worried about my blood pressure?" — pulls medical docs, gives context
- "What should I focus on at work this quarter?" — pulls your performance review, highlights growth areas
- "Who should I call if there's an emergency with the kids?" — pulls your contacts document

The AI connects your question to the right documents and synthesizes an answer. Like asking a coworker who read all your files.

### Step 4: Understand what you can trust

RAG answers are only as good as the documents behind them. If your vault says your appointment is in July, the AI says July. If your vault doesn't mention something, the AI should say "I don't have that information" — not make something up.

Always check the source. Good RAG systems tell you where the answer came from. Trust the system, but verify the output.

---

## THE PATTERN

```
QUESTION  →  SEARCH VAULT  →  PULL CONTEXT  →  GENERATE ANSWER
 (text)      (vault_search)   (top matches)    (chat_with_shanebrain)
```

Module 3.1 built the vault. This module puts it to work. Module 3.3 will use the same context to write drafts instead of answers.

---

## WHAT YOU PROVED

- You can ask plain-English questions and get answers from your private data
- RAG grounds the AI's responses in your actual documents
- The AI connects questions to relevant vault entries even with different wording
- You understand the search-then-generate pipeline that powers modern AI assistants
- Your answers come from YOUR data, not internet guesses

**Next:** Run `exercise.bat` to start asking your vault questions.
