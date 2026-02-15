#!/bin/bash
# =============================================================================
# ShaneBrain Core - Setup Script
# =============================================================================
#
# This script sets up the complete ShaneBrain environment:
# - Creates directory structure
# - Installs Python dependencies
# - Sets up Docker containers
# - Initializes databases
# - Downloads models (optional)
#
# Usage:
#   chmod +x setup.sh
#   ./setup.sh
#
# Author: Shane Brazelton
# =============================================================================

set -e  # Exit on error

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SHANEBRAIN_ROOT="${SHANEBRAIN_ROOT:-/mnt/8TB/ShaneBrain-Core}"

# =============================================================================
# Helper Functions
# =============================================================================

print_header() {
    echo -e "\n${BLUE}============================================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}============================================================${NC}\n"
}

print_step() {
    echo -e "${YELLOW}[*]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

check_command() {
    if command -v "$1" &> /dev/null; then
        print_success "$1 is installed"
        return 0
    else
        print_error "$1 is not installed"
        return 1
    fi
}

# =============================================================================
# Main Setup
# =============================================================================

print_header "ShaneBrain Core - Setup"

echo "This script will set up your ShaneBrain environment."
echo ""
echo "Configuration:"
echo "  Project Root: $PROJECT_ROOT"
echo "  Data Root:    $SHANEBRAIN_ROOT"
echo ""
read -p "Press Enter to continue or Ctrl+C to cancel..."

# =============================================================================
# Step 1: Check Prerequisites
# =============================================================================

print_header "Step 1: Checking Prerequisites"

MISSING_DEPS=0

print_step "Checking Python..."
if check_command python3; then
    PYTHON_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2)
    echo "         Version: $PYTHON_VERSION"
else
    MISSING_DEPS=1
fi

print_step "Checking Docker..."
if check_command docker; then
    if docker info &> /dev/null; then
        print_success "Docker daemon is running"
    else
        print_warning "Docker is installed but daemon is not running"
        print_warning "Please start Docker and re-run setup"
        MISSING_DEPS=1
    fi
else
    MISSING_DEPS=1
fi

print_step "Checking docker-compose..."
check_command docker-compose || MISSING_DEPS=1

print_step "Checking git..."
check_command git || MISSING_DEPS=1

print_step "Checking curl..."
check_command curl || MISSING_DEPS=1

if [ $MISSING_DEPS -eq 1 ]; then
    print_error "Missing dependencies. Please install them and re-run setup."
    exit 1
fi

print_success "All prerequisites met!"

# =============================================================================
# Step 2: Create Directory Structure
# =============================================================================

print_header "Step 2: Creating Directory Structure"

DIRECTORIES=(
    "$SHANEBRAIN_ROOT"
    "$SHANEBRAIN_ROOT/weaviate-config/data"
    "$SHANEBRAIN_ROOT/weaviate-config/backups"
    "$SHANEBRAIN_ROOT/mongodb-data"
    "$SHANEBRAIN_ROOT/llama-configs/models"
    "$SHANEBRAIN_ROOT/backups"
    "$SHANEBRAIN_ROOT/logs"
    "$SHANEBRAIN_ROOT/planning-system/active-projects"
    "$SHANEBRAIN_ROOT/planning-system/completed-projects"
)

for dir in "${DIRECTORIES[@]}"; do
    if [ ! -d "$dir" ]; then
        print_step "Creating $dir"
        mkdir -p "$dir"
        print_success "Created $dir"
    else
        print_success "$dir already exists"
    fi
done

# =============================================================================
# Step 3: Set Up Python Environment
# =============================================================================

print_header "Step 3: Setting Up Python Environment"

print_step "Creating virtual environment..."
if [ ! -d "$PROJECT_ROOT/venv" ]; then
    python3 -m venv "$PROJECT_ROOT/venv"
    print_success "Virtual environment created"
else
    print_success "Virtual environment already exists"
fi

print_step "Activating virtual environment..."
source "$PROJECT_ROOT/venv/bin/activate"

print_step "Upgrading pip..."
pip install --upgrade pip

print_step "Installing Python dependencies..."
cat > "$PROJECT_ROOT/requirements.txt" << 'EOF'
# ShaneBrain Core Dependencies
# ============================

# LangChain ecosystem
langchain>=0.1.0
langchain-community>=0.0.10
langchain-core>=0.1.0

# Vector database
weaviate-client>=4.0.0

# MongoDB
pymongo>=4.0.0

# Local LLM
llama-cpp-python>=0.2.0

# Utilities
python-dotenv>=1.0.0
pyyaml>=6.0.0
requests>=2.31.0
tqdm>=4.65.0

# Optional: Ollama integration
# ollama>=0.1.0

# Development
pytest>=7.0.0
black>=23.0.0
EOF

pip install -r "$PROJECT_ROOT/requirements.txt"
print_success "Python dependencies installed"

# =============================================================================
# Step 4: Set Up Environment File
# =============================================================================

print_header "Step 4: Setting Up Environment"

if [ ! -f "$PROJECT_ROOT/.env" ]; then
    print_step "Creating .env from template..."
    if [ -f "$PROJECT_ROOT/.env.template" ]; then
        cp "$PROJECT_ROOT/.env.template" "$PROJECT_ROOT/.env"
        # Update the root path
        sed -i "s|SHANEBRAIN_ROOT=.*|SHANEBRAIN_ROOT=$SHANEBRAIN_ROOT|g" "$PROJECT_ROOT/.env"
        chmod 600 "$PROJECT_ROOT/.env"
        print_success ".env created with secure permissions"
        print_warning "Please edit .env to add your credentials"
    else
        print_error ".env.template not found!"
    fi
else
    print_success ".env already exists"
fi

# =============================================================================
# Step 5: Start Docker Services
# =============================================================================

print_header "Step 5: Starting Docker Services"

print_step "Starting Weaviate..."
cd "$PROJECT_ROOT/weaviate-config"

# Create data directory symlink if using external drive
if [ "$SHANEBRAIN_ROOT" != "$PROJECT_ROOT" ]; then
    if [ ! -L "$PROJECT_ROOT/weaviate-config/data" ]; then
        print_step "Linking Weaviate data to $SHANEBRAIN_ROOT..."
        rm -rf "$PROJECT_ROOT/weaviate-config/data"
        ln -s "$SHANEBRAIN_ROOT/weaviate-config/data" "$PROJECT_ROOT/weaviate-config/data"
    fi
fi

docker-compose up -d

print_step "Waiting for Weaviate to be ready..."
for i in {1..30}; do
    if curl -s http://localhost:8080/v1/.well-known/ready > /dev/null 2>&1; then
        print_success "Weaviate is ready!"
        break
    fi
    echo -n "."
    sleep 2
done
echo ""

cd "$PROJECT_ROOT"

# =============================================================================
# Step 6: Initialize Weaviate Schemas
# =============================================================================

print_header "Step 6: Initializing Weaviate Schemas"

print_step "Creating Weaviate schemas..."

# Create schema initialization script
python3 << 'PYTHON_SCRIPT'
import json
import sys
from pathlib import Path

try:
    import weaviate
except ImportError:
    print("Warning: weaviate-client not installed. Skipping schema creation.")
    sys.exit(0)

try:
    client = weaviate.Client("http://localhost:8080")
    if not client.is_ready():
        print("Warning: Weaviate not ready. Skipping schema creation.")
        sys.exit(0)

    schema_dir = Path("weaviate-config/schemas")
    for schema_file in schema_dir.glob("*.json"):
        with open(schema_file) as f:
            schema = json.load(f)

        class_name = schema.get("class")
        if class_name:
            # Check if class already exists
            existing = client.schema.get()
            class_exists = any(c["class"] == class_name for c in existing.get("classes", []))

            if not class_exists:
                client.schema.create_class(schema)
                print(f"[OK] Created schema: {class_name}")
            else:
                print(f"[OK] Schema already exists: {class_name}")

    print("[OK] All schemas initialized")

except Exception as e:
    print(f"Warning: Schema initialization failed: {e}")
PYTHON_SCRIPT

# =============================================================================
# Step 7: Copy Planning Files
# =============================================================================

print_header "Step 7: Setting Up Planning System"

# Copy planning files to data root if different
if [ "$SHANEBRAIN_ROOT" != "$PROJECT_ROOT" ]; then
    print_step "Copying planning templates to $SHANEBRAIN_ROOT..."
    cp -r "$PROJECT_ROOT/planning-system/templates" "$SHANEBRAIN_ROOT/planning-system/"
    cp "$PROJECT_ROOT/planning-system/SKILL.md" "$SHANEBRAIN_ROOT/planning-system/"
    print_success "Planning templates copied"
fi

# =============================================================================
# Step 8: Verify Installation
# =============================================================================

print_header "Step 8: Verifying Installation"

print_step "Running health check..."
python3 "$PROJECT_ROOT/scripts/health_check.py" || true

# =============================================================================
# Complete
# =============================================================================

print_header "Setup Complete!"

echo -e "
${GREEN}ShaneBrain Core has been set up successfully!${NC}

Next steps:
1. Edit .env file with your credentials:
   ${YELLOW}nano $PROJECT_ROOT/.env${NC}

2. (Optional) Download Llama models:
   ${YELLOW}./scripts/download-models.sh${NC}

3. Start ShaneBrain:
   ${YELLOW}./scripts/start-shanebrain.bat${NC}  (Windows)
   ${YELLOW}python langchain-chains/shanebrain_agent.py${NC}  (Direct)

4. Create your first project:
   ${YELLOW}cp planning-system/templates/angel-cloud-template.md planning-system/active-projects/task_plan.md${NC}

For help:
- Documentation: docs/setup.md
- Health check:  python scripts/health_check.py
- Logs:          docker-compose logs -f (in weaviate-config/)

${BLUE}Remember: Progress, not perfection!${NC}
"
