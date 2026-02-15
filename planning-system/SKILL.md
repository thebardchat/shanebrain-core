# ShaneBrain Planning System

> **Persistent markdown-based planning for multi-session project continuity**
> Adapted from the planning-with-files methodology for ADHD-friendly, family-first development.

---

## Overview

This planning system enables you to:
- **Resume instantly** after interruptions (dispatch calls, kids, life)
- **Track progress visually** with checkboxes and status indicators
- **Maintain context** across multiple Claude sessions
- **Learn from errors** with documented lessons learned
- **Switch projects seamlessly** between Angel Cloud, Pulsar, LogiBot, and ShaneBrain Legacy

---

## Core Principles

### 1. File-Based Memory
Everything is stored in markdown files that persist between sessions. When you start a new session, load your planning files to instantly restore context.

### 2. Visual Progress Tracking
Use checkboxes `[ ]` and `[x]` to track progress at a glance. ADHD-friendly visual feedback.

### 3. Error Documentation
Every error is a learning opportunity. Document what went wrong and how you fixed it.

### 4. Context Preservation
Store decisions, rationale, and current state so future-you (or Claude) can understand exactly where you left off.

---

## File Structure

```
planning-system/
├── SKILL.md                 # This file - planning methodology
├── templates/               # Project templates
│   ├── angel-cloud-template.md
│   ├── shanebrain-legacy-template.md
│   ├── pulsar-security-template.md
│   └── logibot-template.md
├── active-projects/         # Current work (in .gitignore)
│   ├── task_plan.md         # Current task breakdown
│   ├── context.md           # Session context
│   ├── errors.md            # Error log
│   └── decisions.md         # Decision log
└── completed-projects/      # Archived work (in .gitignore)
    └── [project-name]/
```

---

## How to Use This System

### Starting a New Project

1. **Copy the appropriate template** from `templates/` to `active-projects/`
2. **Fill in the project header** with your goals and context
3. **Break down tasks** into checkboxes
4. **Start working** and check off tasks as you complete them

### Resuming a Project

1. **Tell Claude:** "Load my planning files from active-projects/"
2. **Claude reads:** `task_plan.md`, `context.md`, `errors.md`, `decisions.md`
3. **You're back in context** - pick up exactly where you left off

### When You Get Interrupted

1. **Save your current state** in `context.md`
2. **Note any pending tasks** in `task_plan.md`
3. **Walk away** - your context is preserved

### Switching Projects

1. **Move current project** to `completed-projects/` or a subfolder
2. **Load new project** from templates or existing files
3. **Update context** with new project focus

---

## Planning File Templates

### task_plan.md

```markdown
# Task Plan: [Project Name]

**Started:** [Date]
**Last Updated:** [Date]
**Status:** [In Progress / Blocked / Completed]
**Project:** [Angel Cloud / Pulsar / LogiBot / ShaneBrain Legacy]

## Current Goal
[What are you trying to achieve?]

## Progress

### Phase 1: [Phase Name]
- [x] Completed task
- [x] Another completed task
- [ ] Current task (in progress)
- [ ] Upcoming task
- [ ] Future task

### Phase 2: [Phase Name]
- [ ] Task 1
- [ ] Task 2

## Blockers
- [List any blockers here]

## Notes
- [Important notes and observations]
```

### context.md

```markdown
# Session Context

**Last Session:** [Date and time]
**Duration:** [How long you worked]
**Next Session Goal:** [What to do next]

## Current State
[Describe exactly where you are in the project]

## Files Modified
- `path/to/file1.py` - Added crisis detection function
- `path/to/file2.md` - Updated documentation

## Open Questions
- [Questions that need answers]

## Resume Instructions
[Step-by-step instructions for resuming]
1. Open [file]
2. Look at [section]
3. Continue with [task]
```

### errors.md

```markdown
# Error Log

## Error: [Error Name/Type]
**Date:** [When it happened]
**Context:** [What you were doing]

### Error Message
```
[Paste the actual error message]
```

### Root Cause
[What caused the error]

### Solution
[How you fixed it]

### Lesson Learned
[What to remember for next time]

---

## Error: [Next Error]
...
```

### decisions.md

```markdown
# Decision Log

## Decision: [Brief Title]
**Date:** [When decided]
**Project:** [Which project]

### Context
[Why this decision was needed]

### Options Considered
1. **Option A:** [Description] - Pros: ... Cons: ...
2. **Option B:** [Description] - Pros: ... Cons: ...

### Decision Made
[What you decided and why]

### Outcome
[Leave blank, fill in later with results]

---

## Decision: [Next Decision]
...
```

---

## Integration with ShaneBrain Core

### Loading Plans into Claude

When starting a session, tell Claude:

```
Please read my planning files:
- active-projects/task_plan.md
- active-projects/context.md
- active-projects/errors.md (if exists)

Then summarize where I am and what's next.
```

### Storing Plans in Weaviate

Planning files are automatically vectorized and stored in Weaviate for:
- **Semantic search:** Find related plans and decisions
- **Context retrieval:** Load relevant plans based on questions
- **Cross-project learning:** Connect lessons across projects

### MongoDB Integration

Progress and decisions are logged to MongoDB for:
- **Analytics:** Track velocity and patterns
- **History:** Long-term project history
- **Backups:** Additional redundancy

---

## Project-Specific Guidelines

### Angel Cloud Projects
- Always include crisis detection considerations
- Document user privacy implications
- Note mental health best practices

### Pulsar Security Projects
- Document security implications of decisions
- Track threat patterns discovered
- Note blockchain-specific considerations

### LogiBot Projects
- Document dispatch workflow impacts
- Note integration points with existing systems
- Track automation efficiency gains

### ShaneBrain Legacy Projects
- Document family-relevant features
- Note preservation considerations
- Track voice/personality capture

---

## Quick Commands

### For Claude

| Command | Action |
|---------|--------|
| "Load my plans" | Read all files from active-projects/ |
| "Update task plan" | Update task_plan.md with current progress |
| "Log this error" | Add error to errors.md |
| "Log this decision" | Add decision to decisions.md |
| "Summarize progress" | Generate progress summary from task_plan.md |
| "What's blocking me?" | Check blockers in task_plan.md |
| "Archive this project" | Move to completed-projects/ |

### Quick Status Markers

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
Update your planning files as you work, not just at the end of sessions.

### 2. Be Specific
"Fixed bug" is bad. "Fixed null pointer exception in crisis_detector.py line 42 by adding input validation" is good.

### 3. Capture Why
Don't just document what you did - document WHY. Future-you will thank you.

### 4. Time-Box Sessions
Set a timer. When it goes off, update your context and take a break. ADHD-friendly.

### 5. Celebrate Progress
Check off those boxes! Visual progress is motivating.

---

## Emergency Recovery

If you lose context:

1. **Check Git history:** `git log --oneline -20`
2. **Search Weaviate:** Query for recent planning documents
3. **Check MongoDB:** Look at recent activity logs
4. **Read error logs:** `active-projects/errors.md`
5. **Start fresh if needed:** Use templates to rebuild

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-01 | Initial ShaneBrain adaptation |

---

**Remember:** This system is built for real life. Kids interrupt. Dispatch calls come in. That's okay. Your context is saved. Pick up where you left off.

**"Progress, not perfection."**
