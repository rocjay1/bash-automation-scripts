#! /bin/bash

# ==============================================================================
# Script Name: backup_and_push.sh
# Description: Automates the backup of a local source directory to a remote 
#              Git repository. It handles logging, error tracking, and ensures
#              the backup directory is synchronized.
# Usage:       ./backup_and_push.sh
# Author:      Rocco Davino
# ==============================================================================

# Strict mode: fail on error, undefined variable, or pipe failure
set -euo pipefail

# ==============================================================================
# Configuration
# ==============================================================================

LOG_DIR="${HOME}/log/bash-automation-scripts"
LOG_FILE="$LOG_DIR/backup_and_push.log"
SOURCE_DIR="${HOME}/Source"
BACKUP_DIR="/tmp/bash-automation-scripts-backup"
BACKUP_FILENAME="backup.tar.gz"

# Uses git-lfs for large backup files
REMOTE_REPO="git@github.com:rocjay1/bash-automation-scripts-backups.git"

log() {
    local message="$1"
    local log_entry="[$(date -Iseconds)] $message"
    echo "$log_entry" >> "$LOG_FILE"
}

# ==============================================================================
# Main Execution
# ==============================================================================

# Redirect stdout and stderr to the log file
exec >> "$LOG_FILE" 2>&1

# Make git and git-lfs visible to cron
export PATH=/opt/homebrew/bin/:/usr/bin/:$PATH

# Ensure log directory and file exist
if [ ! -d "$LOG_DIR" ]; then
    mkdir -p "$LOG_DIR"
fi
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
fi

log "Starting backup process..."

# Prepare backup directory
if [ ! -d "$BACKUP_DIR" ]; then
    log "Backup directory not found. Creating and cloning..."
    mkdir -p "$BACKUP_DIR"
    git clone "$REMOTE_REPO" "$BACKUP_DIR"
    cd "$BACKUP_DIR"
    log "Successfully created and initialized backup directory."
else 
    log "Backup directory exists at $BACKUP_DIR. Cleaning up old backups..."
    cd "$BACKUP_DIR"

    # Safely remove old tarballs if they exist (ignore if missing)
    git rm --ignore-unmatch -f ./*.tar.gz
    git add .
    
    # Only commit if there are staged changes to avoid empty commit errors
    if ! git diff --cached --quiet; then
        git commit -m "Removing old backups"
        log "Successfully committed removal of old backups."
    else
        log "No old backups to remove or clean up."
    fi
fi

# Archive source directory
log "Creating new backup of $SOURCE_DIR..."
tar -czf "$BACKUP_FILENAME" -C "$(dirname "$SOURCE_DIR")" "$(basename "$SOURCE_DIR")"
log "Finished creating new backup archive."

# Push to remote
log "Committing and pushing new backup to GitHub..."
git add .
git commit -m "Adding new backup: $(date)"
git pull --rebase
git push
log "Successfully committed and pushed new backup."

echo "" >> "$LOG_FILE"