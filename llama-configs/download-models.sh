#!/bin/bash
# =============================================================================
# ShaneBrain Core - Llama Model Download Script
# =============================================================================
#
# Downloads Llama models for local inference.
# Models are stored on your 8TB drive for offline use.
#
# Usage:
#   ./download-models.sh              # Interactive selection
#   ./download-models.sh 3b           # Download 3B model
#   ./download-models.sh 11b          # Download 11B model
#   ./download-models.sh all          # Download all models
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

# Load environment
if [ -f "$PROJECT_ROOT/../.env" ]; then
    export $(grep -v '^#' "$PROJECT_ROOT/../.env" | xargs 2>/dev/null) || true
fi

MODELS_DIR="${LLAMA_MODELS_PATH:-$SCRIPT_DIR/models}"

# Model URLs (Hugging Face)
# Using quantized GGUF models for efficiency
declare -A MODELS=(
    ["3b"]="https://huggingface.co/TheBloke/Llama-2-3B-GGUF/resolve/main/llama-2-3b.Q4_K_M.gguf"
    ["7b"]="https://huggingface.co/TheBloke/Llama-2-7B-GGUF/resolve/main/llama-2-7b.Q4_K_M.gguf"
    ["13b"]="https://huggingface.co/TheBloke/Llama-2-13B-GGUF/resolve/main/llama-2-13b.Q4_K_M.gguf"
)

# Model sizes (approximate)
declare -A SIZES=(
    ["3b"]="2.0 GB"
    ["7b"]="4.0 GB"
    ["13b"]="7.5 GB"
)

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

check_disk_space() {
    local required_gb=$1
    local available_gb=$(df -BG "$MODELS_DIR" | tail -1 | awk '{print $4}' | tr -d 'G')

    if [ "$available_gb" -lt "$required_gb" ]; then
        print_error "Not enough disk space. Need ${required_gb}GB, have ${available_gb}GB"
        return 1
    fi
    return 0
}

download_model() {
    local model_id=$1
    local url=${MODELS[$model_id]}
    local size=${SIZES[$model_id]}
    local filename=$(basename "$url")
    local filepath="$MODELS_DIR/$filename"

    if [ -z "$url" ]; then
        print_error "Unknown model: $model_id"
        return 1
    fi

    print_header "Downloading Llama $model_id Model"

    # Check if already exists
    if [ -f "$filepath" ]; then
        print_warning "Model already exists: $filename"
        read -p "Re-download? (y/N): " confirm
        if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
            return 0
        fi
    fi

    print_step "Model: $model_id"
    print_step "Size: $size (approximate)"
    print_step "Destination: $filepath"
    echo ""

    # Create directory
    mkdir -p "$MODELS_DIR"

    # Download with progress
    print_step "Downloading..."

    if command -v wget &> /dev/null; then
        wget -c -O "$filepath" "$url"
    elif command -v curl &> /dev/null; then
        curl -L -C - -o "$filepath" "$url"
    else
        print_error "Neither wget nor curl found. Please install one."
        return 1
    fi

    if [ -f "$filepath" ]; then
        print_success "Downloaded: $filename"
        print_success "Location: $filepath"
    else
        print_error "Download failed"
        return 1
    fi
}

list_models() {
    print_header "Available Models"

    echo "Models that can be downloaded:"
    echo ""
    for model in "${!MODELS[@]}"; do
        echo "  $model - ${SIZES[$model]}"
    done
    echo ""

    print_header "Installed Models"

    if [ -d "$MODELS_DIR" ]; then
        local count=$(find "$MODELS_DIR" -name "*.gguf" -o -name "*.bin" 2>/dev/null | wc -l)
        if [ "$count" -gt 0 ]; then
            echo "Found $count model(s):"
            echo ""
            find "$MODELS_DIR" -name "*.gguf" -o -name "*.bin" 2>/dev/null | while read -r f; do
                local size=$(du -h "$f" | cut -f1)
                echo "  $(basename "$f") ($size)"
            done
        else
            echo "No models installed yet."
        fi
    else
        echo "Models directory not found: $MODELS_DIR"
    fi
}

interactive_menu() {
    print_header "Llama Model Download"

    echo "Select a model to download:"
    echo ""
    echo "  [1] 3B  - Fast, lower quality (${SIZES[3b]})"
    echo "  [2] 7B  - Balanced (${SIZES[7b]})"
    echo "  [3] 13B - Best quality, slower (${SIZES[13b]})"
    echo "  [4] All - Download all models"
    echo "  [5] List installed models"
    echo "  [6] Exit"
    echo ""
    read -p "Select option: " choice

    case $choice in
        1) download_model "3b" ;;
        2) download_model "7b" ;;
        3) download_model "13b" ;;
        4)
            download_model "3b"
            download_model "7b"
            download_model "13b"
            ;;
        5) list_models ;;
        6) exit 0 ;;
        *) print_error "Invalid option" ;;
    esac
}

# =============================================================================
# Alternative: Use Ollama
# =============================================================================

setup_ollama() {
    print_header "Ollama Setup (Alternative)"

    echo "Ollama provides an easier way to manage local LLMs."
    echo ""

    if command -v ollama &> /dev/null; then
        print_success "Ollama is installed"
        echo ""
        echo "To download Llama 3.2:"
        echo "  ollama pull llama3.2"
        echo ""
        echo "To run:"
        echo "  ollama run llama3.2"
    else
        echo "Ollama is not installed. To install:"
        echo ""
        echo "  Linux/WSL:"
        echo "    curl -fsSL https://ollama.com/install.sh | sh"
        echo ""
        echo "  macOS:"
        echo "    brew install ollama"
        echo ""
        echo "  Windows:"
        echo "    Download from https://ollama.com/download"
    fi
}

# =============================================================================
# Main
# =============================================================================

print_header "ShaneBrain Model Downloader"
echo "Models directory: $MODELS_DIR"

case "${1:-}" in
    3b|7b|13b)
        download_model "$1"
        ;;
    all)
        download_model "3b"
        download_model "7b"
        download_model "13b"
        ;;
    list)
        list_models
        ;;
    ollama)
        setup_ollama
        ;;
    "")
        interactive_menu
        ;;
    *)
        echo "Usage: $0 {3b|7b|13b|all|list|ollama}"
        echo ""
        echo "Options:"
        echo "  3b      - Download 3B parameter model"
        echo "  7b      - Download 7B parameter model"
        echo "  13b     - Download 13B parameter model"
        echo "  all     - Download all models"
        echo "  list    - List installed models"
        echo "  ollama  - Show Ollama setup instructions"
        exit 1
        ;;
esac

echo ""
print_success "Done!"
