#!/bin/bash
# =============================================================================
# ShaneBrain Core - Offline Mode
# =============================================================================
#
# Runs ShaneBrain in completely offline mode:
# - Disables all cloud connections
# - Uses only local Weaviate and MongoDB
# - Uses local Llama models
# - No internet required
#
# Usage:
#   ./offline-mode.sh start    # Start offline mode
#   ./offline-mode.sh stop     # Stop services
#   ./offline-mode.sh status   # Check status
#
# Author: Shane Brazelton
# =============================================================================

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# =============================================================================
# Helper Functions
# =============================================================================

print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}\n"
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

# =============================================================================
# Offline Mode Functions
# =============================================================================

create_offline_env() {
    print_step "Creating offline environment configuration..."

    # Create offline .env overrides
    cat > "$PROJECT_ROOT/.env.offline" << 'EOF'
# =============================================================================
# ShaneBrain Offline Mode Configuration
# =============================================================================
# This file overrides settings for offline operation
# Source this AFTER .env: source .env && source .env.offline
# =============================================================================

# Disable all cloud services
MONGODB_ATLAS_ENABLED=false
MONGODB_ATLAS_URI=
WEAVIATE_CLOUD_ENABLED=false
WEAVIATE_CLOUD_URL=
WEAVIATE_CLOUD_API_KEY=

# Force local mode
MONGODB_LOCAL=true
WEAVIATE_LOCAL=true

# Disable telemetry/tracing
LANGCHAIN_TRACING_V2=false
LANGCHAIN_API_KEY=

# Disable cloud backup
CLOUD_BACKUP_ENABLED=false

# Use local Llama (not Ollama cloud)
OLLAMA_ENABLED=false

# Offline indicator
SHANEBRAIN_OFFLINE_MODE=true
EOF

    print_success "Offline configuration created: .env.offline"
}

start_offline() {
    print_header "Starting ShaneBrain Offline Mode"

    # Check if Docker is running
    if ! docker info &> /dev/null; then
        print_error "Docker is not running. Please start Docker first."
        exit 1
    fi

    # Create offline env if not exists
    if [ ! -f "$PROJECT_ROOT/.env.offline" ]; then
        create_offline_env
    fi

    # Load environment
    if [ -f "$PROJECT_ROOT/.env" ]; then
        export $(grep -v '^#' "$PROJECT_ROOT/.env" | xargs)
    fi
    export $(grep -v '^#' "$PROJECT_ROOT/.env.offline" | xargs)

    # Start Weaviate
    print_step "Starting Weaviate (local mode)..."
    cd "$PROJECT_ROOT/weaviate-config"
    docker-compose up -d

    # Wait for Weaviate
    print_step "Waiting for Weaviate to be ready..."
    for i in {1..30}; do
        if curl -s http://localhost:8080/v1/.well-known/ready > /dev/null 2>&1; then
            print_success "Weaviate is ready"
            break
        fi
        echo -n "."
        sleep 2
    done
    echo ""

    cd "$PROJECT_ROOT"

    # Check for local MongoDB (optional)
    print_step "Checking local MongoDB..."
    if docker ps | grep -q mongo; then
        print_success "MongoDB container running"
    elif command -v mongod &> /dev/null; then
        print_success "Local MongoDB available"
    else
        print_warning "No local MongoDB found (optional for basic usage)"
    fi

    # Check for Llama models
    print_step "Checking Llama models..."
    MODELS_DIR="${LLAMA_MODELS_PATH:-$PROJECT_ROOT/llama-configs/models}"
    if [ -d "$MODELS_DIR" ] && [ "$(ls -A $MODELS_DIR 2>/dev/null)" ]; then
        model_count=$(find "$MODELS_DIR" -name "*.gguf" -o -name "*.bin" 2>/dev/null | wc -l)
        print_success "$model_count model(s) available"
    else
        print_warning "No Llama models found. Download with: ./scripts/download-models.sh"
    fi

    # Display status
    print_header "Offline Mode Active"
    echo -e "
${GREEN}ShaneBrain is running in OFFLINE MODE${NC}

Services:
  - Weaviate: http://localhost:8080
  - MongoDB:  localhost:27017 (if available)

No internet connection required.

To stop: $0 stop
To check status: $0 status

${BLUE}All data stays on your local drive.${NC}
"
}

stop_offline() {
    print_header "Stopping ShaneBrain Offline Mode"

    print_step "Stopping Weaviate..."
    cd "$PROJECT_ROOT/weaviate-config"
    docker-compose down
    cd "$PROJECT_ROOT"

    print_success "Services stopped"
}

check_status() {
    print_header "ShaneBrain Offline Status"

    # Check Weaviate
    echo -n "Weaviate: "
    if curl -s http://localhost:8080/v1/.well-known/ready > /dev/null 2>&1; then
        echo -e "${GREEN}ONLINE${NC}"
    else
        echo -e "${RED}OFFLINE${NC}"
    fi

    # Check MongoDB
    echo -n "MongoDB:  "
    if docker ps | grep -q mongo 2>/dev/null || nc -z localhost 27017 2>/dev/null; then
        echo -e "${GREEN}ONLINE${NC}"
    else
        echo -e "${YELLOW}NOT RUNNING${NC}"
    fi

    # Check offline mode
    echo -n "Mode:     "
    if [ -f "$PROJECT_ROOT/.env.offline" ]; then
        echo -e "${GREEN}OFFLINE CONFIGURED${NC}"
    else
        echo -e "${YELLOW}STANDARD MODE${NC}"
    fi

    # Check models
    echo -n "Models:   "
    MODELS_DIR="${LLAMA_MODELS_PATH:-$PROJECT_ROOT/llama-configs/models}"
    if [ -d "$MODELS_DIR" ] && [ "$(ls -A $MODELS_DIR 2>/dev/null)" ]; then
        model_count=$(find "$MODELS_DIR" -name "*.gguf" -o -name "*.bin" 2>/dev/null | wc -l)
        echo -e "${GREEN}$model_count available${NC}"
    else
        echo -e "${YELLOW}NONE${NC}"
    fi

    # Docker containers
    echo ""
    echo "Docker Containers:"
    docker ps --filter "name=shanebrain" --format "  {{.Names}}: {{.Status}}" 2>/dev/null || echo "  None running"
}

# =============================================================================
# Main
# =============================================================================

case "${1:-status}" in
    start)
        start_offline
        ;;
    stop)
        stop_offline
        ;;
    status)
        check_status
        ;;
    *)
        echo "Usage: $0 {start|stop|status}"
        echo ""
        echo "Commands:"
        echo "  start   - Start ShaneBrain in offline mode"
        echo "  stop    - Stop all services"
        echo "  status  - Check current status"
        exit 1
        ;;
esac
