# Module 3.2 Hints: Ask Your Vault

## Common Issues

### "PersonalDoc not found"
- You need to complete Module 3.1 first
- Run `phases/phase-3-everyday/module-3.1-your-private-vault/exercise.bat`

### Answers are slow
- Ollama generates answers using your local CPU/GPU
- On a Pi 5 or older PC, expect 5-15 seconds per answer
- This is normal — the tradeoff for privacy is speed
- Try llama3.2:1b for faster (but less detailed) answers

### Answers don't match the question
- Semantic search finds SIMILAR content, not exact keyword matches
- Try rephrasing your question
- More specific questions get better results
- "What medication does Dad take?" works better than "Dad meds"

### "Ollama returned empty response"
- The model might not be loaded: `ollama pull llama3.2:3b`
- Ollama might be out of memory — close other programs
- Try a smaller model: change `llama3.2:3b` to `llama3.2:1b`

### Want to add more personal data?
- Go back to Module 3.1 hints for how to add documents via curl
- The more data in your vault, the better the answers

## Understanding Certainty Scores
- 90%+ = Very confident match
- 70-90% = Good match
- 50-70% = Possible match, might not be relevant
- Below 50% = Probably not what you're looking for
