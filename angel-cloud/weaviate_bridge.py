"""
Weaviate Bridge — Creates FriendProfile entries for new Angel Cloud users.
Uses the existing WeaviateHelper from shanebrain-core.
"""

import sys
import os
from datetime import datetime, timezone

# Add parent dir so we can import from scripts/
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from scripts.weaviate_helpers import WeaviateHelper


def register_user_in_weaviate(username: str, email: str) -> bool:
    """Create a FriendProfile in Weaviate for a newly registered user."""
    try:
        with WeaviateHelper() as helper:
            if not helper.is_ready():
                print("Weaviate not ready, skipping profile creation")
                return False

            if not helper.client.collections.exists("FriendProfile"):
                print("FriendProfile collection not found")
                return False

            collection = helper.client.collections.get("FriendProfile")
            now = datetime.now(timezone.utc)

            data = {
                "name": username,
                "facebook_id": f"angel-cloud:{email}",
                "interaction_count": 0,
                "first_seen": now.isoformat(),
                "last_seen": now.isoformat(),
                "sentiment_profile": "positive",
                "topics_discussed": ["angel-cloud", "newborn"],
                "relationship_strength": 0.05,
                "summary": f"Angel Cloud Newborn: {username}. Registered via the gateway.",
            }

            collection.data.insert(data)

            # Log the registration event
            helper.log_conversation(
                message=f"New Angel Cloud user registered: {username} ({email})",
                role="system",
                mode="CHAT",
            )

            return True
    except Exception as e:
        print(f"Weaviate bridge error: {e}")
        return False


def get_weaviate_stats() -> dict:
    """Get collection counts for the stats endpoint."""
    stats = {}
    try:
        with WeaviateHelper() as helper:
            if not helper.is_ready():
                return {"weaviate": "offline"}
            for name in ["LegacyKnowledge", "Conversation", "SocialKnowledge", "FriendProfile", "CrisisLog"]:
                stats[name] = helper.get_collection_count(name)
            stats["weaviate"] = "online"
    except Exception:
        stats["weaviate"] = "offline"
    return stats
