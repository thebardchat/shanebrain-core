# Module 3.5 — Daily Briefing

## WHAT YOU'LL BUILD

A personal journaling and daily briefing system powered by your AI. You'll log journal entries, todos, and reminders — then ask your AI to generate a daily briefing that pulls it all together. Like having a foreman who reads your clipboard every morning and tells you what matters today.

---

## WHO THIS IS FOR

Anyone who starts their day without a clear picture of what's on their plate. Parents juggling school schedules and work deadlines. Business owners who need to track what happened yesterday and what's due tomorrow. People who want to journal but never stick with it because there's no payoff — until now, because your AI actually reads what you write.

---

## KEY TERMS

- **Daily Note**: A timestamped entry in your AI system. Can be one of four types: journal, todo, reminder, or reflection. Each one gets embedded as a vector so the AI can find it by meaning later.

- **daily_note_add**: The MCP tool that creates a new daily note. You give it content, a type (journal/todo/reminder/reflection), and an optional mood tag. Think of it like writing on a sticky note and handing it to your AI assistant.

- **daily_note_search**: Searches your daily notes by meaning. Ask "what did I say about the Johnson project?" and it finds the relevant entries even if you called it "the big pour on 5th Street."

- **daily_briefing**: The AI reads your recent notes — journals, todos, reminders — and generates a summary. Like a dispatcher pulling together the morning's schedule from everyone's notes. One call, full picture.

- **Mood Tag**: An optional label on journal entries — grateful, tired, focused, anxious, energized. Over time, you build a map of how you felt and what you were doing. Patterns emerge that you'd never notice on your own.

---

## THE LESSON

### Why Journal to an AI?

Most people quit journaling because it feels like shouting into a void. You write, nobody reads it, and you never look back. An AI journal is different. Everything you write becomes searchable, summarizable, and actionable.

Write "Gavin called about the driveway estimate — needs it by Friday" as a todo. Thursday morning, your daily briefing reminds you. That's not magic. That's your AI doing what a good dispatcher does — keeping track so you don't have to.

### The Four Note Types

| Type | Purpose | Example |
|------|---------|---------|
| **journal** | Record what happened, how you feel | "Good day on the Henderson job. Finished the foundation ahead of schedule." |
| **todo** | Track tasks that need doing | "Send revised estimate to Martinez by Wednesday" |
| **reminder** | Future-facing alerts | "Truck inspection due next month — schedule it" |
| **reflection** | Deeper thinking, lessons learned | "Realized I need to pad my estimates by 10% for residential jobs" |

### How the Daily Briefing Works

When you call `daily_briefing`, the AI:

1. Pulls your recent daily notes
2. Groups them by type (journals, todos, reminders, reflections)
3. Generates a natural-language summary through Ollama
4. Returns a briefing you can read in 30 seconds

It's like having a foreman who reads every note on the job board and gives you the rundown before the crew shows up.

### Building the Habit

The real power comes from consistency. A single journal entry is a data point. A month of entries is a pattern. Three months and your AI knows your rhythms — when you're productive, what stresses you out, which projects drag on.

Start simple:
- Morning: Add one todo for the day
- Evening: Add one journal entry about what happened
- Weekly: Call daily_briefing and read the summary

That's it. Five minutes a day. Your AI does the rest.

---

## THE PATTERN

```
You write a note ──> daily_note_add stores it with embedding
                          │
You write more notes ─────┤
                          │
You call daily_briefing ──> AI reads recent notes
                          │
                          └──> Generates summary via Ollama
                          │
                          └──> You get a 30-second briefing
```

Every note you add makes the briefing smarter. Every briefing saves you time that would've been spent re-reading old notes.

---

## WHAT YOU PROVED

- You can log structured daily notes (journal, todo, reminder, reflection) through MCP
- Mood tags add emotional context that builds patterns over time
- Semantic search finds your notes by meaning, not exact words
- The AI generates daily briefings from your recent activity
- A five-minute daily habit creates a personal AI that actually knows your life

**Next:** Run `exercise.bat` to start journaling with your AI.
