"""
ShaneBrain Social Bot — Main entry point.
Facebook automation with Weaviate knowledge harvesting.

Usage:
  python -m social.fb_bot --verify       Check Facebook token
  python -m social.fb_bot --dry-run      Preview a post without publishing
  python -m social.fb_bot --post         Generate and publish one post
  python -m social.fb_bot --post-image   Generate and publish with AI image
  python -m social.fb_bot --harvest      Poll comments and store in Weaviate
  python -m social.fb_bot --ideas        Generate post ideas
  python -m social.fb_bot --status       Show page stats
  python -m social.fb_bot --friends      Show top friend profiles
  python -m social.fb_bot               Start scheduler (default)
"""

import sys
import os
import signal
from datetime import datetime

from . import config
from .facebook_api import FacebookAPI
from .content_generator import ContentGenerator
from .content_calendar import get_todays_theme, get_weekly_preview
from .comment_harvester import harvest_comments
from .friend_profiler import show_friends

# Colors
GREEN = '\033[92m'
RED = '\033[91m'
YELLOW = '\033[93m'
BLUE = '\033[94m'
CYAN = '\033[96m'
DIM = '\033[2m'
RESET = '\033[0m'

# Log file
LOG_FILE = config.LOGS_DIR / "posts.log"


def log(msg, level="info"):
    prefix = {
        "info": f"{CYAN}[INFO]{RESET}",
        "success": f"{GREEN}[OK]{RESET}",
        "warn": f"{YELLOW}[WARN]{RESET}",
        "error": f"{RED}[ERROR]{RESET}",
    }
    print(f"{prefix.get(level, '')} {msg}")


def log_to_file(content, status="POSTED", error=None):
    """Append to posts.log."""
    timestamp = datetime.now().isoformat()
    entry = f"[{timestamp}] [{status}]\n{content}\n"
    if error:
        entry += f"Error: {error}\n"
    entry += "─" * 50 + "\n"
    with open(LOG_FILE, "a") as f:
        f.write(entry)


def banner():
    print(f"\n{CYAN}╔══════════════════════════════════════╗{RESET}")
    print(f"{CYAN}║{RESET}  {GREEN}ShaneBrain Social Bot{RESET} v1.0.0       {CYAN}║{RESET}")
    print(f"{CYAN}║{RESET}  {DIM}Facebook + Weaviate knowledge{RESET}       {CYAN}║{RESET}")
    print(f"{CYAN}╚══════════════════════════════════════╝{RESET}\n")


def cmd_verify():
    """Check if the Facebook token is valid."""
    log("Verifying Facebook token...")
    fb = FacebookAPI()
    result = fb.verify_token()
    if result["valid"]:
        log(f"Token valid! Connected as: {result['name']} (ID: {result['id']})", "success")
    else:
        log(f"Token invalid: {result.get('error', 'unknown')}", "error")
        log("Run: python -m social.token_exchange YOUR_SHORT_LIVED_TOKEN", "info")


def cmd_dry_run():
    """Generate a post and show it without publishing."""
    gen = ContentGenerator()
    theme = get_todays_theme()

    log(f"Today's theme: {theme['theme']} ({theme['mood']})")
    log("Generating content...")

    content = gen.generate_post()

    print(f"\n{GREEN}Generated post:{RESET}")
    print("─" * 50)
    print(content)
    print("─" * 50)
    print(f"Characters: {len(content)}")
    print()

    log("DRY RUN — Post was NOT published", "warn")
    log_to_file(content, status="DRY-RUN")


def cmd_post(with_image=False):
    """Generate and publish a post."""
    fb = FacebookAPI()
    gen = ContentGenerator()
    theme = get_todays_theme()

    log(f"Today's theme: {theme['theme']} ({theme['mood']})")
    log("Generating content...")

    content = gen.generate_post()

    print(f"\n{GREEN}Generated post:{RESET}")
    print("─" * 50)
    print(content)
    print("─" * 50)

    log("Publishing to Facebook...")

    try:
        if with_image:
            image_url = gen.generate_image_url(content)
            log(f"Image: {image_url}", "info")
            result = fb.post_with_image(content, image_url)
        else:
            result = fb.post(content)

        log(f"Post published! ID: {result['post_id']}", "success")
        log_to_file(content, status="POSTED")
    except Exception as e:
        log(f"Failed to post: {e}", "error")
        log_to_file(content, status="FAILED", error=str(e))


def cmd_harvest():
    """Poll comments and store in Weaviate."""
    harvest_comments(auto_reply=False, verbose=True)


def cmd_ideas():
    """Generate post ideas."""
    gen = ContentGenerator()
    log("Generating post ideas...")
    ideas = gen.generate_ideas(5)
    print(f"\n{GREEN}Post Ideas:{RESET}")
    print(ideas)
    print()


def cmd_status():
    """Show page status and recent post stats."""
    fb = FacebookAPI()
    theme = get_todays_theme()

    print(f"\n{BLUE}{'='*50}{RESET}")
    print(f"{BLUE}  ShaneBrain Social — Status{RESET}")
    print(f"{BLUE}{'='*50}{RESET}\n")

    # Token status
    result = fb.verify_token()
    if result["valid"]:
        print(f"  Page: {GREEN}{result['name']}{RESET}")
    else:
        print(f"  Token: {RED}INVALID{RESET}")

    # Today's theme
    print(f"  Today: {theme['theme']} ({theme['mood']})")
    print(f"  Schedule: {config.FACEBOOK_POST_SCHEDULE}")
    print(f"  Comment poll: every {config.FACEBOOK_COMMENT_POLL_MINUTES} min")

    # Recent posts
    print(f"\n  {BLUE}Recent Posts:{RESET}")
    try:
        posts = fb.get_recent_posts(limit=5)
        for post in posts:
            msg = post.get("message", "(no text)")[:50]
            created = post.get("created_time", "?")[:10]
            post_id = post.get("id", "?")
            try:
                engagement = fb.get_post_engagement(post_id)
                stats = f"👍{engagement['likes']} 💬{engagement['comments']} 🔄{engagement['shares']}"
            except Exception:
                stats = ""
            print(f"    [{created}] {msg}  {stats}")
    except Exception as e:
        print(f"    {RED}Failed to get posts: {e}{RESET}")

    # Weekly calendar
    print(f"\n  {BLUE}Weekly Calendar:{RESET}")
    print(get_weekly_preview())

    # Weaviate stats
    try:
        from scripts.weaviate_helpers import WeaviateHelper
        with WeaviateHelper() as wv:
            social_count = wv.get_collection_count("SocialKnowledge")
            friend_count = wv.get_collection_count("FriendProfile")
            print(f"\n  {BLUE}Weaviate:{RESET}")
            print(f"    Social interactions: {social_count}")
            print(f"    Friend profiles: {friend_count}")
    except Exception:
        pass

    print(f"\n{BLUE}{'='*50}{RESET}\n")


def cmd_scheduler():
    """Run the scheduler with cron-based posting and comment harvesting."""
    from apscheduler.schedulers.blocking import BlockingScheduler
    from apscheduler.triggers.cron import CronTrigger
    from apscheduler.triggers.interval import IntervalTrigger

    scheduler = BlockingScheduler()

    # Parse cron schedule (minute hour day month dow)
    cron_parts = config.FACEBOOK_POST_SCHEDULE.split()
    if len(cron_parts) == 5:
        trigger = CronTrigger(
            minute=cron_parts[0],
            hour=cron_parts[1],
            day=cron_parts[2],
            month=cron_parts[3],
            day_of_week=cron_parts[4],
        )
    else:
        log(f"Invalid cron schedule: {config.FACEBOOK_POST_SCHEDULE}", "error")
        sys.exit(1)

    # Add posting job
    def scheduled_post():
        log("Scheduled post triggered...")
        try:
            fb = FacebookAPI()
            gen = ContentGenerator()
            content = gen.generate_post()
            log(f'Generated: "{content[:50]}..."')
            result = fb.post(content)
            log(f"Posted! ID: {result['post_id']}", "success")
            log_to_file(content, status="POSTED")
        except Exception as e:
            log(f"Failed: {e}", "error")
            log_to_file("(generation/post failed)", status="FAILED", error=str(e))

    scheduler.add_job(scheduled_post, trigger, id="post")

    # Add comment harvesting job
    def scheduled_harvest():
        harvest_comments(auto_reply=False, verbose=False)

    scheduler.add_job(
        scheduled_harvest,
        IntervalTrigger(minutes=config.FACEBOOK_COMMENT_POLL_MINUTES),
        id="harvest",
    )

    log(f"Scheduler started.", "success")
    log(f"  Post schedule: {config.FACEBOOK_POST_SCHEDULE}")
    log(f"  Comment poll: every {config.FACEBOOK_COMMENT_POLL_MINUTES} min")
    log("Press Ctrl+C to stop.", "warn")

    # Graceful shutdown
    def shutdown(signum, frame):
        log("\nShutting down scheduler...", "warn")
        scheduler.shutdown(wait=False)
        sys.exit(0)

    signal.signal(signal.SIGINT, shutdown)
    signal.signal(signal.SIGTERM, shutdown)

    try:
        scheduler.start()
    except (KeyboardInterrupt, SystemExit):
        pass


def main():
    banner()

    args = sys.argv[1:]

    if "--verify" in args:
        cmd_verify()
    elif "--dry-run" in args:
        cmd_dry_run()
    elif "--post-image" in args:
        cmd_post(with_image=True)
    elif "--post" in args:
        cmd_post()
    elif "--harvest" in args:
        cmd_harvest()
    elif "--ideas" in args:
        cmd_ideas()
    elif "--status" in args:
        cmd_status()
    elif "--friends" in args:
        show_friends()
    elif args:
        print(f"Unknown argument: {args[0]}")
        print(__doc__)
    else:
        # Default: run scheduler
        cmd_scheduler()


if __name__ == "__main__":
    main()
