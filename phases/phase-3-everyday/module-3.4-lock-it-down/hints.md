# Module 3.4 Hints: Lock It Down

## Common Issues

### "tasklist is not recognized"
- On Linux/Mac, the script automatically falls back to `ps aux`
- `tasklist` is a standard Windows command — no admin needed
- If on Windows and it fails, try running CMD as administrator

### "netstat is not recognized"
- On Linux, the script falls back to `ss -tuln`
- On Windows, `netstat` is built-in — should always work
- Try opening a new CMD window

### Process count seems high
- Modern Windows typically runs 100-200 processes
- Linux systems typically run 50-150 processes
- Most are system services — this is normal
- Focus on processes you DON'T recognize

### Understanding risk levels
- **SAFE**: System processes (svchost, csrss, explorer) — these run Windows
- **CAUTION**: Cloud apps (Chrome, OneDrive, Teams) — they're sending data
- **WARNING**: Unknown processes — worth investigating

## What to do about CAUTION items
Cloud apps in the CAUTION category aren't malware. They're legitimate apps
that send data to company servers. The point is AWARENESS:
- Chrome syncs your browsing to Google
- OneDrive syncs files to Microsoft
- Teams is always connected to Microsoft servers
- Knowing this helps you make informed decisions

## Digital Hygiene Quick Wins
1. Use a password manager (even the free built-in ones)
2. Turn on automatic updates
3. Check email sender addresses before clicking
4. Review app permissions quarterly
5. Change your WiFi password from the default
