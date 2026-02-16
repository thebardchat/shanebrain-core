#!/usr/bin/env python3
"""
GitHub Poller — Polls GitHub for commits and PRs, awards Angel Cloud points.
Runs via systemd timer every 15 minutes.
Uses `gh api` CLI (requires gh auth login on the Pi).
"""

import json
import os
import subprocess
import sys
from datetime import datetime, timezone

# Ensure angel-cloud modules are importable
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import models

STATE_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "github_poller_state.json")
REPOS = ["shanebrain-core", "angel-cloud", "pulsar_sentinel"]
ORG = "thebardchat"


def load_state() -> dict:
    try:
        with open(STATE_FILE, "r") as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def save_state(state: dict):
    with open(STATE_FILE, "w") as f:
        json.dump(state, f, indent=2)


def gh_api(endpoint: str) -> list:
    """Call gh api and return parsed JSON."""
    try:
        result = subprocess.run(
            ["gh", "api", endpoint, "--paginate"],
            capture_output=True, text=True, timeout=30,
        )
        if result.returncode != 0:
            print(f"[POLLER] gh api error for {endpoint}: {result.stderr[:200]}")
            return []
        return json.loads(result.stdout) if result.stdout.strip() else []
    except subprocess.TimeoutExpired:
        print(f"[POLLER] gh api timeout for {endpoint}")
        return []
    except json.JSONDecodeError:
        print(f"[POLLER] gh api invalid JSON for {endpoint}")
        return []


def poll_commits(repo: str, since: str) -> int:
    """Poll commits and award points. Returns number of points awarded."""
    endpoint = f"repos/{ORG}/{repo}/commits?since={since}&per_page=100"
    commits = gh_api(endpoint)
    if not isinstance(commits, list):
        return 0

    total_points = 0
    for commit in commits:
        author_login = ""
        if commit.get("author"):
            author_login = commit["author"].get("login", "")
        if not author_login:
            continue

        user = models.get_user_by_github(author_login)
        if not user:
            continue

        sha_short = commit.get("sha", "")[:7]
        msg = commit.get("commit", {}).get("message", "").split("\n")[0][:60]
        desc = f"Commit {sha_short} in {repo}: {msg}"

        models.add_interaction_points(user["id"], 3, "github_commit", desc)
        models.check_level_up(user["id"])
        total_points += 3
        print(f"[POLLER] +3 pts to {user['username']}: {desc}")

    return total_points


def poll_prs(repo: str, since: str) -> int:
    """Poll PRs and award points. Returns number of points awarded."""
    endpoint = f"repos/{ORG}/{repo}/pulls?state=all&sort=updated&direction=desc&per_page=50"
    prs = gh_api(endpoint)
    if not isinstance(prs, list):
        return 0

    total_points = 0
    for pr in prs:
        updated = pr.get("updated_at", "")
        if updated < since:
            continue

        author_login = ""
        if pr.get("user"):
            author_login = pr["user"].get("login", "")
        if not author_login:
            continue

        user = models.get_user_by_github(author_login)
        if not user:
            continue

        pr_num = pr.get("number", "?")
        title = pr.get("title", "")[:50]
        merged = pr.get("merged_at")
        created = pr.get("created_at", "")

        # Merged PR: 5 points (only if merged since last poll)
        if merged and merged >= since:
            desc = f"Merged PR #{pr_num} in {repo}: {title}"
            models.add_interaction_points(user["id"], 5, "github_pr_merged", desc)
            models.check_level_up(user["id"])
            total_points += 5
            print(f"[POLLER] +5 pts to {user['username']}: {desc}")
        # Opened PR: 2 points (only if created since last poll)
        elif created >= since and not merged:
            desc = f"Opened PR #{pr_num} in {repo}: {title}"
            models.add_interaction_points(user["id"], 2, "github_pr", desc)
            models.check_level_up(user["id"])
            total_points += 2
            print(f"[POLLER] +2 pts to {user['username']}: {desc}")

    return total_points


def main():
    models.init_db()
    state = load_state()
    last_poll = state.get("last_poll", "2026-01-01T00:00:00Z")
    now = datetime.now(timezone.utc).isoformat()

    print(f"[POLLER] Polling since {last_poll}")
    total = 0

    for repo in REPOS:
        total += poll_commits(repo, last_poll)
        total += poll_prs(repo, last_poll)

    state["last_poll"] = now
    save_state(state)
    print(f"[POLLER] Done. Awarded {total} total points.")


if __name__ == "__main__":
    main()
