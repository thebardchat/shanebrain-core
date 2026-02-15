#!/usr/bin/env python3
"""
RAG.md Importer for ShaneBrain Core
Parses RAG.md and imports chunks into Weaviate's LegacyKnowledge class.
Compatible with weaviate-client v4.
"""

import weaviate
from weaviate.classes.query import Filter
import re
import sys
from pathlib import Path
from datetime import datetime, timezone

# Colors for terminal output
GREEN = '\033[92m'
RED = '\033[91m'
YELLOW = '\033[93m'
BLUE = '\033[94m'
RESET = '\033[0m'


def parse_rag_file(filepath):
    """Parse RAG.md into chunks by ## headers."""
    print(f"{BLUE}Parsing {filepath}...{RESET}")

    try:
        content = Path(filepath).read_text(encoding='utf-8')
    except FileNotFoundError:
        print(f"{RED}✗ File not found: {filepath}{RESET}")
        return []
    except Exception as e:
        print(f"{RED}✗ Error reading file: {e}{RESET}")
        return []

    # Split by ## headers (keeping the header with content)
    sections = re.split(r'\n(?=## )', content)
    chunks = []

    for section in sections:
        section = section.strip()
        if not section:
            continue

        # Skip if it's just the main title (# RAG)
        if section.startswith('# ') and not section.startswith('## '):
            # Check if there's content after the title
            lines = section.split('\n', 1)
            if len(lines) > 1:
                section = lines[1].strip()
            else:
                continue

        # Handle ## headers
        if section.startswith('## '):
            lines = section.split('\n', 1)
            header = lines[0].replace('## ', '').strip()
            body = lines[1].strip() if len(lines) > 1 else ''
        else:
            # Content without a ## header
            header = "General"
            body = section

        if not body:
            continue

        # Categorize based on header keywords
        header_lower = header.lower()
        if any(word in header_lower for word in ['family', 'sons', 'wife', 'tiffany', 'kids', 'children', 'parent']):
            category = 'family'
        elif any(word in header_lower for word in ['faith', 'god', 'christian', 'church', 'prayer', 'spiritual', 'jesus']):
            category = 'faith'
        elif any(word in header_lower for word in ['technical', 'code', 'project', 'tools', 'programming', 'software', 'developer']):
            category = 'technical'
        elif any(word in header_lower for word in ['philosophy', 'message', 'mission', 'vision', 'purpose', 'values', 'believe']):
            category = 'philosophy'
        elif any(word in header_lower for word in ['health', 'wellness', 'mental', 'anxiety', 'depression']):
            category = 'wellness'
        else:
            category = 'general'

        chunks.append({
            'content': body,
            'category': category,
            'source': 'RAG.md',
            'title': header
        })

    print(f"{GREEN}✓ Found {len(chunks)} chunks{RESET}")
    return chunks


def import_to_weaviate(chunks, clear_existing=False):
    """Import chunks into LegacyKnowledge class."""
    print(f"\n{BLUE}Connecting to Weaviate...{RESET}")

    try:
        client = weaviate.connect_to_local()
    except Exception as e:
        print(f"{RED}✗ Could not connect to Weaviate: {e}{RESET}")
        return 0

    try:
        if not client.is_ready():
            print(f"{RED}✗ Weaviate is not ready{RESET}")
            return 0

        print(f"{GREEN}✓ Connected to Weaviate{RESET}")

        # Check if LegacyKnowledge class exists
        if not client.collections.exists("LegacyKnowledge"):
            print(f"{RED}✗ LegacyKnowledge class not found. Run setup_weaviate_schema.py first.{RESET}")
            return 0

        collection = client.collections.get("LegacyKnowledge")

        # Optionally clear existing data from RAG.md
        if clear_existing:
            print(f"{YELLOW}Clearing existing RAG.md entries...{RESET}")
            try:
                collection.data.delete_many(
                    where=Filter.by_property("source").equal("RAG.md")
                )
                print(f"{GREEN}✓ Cleared existing entries{RESET}")
            except Exception as e:
                print(f"{YELLOW}Note: Could not clear existing entries: {e}{RESET}")

        print(f"\n{BLUE}Importing {len(chunks)} chunks...{RESET}\n")

        imported = 0
        for chunk in chunks:
            try:
                collection.data.insert(chunk)
                imported += 1
                # Truncate content for display
                content_preview = chunk['content'][:50].replace('\n', ' ')
                if len(chunk['content']) > 50:
                    content_preview += "..."
                print(f"{GREEN}✓{RESET} [{chunk['category']:10}] {chunk['title'][:30]}")
            except Exception as e:
                print(f"{RED}✗{RESET} Error importing '{chunk['title']}': {e}")

        return imported

    finally:
        client.close()


def verify_import():
    """Query to verify data was imported."""
    print(f"\n{BLUE}=== Verifying Import ==={RESET}\n")

    try:
        client = weaviate.connect_to_local()
    except Exception as e:
        print(f"{RED}✗ Could not connect to Weaviate: {e}{RESET}")
        return

    try:
        if not client.collections.exists("LegacyKnowledge"):
            print(f"{RED}✗ LegacyKnowledge class not found{RESET}")
            return

        collection = client.collections.get("LegacyKnowledge")

        # Get total count
        response = collection.aggregate.over_all(total_count=True)
        total = response.total_count
        print(f"Total LegacyKnowledge records: {total}")

        # Get count by source
        rag_response = collection.query.fetch_objects(
            filters=Filter.by_property("source").equal("RAG.md"),
            limit=1000
        )
        rag_count = len(rag_response.objects)
        print(f"Records from RAG.md: {rag_count}")

        # Show category breakdown
        print(f"\n{BLUE}Category breakdown:{RESET}")
        categories = {}
        for obj in rag_response.objects:
            cat = obj.properties.get('category', 'unknown')
            categories[cat] = categories.get(cat, 0) + 1
        for cat, count in sorted(categories.items()):
            print(f"  {cat}: {count}")

        # Show sample records
        print(f"\n{BLUE}Sample records:{RESET}")
        sample = collection.query.fetch_objects(limit=3)
        for obj in sample.objects:
            title = obj.properties.get('title', 'Untitled')[:40]
            cat = obj.properties.get('category', 'unknown')
            print(f"  [{cat}] {title}")

    finally:
        client.close()


def main():
    print(f"\n{BLUE}{'='*60}{RESET}")
    print(f"{BLUE}     ShaneBrain Core - RAG.md Importer{RESET}")
    print(f"{BLUE}{'='*60}{RESET}\n")

    # Parse arguments
    rag_path = sys.argv[1] if len(sys.argv) > 1 else "RAG.md"
    clear_existing = "--clear" in sys.argv or "-c" in sys.argv

    if clear_existing:
        print(f"{YELLOW}Note: Will clear existing RAG.md entries before import{RESET}\n")

    # Parse the file
    chunks = parse_rag_file(rag_path)
    if not chunks:
        print(f"{RED}No chunks to import{RESET}")
        return 1

    # Import to Weaviate
    imported = import_to_weaviate(chunks, clear_existing=clear_existing)

    print(f"\n{BLUE}{'='*60}{RESET}")
    print(f"Imported {imported}/{len(chunks)} chunks")
    print(f"{BLUE}{'='*60}{RESET}")

    # Verify
    if imported > 0:
        verify_import()

    return 0 if imported == len(chunks) else 1


if __name__ == "__main__":
    sys.exit(main())
