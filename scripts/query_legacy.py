#!/usr/bin/env python3
"""
Legacy Knowledge Query CLI for ShaneBrain Core
Interactive CLI to query the LegacyKnowledge collection in Weaviate.
Compatible with weaviate-client v4.
"""

import weaviate
from weaviate.classes.query import Filter, MetadataQuery
import sys
import argparse

# Colors for terminal output
GREEN = '\033[92m'
RED = '\033[91m'
YELLOW = '\033[93m'
BLUE = '\033[94m'
CYAN = '\033[96m'
BOLD = '\033[1m'
RESET = '\033[0m'


def connect():
    """Connect to Weaviate."""
    try:
        client = weaviate.connect_to_local()
        if not client.is_ready():
            print(f"{RED}✗ Weaviate is not ready{RESET}")
            return None
        return client
    except Exception as e:
        print(f"{RED}✗ Could not connect to Weaviate: {e}{RESET}")
        return None


def semantic_search(client, query, limit=5):
    """Perform semantic (vector) search on LegacyKnowledge."""
    if not client.collections.exists("LegacyKnowledge"):
        print(f"{RED}✗ LegacyKnowledge class not found{RESET}")
        return []

    collection = client.collections.get("LegacyKnowledge")

    try:
        response = collection.query.near_text(
            query=query,
            limit=limit,
            return_metadata=MetadataQuery(distance=True)
        )
        return response.objects
    except Exception as e:
        print(f"{RED}✗ Search error: {e}{RESET}")
        return []


def keyword_search(client, keyword, limit=10):
    """Search for keyword in content."""
    if not client.collections.exists("LegacyKnowledge"):
        print(f"{RED}✗ LegacyKnowledge class not found{RESET}")
        return []

    collection = client.collections.get("LegacyKnowledge")

    try:
        response = collection.query.bm25(
            query=keyword,
            limit=limit
        )
        return response.objects
    except Exception as e:
        print(f"{RED}✗ Search error: {e}{RESET}")
        return []


def filter_by_category(client, category, limit=10):
    """Get all entries in a specific category."""
    if not client.collections.exists("LegacyKnowledge"):
        print(f"{RED}✗ LegacyKnowledge class not found{RESET}")
        return []

    collection = client.collections.get("LegacyKnowledge")

    try:
        response = collection.query.fetch_objects(
            filters=Filter.by_property("category").equal(category),
            limit=limit
        )
        return response.objects
    except Exception as e:
        print(f"{RED}✗ Filter error: {e}{RESET}")
        return []


def list_all(client, limit=20):
    """List all entries."""
    if not client.collections.exists("LegacyKnowledge"):
        print(f"{RED}✗ LegacyKnowledge class not found{RESET}")
        return []

    collection = client.collections.get("LegacyKnowledge")

    try:
        response = collection.query.fetch_objects(limit=limit)
        return response.objects
    except Exception as e:
        print(f"{RED}✗ Error: {e}{RESET}")
        return []


def get_categories(client):
    """Get all unique categories."""
    if not client.collections.exists("LegacyKnowledge"):
        return []

    collection = client.collections.get("LegacyKnowledge")

    try:
        response = collection.query.fetch_objects(limit=1000)
        categories = set()
        for obj in response.objects:
            cat = obj.properties.get('category')
            if cat:
                categories.add(cat)
        return sorted(categories)
    except:
        return []


def display_results(results, show_full=False):
    """Display search results."""
    if not results:
        print(f"{YELLOW}No results found{RESET}")
        return

    print(f"\n{BLUE}Found {len(results)} results:{RESET}\n")

    for i, obj in enumerate(results, 1):
        props = obj.properties
        title = props.get('title', 'Untitled')
        category = props.get('category', 'unknown')
        content = props.get('content', '')
        source = props.get('source', 'unknown')

        # Get distance if available
        distance = ""
        if hasattr(obj, 'metadata') and obj.metadata and hasattr(obj.metadata, 'distance'):
            dist_val = obj.metadata.distance
            if dist_val is not None:
                distance = f" (distance: {dist_val:.4f})"

        print(f"{BOLD}{CYAN}[{i}] {title}{RESET}{distance}")
        print(f"    {YELLOW}Category:{RESET} {category} | {YELLOW}Source:{RESET} {source}")

        if show_full:
            print(f"    {YELLOW}Content:{RESET}")
            # Indent content
            for line in content.split('\n'):
                print(f"      {line}")
        else:
            # Show preview
            preview = content[:200].replace('\n', ' ')
            if len(content) > 200:
                preview += "..."
            print(f"    {preview}")
        print()


def interactive_mode(client):
    """Run interactive query session."""
    print(f"\n{BLUE}{'='*60}{RESET}")
    print(f"{BLUE}     ShaneBrain Legacy Knowledge Query{RESET}")
    print(f"{BLUE}{'='*60}{RESET}")
    print(f"\n{CYAN}Commands:{RESET}")
    print(f"  {BOLD}search <query>{RESET}  - Semantic search")
    print(f"  {BOLD}keyword <word>{RESET}  - Keyword/BM25 search")
    print(f"  {BOLD}category <cat>{RESET}  - Filter by category")
    print(f"  {BOLD}categories{RESET}      - List all categories")
    print(f"  {BOLD}list{RESET}            - List all entries")
    print(f"  {BOLD}full{RESET}            - Toggle full content display")
    print(f"  {BOLD}help{RESET}            - Show this help")
    print(f"  {BOLD}quit{RESET}            - Exit")
    print()

    show_full = False
    categories = get_categories(client)
    if categories:
        print(f"{YELLOW}Available categories:{RESET} {', '.join(categories)}\n")

    while True:
        try:
            user_input = input(f"{GREEN}legacy>{RESET} ").strip()
        except (KeyboardInterrupt, EOFError):
            print("\nGoodbye!")
            break

        if not user_input:
            continue

        parts = user_input.split(maxsplit=1)
        cmd = parts[0].lower()
        arg = parts[1] if len(parts) > 1 else ""

        if cmd in ['quit', 'exit', 'q']:
            print("Goodbye!")
            break

        elif cmd == 'help':
            print(f"\n{CYAN}Commands:{RESET}")
            print(f"  search <query>  - Semantic search using vectors")
            print(f"  keyword <word>  - Keyword/BM25 search")
            print(f"  category <cat>  - Filter by category ({', '.join(categories)})")
            print(f"  categories      - List all categories")
            print(f"  list            - List all entries")
            print(f"  full            - Toggle full content display (currently: {show_full})")
            print(f"  quit            - Exit\n")

        elif cmd == 'full':
            show_full = not show_full
            print(f"Full content display: {show_full}")

        elif cmd == 'categories':
            cats = get_categories(client)
            if cats:
                print(f"\n{YELLOW}Categories:{RESET} {', '.join(cats)}\n")
            else:
                print("No categories found")

        elif cmd == 'list':
            results = list_all(client)
            display_results(results, show_full)

        elif cmd == 'search':
            if not arg:
                print(f"{YELLOW}Usage: search <query>{RESET}")
                continue
            print(f"\n{BLUE}Searching for: {arg}{RESET}")
            results = semantic_search(client, arg)
            display_results(results, show_full)

        elif cmd == 'keyword':
            if not arg:
                print(f"{YELLOW}Usage: keyword <word>{RESET}")
                continue
            print(f"\n{BLUE}Keyword search: {arg}{RESET}")
            results = keyword_search(client, arg)
            display_results(results, show_full)

        elif cmd == 'category':
            if not arg:
                print(f"{YELLOW}Usage: category <name>{RESET}")
                print(f"Available: {', '.join(categories)}")
                continue
            print(f"\n{BLUE}Category: {arg}{RESET}")
            results = filter_by_category(client, arg)
            display_results(results, show_full)

        else:
            # Default to semantic search
            print(f"\n{BLUE}Searching for: {user_input}{RESET}")
            results = semantic_search(client, user_input)
            display_results(results, show_full)


def main():
    parser = argparse.ArgumentParser(description='Query ShaneBrain Legacy Knowledge')
    parser.add_argument('query', nargs='?', help='Search query (or enter interactive mode)')
    parser.add_argument('-k', '--keyword', action='store_true', help='Use keyword search instead of semantic')
    parser.add_argument('-c', '--category', help='Filter by category')
    parser.add_argument('-l', '--limit', type=int, default=5, help='Number of results (default: 5)')
    parser.add_argument('-f', '--full', action='store_true', help='Show full content')
    parser.add_argument('-i', '--interactive', action='store_true', help='Interactive mode')

    args = parser.parse_args()

    client = connect()
    if not client:
        return 1

    try:
        # Interactive mode
        if args.interactive or (not args.query and not args.category):
            interactive_mode(client)
            return 0

        # Category filter
        if args.category:
            results = filter_by_category(client, args.category, args.limit)
            display_results(results, args.full)
            return 0

        # Query mode
        if args.query:
            if args.keyword:
                results = keyword_search(client, args.query, args.limit)
            else:
                results = semantic_search(client, args.query, args.limit)
            display_results(results, args.full)
            return 0

    finally:
        client.close()

    return 0


if __name__ == "__main__":
    sys.exit(main())
