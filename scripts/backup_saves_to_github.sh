#!/bin/bash

# Script to back up Factorio saves to GitHub hourly
# Run as facserver user via cron
# Assumes /home/facserver/factorio/saves is a symbolic link to /home/facserver/FactorioServer/saves
# Verifies SSH remote URL
# Logs to ~/factorio_backup.log

# Configuration
REPO_DIR="/home/facserver/FactorioServer"
REPO_SAVES_DIR="$REPO_DIR/saves"
LOG_FILE="/home/facserver/factorio_backup.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Function to log messages
log() {
    echo "[$TIMESTAMP] $1" >> "$LOG_FILE"
}

# Check if directories exist
if [ ! -d "$REPO_DIR" ]; then
    log "Error: Git repository directory $REPO_DIR not found."
    exit 1
fi
if [ ! -d "$REPO_SAVES_DIR" ]; then
    log "Error: Saves directory $REPO_SAVES_DIR not found."
    exit 1
fi

# Verify SSH remote URL
cd "$REPO_DIR" || {
    log "Error: Failed to change to $REPO_DIR."
    exit 1
}
REMOTE_URL=$(git remote get-url origin)
if [[ ! "$REMOTE_URL" =~ ^git@github.com: ]]; then
    log "Error: Git remote URL is not SSH ($REMOTE_URL). Run: git remote set-url origin git@github.com:codyklr/FactorioServer.git"
    exit 1
fi

# Commit and push to GitHub
log "Committing changes..."
git add saves
if git commit -m "Hourly saves backup $TIMESTAMP"; then
    log "Changes committed."
else
    log "No changes to commit."
fi

log "Pushing to GitHub..."
if git push origin main; then
    log "Successfully pushed to GitHub."
else
    log "Error: Failed to push to GitHub."
    exit 1
fi

log "Backup completed successfully."
