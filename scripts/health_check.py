#!/usr/bin/env python3
"""
ShaneBrain Core - Health Check Script
Verifies all services are running and accessible.
"""

import os
import sys
import subprocess
from pathlib import Path

# Colors for terminal output
GREEN = '\033[92m'
RED = '\033[91m'
YELLOW = '\033[93m'
BLUE = '\033[94m'
RESET = '\033[0m'

def check_mark(success):
    return f"{GREEN}✓{RESET}" if success else f"{RED}✗{RESET}"

def print_status(name, status, message=""):
    mark = check_mark(status)
    msg = f" - {message}" if message else ""
    print(f"  {mark} {name}{msg}")

def check_docker():
    """Check if Docker daemon is running."""
    try:
        result = subprocess.run(
            ["docker", "info"],
            capture_output=True,
            text=True,
            timeout=10
        )
        return result.returncode == 0
    except Exception:
        return False

def check_container(name):
    """Check if a Docker container is running."""
    try:
        result = subprocess.run(
            ["docker", "inspect", "-f", "{{.State.Running}}", name],
            capture_output=True,
            text=True,
            timeout=10
        )
        return result.stdout.strip() == "true"
    except Exception:
        return False

def check_weaviate():
    """Check if Weaviate is responding."""
    try:
        import urllib.request
        req = urllib.request.urlopen("http://localhost:8080/v1/.well-known/ready", timeout=5)
        return req.status == 200
    except Exception:
        return False

def check_ollama():
    """Check if Ollama is running."""
    try:
        import urllib.request
        req = urllib.request.urlopen("http://localhost:11434/api/tags", timeout=5)
        return req.status == 200
    except Exception:
        return False

def check_mongodb():
    """Check if MongoDB is accessible."""
    try:
        result = subprocess.run(
            ["docker", "inspect", "-f", "{{.State.Running}}", "shanebrain-mongodb"],
            capture_output=True,
            text=True,
            timeout=10
        )
        return result.stdout.strip() == "true"
    except Exception:
        # MongoDB might not be containerized
        return None

def check_env_file():
    """Check if .env file exists and has key variables."""
    env_path = Path(__file__).parent.parent / ".env"
    if not env_path.exists():
        return False, "Missing .env file"
    
    with open(env_path, 'r') as f:
        content = f.read()
    
    required = ["SHANEBRAIN_ROOT", "WEAVIATE_URL"]
    missing = [key for key in required if key not in content]
    
    if missing:
        return False, f"Missing: {', '.join(missing)}"
    return True, "Configured"

def check_planning_system():
    """Check if planning system directories exist."""
    base = Path(__file__).parent.parent / "planning-system"
    required_dirs = ["templates", "active-projects"]
    
    if not base.exists():
        return False, "Directory missing"
    
    for d in required_dirs:
        if not (base / d).exists():
            return False, f"Missing {d}/"
    
    return True, "Ready"

def main():
    print(f"\n{BLUE}{'='*60}{RESET}")
    print(f"{BLUE}         ShaneBrain Core - Health Check{RESET}")
    print(f"{BLUE}{'='*60}{RESET}\n")
    
    all_healthy = True
    
    # Docker
    print(f"{BLUE}[Docker]{RESET}")
    docker_ok = check_docker()
    print_status("Docker Daemon", docker_ok)
    all_healthy &= docker_ok
    
    # Containers
    print(f"\n{BLUE}[Containers]{RESET}")
    containers = [
        ("shanebrain-weaviate", "Vector Database"),
        ("shanebrain-t2v", "Text-to-Vector"),
        ("shanebrain-qna", "QnA Transformer"),
    ]
    for container, desc in containers:
        status = check_container(container)
        print_status(f"{desc} ({container})", status)
        if container == "shanebrain-weaviate":
            all_healthy &= status
    
    # Services
    print(f"\n{BLUE}[Services]{RESET}")
    
    weaviate_ok = check_weaviate()
    print_status("Weaviate API", weaviate_ok, "http://localhost:8080")
    all_healthy &= weaviate_ok
    
    ollama_ok = check_ollama()
    print_status("Ollama", ollama_ok, "http://localhost:11434" if ollama_ok else "Not running (optional)")
    
    # Configuration
    print(f"\n{BLUE}[Configuration]{RESET}")
    
    env_ok, env_msg = check_env_file()
    print_status(".env File", env_ok, env_msg)
    all_healthy &= env_ok
    
    planning_ok, planning_msg = check_planning_system()
    print_status("Planning System", planning_ok, planning_msg)
    all_healthy &= planning_ok
    
    # Summary
    print(f"\n{BLUE}{'='*60}{RESET}")
    if all_healthy:
        print(f"{GREEN}[OK] All core systems healthy!{RESET}")
    else:
        print(f"{YELLOW}[WARN] Some systems need attention{RESET}")
    print(f"{BLUE}{'='*60}{RESET}\n")
    
    return 0 if all_healthy else 1

if __name__ == "__main__":
    sys.exit(main())
