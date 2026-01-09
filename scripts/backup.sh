#!/bin/bash
# =============================================================================
# ShaneBrain Core - Backup Script
# =============================================================================
#
# Backs up all ShaneBrain data:
# - Weaviate vector database
# - MongoDB data
# - Planning files
# - Configuration
#
# Usage:
#   ./backup.sh                  # Full backup
#   ./backup.sh weaviate         # Weaviate only
#   ./backup.sh planning         # Planning files only
#   ./backup.sh restore [name]   # Restore from backup
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
if [ -f "$PROJECT_ROOT/.env" ]; then
    export $(grep -v '^#' "$PROJECT_ROOT/.env" | xargs)
fi

SHANEBRAIN_ROOT="${SHANEBRAIN_ROOT:-/mnt/8TB/ShaneBrain-Core}"
BACKUP_DIR="${BACKUPS_PATH:-$SHANEBRAIN_ROOT/backups}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

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

# =============================================================================
# Backup Functions
# =============================================================================

backup_weaviate() {
    print_header "Backing up Weaviate"

    local backup_name="weaviate-backup-$TIMESTAMP"
    local backup_path="$BACKUP_DIR/$backup_name"

    print_step "Creating backup: $backup_name"

    # Use Weaviate backup API
    curl -s -X POST \
        "http://localhost:8080/v1/backups/filesystem" \
        -H "Content-Type: application/json" \
        -d "{\"id\": \"$backup_name\", \"include\": []}" \
        > /dev/null 2>&1

    if [ $? -eq 0 ]; then
        # Wait for backup to complete
        print_step "Waiting for backup to complete..."
        sleep 5

        # Check backup status
        status=$(curl -s "http://localhost:8080/v1/backups/filesystem/$backup_name" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)

        if [ "$status" = "SUCCESS" ]; then
            print_success "Weaviate backup created: $backup_name"
        else
            print_error "Backup status: $status"
        fi
    else
        # Fallback: copy data directory
        print_step "API backup failed, copying data directory..."
        mkdir -p "$backup_path"
        cp -r "$PROJECT_ROOT/weaviate-config/data" "$backup_path/"
        print_success "Weaviate data copied to: $backup_path"
    fi
}

backup_mongodb() {
    print_header "Backing up MongoDB"

    local backup_name="mongodb-backup-$TIMESTAMP"
    local backup_path="$BACKUP_DIR/$backup_name"

    print_step "Creating backup: $backup_name"
    mkdir -p "$backup_path"

    # Check if mongodump is available
    if command -v mongodump &> /dev/null; then
        mongodump --uri="mongodb://localhost:27017/shanebrain_db" --out="$backup_path"
        print_success "MongoDB backup created: $backup_path"
    else
        print_step "mongodump not available, copying data directory..."
        if [ -d "$SHANEBRAIN_ROOT/mongodb-data" ]; then
            cp -r "$SHANEBRAIN_ROOT/mongodb-data" "$backup_path/"
            print_success "MongoDB data copied to: $backup_path"
        else
            print_error "No MongoDB data found"
        fi
    fi
}

backup_planning() {
    print_header "Backing up Planning Files"

    local backup_name="planning-backup-$TIMESTAMP"
    local backup_path="$BACKUP_DIR/$backup_name"

    print_step "Creating backup: $backup_name"
    mkdir -p "$backup_path"

    # Backup active projects
    if [ -d "$PROJECT_ROOT/planning-system/active-projects" ]; then
        cp -r "$PROJECT_ROOT/planning-system/active-projects" "$backup_path/"
        print_success "Active projects backed up"
    fi

    # Backup completed projects
    if [ -d "$PROJECT_ROOT/planning-system/completed-projects" ]; then
        cp -r "$PROJECT_ROOT/planning-system/completed-projects" "$backup_path/"
        print_success "Completed projects backed up"
    fi

    # Backup from data root if different
    if [ "$SHANEBRAIN_ROOT" != "$PROJECT_ROOT" ]; then
        if [ -d "$SHANEBRAIN_ROOT/planning-system" ]; then
            cp -r "$SHANEBRAIN_ROOT/planning-system" "$backup_path/data-root/"
            print_success "Data root planning files backed up"
        fi
    fi

    print_success "Planning backup created: $backup_path"
}

backup_config() {
    print_header "Backing up Configuration"

    local backup_name="config-backup-$TIMESTAMP"
    local backup_path="$BACKUP_DIR/$backup_name"

    print_step "Creating backup: $backup_name"
    mkdir -p "$backup_path"

    # Backup env (if exists)
    if [ -f "$PROJECT_ROOT/.env" ]; then
        cp "$PROJECT_ROOT/.env" "$backup_path/.env"
        print_success ".env backed up"
    fi

    # Backup schemas
    cp -r "$PROJECT_ROOT/weaviate-config/schemas" "$backup_path/"
    cp -r "$PROJECT_ROOT/mongodb-schemas" "$backup_path/"
    print_success "Schemas backed up"

    # Backup docker-compose
    cp "$PROJECT_ROOT/weaviate-config/docker-compose.yml" "$backup_path/"
    print_success "Docker config backed up"

    print_success "Config backup created: $backup_path"
}

full_backup() {
    print_header "Full ShaneBrain Backup"

    local backup_name="full-backup-$TIMESTAMP"
    local backup_path="$BACKUP_DIR/$backup_name"

    print_step "Creating full backup: $backup_name"
    mkdir -p "$backup_path"

    backup_weaviate
    backup_mongodb
    backup_planning
    backup_config

    # Create compressed archive
    print_step "Creating compressed archive..."
    cd "$BACKUP_DIR"
    tar -czf "${backup_name}.tar.gz" \
        "weaviate-backup-$TIMESTAMP" \
        "mongodb-backup-$TIMESTAMP" \
        "planning-backup-$TIMESTAMP" \
        "config-backup-$TIMESTAMP" \
        2>/dev/null || true

    print_success "Full backup created: ${backup_name}.tar.gz"

    # Cleanup individual directories
    rm -rf "weaviate-backup-$TIMESTAMP" \
           "mongodb-backup-$TIMESTAMP" \
           "planning-backup-$TIMESTAMP" \
           "config-backup-$TIMESTAMP" \
           2>/dev/null || true

    # Show backup size
    local size=$(du -h "${backup_name}.tar.gz" | cut -f1)
    print_success "Backup size: $size"
}

restore_backup() {
    local backup_name="$1"

    if [ -z "$backup_name" ]; then
        print_header "Available Backups"
        ls -la "$BACKUP_DIR"/*.tar.gz 2>/dev/null || echo "No backups found"
        echo ""
        echo "Usage: $0 restore <backup-name>"
        return 1
    fi

    print_header "Restoring from: $backup_name"

    local backup_file="$BACKUP_DIR/$backup_name"

    if [ ! -f "$backup_file" ]; then
        # Try with .tar.gz extension
        backup_file="$BACKUP_DIR/${backup_name}.tar.gz"
    fi

    if [ ! -f "$backup_file" ]; then
        print_error "Backup not found: $backup_name"
        return 1
    fi

    print_step "Extracting backup..."
    cd "$BACKUP_DIR"
    tar -xzf "$backup_file"

    print_warning "Restoration requires manual steps:"
    echo "1. Stop services: docker-compose down (in weaviate-config/)"
    echo "2. Copy restored data to appropriate locations"
    echo "3. Restart services: docker-compose up -d"
    echo ""
    echo "Extracted files are in: $BACKUP_DIR/"
}

cleanup_old_backups() {
    print_header "Cleaning Up Old Backups"

    local retention_days="${BACKUP_RETENTION_DAYS:-30}"

    print_step "Removing backups older than $retention_days days..."

    find "$BACKUP_DIR" -name "*.tar.gz" -mtime +$retention_days -delete 2>/dev/null || true
    find "$BACKUP_DIR" -type d -name "*-backup-*" -mtime +$retention_days -exec rm -rf {} \; 2>/dev/null || true

    print_success "Cleanup complete"
}

# =============================================================================
# Main
# =============================================================================

print_header "ShaneBrain Backup Utility"

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

case "${1:-full}" in
    weaviate)
        backup_weaviate
        ;;
    mongodb)
        backup_mongodb
        ;;
    planning)
        backup_planning
        ;;
    config)
        backup_config
        ;;
    full)
        full_backup
        ;;
    restore)
        restore_backup "$2"
        ;;
    cleanup)
        cleanup_old_backups
        ;;
    *)
        echo "Usage: $0 {full|weaviate|mongodb|planning|config|restore|cleanup}"
        exit 1
        ;;
esac

echo ""
print_success "Backup operation complete"
echo "Backups stored in: $BACKUP_DIR"
