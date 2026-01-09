# ShaneBrain Core - Security Guide

> Security best practices for the ShaneBrain infrastructure.

---

## Security Philosophy

**Core Principles:**
1. **Local-First** - Your data stays on your hardware
2. **Zero Cloud Dependency** - Works without internet
3. **Privacy by Design** - No telemetry, no tracking
4. **Minimal Attack Surface** - Only what's needed

---

## Credential Management

### The .env File

Your `.env` file contains sensitive credentials. **NEVER commit it to git.**

**Setup:**
```bash
# Create from template
cp .env.template .env

# Set secure permissions (owner read/write only)
chmod 600 .env

# Or use the setup script
python scripts/setup_credentials.py
```

**What Goes in .env:**
- Database connection strings
- API keys (optional cloud services)
- Encryption keys
- Paths to sensitive data

**What NEVER Goes in .env:**
- Actual passwords in comments
- Production credentials in dev environments
- Credentials for services you don't use

### .gitignore Protection

The following are automatically blocked from git:

```gitignore
# Credentials
.env
.env.local
credentials.json
*.key
*.pem

# Personal data
planning-system/active-projects/*.md
conversations/
crisis-logs/

# Database files
weaviate-config/data/
mongodb-data/
*.gguf
```

---

## Data Classification

### Sensitivity Levels

| Level | Description | Examples | Protection |
|-------|-------------|----------|------------|
| **Public** | Safe to share | Code, templates | Version control |
| **Internal** | Business use | Logs, analytics | Local storage |
| **Personal** | User data | Conversations, projects | Encrypted local |
| **Sensitive** | Critical | Crisis logs, credentials | Encrypted + restricted |

### Mental Health Data (Angel Cloud)

**Special Handling Required:**

1. **Crisis Logs**
   - Encrypted at rest
   - 7-year retention (legal)
   - No content in logs (only metadata)
   - Access audited

2. **Conversations**
   - User-controlled retention
   - Encrypted in MongoDB
   - Never transmitted externally
   - Deletable on request

---

## Encryption

### At-Rest Encryption

**Sensitive Fields:**
```python
# These fields should be encrypted:
ENCRYPTED_FIELDS = [
    "crisis_logs.triggering_message",
    "user_sessions.security.auth_tokens",
    "conversations.messages.content"  # Optional
]
```

**Implementation:**
```python
from cryptography.fernet import Fernet

# Load key from environment
key = os.environ.get("ENCRYPTION_KEY")
cipher = Fernet(key.encode())

# Encrypt
encrypted = cipher.encrypt(data.encode())

# Decrypt
decrypted = cipher.decrypt(encrypted).decode()
```

### Key Management

1. **Generate a strong key:**
   ```bash
   openssl rand -hex 32
   ```

2. **Store securely:**
   - In `.env` file (chmod 600)
   - Never in code or logs
   - Backup securely (not in git)

3. **Rotation:**
   - Rotate every 90 days
   - Re-encrypt existing data
   - Keep old key for decryption during transition

---

## Network Security

### Local-Only Mode (Default)

ShaneBrain runs entirely locally:
- Weaviate: `localhost:8080`
- MongoDB: `localhost:27017`
- No external API calls

### If Enabling Remote Access

**NOT RECOMMENDED** without proper security:

1. **Use VPN** - Don't expose directly
2. **Enable Authentication** - On all services
3. **Use HTTPS** - Never plain HTTP
4. **Firewall Rules** - Whitelist IPs

**Weaviate Authentication:**
```yaml
# docker-compose.yml
environment:
  AUTHENTICATION_APIKEY_ENABLED: 'true'
  AUTHENTICATION_APIKEY_USERS: 'admin'
  AUTHENTICATION_APIKEY_ALLOWED_KEYS: '${WEAVIATE_API_KEY}'
```

---

## Access Control

### File Permissions

```bash
# Credentials - owner only
chmod 600 .env

# Scripts - owner execute
chmod 700 scripts/*.sh

# Data directories - owner only
chmod 700 planning-system/active-projects/
```

### Docker Security

```yaml
# docker-compose.yml security settings
services:
  weaviate:
    security_opt:
      - no-new-privileges:true
    read_only: false  # Weaviate needs write
    user: "1000:1000"  # Run as non-root
```

---

## Crisis Detection Security

### Safe Logging

**DO:**
```python
# Log metadata only
log_entry = {
    "crisis_level": result.crisis_level.value,
    "crisis_score": result.crisis_score,
    "keywords_count": len(result.keywords_found),
    "timestamp": datetime.now()
}
```

**DON'T:**
```python
# Never log actual content
log_entry = {
    "message": user_message,  # BAD!
    "keywords": result.keywords_found  # BAD!
}
```

### Escalation Security

When crisis is detected:
1. Response is generated immediately
2. Only metadata is logged
3. No content stored unless encrypted
4. Audit trail maintained

---

## Backup Security

### Backup Encryption

```bash
# Create encrypted backup
tar -czf - backup-data/ | \
  openssl enc -aes-256-cbc -salt -out backup.tar.gz.enc

# Restore
openssl enc -aes-256-cbc -d -in backup.tar.gz.enc | \
  tar -xzf -
```

### Backup Storage

- **Local:** On 8TB drive (primary)
- **Offsite:** Encrypted only
- **Cloud:** MongoDB Atlas, Weaviate Cloud (optional)

### Backup Verification

```bash
# Test backup integrity
./scripts/backup.sh restore test-backup
python scripts/health_check.py
```

---

## Security Checklist

### Initial Setup

- [ ] Created `.env` from template
- [ ] Set `.env` permissions to 600
- [ ] Generated strong encryption key
- [ ] Verified `.gitignore` is active
- [ ] Reviewed Docker security settings

### Ongoing

- [ ] Rotate encryption keys (quarterly)
- [ ] Review access logs (weekly)
- [ ] Test backup restoration (monthly)
- [ ] Update dependencies (monthly)
- [ ] Security audit (annually)

### Before Sharing Code

- [ ] No credentials in code
- [ ] No personal data in commits
- [ ] `.env.template` has placeholders only
- [ ] Sensitive files are gitignored

---

## Incident Response

### If Credentials Are Exposed

1. **Immediately** rotate affected credentials
2. **Check** git history for exposure
3. **Revoke** any cloud API keys
4. **Audit** for unauthorized access
5. **Document** the incident

### If Data Is Compromised

1. **Isolate** affected systems
2. **Assess** scope of exposure
3. **Notify** affected parties (if applicable)
4. **Restore** from clean backup
5. **Review** and improve security

---

## Security Resources

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Docker Security](https://docs.docker.com/engine/security/)
- [MongoDB Security Checklist](https://www.mongodb.com/docs/manual/administration/security-checklist/)
- [Weaviate Security](https://weaviate.io/developers/weaviate/configuration/authentication)

---

**Remember: Security is a process, not a destination.**

**"Your data, your hardware, your control."**
