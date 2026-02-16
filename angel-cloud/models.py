"""
Angel Cloud User Models — SQLite storage for user accounts and angel progression.
"""

import sqlite3
import bcrypt
import os
import random
from datetime import datetime, timezone, timedelta
from typing import Optional

DB_PATH = os.path.join(os.path.dirname(__file__), "angel_cloud.db")

ANGEL_LEVELS = [
    "Newborn",
    "Young Angel",
    "Growing Angel",
    "Helping Angel",
    "Guardian Angel",
    "Angel",
]

PROGRESSION_THRESHOLDS = {
    "Newborn": 0,
    "Young Angel": 10,
    "Growing Angel": 25,
    "Helping Angel": 50,
    "Guardian Angel": 100,
    "Angel": 250,
}


def get_db() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    return conn


def init_db():
    conn = get_db()
    conn.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            email TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            angel_level TEXT NOT NULL DEFAULT 'Newborn',
            created_at TEXT NOT NULL,
            last_seen TEXT NOT NULL
        )
    """)
    # Idempotent schema migration — add columns if missing
    cursor = conn.execute("PRAGMA table_info(users)")
    existing = {row[1] for row in cursor.fetchall()}
    if "interaction_count" not in existing:
        conn.execute("ALTER TABLE users ADD COLUMN interaction_count INTEGER DEFAULT 0")
    if "display_name" not in existing:
        conn.execute("ALTER TABLE users ADD COLUMN display_name TEXT DEFAULT ''")
    if "discord_id" not in existing:
        conn.execute("ALTER TABLE users ADD COLUMN discord_id TEXT")
    if "github_username" not in existing:
        conn.execute("ALTER TABLE users ADD COLUMN github_username TEXT")
    if "last_activity" not in existing:
        conn.execute("ALTER TABLE users ADD COLUMN last_activity TEXT")

    # Link codes table for Discord verification
    conn.execute("""
        CREATE TABLE IF NOT EXISTS link_codes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            code TEXT NOT NULL,
            discord_id TEXT NOT NULL,
            discord_name TEXT NOT NULL,
            email TEXT NOT NULL,
            created_at TEXT NOT NULL,
            expires_at TEXT NOT NULL,
            used INTEGER DEFAULT 0
        )
    """)

    # Activity log for all point-earning events
    conn.execute("""
        CREATE TABLE IF NOT EXISTS activity_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            points INTEGER NOT NULL,
            activity_type TEXT NOT NULL,
            description TEXT NOT NULL,
            created_at TEXT NOT NULL,
            FOREIGN KEY (user_id) REFERENCES users(id)
        )
    """)

    conn.commit()
    conn.close()


def create_user(username: str, email: str, password: str) -> Optional[dict]:
    password_hash = bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()
    now = datetime.now(timezone.utc).isoformat()
    conn = get_db()
    try:
        conn.execute(
            "INSERT INTO users (username, email, password_hash, angel_level, created_at, last_seen) VALUES (?, ?, ?, ?, ?, ?)",
            (username, email.lower(), password_hash, "Newborn", now, now),
        )
        conn.commit()
        user = conn.execute(
            "SELECT * FROM users WHERE username = ?", (username,)
        ).fetchone()
        return dict(user)
    except sqlite3.IntegrityError:
        return None
    finally:
        conn.close()


def authenticate(email: str, password: str) -> Optional[dict]:
    conn = get_db()
    user = conn.execute(
        "SELECT * FROM users WHERE email = ?", (email.lower(),)
    ).fetchone()
    if user and bcrypt.checkpw(password.encode(), user["password_hash"].encode()):
        now = datetime.now(timezone.utc).isoformat()
        conn.execute("UPDATE users SET last_seen = ? WHERE id = ?", (now, user["id"]))
        conn.commit()
        conn.close()
        return dict(user)
    conn.close()
    return None


def get_user_by_id(user_id: int) -> Optional[dict]:
    conn = get_db()
    user = conn.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
    conn.close()
    return dict(user) if user else None


def get_user_count() -> int:
    conn = get_db()
    count = conn.execute("SELECT COUNT(*) FROM users").fetchone()[0]
    conn.close()
    return count


def get_level_index(level: str) -> int:
    try:
        return ANGEL_LEVELS.index(level)
    except ValueError:
        return 0


def increment_interaction(user_id: int) -> int:
    """Increment interaction count and return the new value."""
    conn = get_db()
    conn.execute("UPDATE users SET interaction_count = interaction_count + 1 WHERE id = ?", (user_id,))
    conn.commit()
    count = conn.execute("SELECT interaction_count FROM users WHERE id = ?", (user_id,)).fetchone()[0]
    conn.close()
    return count


def add_interaction_points(user_id: int, points: int, activity_type: str, description: str) -> int:
    """Add points to a user's interaction count and log the activity. Returns new count."""
    now = datetime.now(timezone.utc).isoformat()
    conn = get_db()
    conn.execute(
        "UPDATE users SET interaction_count = interaction_count + ?, last_activity = ? WHERE id = ?",
        (points, now, user_id),
    )
    conn.execute(
        "INSERT INTO activity_log (user_id, points, activity_type, description, created_at) VALUES (?, ?, ?, ?, ?)",
        (user_id, points, activity_type, description, now),
    )
    conn.commit()
    count = conn.execute("SELECT interaction_count FROM users WHERE id = ?", (user_id,)).fetchone()[0]
    conn.close()
    return count


def check_level_up(user_id: int) -> Optional[str]:
    """Check if user qualifies for a level up. Returns new level name or None."""
    conn = get_db()
    user = conn.execute("SELECT angel_level, interaction_count FROM users WHERE id = ?", (user_id,)).fetchone()
    if not user:
        conn.close()
        return None

    current_level = user["angel_level"]
    count = user["interaction_count"]
    current_idx = get_level_index(current_level)

    # Walk through levels above current to find the highest qualified
    new_level = None
    for i in range(current_idx + 1, len(ANGEL_LEVELS)):
        level_name = ANGEL_LEVELS[i]
        if count >= PROGRESSION_THRESHOLDS[level_name]:
            new_level = level_name
        else:
            break

    if new_level:
        conn.execute("UPDATE users SET angel_level = ? WHERE id = ?", (new_level, user_id))
        conn.commit()
    conn.close()
    return new_level


def get_next_threshold(level: str) -> Optional[int]:
    """Return the interaction count needed for the next level, or None if max."""
    idx = get_level_index(level)
    if idx >= len(ANGEL_LEVELS) - 1:
        return None
    return PROGRESSION_THRESHOLDS[ANGEL_LEVELS[idx + 1]]


def update_profile(user_id: int, display_name: str) -> bool:
    conn = get_db()
    conn.execute("UPDATE users SET display_name = ? WHERE id = ?", (display_name.strip(), user_id))
    conn.commit()
    conn.close()
    return True


def update_password(user_id: int, current_password: str, new_password: str) -> bool:
    """Change password after verifying current password. Returns True on success."""
    conn = get_db()
    user = conn.execute("SELECT password_hash FROM users WHERE id = ?", (user_id,)).fetchone()
    if not user:
        conn.close()
        return False
    if not bcrypt.checkpw(current_password.encode(), user["password_hash"].encode()):
        conn.close()
        return False
    new_hash = bcrypt.hashpw(new_password.encode(), bcrypt.gensalt()).decode()
    conn.execute("UPDATE users SET password_hash = ? WHERE id = ?", (new_hash, user_id))
    conn.commit()
    conn.close()
    return True


# ---------------------------------------------------------------------------
# Discord Link
# ---------------------------------------------------------------------------

def create_link_code(discord_id: str, discord_name: str, email: str) -> Optional[str]:
    """Create a 6-digit link code for Discord verification. Returns the code or None if email not found."""
    conn = get_db()
    user = conn.execute("SELECT id FROM users WHERE email = ?", (email.lower(),)).fetchone()
    if not user:
        conn.close()
        return None

    # Check if already linked
    existing = conn.execute("SELECT discord_id FROM users WHERE id = ?", (user["id"],)).fetchone()
    if existing and existing["discord_id"]:
        conn.close()
        return None

    code = str(random.randint(100000, 999999))
    now = datetime.now(timezone.utc)
    expires = now + timedelta(minutes=10)
    conn.execute(
        "INSERT INTO link_codes (code, discord_id, discord_name, email, created_at, expires_at) VALUES (?, ?, ?, ?, ?, ?)",
        (code, discord_id, discord_name, email.lower(), now.isoformat(), expires.isoformat()),
    )
    conn.commit()
    conn.close()
    return code


def verify_link_code(user_id: int, code: str) -> Optional[str]:
    """Validate a 6-digit code and bind the Discord ID to the user. Returns discord_name or None."""
    conn = get_db()
    user = conn.execute("SELECT email, discord_id FROM users WHERE id = ?", (user_id,)).fetchone()
    if not user:
        conn.close()
        return None
    if user["discord_id"]:
        conn.close()
        return None  # Already linked

    now = datetime.now(timezone.utc).isoformat()
    row = conn.execute(
        "SELECT * FROM link_codes WHERE code = ? AND email = ? AND used = 0 AND expires_at > ? ORDER BY created_at DESC LIMIT 1",
        (code, user["email"], now),
    ).fetchone()
    if not row:
        conn.close()
        return None

    conn.execute("UPDATE link_codes SET used = 1 WHERE id = ?", (row["id"],))
    conn.execute("UPDATE users SET discord_id = ? WHERE id = ?", (row["discord_id"], user_id))
    conn.commit()
    conn.close()
    return row["discord_name"]


def get_user_by_discord_id(discord_id: str) -> Optional[dict]:
    conn = get_db()
    user = conn.execute("SELECT * FROM users WHERE discord_id = ?", (discord_id,)).fetchone()
    conn.close()
    return dict(user) if user else None


def get_user_by_github(github_username: str) -> Optional[dict]:
    conn = get_db()
    user = conn.execute("SELECT * FROM users WHERE github_username = ?", (github_username,)).fetchone()
    conn.close()
    return dict(user) if user else None


def link_github(user_id: int, github_username: str) -> bool:
    """Store a GitHub username on the user. Returns False if username already taken."""
    conn = get_db()
    existing = conn.execute(
        "SELECT id FROM users WHERE github_username = ? AND id != ?", (github_username, user_id)
    ).fetchone()
    if existing:
        conn.close()
        return False
    conn.execute("UPDATE users SET github_username = ? WHERE id = ?", (github_username.strip(), user_id))
    conn.commit()
    conn.close()
    return True


# ---------------------------------------------------------------------------
# Leaderboard & Community
# ---------------------------------------------------------------------------

def get_leaderboard(limit: int = 20) -> list[dict]:
    conn = get_db()
    rows = conn.execute(
        "SELECT id, username, display_name, angel_level, interaction_count, discord_id, github_username "
        "FROM users ORDER BY interaction_count DESC LIMIT ?",
        (limit,),
    ).fetchall()
    conn.close()
    return [dict(r) for r in rows]


def get_recent_activity(limit: int = 30) -> list[dict]:
    conn = get_db()
    rows = conn.execute(
        "SELECT a.activity_type, a.description, a.points, a.created_at, u.username, u.display_name "
        "FROM activity_log a JOIN users u ON a.user_id = u.id "
        "ORDER BY a.created_at DESC LIMIT ?",
        (limit,),
    ).fetchall()
    conn.close()
    return [dict(r) for r in rows]


def get_community_stats() -> dict:
    conn = get_db()
    total = conn.execute("SELECT COUNT(*) FROM users").fetchone()[0]
    discord_linked = conn.execute("SELECT COUNT(*) FROM users WHERE discord_id IS NOT NULL").fetchone()[0]
    github_linked = conn.execute("SELECT COUNT(*) FROM users WHERE github_username IS NOT NULL").fetchone()[0]
    total_interactions = conn.execute("SELECT COALESCE(SUM(interaction_count), 0) FROM users").fetchone()[0]
    conn.close()
    return {
        "total_angels": total,
        "discord_linked": discord_linked,
        "github_linked": github_linked,
        "total_interactions": total_interactions,
    }
