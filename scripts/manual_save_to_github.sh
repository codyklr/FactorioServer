#!/bin/bash

# Script to manually back up Factorio saves to GitHub
# Run as facserver user: ./manual_save_to_github.sh [--force]
# Logs to ~/factorio_backup.log
# Pushes changes to GitHub repository
# Checks saves symlink integrity

# Configuration
REPO_DIR="/home/facserver/FactorioServer"
SAVES_DIR="$REPO_DIR/saves"
FACTORIO_SAVES="/home/facserver/factorio/saves"
LOG_FILE="/home/facserver/factorio_backup.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Function to log messages
log() {
    echo "[$TIMESTAMP] $1" >> "$LOG_FILE"
}

# Check for required commands
for cmd in git; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: $cmd is required. Install it with: sudo apt install $cmd"
        log "Error: $cmd is required."
        exit 1
    fi
done

# Check if repository directory exists
if [ ! -d "$REPO_DIR" ]; then
    echo "Error: Repository directory $REPO_DIR not found."
    log "Error: Repository directory $REPO_DIR not found."
    exit 1
fi

# Check if saves directory exists
if [ ! -d "$SAVES_DIR" ]; then
    echo "Error: Saves directory $SAVES_DIR not found."
    log "Error: Saves directory $SAVES_DIR not found."
    exit 1
fi

# Check saves symlink
if [ ! -L "$FACTORIO_SAVES" ] || [ "$(readlink -f "$FACTORIO_SAVES")" != "$SAVES_DIR" ]; then
    echo "Error: Saves symlink $FACTORIO_SAVES is missing or broken (should point to $SAVES_DIR)."
    echo "Fix by running:"
    echo "  rm -rf $FACTORIO_SAVES"
    echo "  ln -s $SAVES_DIR $FACTORIO_SAVES"
    log "Error: Saves symlink $FACTORIO_SAVES is missing or broken."
    exit 1
fi

# Navigate to repository
cd "$REPO_DIR" || { echo "Error: Failed to change to $REPO_DIR"; log "Error: Failed to change to $REPO_DIR"; exit 1; }

# Check for --force flag
FORCE_COMMIT=false
if [ "$1" == "--force" ]; then
    FORCE_COMMIT=true
fi

# Check for changes
git add saves/*
if git diff --staged --quiet && [ "$FORCE_COMMIT" != "true" ]; then
    echo "No changes in saves to commit."
    log "No changes in saves to commit."
    exit 0
fi

# Commit changes
echo "Committing save changes..."
log "Committing save changes..."
git commit -m "Manual backup $TIMESTAMP"
if [ $? -ne 0 ]; then
    echo "Error: Failed to commit changes."
    log "Error: Failed to commit changes."
    exit 1
fi

# Push to GitHub
echo "Pushing to GitHub..."
log "Pushing to GitHub..."
git push origin main
if [ $? -ne 0 ]; then
    echo "Error: Failed to push to GitHub. Check authentication or remote configuration."
    log "Error: Failed to push to GitHub."
    exit 1
fi

echo "Saves successfully backed up to GitHub."
log "Saves successfully backed up to GitHub."
