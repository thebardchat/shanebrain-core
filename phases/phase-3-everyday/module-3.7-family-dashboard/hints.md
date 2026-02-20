# Module 3.7 Hints: The Family Dashboard

## Common Issues

### Dashboard shows "[not created yet]" for a collection
- That module's exercise hasn't been run yet
- Go through modules 3.1-3.6 in order
- Each one creates its Weaviate collection

### "Weaviate is NOT running" or "Ollama is NOT running"
- Start Docker and Weaviate: `cd weaviate-config && docker-compose up -d`
- Start Ollama: `ollama serve` (or check the systemd service)
- Wait 15 seconds after starting, then refresh health check (option 7)

### Launching a tool returns an error
- Each tool uses `call` to run the module's exercise.bat
- Make sure the module directories are in the expected relative paths
- The dashboard expects to be in `module-3.7-family-dashboard/`

### Object counts seem low
- Run each module's exercise to populate sample data
- Add your own personal data for the most useful experience

## Making It a Daily Tool
1. Create a desktop shortcut to this exercise.bat
2. Use option 5 (Daily Briefing) every morning for your daily plan
3. Use option 2 (Ask Your Vault) whenever you need family info
4. Use option 3 (Write It Right) for personal messages
5. Run option 4 (Lock It Down) monthly as a security checkup
6. Run option 6 (Digital Footprint) quarterly to review privacy

## What You've Built
The Family Dashboard represents the capstone of Phase 3. You now have:
- A private knowledge base (no cloud storage needed)
- An AI Q&A system (no ChatGPT needed)
- A writing assistant (no Grammarly needed)
- A security awareness tool (know your machine)
- A personal journal (no cloud journal needed)
- A privacy audit (understand your footprint)

All running locally. All private. All yours.
