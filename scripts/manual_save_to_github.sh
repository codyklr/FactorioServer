#!/bin/bash

# Script to manually back up Factorio saves to GitHub
# Run as facserver user: ./manual_save_to_github.sh
# Assumes /home/facserver/factorio/saves is a symbolic link to /home/facserver/FactorioServer/saves
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
    echo "Error: Git repository directory $REPO_DIR not found."
    log "Error: Git repository directory $REPO_DIR not found."
    exit 1
fi
if [ ! -d "$REPO_SAVES_DIR" ]; then
    echo "Error: Saves directory $REPO_SAVES_DIR not found."
    log "Error: Saves directory $REPO_SAVES_DIR not found."
    exit 1
fi

# Commit and push to GitHub
cd "$REPO_DIR" || {
    echo "Error: Failed to change to $REPO_DIR."
    log "Error: Failed to change to $REPO_DIR."
    exit 1
}
echo "Committing changes..."
log "Committing changes..."
git add saves
if git commit -m "Manual saves backup $TIMESTAMP"; then
    echo "Changes committed."
    log "Changes committed."
else
    echo "No changes to commit."
    log "No changes to commit."
fi

echo "Pushing to GitHub..."
log "Pushing to GitHub..."
if git push origin main; then
    echo "Successfully pushed to GitHub."
    log "Successfully pushed to GitHub."
else
    echo "Error: Failed to push to GitHub."
    log "Error: Failed to push to GitHub."
    exit 1
fi

echo "Manual backup completed successfully."
log "Manual backup completed successfully."
