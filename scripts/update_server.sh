#!/bin/bash

# Script to update Factorio headless server to the latest stable version
# Run as facserver user: ./update_server.sh
# Logs to ~/factorio_backup.log
# Requires sudo for systemctl commands
# Does not create server backups
# Preserves symlinks for saves and mods

# Configuration
FACTORIO_DIR="/home/facserver/factorio"
SAVES_DIR="/home/facserver/FactorioServer/saves"
MODS_DIR="/home/facserver/FactorioServer/mods"
SERVICE_NAME="factorio"
LOG_FILE="/home/facserver/factorio_backup.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
TEMP_DIR="/tmp/factorio_update"
DOWNLOAD_URL="https://factorio.com/get-download/stable/headless/linux64"
DOWNLOAD_FILE="/tmp/factorio_headless.tar.xz"

# Function to log messages
log() {
    echo "[$TIMESTAMP] $1" >> "$LOG_FILE"
}

# Check for required commands
for cmd in wget tar rsync systemctl; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: $cmd is required. Install it with: sudo apt install $cmd"
        log "Error: $cmd is required."
        exit 1
    fi
done

# Check if Factorio directory exists
if [ ! -d "$FACTORIO_DIR" ]; then
    echo "Error: Factorio directory $FACTORIO_DIR not found."
    log "Error: Factorio directory $FACTORIO_DIR not found."
    exit 1
fi

# Check symlinks
SAVES_SYMLINK=false
MODS_SYMLINK=false
if [ -L "$FACTORIO_DIR/saves" ] && [ "$(readlink -f "$FACTORIO_DIR/saves")" = "$SAVES_DIR" ]; then
    SAVES_SYMLINK=true
    echo "Saves symlink intact: $FACTORIO_DIR/saves -> $SAVES_DIR"
    log "Saves symlink intact: $FACTORIO_DIR/saves -> $SAVES_DIR"
else
    echo "Warning: Saves symlink missing or broken. Will recreate after update."
    log "Warning: Saves symlink missing or broken."
fi
if [ -L "$FACTORIO_DIR/mods" ] && [ "$(readlink -f "$FACTORIO_DIR/mods")" = "$MODS_DIR" ]; then
    MODS_SYMLINK=true
    echo "Mods symlink intact: $FACTORIO_DIR/mods -> $MODS_DIR"
    log "Mods symlink intact: $FACTORIO_DIR/mods -> $MODS_DIR"
else
    echo "Warning: Mods symlink missing or broken. Will recreate after update."
    log "Warning: Mods symlink missing or broken."
fi

# Stop the server if running
if systemctl --quiet is-active "$SERVICE_NAME"; then
    echo "Stopping Factorio service..."
    log "Stopping Factorio service..."
    if sudo systemctl stop "$SERVICE_NAME"; then
        echo "Factorio service stopped."
        log "Factorio service stopped."
    else
        echo "Error: Failed to stop Factorio service."
        log "Error: Failed to stop Factorio service."
        exit 1
    fi
fi

# Create temporary directory
mkdir -p "$TEMP_DIR"
if [ $? -ne 0 ]; then
    echo "Error: Failed to create temporary directory $TEMP_DIR."
    log "Error: Failed to create temporary directory $TEMP_DIR."
    exit 1
fi

# Download latest server version
echo "Downloading latest Factorio headless server..."
log "Downloading latest Factorio headless server..."
wget -q --show-progress -O "$DOWNLOAD_FILE" "$DOWNLOAD_URL"
if [ $? -ne 0 ]; then
    echo "Error: Failed to download server from $DOWNLOAD_URL."
    log "Error: Failed to download server from $DOWNLOAD_URL."
    rm -rf "$TEMP_DIR" "$DOWNLOAD_FILE"
    exit 1
fi

# Extract to temporary directory
echo "Extracting server files..."
log "Extracting server files..."
tar -xf "$DOWNLOAD_FILE" -C "$TEMP_DIR"
if [ $? -ne 0 ]; then
    echo "Error: Failed to extract server files."
    log "Error: Failed to extract server files."
    rm -rf "$TEMP_DIR" "$DOWNLOAD_FILE"
    exit 1
fi

# Preserve existing data, saves, and mods
echo "Preserving existing configuration, saves, and mods..."
log "Preserving existing configuration, saves, and mods..."
mkdir -p "$TEMP_DIR/factorio/data"
cp -r "$FACTORIO_DIR/data/server-settings.json" "$FACTORIO_DIR/data/server-whitelist.json" "$FACTORIO_DIR/data/server-adminlist.json" "$TEMP_DIR/factorio/data/" 2>/dev/null
if [ -d "$SAVES_DIR" ]; then
    cp -r "$SAVES_DIR" "$TEMP_DIR/factorio/"
fi
if [ -d "$MODS_DIR" ]; then
    cp -r "$MODS_DIR" "$TEMP_DIR/factorio/"
fi

# Update server files
echo "Updating server files..."
log "Updating server files..."
rsync -a --delete "$TEMP_DIR/factorio/" "$FACTORIO_DIR/"
if [ $? -ne 0 ]; then
    echo "Error: Failed to update server files."
    log "Error: Failed to update server files."
    rm -rf "$TEMP_DIR" "$DOWNLOAD_FILE"
    exit 1
fi

# Recreate symlinks if they were present
if [ "$SAVES_SYMLINK" = "true" ] && [ ! -L "$FACTORIO_DIR/saves" ]; then
    rm -rf "$FACTORIO_DIR/saves"
    ln -s "$SAVES_DIR" "$FACTORIO_DIR/saves"
    echo "Recreated saves symlink: $FACTORIO_DIR/saves -> $SAVES_DIR"
    log "Recreated saves symlink: $FACTORIO_DIR/saves -> $SAVES_DIR"
fi
if [ "$MODS_SYMLINK" = "true" ] && [ ! -L "$FACTORIO_DIR/mods" ]; then
    rm -rf "$FACTORIO_DIR/mods"
    ln -s "$MODS_DIR" "$FACTORIO_DIR/mods"
    echo "Recreated mods symlink: $FACTORIO_DIR/mods -> $MODS_DIR"
    log "Recreated mods symlink: $FACTORIO_DIR/mods -> $MODS_DIR"
fi

# Clean up
rm -rf "$TEMP_DIR" "$DOWNLOAD_FILE"
echo "Cleaned up temporary files."
log "Cleaned up temporary files."

# Set permissions
chown -R facserver:facserver "$FACTORIO_DIR"
chmod -R u+rw "$FACTORIO_DIR"

# Start the server
echo "Starting Factorio service..."
log "Starting Factorio service..."
if sudo systemctl start "$SERVICE_NAME"; then
    echo "Factorio service started."
    log "Factorio service started."
else
    echo "Error: Failed to start Factorio service."
    log "Error: Failed to start Factorio service."
    exit 1
fi

echo "Server update complete. Check version in /home/facserver/factorio/factorio-current.log."
log "Server update complete."
