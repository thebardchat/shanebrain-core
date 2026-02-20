# Module 3.1 Hints: Your Private Vault

## Common Issues

### "Weaviate is not running"
- Make sure Docker is running first
- Start Weaviate: `cd weaviate-config && docker-compose up -d`
- Wait 15 seconds, then try again

### "Ollama is not running"
- Start Ollama: `ollama serve` (or it may already be running as a service)
- Check: `curl http://localhost:11434/api/tags`

### "Failed to create PersonalDoc collection"
- Weaviate may already have a PersonalDoc collection from a previous run
- This is fine — the script skips creation if it already exists
- To start fresh: delete via `curl -X DELETE http://localhost:8080/v1/schema/PersonalDoc`

### "nomic-embed-text model not found"
- Pull the embedding model: `ollama pull nomic-embed-text`
- This is required for Weaviate to vectorize your documents

### Documents loaded but count is wrong
- Some documents may have failed to embed (Ollama was busy)
- Run the exercise again — it will add more documents
- To start completely fresh, delete the collection and re-run

## Adding Your Own Documents

After running the exercise, you can add your own documents using curl:

```
curl -X POST http://localhost:8080/v1/objects?class=PersonalDoc ^
  -H "Content-Type: application/json" ^
  -d "{\"title\": \"Your Title\", \"content\": \"Your content here\", \"category\": \"family\", \"source\": \"Where you got this\"}"
```

Valid categories: family, health, recipes, school, finance, general

## What NOT to Store
- Actual passwords (store WHERE the password is written)
- Social Security numbers
- Credit card numbers
- Bank account numbers

Store REMINDERS, not the sensitive data itself.
