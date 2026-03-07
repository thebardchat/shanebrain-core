#!/usr/bin/env python3
"""
Update CLAUDE.md with live Weaviate collection counts.
Run: python scripts/update_claude_md_counts.py
"""

import re
import sys
import os

sys.path.insert(0, os.path.dirname(__file__))
from weaviate_helpers import WeaviateHelper

CLAUDE_MD = os.path.join(os.path.dirname(__file__), "..", "CLAUDE.md")

COLLECTIONS = [
    "LegacyKnowledge", "Conversation", "FriendProfile",
    "SocialKnowledge", "CrisisLog",
    "PersonalDoc", "DailyNote", "PersonalDraft",
    "SecurityLog", "PrivacyAudit",
    "BrainDoc", "BusinessDoc", "Document",
    "DraftTemplate", "MessageLog", "MyBrain",
]


def main():
    with WeaviateHelper() as h:
        if not h.is_ready():
            print("Weaviate not ready")
            sys.exit(1)

        counts = {}
        total = 0
        for name in COLLECTIONS:
            c = h.get_collection_count(name)
            counts[name] = c
            total += c

    # Build the replacement string
    parts = ", ".join(f"{name} ({counts[name]})" for name in COLLECTIONS)
    new_line = f"- Weaviate collections (17 total, ALL use text2vec-ollama + nomic-embed-text, {total} objects): {parts}"

    # Read CLAUDE.md
    with open(CLAUDE_MD, "r") as f:
        content = f.read()

    # Replace the line
    pattern = r"- Weaviate collections \(17 total.*?\):.+"
    if not re.search(pattern, content):
        print("Could not find Weaviate collections line in CLAUDE.md")
        sys.exit(1)

    updated = re.sub(pattern, new_line, content)

    if updated == content:
        print("No changes needed — counts are current")
        return

    with open(CLAUDE_MD, "w") as f:
        f.write(updated)

    print(f"Updated CLAUDE.md — {total} total objects across 17 collections:")
    for name in COLLECTIONS:
        print(f"  {name}: {counts[name]}")


if __name__ == "__main__":
    main()
