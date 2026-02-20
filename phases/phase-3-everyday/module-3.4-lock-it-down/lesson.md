# Module 3.4: Lock It Down

## What You'll Build
A security awareness tool that checks what's running on your machine,
spots suspicious activity, and teaches basic digital hygiene. Think of
it as a health checkup for your computer.

## Time: ~20 minutes

## Prerequisites
- Module 3.1 complete (PersonalDoc vault)
- Ollama running
- Weaviate running on port 8080

## What You'll Learn
1. How to see what programs are running on your machine
2. How to check what your computer is talking to on the network
3. Basic digital hygiene (passwords, updates, phishing awareness)
4. **Security lesson**: What's running on your machine and who it talks to

---

## The Security Lesson: Know Your Machine

Most people have NO IDEA what's running on their computer right now.

Open Task Manager (Ctrl+Shift+Esc) and look at the processes tab. See all
those entries? Each one is a program running on YOUR machine, potentially:
- Using your CPU and RAM
- Sending data over the internet
- Running in the background without you knowing
- Installed by something you downloaded years ago

**This module teaches you to READ your machine.** Not as a hacker — as an
informed owner. You wouldn't ignore weird noises from your car engine.
Don't ignore weird processes on your computer.

---

## What We Check

| Check | What It Does | Risk Levels |
|-------|-------------|-------------|
| Running Processes | Lists what programs are active | safe / caution / warning |
| Network Connections | Shows what your PC is talking to | safe / caution / warning |
| Startup Programs | What loads when you turn on your PC | safe / caution |
| Browser Awareness | What your browser knows about you | informational |

## Risk Levels

- **SAFE** — Normal system process, expected behavior
- **CAUTION** — Worth investigating, might be fine
- **WARNING** — Unusual activity, should investigate

---

## Digital Hygiene Checklist

The exercise also walks through basic digital hygiene:

1. **Passwords** — Do you reuse passwords? Do you use a password manager?
2. **Updates** — Is Windows Update turned on? When did you last update?
3. **Phishing** — Can you spot a fake email? A fake link?
4. **Downloads** — Do you check what you're installing?
5. **WiFi** — Is your home WiFi password-protected?

These aren't paranoid questions. They're the digital equivalent of
"Do you lock your front door?"

---

## After the Exercise

You'll have a SecurityLog collection with the results of your machine checkup.
You'll know what's running, what's connecting, and what to watch for.
More importantly, you'll have the AWARENESS to spot when something changes.

Module 3.5 builds your Daily Briefing — a personal journal and daily planner.
