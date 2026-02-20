# Module 3.3 Hints: Write It Right

## Common Issues

### Drafts sound generic
- Make sure Module 3.1 vault has relevant personal data
- The more personal context in your vault, the more personalized the drafts
- Add documents about the people you're writing to

### "PersonalDraft collection already exists"
- This is fine — the script skips creation if it exists
- To reset: `curl -X DELETE http://localhost:8080/v1/schema/PersonalDraft`

### Generation is slow
- Draft generation takes 10-20 seconds on typical hardware
- This is normal for local AI — the tradeoff for privacy
- Use llama3.2:1b for faster generation (shorter outputs)

### Draft is too long/short
- The prompt asks for under 150 words
- You can edit the generated draft — it's a STARTING POINT
- Copy it, paste into your email/card, and personalize

## Tips for Better Drafts
- Be specific in your description: "Thank Aunt Sarah for the $50 birthday check she sent for Tommy" works better than "write a thank you"
- The tone setting matters — "warm" for family, "formal" for teachers/business
- Add more personal context to your vault for better personalization

## Retrieving Past Drafts
To see all saved drafts:
```
curl -s http://localhost:8080/v1/graphql -H "Content-Type: application/json" -d "{\"query\": \"{ Get { PersonalDraft { title messageType tone content } } }\"}"
```
