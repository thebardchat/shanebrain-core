#!/usr/bin/env python3
"""
ShaneBrain Core - Health Check
==============================

Checks the health of all ShaneBrain components:
- Weaviate connection and schemas
- MongoDB connection
- Planning system files
- Environment configuration
- Docker services

Usage:
    python health_check.py
    python health_check.py --verbose
    python health_check.py --json

Author: Shane Brazelton
"""

import os
import sys
import json
import argparse
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Tuple, Optional

# =============================================================================
# CONFIGURATION
# =============================================================================

SCRIPT_DIR = Path(__file__).parent.resolve()
PROJECT_ROOT = SCRIPT_DIR.parent


class Colors:
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    NC = '\033[0m'
    BOLD = '\033[1m'


# =============================================================================
# HEALTH CHECK FUNCTIONS
# =============================================================================

def check_env_file() -> Tuple[bool, str, Dict]:
    """Check if .env file exists and has required variables."""
    env_file = PROJECT_ROOT / ".env"
    details = {"exists": False, "variables": [], "missing": []}

    if not env_file.exists():
        return False, ".env file not found", details

    details["exists"] = True

    required_vars = [
        "SHANEBRAIN_ROOT",
        "WEAVIATE_HOST",
        "WEAVIATE_PORT",
    ]

    optional_vars = [
        "MONGODB_ATLAS_URI",
        "ENCRYPTION_KEY",
        "LLAMA_DEFAULT_MODEL",
    ]

    # Parse .env file
    env_vars = {}
    try:
        with open(env_file) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    key, value = line.split("=", 1)
                    env_vars[key] = value
                    details["variables"].append(key)
    except Exception as e:
        return False, f"Error reading .env: {e}", details

    # Check required variables
    for var in required_vars:
        if var not in env_vars or not env_vars[var]:
            details["missing"].append(var)

    if details["missing"]:
        return False, f"Missing required variables: {details['missing']}", details

    return True, f"{len(env_vars)} variables configured", details


def check_weaviate() -> Tuple[bool, str, Dict]:
    """Check Weaviate connection and schemas."""
    details = {"connected": False, "schemas": [], "ready": False}

    try:
        import weaviate
    except ImportError:
        return False, "weaviate-client not installed", details

    try:
        # Get host/port from env or defaults
        host = os.environ.get("WEAVIATE_HOST", "localhost")
        port = os.environ.get("WEAVIATE_PORT", "8080")

        client = weaviate.Client(f"http://{host}:{port}")

        if not client.is_ready():
            return False, "Weaviate not ready", details

        details["connected"] = True
        details["ready"] = True

        # Check schemas
        schema = client.schema.get()
        classes = schema.get("classes", [])
        details["schemas"] = [c["class"] for c in classes]

        expected_schemas = ["ShanebrainMemory", "AngelCloudConversation", "PulsarSecurityEvent"]
        missing = [s for s in expected_schemas if s not in details["schemas"]]

        if missing:
            return True, f"Connected, missing schemas: {missing}", details

        return True, f"Connected, {len(details['schemas'])} schemas loaded", details

    except Exception as e:
        return False, f"Connection failed: {str(e)[:50]}", details


def check_mongodb() -> Tuple[bool, str, Dict]:
    """Check MongoDB connection."""
    details = {"connected": False, "local": False, "atlas": False}

    try:
        from pymongo import MongoClient
        from pymongo.errors import ServerSelectionTimeoutError
    except ImportError:
        return False, "pymongo not installed", details

    # Check local MongoDB
    try:
        client = MongoClient("mongodb://localhost:27017/", serverSelectionTimeoutMS=2000)
        client.admin.command('ping')
        details["local"] = True
        details["connected"] = True
        client.close()
    except Exception:
        pass

    # Check Atlas (if configured)
    atlas_uri = os.environ.get("MONGODB_ATLAS_URI")
    if atlas_uri:
        try:
            client = MongoClient(atlas_uri, serverSelectionTimeoutMS=5000)
            client.admin.command('ping')
            details["atlas"] = True
            details["connected"] = True
            client.close()
        except Exception:
            pass

    if details["connected"]:
        sources = []
        if details["local"]:
            sources.append("local")
        if details["atlas"]:
            sources.append("Atlas")
        return True, f"Connected ({', '.join(sources)})", details

    return False, "No MongoDB connection", details


def check_planning_system() -> Tuple[bool, str, Dict]:
    """Check planning system files."""
    details = {"skill_file": False, "templates": [], "active_projects": []}

    planning_root = PROJECT_ROOT / "planning-system"

    # Check SKILL.md
    skill_file = planning_root / "SKILL.md"
    details["skill_file"] = skill_file.exists()

    # Check templates
    templates_dir = planning_root / "templates"
    if templates_dir.exists():
        details["templates"] = [f.name for f in templates_dir.glob("*.md")]

    # Check active projects
    active_dir = planning_root / "active-projects"
    if active_dir.exists():
        details["active_projects"] = [f.name for f in active_dir.glob("*.md") if f.name != ".gitkeep"]

    if not details["skill_file"]:
        return False, "SKILL.md not found", details

    if not details["templates"]:
        return False, "No templates found", details

    active_count = len(details["active_projects"])
    return True, f"{len(details['templates'])} templates, {active_count} active projects", details


def check_docker() -> Tuple[bool, str, Dict]:
    """Check Docker status."""
    details = {"running": False, "containers": []}

    import subprocess

    try:
        # Check if Docker is running
        result = subprocess.run(
            ["docker", "info"],
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode != 0:
            return False, "Docker daemon not running", details

        details["running"] = True

        # Check ShaneBrain containers
        result = subprocess.run(
            ["docker", "ps", "--filter", "name=shanebrain", "--format", "{{.Names}}: {{.Status}}"],
            capture_output=True,
            text=True,
            timeout=5
        )

        if result.stdout.strip():
            details["containers"] = result.stdout.strip().split("\n")

        container_count = len(details["containers"])
        if container_count > 0:
            return True, f"{container_count} ShaneBrain containers running", details
        else:
            return True, "Docker running, no ShaneBrain containers", details

    except FileNotFoundError:
        return False, "Docker not installed", details
    except subprocess.TimeoutExpired:
        return False, "Docker command timed out", details
    except Exception as e:
        return False, f"Docker check failed: {e}", details


def check_llama_models() -> Tuple[bool, str, Dict]:
    """Check for Llama models."""
    details = {"models_dir": False, "models": []}

    # Check multiple possible locations
    possible_paths = [
        PROJECT_ROOT / "llama-configs" / "models",
        Path(os.environ.get("LLAMA_MODELS_PATH", "/mnt/8TB/ShaneBrain-Core/llama-configs/models")),
    ]

    for models_dir in possible_paths:
        if models_dir.exists():
            details["models_dir"] = True
            # Look for model files
            for ext in ["*.gguf", "*.bin", "*.ggml"]:
                details["models"].extend([f.name for f in models_dir.glob(ext)])

    if not details["models_dir"]:
        return False, "Models directory not found", details

    if not details["models"]:
        return True, "Models directory exists, no models downloaded", details

    return True, f"{len(details['models'])} models found", details


def check_langchain_chains() -> Tuple[bool, str, Dict]:
    """Check LangChain chain files."""
    details = {"chains": []}

    chains_dir = PROJECT_ROOT / "langchain-chains"

    expected_chains = [
        "crisis_detection_chain.py",
        "qa_retrieval_chain.py",
        "code_generation_chain.py",
        "shanebrain_agent.py",
    ]

    for chain in expected_chains:
        chain_file = chains_dir / chain
        if chain_file.exists():
            details["chains"].append(chain)

    missing = set(expected_chains) - set(details["chains"])

    if missing:
        return False, f"Missing chains: {list(missing)}", details

    return True, f"{len(details['chains'])} chains available", details


def check_disk_space() -> Tuple[bool, str, Dict]:
    """Check available disk space."""
    details = {"total_gb": 0, "used_gb": 0, "free_gb": 0, "percent_used": 0}

    try:
        import shutil
        root_path = os.environ.get("SHANEBRAIN_ROOT", str(PROJECT_ROOT))
        total, used, free = shutil.disk_usage(root_path)

        details["total_gb"] = round(total / (1024**3), 1)
        details["used_gb"] = round(used / (1024**3), 1)
        details["free_gb"] = round(free / (1024**3), 1)
        details["percent_used"] = round((used / total) * 100, 1)

        if details["free_gb"] < 10:
            return False, f"Low disk space: {details['free_gb']}GB free", details

        if details["percent_used"] > 90:
            return False, f"Disk {details['percent_used']}% full", details

        return True, f"{details['free_gb']}GB free ({details['percent_used']}% used)", details

    except Exception as e:
        return False, f"Could not check disk: {e}", details


# =============================================================================
# MAIN HEALTH CHECK
# =============================================================================

def run_health_check(verbose: bool = False) -> Dict:
    """Run all health checks and return results."""
    checks = {
        "Environment": check_env_file,
        "Docker": check_docker,
        "Weaviate": check_weaviate,
        "MongoDB": check_mongodb,
        "Planning System": check_planning_system,
        "LangChain Chains": check_langchain_chains,
        "Llama Models": check_llama_models,
        "Disk Space": check_disk_space,
    }

    results = {
        "timestamp": datetime.now().isoformat(),
        "overall_status": "healthy",
        "checks": {},
    }

    print(f"\n{Colors.BLUE}{Colors.BOLD}ShaneBrain Health Check{Colors.NC}")
    print(f"{Colors.BLUE}{'=' * 50}{Colors.NC}\n")

    failed_checks = []

    for name, check_func in checks.items():
        try:
            success, message, details = check_func()
        except Exception as e:
            success, message, details = False, f"Check failed: {e}", {}

        results["checks"][name] = {
            "success": success,
            "message": message,
            "details": details if verbose else {},
        }

        # Print result
        if success:
            status = f"{Colors.GREEN}✓{Colors.NC}"
        else:
            status = f"{Colors.RED}✗{Colors.NC}"
            failed_checks.append(name)

        print(f"  {status} {name}: {message}")

        if verbose and details:
            for key, value in details.items():
                print(f"      {key}: {value}")

    # Overall status
    if failed_checks:
        results["overall_status"] = "unhealthy"
        print(f"\n{Colors.RED}Status: UNHEALTHY{Colors.NC}")
        print(f"Failed checks: {', '.join(failed_checks)}")
    else:
        print(f"\n{Colors.GREEN}Status: HEALTHY{Colors.NC}")

    print(f"\n{Colors.BLUE}{'=' * 50}{Colors.NC}")

    return results


def main():
    parser = argparse.ArgumentParser(description="ShaneBrain Health Check")
    parser.add_argument("--verbose", "-v", action="store_true", help="Show detailed information")
    parser.add_argument("--json", "-j", action="store_true", help="Output as JSON")
    args = parser.parse_args()

    # Load environment
    env_file = PROJECT_ROOT / ".env"
    if env_file.exists():
        try:
            with open(env_file) as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith("#") and "=" in line:
                        key, value = line.split("=", 1)
                        os.environ[key] = value
        except Exception:
            pass

    results = run_health_check(verbose=args.verbose)

    if args.json:
        print(json.dumps(results, indent=2))

    # Exit code based on health
    sys.exit(0 if results["overall_status"] == "healthy" else 1)


if __name__ == "__main__":
    main()
