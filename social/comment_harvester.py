"""
Comment Harvester for ShaneBrain Social Bot.
Polls Facebook comments, analyzes sentiment, stores in Weaviate,
updates friend profiles, and optionally auto-replies.
"""

import json
from datetime import datetime, timezone
from pathlib import Path
from scripts.weaviate_helpers import WeaviateHelper
from .facebook_api import FacebookAPI
from .content_generator import ContentGenerator
from . import config

# Colors
GREEN = '\033[92m'
RED = '\033[91m'
YELLOW = '\033[93m'
BLUE = '\033[94m'
DIM = '\033[2m'
RESET = '\033[0m'

# Persist seen comment IDs to avoid reprocessing
SEEN_FILE = config.LOGS_DIR / "seen_comments.json"


def _load_seen():
    """Load set of already-processed comment IDs."""
    if SEEN_FILE.exists():
        try:
            return set(json.loads(SEEN_FILE.read_text()))
        except Exception:
            return set()
    return set()


def _save_seen(seen):
    """Persist seen comment IDs."""
    SEEN_FILE.write_text(json.dumps(list(seen)))


def harvest_comments(auto_reply=False, max_posts=10, verbose=True):
    """
    Poll recent posts for new comments, analyze and store them.

    Args:
        auto_reply: Whether to auto-reply to new comments
        max_posts: How many recent posts to check
        verbose: Print progress to terminal

    Returns:
        Dict with counts: {new_comments, stored, replied, errors}
    """
    fb = FacebookAPI()
    gen = ContentGenerator()
    seen = _load_seen()
    stats = {"new_comments": 0, "stored": 0, "replied": 0, "errors": 0}

    if verbose:
        print(f"{BLUE}[HARVEST] Checking recent posts for new comments...{RESET}")

    try:
        posts = fb.get_recent_posts(limit=max_posts)
    except Exception as e:
        if verbose:
            print(f"{RED}[ERROR] Failed to get posts: {e}{RESET}")
        return stats

    with WeaviateHelper() as wv:
        for post in posts:
            post_id = post.get("id", "")
            if not post_id:
                continue

            try:
                comments = fb.get_post_comments(post_id)
            except Exception as e:
                if verbose:
                    print(f"{YELLOW}[WARN] Failed to get comments for {post_id}: {e}{RESET}")
                stats["errors"] += 1
                continue

            for comment in comments:
                comment_id = comment.get("id", "")
                if not comment_id or comment_id in seen:
                    continue

                stats["new_comments"] += 1
                seen.add(comment_id)

                # Extract comment data
                author = comment.get("from", {})
                author_name = author.get("name", "Unknown")
                author_id = author.get("id", "unknown")
                message = comment.get("message", "")
                created_time = comment.get("created_time", "")

                if not message:
                    continue

                if verbose:
                    print(f"{DIM}  [{author_name}] {message[:60]}...{RESET}")

                # Analyze sentiment
                sentiment = gen.analyze_sentiment(message)

                # Extract topics for profiling
                topics = gen.extract_topics(message)

                # Parse timestamp
                ts = None
                if created_time:
                    try:
                        ts = datetime.fromisoformat(created_time.replace("+0000", "+00:00"))
                    except Exception:
                        ts = datetime.now(timezone.utc)

                # Store in Weaviate SocialKnowledge
                try:
                    wv.log_social_interaction(
                        content=message,
                        author_name=author_name,
                        author_id=author_id,
                        interaction_type="comment",
                        source_post_id=post_id,
                        sentiment=sentiment,
                        context=f"Comment on post {post_id}",
                        relationship_tags=[],
                        knowledge_extracted="",
                        timestamp=ts,
                    )
                    stats["stored"] += 1
                except Exception as e:
                    if verbose:
                        print(f"{RED}  [ERROR] Weaviate store failed: {e}{RESET}")
                    stats["errors"] += 1

                # Update friend profile
                try:
                    wv.upsert_friend_profile(
                        name=author_name,
                        facebook_id=author_id,
                        sentiment=sentiment,
                        topics=topics,
                    )
                except Exception as e:
                    if verbose:
                        print(f"{YELLOW}  [WARN] Profile update failed: {e}{RESET}")

                # Auto-reply if enabled
                if auto_reply:
                    try:
                        reply = gen.generate_reply(message, author_name)
                        fb.reply_to_comment(comment_id, reply)
                        stats["replied"] += 1
                        if verbose:
                            print(f"{GREEN}  [REPLY] -> {reply[:60]}{RESET}")
                    except Exception as e:
                        if verbose:
                            print(f"{YELLOW}  [WARN] Reply failed: {e}{RESET}")

    _save_seen(seen)

    if verbose:
        print(f"\n{BLUE}[HARVEST] Done.{RESET}")
        print(f"  New comments: {stats['new_comments']}")
        print(f"  Stored in Weaviate: {stats['stored']}")
        print(f"  Replies sent: {stats['replied']}")
        print(f"  Errors: {stats['errors']}")

    return stats
