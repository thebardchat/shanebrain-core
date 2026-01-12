#!/usr/bin/env python3
"""
Backup Weaviate Data for ShaneBrain Core
Exports data from Weaviate collections to JSON files for backup.
Compatible with weaviate-client v4.
"""

import weaviate
import json
import sys
from pathlib import Path
from datetime import datetime

# Colors for terminal output
GREEN = '\033[92m'
RED = '\033[91m'
YELLOW = '\033[93m'
BLUE = '\033[94m'
RESET = '\033[0m'


def export_collection(client, class_name: str, output_dir: Path) -> int:
    """Export a collection to JSON file."""
    if not client.collections.exists(class_name):
        print(f"  {YELLOW}○{RESET} {class_name} - not found, skipping")
        return 0

    collection = client.collections.get(class_name)

    try:
        # Fetch all objects (paginated for large collections)
        all_objects = []
        offset = 0
        batch_size = 100

        while True:
            response = collection.query.fetch_objects(
                limit=batch_size,
                offset=offset
            )

            if not response.objects:
                break

            for obj in response.objects:
                all_objects.append({
                    "uuid": str(obj.uuid),
                    "properties": obj.properties
                })

            offset += batch_size

            # Safety limit
            if offset > 10000:
                print(f"  {YELLOW}!{RESET} {class_name} - truncated at 10000 records")
                break

        if not all_objects:
            print(f"  {YELLOW}○{RESET} {class_name} - empty, no data to export")
            return 0

        # Write to file
        output_file = output_dir / f"{class_name}.json"
        with open(output_file, 'w') as f:
            json.dump({
                "class": class_name,
                "exported_at": datetime.utcnow().isoformat(),
                "count": len(all_objects),
                "objects": all_objects
            }, f, indent=2, default=str)

        print(f"  {GREEN}✓{RESET} {class_name} - {len(all_objects)} records -> {output_file.name}")
        return len(all_objects)

    except Exception as e:
        print(f"  {RED}✗{RESET} {class_name} - error: {e}")
        return 0


def main():
    import argparse

    parser = argparse.ArgumentParser(description='Backup Weaviate data to JSON')
    parser.add_argument('-o', '--output', default='weaviate-backups',
                        help='Output directory (default: weaviate-backups)')
    parser.add_argument('-c', '--classes', nargs='+',
                        help='Specific classes to backup (default: all)')
    args = parser.parse_args()

    print(f"\n{BLUE}{'='*60}{RESET}")
    print(f"{BLUE}     ShaneBrain Core - Weaviate Backup{RESET}")
    print(f"{BLUE}{'='*60}{RESET}\n")

    # Connect to Weaviate
    try:
        client = weaviate.connect_to_local()
        if not client.is_ready():
            print(f"{RED}Weaviate is not ready{RESET}")
            return 1
        print(f"{GREEN}✓ Connected to Weaviate{RESET}")
    except Exception as e:
        print(f"{RED}Could not connect to Weaviate: {e}{RESET}")
        return 1

    try:
        # Create output directory with timestamp
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        output_dir = Path(args.output) / timestamp
        output_dir.mkdir(parents=True, exist_ok=True)
        print(f"{BLUE}Backup directory:{RESET} {output_dir}\n")

        # Determine classes to backup
        if args.classes:
            classes_to_backup = args.classes
        else:
            # Default classes
            classes_to_backup = [
                'Conversation',
                'LegacyKnowledge',
                'CrisisLog',
                'ShanebrainMemory',
                'AngelCloudConversation',
                'PulsarSecurityEvent'
            ]

        print(f"{BLUE}Exporting collections...{RESET}\n")

        total_records = 0
        exported_count = 0

        for class_name in classes_to_backup:
            count = export_collection(client, class_name, output_dir)
            total_records += count
            if count > 0:
                exported_count += 1

        # Write manifest
        manifest = {
            "backup_time": datetime.utcnow().isoformat(),
            "classes_exported": exported_count,
            "total_records": total_records,
            "classes": classes_to_backup
        }
        manifest_file = output_dir / "manifest.json"
        with open(manifest_file, 'w') as f:
            json.dump(manifest, f, indent=2)

        print(f"\n{BLUE}{'='*60}{RESET}")
        print(f"{GREEN}[SUCCESS] Backup complete{RESET}")
        print(f"  Collections: {exported_count}")
        print(f"  Records: {total_records}")
        print(f"  Location: {output_dir}")
        print(f"{BLUE}{'='*60}{RESET}\n")

        return 0

    finally:
        client.close()


if __name__ == "__main__":
    sys.exit(main())
