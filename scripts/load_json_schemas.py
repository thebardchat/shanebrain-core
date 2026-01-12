#!/usr/bin/env python3
"""
Load JSON Schemas to Weaviate for ShaneBrain Core
Loads pre-defined schema files from weaviate-config/schemas/ into Weaviate.
Compatible with weaviate-client v4.
"""

import weaviate
import json
import sys
import time
from pathlib import Path

# Colors for terminal output
GREEN = '\033[92m'
RED = '\033[91m'
YELLOW = '\033[93m'
BLUE = '\033[94m'
RESET = '\033[0m'


def wait_for_weaviate(max_attempts=5):
    """Wait for Weaviate to be ready."""
    print(f"{BLUE}Connecting to Weaviate...{RESET}")

    for i in range(max_attempts):
        try:
            client = weaviate.connect_to_local()
            if client.is_ready():
                print(f"{GREEN}✓ Weaviate is ready!{RESET}")
                return client
        except Exception as e:
            print(f"{YELLOW}Waiting for Weaviate... attempt {i+1}/{max_attempts}{RESET}")
            if i < max_attempts - 1:
                time.sleep(3)

    print(f"{RED}✗ Could not connect to Weaviate after {max_attempts} attempts{RESET}")
    sys.exit(1)


def find_schema_files():
    """Find all schema JSON files."""
    # Look in multiple locations
    search_paths = [
        Path(__file__).parent.parent / "weaviate-config" / "schemas",
        Path.cwd() / "weaviate-config" / "schemas",
    ]

    schema_files = []
    for path in search_paths:
        if path.exists():
            schema_files.extend(path.glob("*.json"))
            break

    return sorted(set(schema_files))


def load_schema_from_json(filepath):
    """Load and parse a schema JSON file."""
    try:
        with open(filepath, 'r') as f:
            return json.load(f)
    except Exception as e:
        print(f"{RED}✗ Error reading {filepath}: {e}{RESET}")
        return None


def create_class_from_json(client, schema_dict):
    """Create a Weaviate class from JSON schema definition."""
    class_name = schema_dict.get("class")
    if not class_name:
        return False, "No class name in schema"

    try:
        # Check if class already exists
        if client.collections.exists(class_name):
            return None, "already exists"

        # Use the REST API approach to create from dict
        # This preserves all the moduleConfig settings from the JSON
        client.collections.create_from_dict(schema_dict)
        return True, "created"

    except Exception as e:
        error_msg = str(e).lower()
        if "already exists" in error_msg:
            return None, "already exists"
        return False, str(e)


def main():
    print(f"\n{BLUE}{'='*60}{RESET}")
    print(f"{BLUE}     ShaneBrain Core - JSON Schema Loader{RESET}")
    print(f"{BLUE}{'='*60}{RESET}\n")

    # Find schema files
    schema_files = find_schema_files()

    if not schema_files:
        print(f"{YELLOW}No schema files found in weaviate-config/schemas/{RESET}")
        print(f"Expected location: weaviate-config/schemas/*.json")
        return 1

    print(f"{BLUE}Found {len(schema_files)} schema files:{RESET}")
    for f in schema_files:
        print(f"  • {f.name}")
    print()

    # Connect to Weaviate
    client = wait_for_weaviate()

    try:
        print(f"\n{BLUE}=== Loading Schemas ==={RESET}\n")

        created = 0
        skipped = 0
        failed = 0

        for schema_file in schema_files:
            schema = load_schema_from_json(schema_file)
            if not schema:
                failed += 1
                continue

            class_name = schema.get("class", "Unknown")
            success, message = create_class_from_json(client, schema)

            if success is True:
                print(f"{GREEN}✓ Created: {class_name}{RESET}")
                created += 1
            elif success is None:
                print(f"{YELLOW}○ Skipped: {class_name} ({message}){RESET}")
                skipped += 1
            else:
                print(f"{RED}✗ Failed: {class_name} - {message}{RESET}")
                failed += 1

        # Summary
        print(f"\n{BLUE}=== Summary ==={RESET}")
        print(f"  Created: {created}")
        print(f"  Skipped: {skipped}")
        print(f"  Failed:  {failed}")

        print(f"\n{BLUE}{'='*60}{RESET}")
        if failed == 0:
            print(f"{GREEN}[OK] Schema loading complete!{RESET}")
        else:
            print(f"{YELLOW}[WARN] Some schemas failed to load{RESET}")
        print(f"{BLUE}{'='*60}{RESET}\n")

        # Show current schema status
        print(f"{BLUE}Current schema classes:{RESET}")
        for class_name in ['ShanebrainMemory', 'AngelCloudConversation', 'PulsarSecurityEvent',
                          'Conversation', 'LegacyKnowledge', 'CrisisLog']:
            exists = client.collections.exists(class_name)
            status = f"{GREEN}✓{RESET}" if exists else f"{YELLOW}○{RESET}"
            print(f"  {status} {class_name}")

        return 0 if failed == 0 else 1

    finally:
        client.close()


if __name__ == "__main__":
    sys.exit(main())
