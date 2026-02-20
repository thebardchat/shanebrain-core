# Module 3.5 Hints: Daily Briefing

## Common Issues

### Briefing generation is slow
- Summarizing multiple notes takes 10-20 seconds
- This is normal for local AI processing
- The briefing reads ALL recent notes to create the summary

### Search doesn't find my entry
- Semantic search looks for MEANING, not exact words
- "groceries" will find notes about shopping and food
- Give it a few seconds after adding — Weaviate needs to index

### Notes seem to duplicate
- Running the exercise multiple times adds more sample data
- This is fine — more data means better briefings
- To start fresh: `curl -X DELETE http://localhost:8080/v1/schema/DailyNote`

## Tips for Daily Use
- **Morning**: Add a to-do note for the day
- **During the day**: Add reminders as they come up
- **Evening**: Write a brief reflection
- **Anytime**: Generate a briefing to see your priorities

## Building a Habit
The most valuable journal is the one you use consistently.
Even one sentence per day builds a searchable personal history.
Over months, you'll have a rich record of your life — fully private,
fully searchable, fully yours.
