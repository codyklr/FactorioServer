#!/bin/bash

# Script to update Factorio headless server to the latest stable version
# Run as facserver user: ./update_server.sh
# Preserves settings files, saves, and mods
# Logs to ~/factorio_backup.log
# Requires sudo for systemctl commands

# Configuration
FACTORIO_DIR="/home/facserver/factorio"
BACKUP_DIR="/home/facserver/FactorioServer/server-backup"
SAVES_DIR="/home/facserver/FactorioServer/saves"
MODS_DIR="/home/facserver/FactorioServer/mods"
SERVICE_NAME="factorio"
LOG_FILE="/home/facserver/factorio_backup.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
TEMP_DIR="/tmp/factorio_update"
DOWNLOAD_URL="https://factorio.com/get-download/stable/headless/linux64"
DOWNLOAD_FILE="/tmp/factorio_headless.tar.xz"
SETTINGS_FILES=(
    "data/server-settings.json"
    "data/server-whitelist.json"
    "data/server-adminlist.json"
    "data/server-banlist.json"
    "data/server-id.json"
    "config/config.ini"
)

# Function to log messages
log() {
    echo "[$TIMESTAMP] $1" >> "$LOG_FILE"
}

# Check for required commands
for cmd in wget tar rsync systemctl md5sum; do
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

# Create backup directory
mkdir -p "$BACKUP_DIR"
if [ $? -ne 0 ]; then
    echo "Error: Failed to create backup directory $BACKUP_DIR."
    log "Error: Failed to create backup directory $BACKUP_DIR."
    exit 1
fi

# Compute checksums of settings files before backup
echo "Computing checksums of settings files..."
log "Computing checksums of settings files..."
declare -A pre_checksums
for file in "${SETTINGS_FILES[@]}"; do
    full_path="$FACTORIO_DIR/$file"
    if [ -f "$full_path" ]; then
        checksum=$(md5sum "$full_path" | awk '{print $1}')
        pre_checksums["$file"]="$checksum"
        echo "Pre-update checksum for $file: $checksum"
        log "Pre-update checksum for $file: $checksum"
    fi
done

# Backup current server files
backup_file="$BACKUP_DIR/factorio-$(date '+%Y%m%d%H%M%S').tar.gz"
tar -czf "$backup_file" -C "$(dirname "$FACTORIO_DIR")" factorio
if [ $? -ne 0 ]; then
    echo "Error: Failed to backup server to $backup_file."
    log "Error: Failed to backup server to $backup_file."
    exit 1
fi
echo "Backed up current server to $backup_file."
log "Backed up current server to $backup_file."

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

# Preserve existing settings, saves, and mods
echo "Preserving existing configuration, saves, and mods..."
log "Preserving existing configuration, saves, and mods..."
mkdir -p "$TEMP_DIR/factorio/data" "$TEMP_DIR/factorio/config"
for file in "${SETTINGS_FILES[@]}"; do
    full_path="$FACTORIO_DIR/$file"
    if [ -f "$full_path" ]; then
        cp "$full_path" "$TEMP_DIR/factorio/$file"
        if [ $? -eq 0 ]; then
            echo "Preserved $file."
            log "Preserved $file."
        else
            echo "Warning: Failed to preserve $file."
            log "Warning: Failed to preserve $file."
        fi
    fi
done
if [ -d "$SAVES_DIR" ]; then
    cp -r "$SAVES_DIR" "$TEMP_DIR/factorio/"
    echo "Preserved saves."
    log "Preserved saves."
fi
if [ -d "$MODS_DIR" ]; then
    cp -r "$MODS_DIR" "$TEMP_DIR/factorio/"
    echo "Preserved mods."
    log "Preserved mods."
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

# Clean up
rm -rf "$TEMP_DIR" "$DOWNLOAD_FILE"
echo "Cleaned up temporary files."
log "Cleaned up temporary files."

# Set permissions
chown -R facserver:facserver "$FACTORIO_DIR"
chmod -R u+rw "$FACTORIO_DIR"

# Verify settings files integrity
echo "Verifying settings files integrity..."
log "Verifying settings files integrity..."
for file in "${SETTINGS_FILES[@]}"; do
    full_path="$FACTORIO_DIR/$file"
    if [ -f "$full_path" ] && [ -n "${pre_checksums[$file]}" ]; then
        post_checksum=$(md5sum "$full_path" | awk '{print $1}')
        if [ "$post_checksum" = "${pre_checksums[$file]}" ]; then
            echo "Checksum verified for $file: $post_checksum"
            log "Checksum verified for $file: $post_checksum"
        else
            echo "Warning: Checksum mismatch for $file. Expected ${pre_checksums[$file]}, got $post_checksum."
            log "Warning: Checksum mismatch for $file. Expected ${pre_checksums[$file]}, got $post_checksum."
        fi
    elif [ -f "$full_path" ]; then
        echo "Warning: $file exists but no pre-update checksum available."
        log "Warning: $file exists but no pre-update checksum available."
    fi
done

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

# Commit backup to GitHub
echo "Committing backup to GitHub..."
log "Committing backup to GitHub..."
cd /home/facserver/FactorioServer
git add server-backup/*
git commit -m "Backup server before update on $TIMESTAMP"
git push origin main
if [ $? -eq 0 ]; then
    echo "Backup committed to GitHub."
    log "Backup committed to GitHub."
else
    echo "Error: Failed to commit backup to GitHub."
    log "Error: Failed to commit backup to GitHub."
    exit 1
fi

echo "Server update complete. Check version in /home/facserver/factorio/factorio-current.log."
log "Server update complete."
