#!/bin/bash

# Script to manage Factorio server whitelist and admin list
# Run as facserver user: ./manage_whitelist.sh
# Edits server-whitelist.json and server-adminlist.json
# Logs to ~/factorio_backup.log
# Requires jq: sudo apt install jq

# Configuration
FACTORIO_DATA_DIR="/home/facserver/factorio/data"
WHITELIST_FILE="$FACTORIO_DATA_DIR/server-whitelist.json"
ADMIN_FILE="$FACTORIO_DATA_DIR/server-adminlist.json"
SERVICE_NAME="factorio"
LOG_FILE="/home/facserver/factorio_backup.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Function to log messages
log() {
    echo "[$TIMESTAMP] $1" >> "$LOG_FILE"
}

# Function to check if server is running
check_server_running() {
    if ! systemctl --quiet is-active "$SERVICE_NAME"; then
        echo "Error: Factorio service ($SERVICE_NAME) is not running."
        log "Error: Factorio service ($SERVICE_NAME) is not running."
        return 1
    fi
    return 0
}

# Function to restart server
restart_server() {
    echo "Restarting Factorio service to apply changes..."
    log "Restarting Factorio service to apply changes..."
    if sudo systemctl restart "$SERVICE_NAME"; then
        echo "Factorio service restarted successfully."
        log "Factorio service restarted successfully."
    else
        echo "Error: Failed to restart Factorio service."
        log "Error: Failed to restart Factorio service."
        exit 1
    fi
}

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required. Install it with: sudo apt install jq"
    log "Error: jq is required."
    exit 1
fi

# Check if whitelist file exists, create if not
if [ ! -f "$WHITELIST_FILE" ]; then
    echo "Creating $WHITELIST_FILE..."
    log "Creating $WHITELIST_FILE..."
    echo "[]" > "$WHITELIST_FILE"
    chown facserver:facserver "$WHITELIST_FILE"
    chmod u+rw "$WHITELIST_FILE"
fi

# Check if admin file exists, create if not
if [ ! -f "$ADMIN_FILE" ]; then
    echo "Creating $ADMIN_FILE..."
    log "Creating $ADMIN_FILE..."
    echo "[]" > "$ADMIN_FILE"
    chown facserver:facserver "$ADMIN_FILE"
    chmod u+rw "$ADMIN_FILE"
fi

# Main menu
echo "Factorio Server Manager"
echo "1. List whitelisted players"
echo "2. Add a player to whitelist"
echo "3. Remove a player from whitelist"
echo "4. Clear whitelist"
echo "5. List admins"
echo "6. Add an admin"
echo "7. Remove an admin"
echo "8. Clear admin list"
echo "9. Exit"
read -p "Select an option (1-9): " option

case $option in
    1)
        # List whitelisted players
        if check_server_running; then
            echo "Listing whitelisted players (in-game command recommended)..."
            log "Listing whitelisted players (in-game command)..."
            echo "Run '/whitelist get' in-game as an admin for the current list."
            echo "Current server-whitelist.json contents:"
            cat "$WHITELIST_FILE"
        else
            echo "Server is not running. Showing server-whitelist.json contents:"
            cat "$WHITELIST_FILE"
        fi
        ;;
    2)
        # Add a player to whitelist
        read -p "Enter Factorio username to add: " username
        if [ -z "$username" ]; then
            echo "Error: Username cannot be empty."
            log "Error: Username cannot be empty."
            exit 1
        fi
        if check_server_running; then
            echo "For instant update, run '/whitelist add $username' in-game as an admin."
            echo "Adding $username to server-whitelist.json for next restart..."
            log "Adding $username to whitelist via in-game command guidance and server-whitelist.json..."
        else
            echo "Adding $username to server-whitelist.json..."
            log "Adding $username to server-whitelist.json..."
        fi
        jq --arg user "$username" '. |= . + [$user] | unique' "$WHITELIST_FILE" > tmp.json && mv tmp.json "$WHITELIST_FILE"
        if [ $? -eq 0 ]; then
            echo "$username added to whitelist."
            log "$username added to whitelist."
            if check_server_running; then
                restart_server
            fi
        else
            echo "Error: Failed to update $WHITELIST_FILE."
            log "Error: Failed to update $WHITELIST_FILE."
            exit 1
        fi
        ;;
    3)
        # Remove a player from whitelist
        read -p "Enter Factorio username to remove: " username
        if [ -z "$username" ]; then
            echo "Error: Username cannot be empty."
            log "Error: Username cannot be empty."
            exit 1
        fi
        if check_server_running; then
            echo "For instant update, run '/whitelist remove $username' in-game as an admin."
            echo "Removing $username from server-whitelist.json for next restart..."
            log "Removing $username from whitelist via in-game command guidance and server-whitelist.json..."
        else
            echo "Removing $username from server-whitelist.json..."
            log "Removing $username from server-whitelist.json..."
        fi
        jq --arg user "$username" 'del(.[index($user)])' "$WHITELIST_FILE" > tmp.json && mv tmp.json "$WHITELIST_FILE"
        if [ $? -eq 0 ]; then
            echo "$username removed from whitelist."
            log "$username removed from whitelist."
            if check_server_running; then
                restart_server
            fi
        else
            echo "Error: Failed to update $WHITELIST_FILE."
            log "Error: Failed to update $WHITELIST_FILE."
            exit 1
        fi
        ;;
    4)
        # Clear whitelist
        read -p "Are you sure you want to clear the whitelist? (yes/no): " confirm
        if [ "$confirm" != "yes" ]; then
            echo "Whitelist clear aborted."
            log "Whitelist clear aborted."
            exit 0
        fi
        echo "Clearing whitelist..."
        log "Clearing whitelist..."
        echo "[]" > "$WHITELIST_FILE"
        if [ $? -eq 0 ]; then
            echo "Whitelist cleared."
            log "Whitelist cleared."
            if check_server_running; then
                restart_server
            fi
        else
            echo "Error: Failed to clear $WHITELIST_FILE."
            log "Error: Failed to clear $WHITELIST_FILE."
            exit 1
        fi
        ;;
    5)
        # List admins
        if check_server_running; then
            echo "Listing admins (in-game command recommended)..."
            log "Listing admins (in-game command)..."
            echo "Run '/server-adminlist' in-game as an admin for the current list."
            echo "Current server-adminlist.json contents:"
            cat "$ADMIN_FILE"
        else
            echo "Server is not running. Showing server-adminlist.json contents:"
            cat "$ADMIN_FILE"
        fi
        ;;
    6)
        # Add an admin
        read -p "Enter Factorio username to add as admin: " username
        if [ -z "$username" ]; then
            echo "Error: Username cannot be empty."
            log "Error: Username cannot be empty."
            exit 1
        fi
        if check_server_running; then
            echo "For instant update, run '/promote $username' in-game as an admin."
            echo "Adding $username to server-adminlist.json for next restart..."
            log "Adding $username to admin list via in-game command guidance and server-adminlist.json..."
        else
            echo "Adding $username to server-adminlist.json..."
            log "Adding $username to server-adminlist.json..."
        fi
        jq --arg user "$username" '. |= . + [$user] | unique' "$ADMIN_FILE" > tmp.json && mv tmp.json "$ADMIN_FILE"
        if [ $? -eq 0 ]; then
            echo "$username added to admin list."
            log "$username added to admin list."
            if check_server_running; then
                restart_server
            fi
        else
            echo "Error: Failed to update $ADMIN_FILE."
            log "Error: Failed to update $ADMIN_FILE."
            exit 1
        fi
        ;;
    7)
        # Remove an admin
        read -p "Enter Factorio username to remove as admin: " username
        if [ -z "$username" ]; then
            echo "Error: Username cannot be empty."
            log "Error: Username cannot be empty."
            exit 1
        fi
        if check_server_running; then
            echo "For instant update, run '/demote $username' in-game as an admin."
            echo "Removing $username from server-adminlist.json for next restart..."
            log "Removing $username from admin list via in-game command guidance and server-adminlist.json..."
        else
            echo "Removing $username from server-adminlist.json..."
            log "Removing $username from server-adminlist.json..."
        fi
        jq --arg user "$username" 'del(.[index($user)])' "$ADMIN_FILE" > tmp.json && mv tmp.json "$ADMIN_FILE"
        if [ $? -eq 0 ]; then
            echo "$username removed from admin list."
            log "$username removed from admin list."
            if check_server_running; then
                restart_server
            fi
        else
            echo "Error: Failed to update $ADMIN_FILE."
            log "Error: Failed to update $ADMIN_FILE."
            exit 1
        fi
        ;;
    8)
        # Clear admin list
        read -p "Are you sure you want to clear the admin list? (yes/no): " confirm
        if [ "$confirm" != "yes" ]; then
            echo "Admin list clear aborted."
            log "Admin list clear aborted."
            exit 0
        fi
        echo "Clearing admin list..."
        log "Clearing admin list..."
        echo "[]" > "$ADMIN_FILE"
        if [ $? -eq 0 ]; then
            echo "Admin list cleared."
            log "Admin list cleared."
            if check_server_running; then
                restart_server
            fi
        else
            echo "Error: Failed to clear $ADMIN_FILE."
            log "Error: Failed to clear $ADMIN_FILE."
            exit 1
        fi
        ;;
    9)
        echo "Exiting..."
        exit 0
        ;;
    *)
        echo "Invalid option. Exiting..."
        log "Invalid option selected."
        exit 1
        ;;
esac
