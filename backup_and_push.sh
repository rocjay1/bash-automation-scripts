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

# Make git and git-lfs visible to cron
export PATH=/opt/homebrew/bin/:/usr/bin/:$PATH

# ==============================================================================
# Configuration
# ==============================================================================

# Directories and files
LOG_DIR="${HOME}/log/bash-automation-scripts"
LOG_FILE="$LOG_DIR/backup_and_push.log"
SOURCE_DIR="${HOME}/Source"
BACKUP_DIR="/tmp/bash-automation-scripts-backup"
BACKUP_FILENAME="backup.tar.gz"

# Remote Settings
# Uses git-lfs for large backup files
REMOTE_REPO="git@github.com:rocjay1/bash-automation-scripts-backups.git"

# ==============================================================================
# Logging & Error Handling
# ==============================================================================

log() {
    local message="$1"
    local severity="${2:-INFO}"
    local log_entry="[$(date -Iseconds)] - $severity - $message"

    if [[ "$severity" == "ERROR" ]]; then
        # Write to stderr; global redirection handles writing to log file + console
        echo "$log_entry" >&2
    else
        # Write directly to log file for non-error messages
        echo "$log_entry" >> "$LOG_FILE"
    fi
}

error() {
    local parent_lineno="$1"
    local message="${2:-}"
    local code="${3:-1}"

    log "Failed on or near line ${parent_lineno}; exiting with status ${code}" "ERROR"
    exit "${code}"
}
# Trap ERR signal to handle runtime errors
trap 'error ${LINENO} "" $?' ERR

# ==============================================================================
# Main Execution
# ==============================================================================

# Redirect stderr to both the log file and the console (stderr)
exec 2> >(tee -a "$LOG_FILE" >&2)

# Ensure log directory and file exist
if [ ! -d "$LOG_DIR" ]; then
    mkdir -p "$LOG_DIR"
fi
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
fi

log "Starting backup process..."

# Prepare Backup Directory
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

# Archive Source Directory
log "Creating new backup of $SOURCE_DIR..."
tar -czf "$BACKUP_FILENAME" -C "$(dirname "$SOURCE_DIR")" "$(basename "$SOURCE_DIR")"
log "Finished creating new backup archive."

# Push to Remote
log "Committing and pushing new backup to GitHub..."
git add .
git commit -m "Adding new backup: $(date)"
git pull --rebase
git push
log "Successfully committed and pushed new backup."