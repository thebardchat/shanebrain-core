#!/usr/bin/env python3
"""
Restore Weaviate Data for ShaneBrain Core
Imports data from JSON backup files into Weaviate collections.
Compatible with weaviate-client v4.
"""

import weaviate
import json
import sys
from pathlib import Path

# Colors for terminal output
GREEN = '\033[92m'
RED = '\033[91m'
YELLOW = '\033[93m'
BLUE = '\033[94m'
RESET = '\033[0m'


def restore_collection(client, backup_file: Path, clear_first: bool = False) -> int:
    """Restore a collection from JSON backup file."""
    try:
        with open(backup_file, 'r') as f:
            backup_data = json.load(f)
    except Exception as e:
        print(f"  {RED}✗{RESET} Error reading {backup_file.name}: {e}")
        return 0

    class_name = backup_data.get("class")
    objects = backup_data.get("objects", [])

    if not class_name:
        print(f"  {RED}✗{RESET} Invalid backup file: {backup_file.name}")
        return 0

    if not objects:
        print(f"  {YELLOW}○{RESET} {class_name} - no objects to restore")
        return 0

    # Check if collection exists
    if not client.collections.exists(class_name):
        print(f"  {RED}✗{RESET} {class_name} - collection not found. Run schema setup first.")
        return 0

    collection = client.collections.get(class_name)

    # Optionally clear existing data
    if clear_first:
        try:
            # Delete all objects
            collection.data.delete_many(where=None)
            print(f"  {YELLOW}○{RESET} {class_name} - cleared existing data")
        except:
            pass  # Collection might be empty

    # Import objects
    imported = 0
    errors = 0

    for obj in objects:
        try:
            properties = obj.get("properties", {})
            # Don't preserve UUIDs - let Weaviate generate new ones
            collection.data.insert(properties)
            imported += 1
        except Exception as e:
            errors += 1
            if errors <= 3:  # Only show first few errors
                print(f"    Error: {e}")

    status = f"{GREEN}✓{RESET}" if errors == 0 else f"{YELLOW}!{RESET}"
    error_msg = f" ({errors} errors)" if errors > 0 else ""
    print(f"  {status} {class_name} - restored {imported} records{error_msg}")

    return imported


def main():
    import argparse

    parser = argparse.ArgumentParser(description='Restore Weaviate data from JSON backup')
    parser.add_argument('backup_path', help='Path to backup directory or specific JSON file')
    parser.add_argument('--clear', action='store_true',
                        help='Clear existing data before restoring')
    parser.add_argument('-c', '--classes', nargs='+',
                        help='Specific classes to restore (default: all in backup)')
    args = parser.parse_args()

    print(f"\n{BLUE}{'='*60}{RESET}")
    print(f"{BLUE}     ShaneBrain Core - Weaviate Restore{RESET}")
    print(f"{BLUE}{'='*60}{RESET}\n")

    backup_path = Path(args.backup_path)

    if not backup_path.exists():
        print(f"{RED}Backup path not found: {backup_path}{RESET}")
        return 1

    # Collect backup files
    if backup_path.is_file():
        backup_files = [backup_path]
    else:
        backup_files = list(backup_path.glob("*.json"))
        # Exclude manifest
        backup_files = [f for f in backup_files if f.name != "manifest.json"]

    if not backup_files:
        print(f"{RED}No backup files found{RESET}")
        return 1

    # Filter by class if specified
    if args.classes:
        backup_files = [f for f in backup_files if f.stem in args.classes]

    print(f"{BLUE}Found {len(backup_files)} backup files:{RESET}")
    for f in backup_files:
        print(f"  • {f.name}")
    print()

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
        if args.clear:
            print(f"{YELLOW}Note: Will clear existing data before restoring{RESET}\n")

        print(f"{BLUE}Restoring collections...{RESET}\n")

        total_restored = 0
        restored_count = 0

        for backup_file in backup_files:
            count = restore_collection(client, backup_file, args.clear)
            total_restored += count
            if count > 0:
                restored_count += 1

        print(f"\n{BLUE}{'='*60}{RESET}")
        print(f"{GREEN}[SUCCESS] Restore complete{RESET}")
        print(f"  Collections: {restored_count}")
        print(f"  Records: {total_restored}")
        print(f"{BLUE}{'='*60}{RESET}\n")

        return 0

    finally:
        client.close()


if __name__ == "__main__":
    sys.exit(main())
