#!/bin/bash

# Script to restart the Factorio server
# Run as facserver user: ./restart_factorio.sh
# Requires sudo for systemctl commands

# Configuration
SERVICE_NAME="factorio"
LOG_FILE="/home/facserver/factorio_backup.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Function to log messages
log() {
    echo "[$TIMESTAMP] $1" >> "$LOG_FILE"
}

# Check if service exists
if ! systemctl --quiet is-active "$SERVICE_NAME"; then
    echo "Error: Factorio service ($SERVICE_NAME) is not running."
    log "Error: Factorio service ($SERVICE_NAME) is not running."
    exit 1
fi

# Restart the service
echo "Restarting Factorio service..."
log "Restarting Factorio service..."
if sudo systemctl restart "$SERVICE_NAME"; then
    echo "Factorio service restarted successfully."
    log "Factorio service restarted successfully."
else
    echo "Error: Failed to restart Factorio service."
    log "Error: Failed to restart Factorio service."
    exit 1
fi
