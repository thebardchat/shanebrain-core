"""
Angel Cloud User Models — SQLite storage for user accounts and angel progression.
"""

import sqlite3
import bcrypt
import os
from datetime import datetime, timezone
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
