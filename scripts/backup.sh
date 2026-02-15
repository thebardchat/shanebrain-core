#!/bin/bash
# ShaneBrain Restic Backup Script
# Backs up critical data to 8TB external drive
# Run manually or via cron: 0 3 * * * /mnt/shanebrain-raid/shanebrain-core/scripts/backup.sh

export RESTIC_REPOSITORY="/media/shane/ANGEL_CLOUD/shanebrain-backups"
export RESTIC_PASSWORD="shanebrain-backup-2026"

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
echo "[$TIMESTAMP] Starting ShaneBrain backup..."

# Backup critical files
restic backup \
  /mnt/shanebrain-raid/shanebrain-core/.env \
  /mnt/shanebrain-raid/shanebrain-core/RAG.md \
  /mnt/shanebrain-raid/shanebrain-core/CLAUDE.md \
  /mnt/shanebrain-raid/shanebrain-core/scripts/ \
  /mnt/shanebrain-raid/shanebrain-core/bot/ \
  /mnt/shanebrain-raid/shanebrain-core/social/ \
  /mnt/shanebrain-raid/shanebrain-core/arcade/ \
  /mnt/shanebrain-raid/shanebrain-core/systemd/ \
  /mnt/shanebrain-raid/shanebrain-core/weaviate-config/docker-compose.yml \
  /mnt/shanebrain-raid/shanebrain-core/weaviate-config/schemas/ \
  /mnt/shanebrain-raid/shanebrain-core/requirements.txt \
  --exclude="__pycache__" \
  --exclude="*.pyc" \
  --exclude="node_modules" \
  --exclude="logs/" \
  --tag shanebrain-core

if [ $? -eq 0 ]; then
  echo "[$TIMESTAMP] Backup completed successfully"
else
  echo "[$TIMESTAMP] Backup FAILED"
  exit 1
fi

# Keep last 7 daily, 4 weekly, 6 monthly snapshots
restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune

echo "[$TIMESTAMP] Backup and prune complete"
