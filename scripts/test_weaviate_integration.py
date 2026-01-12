#!/usr/bin/env python3
"""
Weaviate Integration Test for ShaneBrain Core
Tests all Weaviate operations: connection, schema, CRUD, and vector search.
Compatible with weaviate-client v4.
"""

import weaviate
from weaviate.classes.config import Property, DataType, Configure
from weaviate.classes.query import Filter, MetadataQuery
import sys
import time
from datetime import datetime, timezone

# Colors for terminal output
GREEN = '\033[92m'
RED = '\033[91m'
YELLOW = '\033[93m'
BLUE = '\033[94m'
RESET = '\033[0m'

# Test counters
tests_passed = 0
tests_failed = 0


def test(name, condition, error_msg=""):
    """Run a test and track results."""
    global tests_passed, tests_failed
    if condition:
        print(f"  {GREEN}✓{RESET} {name}")
        tests_passed += 1
        return True
    else:
        msg = f" - {error_msg}" if error_msg else ""
        print(f"  {RED}✗{RESET} {name}{msg}")
        tests_failed += 1
        return False


def test_connection():
    """Test Weaviate connection."""
    print(f"\n{BLUE}[1] Connection Test{RESET}")

    try:
        client = weaviate.connect_to_local()
        test("Connect to localhost:8080", True)
        test("Client is ready", client.is_ready())

        meta = client.get_meta()
        version = meta.get('version', 'unknown')
        test(f"Get meta info (version: {version})", True)

        return client
    except Exception as e:
        test("Connect to Weaviate", False, str(e))
        return None


def test_schema_operations(client):
    """Test schema operations."""
    print(f"\n{BLUE}[2] Schema Operations{RESET}")

    test_class = "TestIntegration"

    # Clean up any previous test class
    try:
        if client.collections.exists(test_class):
            client.collections.delete(test_class)
    except:
        pass

    # Create class
    try:
        client.collections.create(
            name=test_class,
            description="Integration test class",
            properties=[
                Property(name="content", data_type=DataType.TEXT),
                Property(name="category", data_type=DataType.TEXT),
                Property(name="score", data_type=DataType.NUMBER),
            ],
            vectorizer_config=Configure.Vectorizer.text2vec_transformers()
        )
        test("Create test class", True)
    except Exception as e:
        test("Create test class", False, str(e))
        return False

    # Verify class exists
    exists = client.collections.exists(test_class)
    test("Verify class exists", exists)

    # Get class config
    try:
        collection = client.collections.get(test_class)
        config = collection.config.get()
        prop_count = len(config.properties)
        test(f"Get class config ({prop_count} properties)", prop_count == 3)
    except Exception as e:
        test("Get class config", False, str(e))

    return True


def test_crud_operations(client):
    """Test CRUD operations."""
    print(f"\n{BLUE}[3] CRUD Operations{RESET}")

    test_class = "TestIntegration"

    try:
        collection = client.collections.get(test_class)
    except Exception as e:
        test("Get collection", False, str(e))
        return False

    # Create (Insert)
    test_data = [
        {"content": "The quick brown fox jumps over the lazy dog", "category": "animals", "score": 0.9},
        {"content": "Machine learning is transforming technology", "category": "tech", "score": 0.8},
        {"content": "Family values are the foundation of a good life", "category": "family", "score": 0.95},
    ]

    try:
        for data in test_data:
            collection.data.insert(data)
        test(f"Insert {len(test_data)} objects", True)
    except Exception as e:
        test("Insert objects", False, str(e))
        return False

    # Read (Fetch)
    try:
        response = collection.query.fetch_objects(limit=10)
        count = len(response.objects)
        test(f"Fetch objects (got {count})", count >= len(test_data))
    except Exception as e:
        test("Fetch objects", False, str(e))

    # Count
    try:
        response = collection.aggregate.over_all(total_count=True)
        total = response.total_count
        test(f"Count objects (total: {total})", total >= len(test_data))
    except Exception as e:
        test("Count objects", False, str(e))

    # Filter
    try:
        response = collection.query.fetch_objects(
            filters=Filter.by_property("category").equal("tech"),
            limit=10
        )
        tech_count = len(response.objects)
        test(f"Filter by category (found {tech_count})", tech_count >= 1)
    except Exception as e:
        test("Filter by category", False, str(e))

    return True


def test_vector_search(client):
    """Test vector search operations."""
    print(f"\n{BLUE}[4] Vector Search{RESET}")

    test_class = "TestIntegration"

    try:
        collection = client.collections.get(test_class)
    except Exception as e:
        test("Get collection for search", False, str(e))
        return False

    # Semantic search (near_text)
    try:
        response = collection.query.near_text(
            query="artificial intelligence and computers",
            limit=2,
            return_metadata=MetadataQuery(distance=True)
        )
        found = len(response.objects)
        # Should find the tech-related content
        test(f"Semantic search (found {found} results)", found > 0)

        if found > 0:
            # Check that we got distance metadata
            has_distance = (hasattr(response.objects[0], 'metadata') and
                          response.objects[0].metadata and
                          hasattr(response.objects[0].metadata, 'distance'))
            test("Distance metadata returned", has_distance)
    except Exception as e:
        test("Semantic search", False, str(e))

    # BM25 search
    try:
        response = collection.query.bm25(
            query="family values",
            limit=2
        )
        found = len(response.objects)
        test(f"BM25 keyword search (found {found})", found > 0)
    except Exception as e:
        test("BM25 search", False, str(e))

    return True


def test_cleanup(client):
    """Clean up test data."""
    print(f"\n{BLUE}[5] Cleanup{RESET}")

    test_class = "TestIntegration"

    try:
        if client.collections.exists(test_class):
            client.collections.delete(test_class)
            test("Delete test class", True)
        else:
            test("Test class already deleted", True)
    except Exception as e:
        test("Delete test class", False, str(e))

    # Verify deletion
    exists = client.collections.exists(test_class)
    test("Verify class deleted", not exists)

    return True


def test_existing_schemas(client):
    """Verify expected ShaneBrain schemas exist."""
    print(f"\n{BLUE}[6] ShaneBrain Schema Check{RESET}")

    expected = {
        "Core": ['Conversation', 'LegacyKnowledge', 'CrisisLog'],
        "Advanced": ['ShanebrainMemory', 'AngelCloudConversation', 'PulsarSecurityEvent']
    }

    for group, classes in expected.items():
        print(f"  {YELLOW}{group} schemas:{RESET}")
        for class_name in classes:
            exists = client.collections.exists(class_name)
            status = f"{GREEN}✓{RESET}" if exists else f"{YELLOW}○{RESET}"
            label = "exists" if exists else "not created"
            print(f"    {status} {class_name} ({label})")


def main():
    global tests_passed, tests_failed

    print(f"\n{BLUE}{'='*60}{RESET}")
    print(f"{BLUE}     ShaneBrain Core - Weaviate Integration Test{RESET}")
    print(f"{BLUE}{'='*60}{RESET}")

    # Test connection
    client = test_connection()
    if not client:
        print(f"\n{RED}Cannot continue without Weaviate connection{RESET}")
        print(f"Make sure Weaviate is running: cd weaviate-config && docker-compose up -d")
        return 1

    try:
        # Run tests
        test_schema_operations(client)
        test_crud_operations(client)
        test_vector_search(client)
        test_cleanup(client)
        test_existing_schemas(client)

        # Summary
        total = tests_passed + tests_failed
        print(f"\n{BLUE}{'='*60}{RESET}")
        print(f"{BLUE}Test Results:{RESET}")
        print(f"  Passed: {GREEN}{tests_passed}{RESET}")
        print(f"  Failed: {RED if tests_failed > 0 else ''}{tests_failed}{RESET if tests_failed > 0 else ''}")
        print(f"  Total:  {total}")

        if tests_failed == 0:
            print(f"\n{GREEN}[PASS] All tests passed!{RESET}")
        else:
            print(f"\n{RED}[FAIL] Some tests failed{RESET}")
        print(f"{BLUE}{'='*60}{RESET}\n")

        return 0 if tests_failed == 0 else 1

    finally:
        client.close()


if __name__ == "__main__":
    sys.exit(main())
