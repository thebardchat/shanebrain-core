#!/usr/bin/env python3
"""
Weaviate Verification Script for ShaneBrain Core
Displays status, schema, and record counts.
Compatible with weaviate-client v4.
"""

import weaviate
import sys

# Colors for terminal output
GREEN = '\033[92m'
RED = '\033[91m'
YELLOW = '\033[93m'
BLUE = '\033[94m'
RESET = '\033[0m'


def verify():
    """Verify Weaviate status, schema, and data."""
    print(f"\n{BLUE}{'='*60}{RESET}")
    print(f"{BLUE}     ShaneBrain Core - Weaviate Verification{RESET}")
    print(f"{BLUE}{'='*60}{RESET}\n")

    try:
        client = weaviate.connect_to_local()
    except Exception as e:
        print(f"{RED}✗ Could not connect to Weaviate: {e}{RESET}")
        print(f"\n{YELLOW}Make sure Weaviate is running:{RESET}")
        print(f"  cd weaviate-config && docker-compose up -d")
        return 1

    try:
        # Status
        print(f"{BLUE}=== Weaviate Status ==={RESET}")
        is_ready = client.is_ready()
        status_icon = f"{GREEN}✓{RESET}" if is_ready else f"{RED}✗{RESET}"
        print(f"  {status_icon} Ready: {is_ready}")

        if not is_ready:
            print(f"\n{RED}Weaviate is not ready. Cannot continue.{RESET}")
            return 1

        # Get meta info
        try:
            meta = client.get_meta()
            print(f"  {GREEN}✓{RESET} Version: {meta.get('version', 'unknown')}")
        except:
            pass

        # Schema Classes
        print(f"\n{BLUE}=== Schema Classes ==={RESET}")

        # Expected classes for ShaneBrain
        expected_classes = [
            'Conversation',
            'LegacyKnowledge',
            'CrisisLog',
            'ShanebrainMemory',
            'AngelCloudConversation',
            'PulsarSecurityEvent'
        ]

        existing_classes = []
        for class_name in expected_classes:
            exists = client.collections.exists(class_name)
            if exists:
                existing_classes.append(class_name)
                collection = client.collections.get(class_name)
                config = collection.config.get()
                prop_count = len(config.properties)
                print(f"  {GREEN}✓{RESET} {class_name}: {prop_count} properties")
            else:
                print(f"  {YELLOW}○{RESET} {class_name}: not created")

        # Record Counts
        print(f"\n{BLUE}=== Record Counts ==={RESET}")

        for class_name in existing_classes:
            try:
                collection = client.collections.get(class_name)
                response = collection.aggregate.over_all(total_count=True)
                count = response.total_count
                print(f"  {class_name}: {count} records")
            except Exception as e:
                print(f"  {class_name}: {YELLOW}error counting{RESET}")

        # Summary
        print(f"\n{BLUE}=== Summary ==={RESET}")
        core_classes = ['Conversation', 'LegacyKnowledge', 'CrisisLog']
        core_ready = all(c in existing_classes for c in core_classes)

        if core_ready:
            print(f"  {GREEN}✓ Core schema ready (Conversation, LegacyKnowledge, CrisisLog){RESET}")
        else:
            missing = [c for c in core_classes if c not in existing_classes]
            print(f"  {YELLOW}! Missing core classes: {', '.join(missing)}{RESET}")
            print(f"  {YELLOW}  Run: python scripts/setup_weaviate_schema.py{RESET}")

        # Check for legacy schemas
        legacy_ready = 'ShanebrainMemory' in existing_classes
        if legacy_ready:
            print(f"  {GREEN}✓ Legacy schema ready (ShanebrainMemory){RESET}")

        angel_ready = 'AngelCloudConversation' in existing_classes
        if angel_ready:
            print(f"  {GREEN}✓ Angel Cloud schema ready{RESET}")

        print(f"\n{BLUE}{'='*60}{RESET}")
        print(f"{GREEN}[OK] Weaviate verification complete{RESET}")
        print(f"{BLUE}{'='*60}{RESET}\n")

        return 0

    finally:
        client.close()


if __name__ == "__main__":
    sys.exit(verify())
