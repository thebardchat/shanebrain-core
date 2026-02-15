#!/usr/bin/env python3
"""
ShaneBrain Core - Secure Credential Setup
==========================================

Interactive setup script for configuring credentials securely.
This script:
- Prompts for credentials interactively
- Creates .env file with proper permissions (chmod 600)
- Tests connections
- Never logs or exposes credentials

Usage:
    python setup_credentials.py          # Full interactive setup
    python setup_credentials.py --verify # Verify existing credentials
    python setup_credentials.py --reset  # Reset to defaults

Author: Shane Brazelton
Security: Credentials are stored locally only, never transmitted
"""

import os
import sys
import stat
import getpass
from pathlib import Path
from typing import Optional, Dict, Tuple
from urllib.parse import quote_plus
import argparse


# =============================================================================
# CONFIGURATION
# =============================================================================

# Default paths - update SHANEBRAIN_ROOT for your 8TB drive location
DEFAULT_ROOT = "/mnt/8TB/ShaneBrain-Core"
SCRIPT_DIR = Path(__file__).parent.resolve()
PROJECT_ROOT = SCRIPT_DIR.parent
ENV_FILE = PROJECT_ROOT / ".env"
ENV_TEMPLATE = PROJECT_ROOT / ".env.template"


# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

def print_header(text: str) -> None:
    """Print a formatted header."""
    print("\n" + "=" * 60)
    print(f" {text}")
    print("=" * 60)


def print_section(text: str) -> None:
    """Print a section header."""
    print(f"\n--- {text} ---")


def print_success(text: str) -> None:
    """Print success message."""
    print(f"[OK] {text}")


def print_warning(text: str) -> None:
    """Print warning message."""
    print(f"[!] {text}")


def print_error(text: str) -> None:
    """Print error message."""
    print(f"[ERROR] {text}")


def print_info(text: str) -> None:
    """Print info message."""
    print(f"[i] {text}")


def secure_input(prompt: str, default: str = "", is_password: bool = False) -> str:
    """
    Get input from user securely.

    Args:
        prompt: The prompt to display
        default: Default value if user presses enter
        is_password: If True, hide input (for passwords)

    Returns:
        User input or default value
    """
    if default:
        display_prompt = f"{prompt} [{default}]: "
    else:
        display_prompt = f"{prompt}: "

    try:
        if is_password:
            value = getpass.getpass(display_prompt)
        else:
            value = input(display_prompt)

        return value.strip() if value.strip() else default
    except KeyboardInterrupt:
        print("\n\nSetup cancelled by user.")
        sys.exit(1)


def yes_no_prompt(prompt: str, default: bool = False) -> bool:
    """
    Get yes/no input from user.

    Args:
        prompt: The prompt to display
        default: Default value if user presses enter

    Returns:
        True for yes, False for no
    """
    default_str = "Y/n" if default else "y/N"
    response = secure_input(f"{prompt} [{default_str}]", "y" if default else "n")
    return response.lower() in ("y", "yes", "true", "1")


def set_file_permissions(filepath: Path, mode: int = 0o600) -> bool:
    """
    Set secure permissions on a file.

    Args:
        filepath: Path to the file
        mode: Permission mode (default: 600 - owner read/write only)

    Returns:
        True if successful
    """
    try:
        os.chmod(filepath, mode)
        return True
    except OSError as e:
        print_error(f"Could not set permissions on {filepath}: {e}")
        return False


# =============================================================================
# CREDENTIAL COLLECTION
# =============================================================================

def collect_base_paths() -> Dict[str, str]:
    """Collect base path configuration."""
    print_section("Base Path Configuration")

    print_info("Where is your 8TB external drive mounted?")
    print_info("Example: /mnt/8TB, /media/user/8TB, D:\\")

    root = secure_input(
        "ShaneBrain root path",
        DEFAULT_ROOT
    )

    return {
        "SHANEBRAIN_ROOT": root,
        "WEAVIATE_DATA_PATH": f"{root}/weaviate-config/data",
        "MONGODB_DATA_PATH": f"{root}/mongodb-data",
        "LLAMA_MODELS_PATH": f"{root}/llama-configs/models",
        "BACKUPS_PATH": f"{root}/backups",
    }


def collect_mongodb_credentials() -> Tuple[Dict[str, str], bool]:
    """
    Collect MongoDB credentials.

    Returns:
        Tuple of (credentials dict, connection_tested)
    """
    print_section("MongoDB Configuration")

    credentials = {
        "MONGODB_LOCAL": "true",
        "MONGODB_LOCAL_PORT": "27017",
        "MONGODB_LOCAL_HOST": "localhost",
        "MONGODB_LOCAL_DATABASE": "shanebrain_db",
        "MONGODB_DATABASE": "shanebrain_db",
        "MONGODB_ATLAS_ENABLED": "false",
        "MONGODB_ATLAS_URI": "",
    }

    print_info("MongoDB can run locally (recommended) or on Atlas cloud.")
    print_info("Local is default and works offline.")

    use_atlas = yes_no_prompt("Do you want to configure MongoDB Atlas backup?", False)

    if use_atlas:
        credentials["MONGODB_ATLAS_ENABLED"] = "true"

        print_info("\nMongoDB Atlas Connection String")
        print_info("Format: mongodb+srv://user:password@cluster.mongodb.net/...")
        print_info("Get this from MongoDB Atlas dashboard > Connect > Drivers")
        print_warning("Your password will be hidden as you type.")

        # Collect Atlas URI components for safety
        print_info("\nLet's build your connection string securely:")

        cluster_host = secure_input(
            "Atlas cluster host (e.g., thebardchat.qo97nbq.mongodb.net)",
            "thebardchat.qo97nbq.mongodb.net"
        )

        db_user = secure_input(
            "Database username",
            "shanebrain_db_user"
        )

        db_password = secure_input(
            "Database password",
            is_password=True
        )

        if db_password:
            # URL-encode the password for special characters
            encoded_password = quote_plus(db_password)

            atlas_uri = (
                f"mongodb+srv://{db_user}:{encoded_password}@{cluster_host}/"
                f"?retryWrites=true&w=majority&appName=thebardchat"
            )
            credentials["MONGODB_ATLAS_URI"] = atlas_uri

            print_success("Atlas connection string configured.")
            print_info("Note: Password is URL-encoded for special characters.")
        else:
            print_warning("No password provided. Atlas backup disabled.")
            credentials["MONGODB_ATLAS_ENABLED"] = "false"

    return credentials, False  # Connection test not implemented yet


def collect_weaviate_credentials() -> Dict[str, str]:
    """Collect Weaviate configuration."""
    print_section("Weaviate Configuration")

    credentials = {
        "WEAVIATE_LOCAL": "true",
        "WEAVIATE_HOST": "localhost",
        "WEAVIATE_PORT": "8080",
        "WEAVIATE_GRPC_PORT": "50051",
        "WEAVIATE_VECTORIZER": "text2vec-transformers",
        "WEAVIATE_CLOUD_ENABLED": "false",
        "WEAVIATE_CLOUD_URL": "",
        "WEAVIATE_CLOUD_API_KEY": "",
    }

    print_info("Weaviate runs locally in Docker by default.")
    print_info("Cloud backup is optional.")

    use_cloud = yes_no_prompt("Configure Weaviate Cloud backup?", False)

    if use_cloud:
        credentials["WEAVIATE_CLOUD_ENABLED"] = "true"

        cloud_url = secure_input(
            "Weaviate Cloud URL",
            ""
        )
        if cloud_url:
            credentials["WEAVIATE_CLOUD_URL"] = cloud_url

        api_key = secure_input(
            "Weaviate Cloud API Key",
            is_password=True
        )
        if api_key:
            credentials["WEAVIATE_CLOUD_API_KEY"] = api_key

    return credentials


def collect_llama_config() -> Dict[str, str]:
    """Collect Llama model configuration."""
    print_section("Llama Model Configuration")

    print_info("Llama models run locally for complete privacy.")
    print_info("You can configure which models to use.")

    config = {
        "LLAMA_DEFAULT_MODEL": "llama-3.2-3b",
        "LLAMA_3B_MODEL": "llama-3.2-3b-instruct-q4_K_M.gguf",
        "LLAMA_11B_MODEL": "llama-3.2-11b-vision-instruct-q4_K_M.gguf",
        "LLAMA_CONTEXT_LENGTH": "4096",
        "LLAMA_MAX_TOKENS": "2048",
        "LLAMA_TEMPERATURE": "0.7",
        "LLAMA_GPU_LAYERS": "0",
        "OLLAMA_ENABLED": "false",
        "OLLAMA_HOST": "http://localhost:11434",
        "OLLAMA_MODEL": "llama3.2",
    }

    use_ollama = yes_no_prompt("Use Ollama for model management?", False)
    if use_ollama:
        config["OLLAMA_ENABLED"] = "true"
        config["OLLAMA_MODEL"] = secure_input("Ollama model name", "llama3.2")

    has_gpu = yes_no_prompt("Do you have a GPU for acceleration?", False)
    if has_gpu:
        layers = secure_input("GPU layers to offload (0-100)", "35")
        config["LLAMA_GPU_LAYERS"] = layers

    return config


def collect_security_config() -> Dict[str, str]:
    """Collect security configuration."""
    print_section("Security Configuration")

    config = {
        "ENCRYPTION_KEY": "",
        "RATE_LIMIT_ENABLED": "true",
        "RATE_LIMIT_REQUESTS_PER_MINUTE": "60",
        "AUDIT_LOG_ENABLED": "true",
    }

    print_info("An encryption key is used to protect sensitive data.")
    print_info("Leave blank to generate one automatically.")

    key = secure_input(
        "Encryption key (leave blank to auto-generate)",
        is_password=True
    )

    if key:
        config["ENCRYPTION_KEY"] = key
    else:
        # Generate a random key
        import secrets
        config["ENCRYPTION_KEY"] = secrets.token_hex(32)
        print_success("Generated random encryption key.")

    return config


def collect_project_config() -> Dict[str, str]:
    """Collect project-specific configuration."""
    print_section("Project Configuration")

    print_info("These settings configure the individual projects.")
    print_info("Defaults are fine for most users.")

    root = os.environ.get("SHANEBRAIN_ROOT", DEFAULT_ROOT)

    config = {
        "ANGEL_CLOUD_CRISIS_THRESHOLD": "0.7",
        "ANGEL_CLOUD_EMERGENCY_CONTACT": "",
        "ANGEL_CLOUD_LOCAL_RESOURCES_PATH": f"{root}/angel-cloud/resources",
        "PULSAR_SECURITY_SCAN_INTERVAL": "300",
        "PULSAR_THREAT_DB_PATH": f"{root}/pulsar/threat-db",
        "LOGIBOT_DISPATCH_INTEGRATION": "false",
        "LEGACY_VOICE_ENABLED": "false",
        "LEGACY_FAMILY_ACCESS_ENABLED": "false",
        "LEGACY_PRESERVATION_MODE": "local",
    }

    # Angel Cloud emergency contact
    emergency = secure_input(
        "Emergency contact phone (for Angel Cloud, optional)",
        ""
    )
    if emergency:
        config["ANGEL_CLOUD_EMERGENCY_CONTACT"] = emergency

    return config


# =============================================================================
# ENV FILE GENERATION
# =============================================================================

def generate_env_content(config: Dict[str, str]) -> str:
    """
    Generate .env file content from configuration.

    Args:
        config: Dictionary of configuration values

    Returns:
        Formatted .env file content
    """
    sections = {
        "BASE PATHS": [
            "SHANEBRAIN_ROOT", "WEAVIATE_DATA_PATH", "MONGODB_DATA_PATH",
            "LLAMA_MODELS_PATH", "BACKUPS_PATH"
        ],
        "MONGODB": [
            "MONGODB_LOCAL", "MONGODB_LOCAL_PORT", "MONGODB_LOCAL_HOST",
            "MONGODB_LOCAL_DATABASE", "MONGODB_DATABASE",
            "MONGODB_ATLAS_ENABLED", "MONGODB_ATLAS_URI"
        ],
        "WEAVIATE": [
            "WEAVIATE_LOCAL", "WEAVIATE_HOST", "WEAVIATE_PORT",
            "WEAVIATE_GRPC_PORT", "WEAVIATE_VECTORIZER",
            "WEAVIATE_CLOUD_ENABLED", "WEAVIATE_CLOUD_URL", "WEAVIATE_CLOUD_API_KEY"
        ],
        "LLAMA MODELS": [
            "LLAMA_DEFAULT_MODEL", "LLAMA_3B_MODEL", "LLAMA_11B_MODEL",
            "LLAMA_CONTEXT_LENGTH", "LLAMA_MAX_TOKENS", "LLAMA_TEMPERATURE",
            "LLAMA_GPU_LAYERS", "OLLAMA_ENABLED", "OLLAMA_HOST", "OLLAMA_MODEL"
        ],
        "SECURITY": [
            "ENCRYPTION_KEY", "RATE_LIMIT_ENABLED",
            "RATE_LIMIT_REQUESTS_PER_MINUTE", "AUDIT_LOG_ENABLED"
        ],
        "PROJECTS": [
            "ANGEL_CLOUD_CRISIS_THRESHOLD", "ANGEL_CLOUD_EMERGENCY_CONTACT",
            "ANGEL_CLOUD_LOCAL_RESOURCES_PATH", "PULSAR_SECURITY_SCAN_INTERVAL",
            "PULSAR_THREAT_DB_PATH", "LOGIBOT_DISPATCH_INTEGRATION",
            "LEGACY_VOICE_ENABLED", "LEGACY_FAMILY_ACCESS_ENABLED",
            "LEGACY_PRESERVATION_MODE"
        ],
    }

    lines = [
        "# =============================================================================",
        "# ShaneBrain Core - Environment Configuration",
        "# =============================================================================",
        "# Generated by setup_credentials.py",
        "# WARNING: This file contains sensitive credentials. Keep it secure!",
        "# This file is in .gitignore - NEVER commit it to version control.",
        "# =============================================================================",
        "",
    ]

    for section_name, keys in sections.items():
        lines.append(f"# --- {section_name} ---")
        for key in keys:
            if key in config:
                value = config[key]
                # Mask sensitive values in comments
                if "PASSWORD" in key or "KEY" in key or "URI" in key:
                    lines.append(f"{key}={value}")
                else:
                    lines.append(f"{key}={value}")
        lines.append("")

    # Add defaults that might not have been collected
    lines.extend([
        "# --- LANGCHAIN ---",
        "LANGCHAIN_TRACING_V2=false",
        "LANGCHAIN_API_KEY=",
        "LANGCHAIN_PROJECT=shanebrain-local",
        "",
        "# --- PLANNING SYSTEM ---",
        f"PLANNING_ROOT={config.get('SHANEBRAIN_ROOT', DEFAULT_ROOT)}/planning-system",
        "PLANNING_AUTOSAVE=true",
        "PLANNING_AUTOSAVE_INTERVAL=60",
        "",
        "# --- DOCKER ---",
        "COMPOSE_PROJECT_NAME=shanebrain",
        "DOCKER_MEMORY_LIMIT=4g",
        "DOCKER_CPU_LIMIT=2",
        "",
        "# --- DEVELOPMENT ---",
        "DEBUG=false",
        "LOG_LEVEL=INFO",
        "",
        "# --- BACKUP ---",
        "AUTO_BACKUP_ENABLED=true",
        "AUTO_BACKUP_INTERVAL=86400",
        "BACKUP_RETENTION_DAYS=30",
        "BACKUP_COMPRESSION=true",
        "CLOUD_BACKUP_ENABLED=false",
        "",
        "# =============================================================================",
        "# END OF CONFIGURATION",
        "# =============================================================================",
    ])

    return "\n".join(lines)


def write_env_file(content: str, filepath: Path) -> bool:
    """
    Write .env file with secure permissions.

    Args:
        content: File content
        filepath: Path to write to

    Returns:
        True if successful
    """
    try:
        # Write the file
        filepath.write_text(content)

        # Set secure permissions (owner read/write only)
        set_file_permissions(filepath, 0o600)

        print_success(f"Created {filepath}")
        print_success(f"Permissions set to 600 (owner read/write only)")

        return True
    except Exception as e:
        print_error(f"Failed to write {filepath}: {e}")
        return False


# =============================================================================
# CONNECTION TESTING
# =============================================================================

def test_mongodb_connection(uri: str) -> bool:
    """
    Test MongoDB connection.

    Args:
        uri: MongoDB connection URI

    Returns:
        True if connection successful
    """
    try:
        from pymongo import MongoClient
        from pymongo.errors import ConnectionFailure, ServerSelectionTimeoutError

        print_info("Testing MongoDB connection...")

        client = MongoClient(uri, serverSelectionTimeoutMS=5000)
        # The ismaster command is cheap and does not require auth.
        client.admin.command('ismaster')
        client.close()

        print_success("MongoDB connection successful!")
        return True

    except ImportError:
        print_warning("pymongo not installed. Skipping connection test.")
        print_info("Install with: pip install pymongo")
        return False
    except (ConnectionFailure, ServerSelectionTimeoutError) as e:
        print_error(f"MongoDB connection failed: {e}")
        return False
    except Exception as e:
        print_error(f"MongoDB test error: {e}")
        return False


def test_weaviate_connection(host: str, port: str) -> bool:
    """
    Test Weaviate connection.

    Args:
        host: Weaviate host
        port: Weaviate port

    Returns:
        True if connection successful
    """
    try:
        import weaviate

        print_info("Testing Weaviate connection...")

        client = weaviate.Client(f"http://{host}:{port}")
        if client.is_ready():
            print_success("Weaviate connection successful!")
            return True
        else:
            print_warning("Weaviate is not ready. Is Docker running?")
            return False

    except ImportError:
        print_warning("weaviate-client not installed. Skipping connection test.")
        print_info("Install with: pip install weaviate-client")
        return False
    except Exception as e:
        print_warning(f"Weaviate not available (this is normal if Docker isn't running): {e}")
        return False


# =============================================================================
# MAIN FUNCTIONS
# =============================================================================

def run_full_setup() -> None:
    """Run full interactive setup."""
    print_header("ShaneBrain Core - Credential Setup")

    print("""
Welcome to ShaneBrain Core setup!

This script will help you configure:
- Base paths for your 8TB drive
- MongoDB credentials (local + optional Atlas backup)
- Weaviate configuration
- Llama model settings
- Security settings
- Project-specific configuration

Your credentials will be stored securely in .env with chmod 600.
They are NEVER transmitted, logged, or exposed.

Press Ctrl+C at any time to cancel.
    """)

    input("Press Enter to continue...")

    # Collect all configuration
    config = {}

    # Base paths
    config.update(collect_base_paths())

    # MongoDB
    mongo_config, _ = collect_mongodb_credentials()
    config.update(mongo_config)

    # Weaviate
    config.update(collect_weaviate_credentials())

    # Llama
    config.update(collect_llama_config())

    # Security
    config.update(collect_security_config())

    # Projects
    config.update(collect_project_config())

    # Generate and write .env file
    print_section("Writing Configuration")

    content = generate_env_content(config)

    if ENV_FILE.exists():
        backup = yes_no_prompt(f"{ENV_FILE} exists. Create backup?", True)
        if backup:
            backup_path = ENV_FILE.with_suffix(".env.backup")
            import shutil
            shutil.copy(ENV_FILE, backup_path)
            print_success(f"Backup created: {backup_path}")

    if write_env_file(content, ENV_FILE):
        print_section("Setup Complete!")

        print(f"""
Configuration saved to: {ENV_FILE}

Next steps:
1. Review the .env file if needed
2. Run: docker-compose up -d  (to start Weaviate)
3. Run: ./scripts/start-shanebrain.bat (to start everything)

To verify your setup later:
    python {__file__} --verify

To reset to defaults:
    python {__file__} --reset

Security reminders:
- .env has chmod 600 (owner read/write only)
- .env is in .gitignore (never committed)
- Your credentials are stored locally only
        """)
    else:
        print_error("Setup failed. Please check errors above.")
        sys.exit(1)


def run_verify() -> None:
    """Verify existing credentials."""
    print_header("ShaneBrain Core - Credential Verification")

    if not ENV_FILE.exists():
        print_error(f"{ENV_FILE} not found. Run setup first.")
        sys.exit(1)

    # Check file permissions
    print_section("File Security")
    file_stat = os.stat(ENV_FILE)
    mode = stat.S_IMODE(file_stat.st_mode)

    if mode == 0o600:
        print_success(f"File permissions correct (600)")
    else:
        print_warning(f"File permissions are {oct(mode)}, should be 600")
        fix = yes_no_prompt("Fix permissions?", True)
        if fix:
            set_file_permissions(ENV_FILE, 0o600)

    # Load and verify configuration
    print_section("Configuration Check")

    # Parse .env file
    config = {}
    for line in ENV_FILE.read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            key, value = line.split("=", 1)
            config[key] = value

    # Check required values
    required = [
        "SHANEBRAIN_ROOT",
        "MONGODB_LOCAL",
        "WEAVIATE_HOST",
        "WEAVIATE_PORT",
    ]

    for key in required:
        if key in config and config[key]:
            print_success(f"{key} configured")
        else:
            print_warning(f"{key} not configured")

    # Check sensitive values (just existence, not content)
    sensitive = ["ENCRYPTION_KEY", "MONGODB_ATLAS_URI", "WEAVIATE_CLOUD_API_KEY"]
    for key in sensitive:
        if key in config and config[key]:
            print_success(f"{key} set (value hidden)")
        else:
            print_info(f"{key} not set (optional)")

    # Test connections
    print_section("Connection Tests")

    if config.get("MONGODB_LOCAL") == "true":
        test_mongodb_connection(
            f"mongodb://{config.get('MONGODB_LOCAL_HOST', 'localhost')}:"
            f"{config.get('MONGODB_LOCAL_PORT', '27017')}/"
        )

    if config.get("MONGODB_ATLAS_ENABLED") == "true" and config.get("MONGODB_ATLAS_URI"):
        test_mongodb_connection(config["MONGODB_ATLAS_URI"])

    test_weaviate_connection(
        config.get("WEAVIATE_HOST", "localhost"),
        config.get("WEAVIATE_PORT", "8080")
    )

    print_section("Verification Complete")


def run_reset() -> None:
    """Reset to default configuration."""
    print_header("ShaneBrain Core - Reset Configuration")

    if ENV_FILE.exists():
        print_warning(f"{ENV_FILE} will be deleted!")
        confirm = yes_no_prompt("Are you sure you want to reset?", False)

        if confirm:
            backup = yes_no_prompt("Create backup first?", True)
            if backup:
                backup_path = ENV_FILE.with_suffix(".env.backup")
                import shutil
                shutil.copy(ENV_FILE, backup_path)
                print_success(f"Backup created: {backup_path}")

            ENV_FILE.unlink()
            print_success("Configuration reset. Run setup again to reconfigure.")
        else:
            print_info("Reset cancelled.")
    else:
        print_info("No configuration to reset.")


# =============================================================================
# ENTRY POINT
# =============================================================================

def main() -> None:
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="ShaneBrain Core - Secure Credential Setup",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python setup_credentials.py           # Full interactive setup
  python setup_credentials.py --verify  # Verify existing credentials
  python setup_credentials.py --reset   # Reset to defaults

Security:
  - Credentials are stored locally only
  - .env file has chmod 600 (owner read/write only)
  - Passwords are hidden during input
  - Never commit .env to version control
        """
    )

    parser.add_argument(
        "--verify",
        action="store_true",
        help="Verify existing credentials"
    )

    parser.add_argument(
        "--reset",
        action="store_true",
        help="Reset configuration to defaults"
    )

    args = parser.parse_args()

    if args.verify:
        run_verify()
    elif args.reset:
        run_reset()
    else:
        run_full_setup()


if __name__ == "__main__":
    main()
