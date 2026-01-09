# ShaneBrain Core - Planning System Guide

> Multi-session project continuity for ADHD-friendly development.

---

## Overview

The Planning System enables you to:
- **Resume instantly** after interruptions
- **Track progress visually** with checkboxes
- **Maintain context** across Claude sessions
- **Learn from errors** with documented lessons
- **Switch projects** seamlessly

---

## Why This System?

**Built for real life:**
- Kids interrupt → Your context is saved
- Dispatch calls → Pick up where you left off
- ADHD brain → Visual progress tracking
- Multiple projects → Easy switching

**Inspired by:**
- Manus AI context engineering
- OthmanAdi's planning-with-files
- Personal experience with ADHD

---

## File Structure

```
planning-system/
├── SKILL.md                 # This methodology
├── templates/               # Project templates
│   ├── angel-cloud-template.md
│   ├── shanebrain-legacy-template.md
│   ├── pulsar-security-template.md
│   └── logibot-template.md
├── active-projects/         # Current work
│   ├── task_plan.md         # Main task tracking
│   ├── context.md           # Session context
│   ├── errors.md            # Error log
│   └── decisions.md         # Decision log
└── completed-projects/      # Archives
    └── [project-name]/
```

---

## Quick Start

### Start a New Project

```bash
# 1. Choose your template
ls planning-system/templates/

# 2. Copy to active-projects
cp planning-system/templates/angel-cloud-template.md \
   planning-system/active-projects/task_plan.md

# 3. Edit your plan
nano planning-system/active-projects/task_plan.md
```

### Resume a Project

When starting a new Claude session:

```
Please read my planning files:
- active-projects/task_plan.md
- active-projects/context.md

Then summarize where I am and what's next.
```

### Save Progress

Before ending a session:

```
Please update my planning files with current progress.
Save the context so I can resume later.
```

---

## Core Files

### task_plan.md

Your main progress tracker:

```markdown
# Task Plan: [Project Name]

**Started:** 2025-01-15
**Last Updated:** 2025-01-15
**Status:** In Progress
**Project:** Angel Cloud

## Current Goal
Build crisis detection for user messages.

## Progress

### Phase 1: Research
- [x] Review existing crisis detection patterns
- [x] Document keyword list
- [ ] Research ML approaches

### Phase 2: Implementation
- [ ] Build keyword matcher
- [ ] Add pattern detection
- [ ] Create response templates

## Blockers
- Need sample crisis messages for testing

## Notes
- Consider privacy implications of logging
```

### context.md

Session state for resuming:

```markdown
# Session Context

**Last Session:** 2025-01-15 2:30 PM
**Duration:** 2 hours
**Next Session Goal:** Implement pattern detection

## Current State
Finished keyword matching in crisis_detection_chain.py.
Need to add pattern analysis next.

## Files Modified
- `langchain-chains/crisis_detection_chain.py` - Added keyword scan
- `planning-system/active-projects/task_plan.md` - Updated progress

## Open Questions
- Should we log detected keywords? (Privacy concern)

## Resume Instructions
1. Open crisis_detection_chain.py
2. Look at _pattern_analysis method (line ~150)
3. Implement farewell_patterns detection
```

### errors.md

Learn from mistakes:

```markdown
# Error Log

## Error: Weaviate Connection Refused
**Date:** 2025-01-15
**Context:** Running health check

### Error Message
```
ConnectionRefusedError: [Errno 111] Connection refused
```

### Root Cause
Docker wasn't running.

### Solution
```bash
sudo systemctl start docker
cd weaviate-config && docker-compose up -d
```

### Lesson Learned
Always check Docker status before running health check.
```

### decisions.md

Document the "why":

```markdown
# Decision Log

## Decision: Use keyword matching before ML
**Date:** 2025-01-15
**Project:** Angel Cloud

### Context
Need to detect crisis indicators in user messages.

### Options Considered
1. **ML only** - More accurate, but slower and needs training data
2. **Keywords only** - Fast, but may miss nuanced cases
3. **Hybrid** - Keywords first, ML for uncertain cases

### Decision Made
Hybrid approach - keywords for speed, ML for depth.

### Rationale
- Safety requires fast detection (keywords)
- Can't miss edge cases (ML backup)
- Works offline (keywords don't need cloud)
```

---

## Templates

### Choosing a Template

| Template | Use For |
|----------|---------|
| `angel-cloud-template.md` | Mental wellness features |
| `shanebrain-legacy-template.md` | Digital legacy work |
| `pulsar-security-template.md` | Blockchain security |
| `logibot-template.md` | Dispatch automation |

### Template Sections

Each template includes:
- **Project Header** - Metadata and status
- **Project Overview** - Goals and success criteria
- **Domain-Specific** - Relevant considerations
- **Technical Architecture** - Components involved
- **Task Breakdown** - Phased progress tracking
- **Testing Strategy** - How to validate
- **Session Log** - Per-session notes

---

## Workflow

### Starting a Session

```
1. Load planning files
2. Review current state
3. Check blockers
4. Set session goal
5. Start working
```

### During a Session

```
1. Check off completed tasks
2. Add notes as you go
3. Log any errors
4. Document decisions
```

### Ending a Session

```
1. Update task_plan.md
2. Save context.md
3. Commit changes (optional)
4. Note next session goal
```

### Switching Projects

```
1. Save current project context
2. Move to completed/ if done
3. Load new project template
4. Continue with new project
```

---

## Integration with Claude

### Loading Context

Tell Claude:
```
Load my planning files from active-projects/
```

Claude will read:
- task_plan.md
- context.md
- errors.md (if exists)

### Updating Progress

Tell Claude:
```
Update task_plan.md - mark "Build keyword matcher" as complete.
Add a note about the privacy consideration.
```

### Quick Commands

| Command | Action |
|---------|--------|
| "Load my plans" | Read all planning files |
| "Update task plan" | Save current progress |
| "Log this error" | Add to errors.md |
| "Log this decision" | Add to decisions.md |
| "What's blocking me?" | Review blockers |
| "Archive this project" | Move to completed/ |

---

## Status Markers

Use these in task lists:

| Marker | Meaning |
|--------|---------|
| `[ ]` | Not started |
| `[x]` | Completed |
| `[~]` | In progress |
| `[!]` | Blocked |
| `[?]` | Needs decision |
| `[-]` | Cancelled |

---

## Best Practices

### 1. Update Frequently
Don't wait until the end. Update as you work.

### 2. Be Specific
Bad: "Fixed bug"
Good: "Fixed null check in crisis_detector.py:42"

### 3. Capture Why
Don't just document what - document WHY.

### 4. Time-Box Sessions
Set a timer. Update context when it goes off.

### 5. Celebrate Progress
Check those boxes! Visual feedback matters.

---

## Recovery

### Lost Context?

1. Check git history:
   ```bash
   git log --oneline -10
   git diff HEAD~1
   ```

2. Search Weaviate for recent docs

3. Check MongoDB activity logs

4. Start fresh from template if needed

### Corrupted Files?

1. Restore from backup:
   ```bash
   ./scripts/backup.sh restore [backup-name]
   ```

2. Or recreate from template

---

## Tips for ADHD

1. **Visual Progress** - Those checkboxes release dopamine
2. **Small Tasks** - Break everything down
3. **Context Files** - Your external memory
4. **Time Boxing** - Work in focused bursts
5. **No Shame** - Interruptions happen, context is saved

---

**Remember: Progress, not perfection.**

**"The system is built for real life. Walk away. Come back. Pick up where you left off."**
