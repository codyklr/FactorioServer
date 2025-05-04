#!/bin/bash

# Script to stop the Factorio server
# Run as facserver user: ./stop_factorio.sh
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

# Stop the service
echo "Stopping Factorio service..."
log "Stopping Factorio service..."
if sudo systemctl stop "$SERVICE_NAME"; then
    echo "Factorio service stopped successfully."
    log "Factorio service stopped successfully."
else
    echo "Error: Failed to stop Factorio service."
    log "Error: Failed to stop Factorio service."
    exit 1
fi
