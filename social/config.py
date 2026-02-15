"""
Configuration loader for ShaneBrain Social Bot.
Loads Facebook credentials and settings from the root .env file.
"""

import os
from pathlib import Path
from dotenv import load_dotenv

# Load .env from shanebrain-core root
_env_path = Path(__file__).resolve().parent.parent / ".env"
load_dotenv(_env_path)


def _require(key):
    """Get a required env var or raise."""
    val = os.getenv(key)
    if not val:
        raise RuntimeError(f"Missing required env var: {key} (check {_env_path})")
    return val


# Facebook credentials
FACEBOOK_PAGE_ID = _require("FACEBOOK_PAGE_ID")
FACEBOOK_ACCESS_TOKEN = _require("FACEBOOK_ACCESS_TOKEN")
FB_APP_ID = os.getenv("FB_APP_ID", "")
FB_APP_SECRET = os.getenv("FB_APP_SECRET", "")
FACEBOOK_API_VERSION = os.getenv("FACEBOOK_API_VERSION", "v21.0")

# Scheduling
FACEBOOK_POST_SCHEDULE = os.getenv("FACEBOOK_POST_SCHEDULE", "0 9,14,19 * * *")
FACEBOOK_COMMENT_POLL_MINUTES = int(os.getenv("FACEBOOK_COMMENT_POLL_MINUTES", "15"))

# Personality
PAGE_PERSONALITY = os.getenv(
    "PAGE_PERSONALITY",
    "Shane Brazelton - a dad sharing real talk about family and building AI"
)

# Ollama
OLLAMA_HOST = os.getenv("OLLAMA_HOST", "http://localhost:11434")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "llama3.2:1b")

# Paths
SHANEBRAIN_ROOT = Path(__file__).resolve().parent.parent
LOGS_DIR = Path(__file__).resolve().parent / "logs"
LOGS_DIR.mkdir(exist_ok=True)

# Graph API base
GRAPH_API_BASE = f"https://graph.facebook.com/{FACEBOOK_API_VERSION}"
