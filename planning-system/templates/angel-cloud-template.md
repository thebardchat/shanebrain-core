# Angel Cloud Project Plan

> **Mental Wellness Platform with AI-Powered Crisis Intervention**
> Part of the ShaneBrain Core ecosystem

---

## Project Header

**Project Name:** [Name of this specific feature/task]
**Created:** [Date]
**Last Updated:** [Date]
**Status:** [ ] Planning [ ] In Progress [ ] Testing [ ] Completed
**Priority:** [ ] Critical [ ] High [ ] Medium [ ] Low

---

## Project Overview

### Goal
[What are you building? What problem does it solve?]

### Why This Matters
- **User Impact:** [How will this help users struggling with mental health?]
- **Scale Impact:** [How does this contribute to helping 800M users?]
- **Family Impact:** [Does this support family-first values?]

### Success Criteria
- [ ] [Measurable outcome 1]
- [ ] [Measurable outcome 2]
- [ ] [Measurable outcome 3]

---

## Mental Health Considerations

### Crisis Detection
- [ ] Does this feature involve user-generated content? → Add crisis detection
- [ ] Does this feature have user interactions? → Monitor for distress signals
- [ ] Is there PII involved? → Encrypt and protect

### Safety Checklist
- [ ] Crisis keywords are detected
- [ ] Emergency resources are accessible
- [ ] Escalation path exists for severe cases
- [ ] User data is encrypted at rest
- [ ] No data leaves local infrastructure without consent

### Ethical Guidelines
- [ ] Respects user autonomy
- [ ] Provides hope, not harm
- [ ] Culturally sensitive
- [ ] Accessible to users with disabilities
- [ ] Works offline (no dependency on cloud for safety features)

---

## Technical Architecture

### Components Involved
- [ ] Frontend (React/Next.js)
- [ ] Backend (Python/FastAPI)
- [ ] Weaviate (vector storage)
- [ ] MongoDB (structured data)
- [ ] LangChain (AI workflows)
- [ ] Llama (local inference)

### Data Flow
```
[User Input] → [Crisis Detection] → [Safe?]
                                      ↓ No
                                   [Escalate]
                                      ↓ Yes
[Normal Processing] → [Response Generation] → [User]
```

### Integration Points
- **Weaviate:** [What vectors are stored/retrieved?]
- **MongoDB:** [What data is logged?]
- **Llama:** [What prompts are used?]
- **Planning System:** [What context is needed?]

---

## Task Breakdown

### Phase 1: Planning & Research
- [ ] Define requirements
- [ ] Research best practices for mental health AI
- [ ] Review existing crisis detection patterns
- [ ] Design data schema
- [ ] Create technical specification

### Phase 2: Core Implementation
- [ ] Set up development environment
- [ ] Implement core logic
- [ ] Add crisis detection integration
- [ ] Connect to Weaviate
- [ ] Connect to MongoDB
- [ ] Write unit tests

### Phase 3: Safety & Testing
- [ ] Test with edge cases
- [ ] Validate crisis detection accuracy
- [ ] Security audit
- [ ] Performance testing
- [ ] Accessibility testing

### Phase 4: Integration & Deployment
- [ ] Integrate with main application
- [ ] Update documentation
- [ ] Deploy to staging
- [ ] User acceptance testing
- [ ] Deploy to production

---

## Crisis Detection Integration

### Keywords to Monitor
```python
CRISIS_KEYWORDS = [
    "suicide", "kill myself", "end it all", "no reason to live",
    "self-harm", "hurt myself", "cutting", "overdose",
    "hopeless", "can't go on", "better off dead",
    "goodbye", "final message", "last words"
]
```

### Detection Thresholds
- **Low (0.0-0.3):** Monitor, no immediate action
- **Medium (0.3-0.7):** Offer resources, gentle check-in
- **High (0.7-0.9):** Immediate resources, encourage professional help
- **Critical (0.9-1.0):** Crisis intervention protocol

### Response Templates
```markdown
**Medium Risk Response:**
"I notice you might be going through a difficult time. Remember, you're not alone.
Would you like me to share some resources that might help?"

**High Risk Response:**
"I'm concerned about what you're sharing. Your wellbeing matters.
The National Suicide Prevention Lifeline is available 24/7 at 988.
Would you like to talk about what's happening?"

**Critical Response:**
"I hear that you're in pain. Please know that help is available right now.
🆘 National Suicide Prevention Lifeline: 988
🆘 Crisis Text Line: Text HOME to 741741
🆘 Emergency Services: 911

You matter. Please reach out to one of these resources."
```

---

## Privacy & Data Protection

### Data Classification
| Data Type | Classification | Storage | Retention |
|-----------|---------------|---------|-----------|
| Crisis logs | Sensitive | Encrypted MongoDB | 7 years |
| Conversations | Personal | Weaviate (local) | User-controlled |
| Analytics | Aggregate | MongoDB | Indefinite |
| User profiles | Personal | MongoDB (encrypted) | User-controlled |

### Encryption Requirements
- [ ] AES-256 for data at rest
- [ ] TLS 1.3 for data in transit
- [ ] Key rotation every 90 days
- [ ] Secure key storage

---

## Testing Strategy

### Unit Tests
- [ ] Crisis detection accuracy
- [ ] Threshold calibration
- [ ] Response generation
- [ ] Data encryption/decryption

### Integration Tests
- [ ] End-to-end user flow
- [ ] Weaviate integration
- [ ] MongoDB integration
- [ ] Offline functionality

### Safety Tests
- [ ] Edge case handling
- [ ] False positive rate
- [ ] False negative rate (CRITICAL)
- [ ] Response appropriateness

---

## Blockers & Dependencies

### Current Blockers
- [ ] [Blocker 1]
- [ ] [Blocker 2]

### Dependencies
- [ ] [Dependency 1] - Status: [Complete/In Progress/Not Started]
- [ ] [Dependency 2] - Status: [Complete/In Progress/Not Started]

---

## Decisions Made

| Decision | Rationale | Date |
|----------|-----------|------|
| [Decision 1] | [Why] | [When] |
| [Decision 2] | [Why] | [When] |

---

## Lessons Learned

### What Went Well
- [Positive outcome 1]
- [Positive outcome 2]

### What Could Improve
- [Area for improvement 1]
- [Area for improvement 2]

### For Next Time
- [Lesson 1]
- [Lesson 2]

---

## Session Log

### Session: [Date]
**Duration:** [Time]
**Focus:** [What you worked on]
**Progress:**
- [x] [Completed task]
- [~] [In progress task]
- [ ] [Remaining task]

**Notes:**
[Session-specific notes]

**Next Session:**
[What to do next]

---

## Resources

### Mental Health Best Practices
- [SAMHSA Guidelines](https://www.samhsa.gov/)
- [WHO Mental Health](https://www.who.int/health-topics/mental-health)
- [Crisis Text Line Best Practices](https://www.crisistextline.org/)

### Technical Resources
- [LangChain Documentation](https://python.langchain.com/)
- [Weaviate Documentation](https://weaviate.io/developers/weaviate)
- [Safety Filters in AI](https://arxiv.org/...)

---

**Remember:** Every feature we build could save a life. Build with care. Test thoroughly. Prioritize safety over features.

**"Technology that heals, not harms."**
