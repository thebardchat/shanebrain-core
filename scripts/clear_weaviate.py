#!/usr/bin/env python3
"""
Clear Weaviate Data for ShaneBrain Core
Deletes data from Weaviate collections (with confirmation).
Compatible with weaviate-client v4.

WARNING: This script permanently deletes data. Use with caution.
"""

import weaviate
import sys

# Colors for terminal output
GREEN = '\033[92m'
RED = '\033[91m'
YELLOW = '\033[93m'
BLUE = '\033[94m'
BOLD = '\033[1m'
RESET = '\033[0m'


def get_collection_count(client, class_name: str) -> int:
    """Get the number of objects in a collection."""
    if not client.collections.exists(class_name):
        return -1  # -1 means not found

    try:
        collection = client.collections.get(class_name)
        response = collection.aggregate.over_all(total_count=True)
        return response.total_count
    except:
        return 0


def clear_collection(client, class_name: str) -> bool:
    """Clear all data from a collection (delete and recreate)."""
    if not client.collections.exists(class_name):
        print(f"  {YELLOW}○{RESET} {class_name} - not found")
        return True

    try:
        # Get current config before deletion
        collection = client.collections.get(class_name)
        config = collection.config.get()

        # Delete the collection
        client.collections.delete(class_name)

        # Recreate with same config
        client.collections.create_from_dict({
            "class": class_name,
            "description": config.description,
            "properties": [
                {"name": p.name, "dataType": [str(p.data_type.value).lower()]}
                for p in config.properties
            ]
        })

        print(f"  {GREEN}✓{RESET} {class_name} - cleared")
        return True

    except Exception as e:
        print(f"  {RED}✗{RESET} {class_name} - error: {e}")
        return False


def delete_collection(client, class_name: str) -> bool:
    """Completely delete a collection (schema and data)."""
    if not client.collections.exists(class_name):
        print(f"  {YELLOW}○{RESET} {class_name} - not found")
        return True

    try:
        client.collections.delete(class_name)
        print(f"  {GREEN}✓{RESET} {class_name} - deleted")
        return True
    except Exception as e:
        print(f"  {RED}✗{RESET} {class_name} - error: {e}")
        return False


def main():
    import argparse

    parser = argparse.ArgumentParser(
        description='Clear or delete Weaviate collections',
        epilog='WARNING: This permanently deletes data!'
    )
    parser.add_argument('-c', '--classes', nargs='+',
                        help='Specific classes to clear (default: core classes)')
    parser.add_argument('--delete-schema', action='store_true',
                        help='Delete schema entirely (not just data)')
    parser.add_argument('--all', action='store_true',
                        help='Include all ShaneBrain classes')
    parser.add_argument('-y', '--yes', action='store_true',
                        help='Skip confirmation prompt')
    args = parser.parse_args()

    print(f"\n{BLUE}{'='*60}{RESET}")
    print(f"{BOLD}{RED}     ShaneBrain Core - Weaviate Data Clear{RESET}")
    print(f"{BLUE}{'='*60}{RESET}\n")

    # Connect to Weaviate
    try:
        client = weaviate.connect_to_local()
        if not client.is_ready():
            print(f"{RED}Weaviate is not ready{RESET}")
            return 1
        print(f"{GREEN}✓ Connected to Weaviate{RESET}\n")
    except Exception as e:
        print(f"{RED}Could not connect to Weaviate: {e}{RESET}")
        return 1

    try:
        # Determine classes to clear
        if args.classes:
            classes_to_clear = args.classes
        elif args.all:
            classes_to_clear = [
                'Conversation',
                'LegacyKnowledge',
                'CrisisLog',
                'ShanebrainMemory',
                'AngelCloudConversation',
                'PulsarSecurityEvent'
            ]
        else:
            # Default: only core classes (user-generated data)
            classes_to_clear = [
                'Conversation',
                'LegacyKnowledge',
                'CrisisLog'
            ]

        # Show what will be affected
        print(f"{YELLOW}The following collections will be {'deleted' if args.delete_schema else 'cleared'}:{RESET}\n")

        total_records = 0
        for class_name in classes_to_clear:
            count = get_collection_count(client, class_name)
            if count == -1:
                print(f"  {YELLOW}○{RESET} {class_name} - not found")
            elif count == 0:
                print(f"  • {class_name} - empty")
            else:
                print(f"  • {class_name} - {count} records")
                total_records += count

        if total_records == 0 and not args.delete_schema:
            print(f"\n{YELLOW}No data to clear.{RESET}")
            return 0

        # Confirmation
        action = "delete" if args.delete_schema else "clear"
        print(f"\n{RED}WARNING: This will {action} {total_records} records!{RESET}")

        if not args.yes:
            confirm = input(f"\nType '{action.upper()}' to confirm: ")
            if confirm != action.upper():
                print(f"\n{YELLOW}Cancelled.{RESET}")
                return 0

        # Perform the operation
        print(f"\n{BLUE}{'Deleting' if args.delete_schema else 'Clearing'} collections...{RESET}\n")

        success_count = 0
        for class_name in classes_to_clear:
            if args.delete_schema:
                if delete_collection(client, class_name):
                    success_count += 1
            else:
                if clear_collection(client, class_name):
                    success_count += 1

        print(f"\n{BLUE}{'='*60}{RESET}")
        if success_count == len(classes_to_clear):
            print(f"{GREEN}[SUCCESS] Operation complete{RESET}")
        else:
            print(f"{YELLOW}[WARN] Some operations failed{RESET}")
        print(f"{BLUE}{'='*60}{RESET}\n")

        if args.delete_schema:
            print(f"{YELLOW}Note: Run setup scripts to recreate schemas{RESET}")
            print(f"  python scripts/setup_all_weaviate.py\n")

        return 0

    finally:
        client.close()


if __name__ == "__main__":
    sys.exit(main())
