# Module 3.4 — Lock It Down

## WHAT YOU'LL BUILD

A security audit workflow for your AI system. You'll check system health, search security logs, and review privacy audit trails. By the end, you'll know how to verify what your AI is doing, who's accessing it, and whether anything looks off.

You built a vault. You taught it to answer and write. Now you learn to watch the front door. Every job site has a safety officer. This module makes you the safety officer of your AI system.

---

## WHO THIS IS FOR

Everyone. Security awareness isn't optional — it's the price of running your own AI. Whether you're storing medical records or business docs, you need to know: Is my system healthy? Has anything unusual happened? Can I prove my data stayed private? This module answers all three.

---

## KEY TERMS

- **system_health**: The MCP tool that checks everything at once — is Weaviate up? Is Ollama running? How many documents are in each collection? Like walking the job site before the crew arrives and checking that all the equipment is running.

- **security_log_search**: Searches the SecurityLog collection for events like failed logins, unusual access patterns, or system alerts. Think of it as checking the security camera footage. If the log is empty, that's actually good news — nothing suspicious happened.

- **privacy_audit_search**: Searches the PrivacyAudit collection for records of who accessed what data and when. This is your paper trail. If someone (or something) accessed your vault, there should be a record here.

- **Health Check**: A quick status report on all services. Shows what's running, what's down, and how much data each collection holds. Run this first, always.

- **Audit Trail**: A chronological record of actions taken on your system. Who searched what? When was data added? What was accessed? Even if no one else uses your system, having an audit trail proves your data pipeline is clean.

---

## THE LESSON

### Step 1: Check system health first

Before digging into logs, know what you're working with. `system_health` gives you the full picture:

- **Services**: Are Weaviate and Ollama running? If either is down, your vault and AI won't work.
- **Collections**: How many objects are in each Weaviate collection? This tells you what data exists.
- **Status**: Any warnings or errors? Catch problems before they become outages.

Run this whenever something feels off, or just as a daily habit. Takes two seconds. Saves hours of debugging.

### Step 2: Search security logs

The SecurityLog collection records security-relevant events. Search it with `security_log_search`:

- "failed login" — any authentication failures?
- "unusual activity" — any patterns that look wrong?
- "access denied" — any blocked requests?

**Empty results are normal.** If you're the only user on a local system, there may be no security events to find. That's good. The point is knowing HOW to check, so when you scale up or add users, you're already watching.

### Step 3: Search privacy audit trails

The PrivacyAudit collection tracks data access patterns. Search it with `privacy_audit_search`:

- "vault access" — who opened the vault?
- "data export" — was any data moved or copied?
- "personal information" — what queries touched sensitive data?

Again, empty results on a fresh system are expected. You're building the muscle memory of checking. Like locking the tool trailer every night — even when nothing's been stolen, the habit keeps you safe.

### Step 4: Build the security habit

Security isn't a one-time check. It's a routine:

1. **Daily**: Run `system_health` to make sure everything is up
2. **Weekly**: Search security logs for anything unusual
3. **Monthly**: Review privacy audit trails
4. **After changes**: Check health after adding new documents or changing configurations

The tools are simple. The discipline is what matters.

---

## THE PATTERN

```
HEALTH CHECK  →  SECURITY LOGS  →  PRIVACY AUDIT
 (system_health)  (security_log_search)  (privacy_audit_search)
```

Three checks. Three layers of awareness. Health tells you what's running. Security tells you what happened. Privacy tells you what was accessed.

---

## WHAT YOU PROVED

- You can check your AI system's health in seconds
- Security logs exist and you know how to search them
- Privacy audit trails track data access patterns
- Empty logs mean a clean system — and you know how to verify that
- You have a security routine you can run anytime

**Next:** Run `exercise.bat` to audit your AI system.
