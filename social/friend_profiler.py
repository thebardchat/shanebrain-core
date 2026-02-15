"""
Friend Profiler for ShaneBrain Social Bot.
Builds and maintains living profiles of people who interact on Facebook.
Regenerates AI summaries periodically.
"""

from scripts.weaviate_helpers import WeaviateHelper
from .content_generator import ContentGenerator

# Colors
GREEN = '\033[92m'
BLUE = '\033[94m'
DIM = '\033[2m'
RESET = '\033[0m'

# Regenerate summary every N interactions
SUMMARY_REGEN_INTERVAL = 10


def regenerate_summary(wv, gen, facebook_id):
    """
    Regenerate the AI summary for a friend profile based on their interactions.

    Args:
        wv: WeaviateHelper instance
        gen: ContentGenerator instance
        facebook_id: Facebook user ID
    """
    profile = wv.get_friend_profile(facebook_id)
    if not profile:
        return

    # Get recent interactions from this person
    interactions = wv.get_interactions_by_author(facebook_id, limit=20)

    if not interactions:
        return

    name = profile.get("name", "Unknown")
    topics = profile.get("topics_discussed", [])
    sentiment = profile.get("sentiment_profile", "neutral")
    count = profile.get("interaction_count", 0)

    # Build context from recent interactions
    recent_comments = []
    for ix in interactions[:10]:
        msg = ix.get("content", "")
        if msg:
            recent_comments.append(msg)

    comments_text = "\n".join(f"- {c[:100]}" for c in recent_comments)
    topics_text = ", ".join(topics[:10]) if topics else "various"

    prompt = (
        f"Write a brief 2-3 sentence profile summary of {name}, who has interacted "
        f"with our Facebook page {count} times. Their overall sentiment is {sentiment}. "
        f"Topics they engage with: {topics_text}.\n\n"
        f"Recent comments:\n{comments_text}\n\n"
        f"Write a warm, human summary of who this person seems to be and how they "
        f"connect with our content. Just the summary, nothing else."
    )

    try:
        summary = gen._ollama_generate(prompt, temperature=0.6)
        wv.upsert_friend_profile(
            name=name,
            facebook_id=facebook_id,
            sentiment=sentiment,
            topics=topics,
            summary=summary,
        )
    except Exception as e:
        print(f"Failed to regenerate summary for {name}: {e}")


def should_regenerate(profile):
    """Check if a profile's summary should be regenerated."""
    count = profile.get("interaction_count", 0)
    return count > 0 and count % SUMMARY_REGEN_INTERVAL == 0


def show_friends(limit=10):
    """Display top friends by relationship strength."""
    print(f"\n{BLUE}{'='*50}{RESET}")
    print(f"{BLUE}  ShaneBrain Social — Top Friends{RESET}")
    print(f"{BLUE}{'='*50}{RESET}\n")

    with WeaviateHelper() as wv:
        friends = wv.get_top_friends(limit=limit)

        if not friends:
            print("  No friend profiles yet. Run --harvest first.\n")
            return

        for i, friend in enumerate(friends, 1):
            name = friend.get("name", "Unknown")
            count = friend.get("interaction_count", 0)
            strength = friend.get("relationship_strength", 0)
            sentiment = friend.get("sentiment_profile", "?")
            topics = friend.get("topics_discussed", [])
            summary = friend.get("summary", "")

            bar_len = int(strength * 20)
            bar = f"{'█' * bar_len}{'░' * (20 - bar_len)}"

            print(f"  {GREEN}{i}. {name}{RESET}")
            print(f"     Interactions: {count} | Sentiment: {sentiment}")
            print(f"     Strength: [{bar}] {strength:.2f}")
            if topics:
                print(f"     Topics: {', '.join(topics[:5])}")
            if summary:
                print(f"     {DIM}{summary[:100]}{RESET}")
            print()

    print(f"{BLUE}{'='*50}{RESET}\n")
