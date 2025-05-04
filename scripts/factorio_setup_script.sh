#!/bin/bash

# Ensure the script is running with bash
if [ -z "$BASH_VERSION" ]; then
    echo "Error: This script must be run with bash."
    exit 1
fi

# Get the full path of the script
SCRIPT_PATH="$(realpath "$0")"

# Welcome message and disclaimer
echo "Welcome to the Factorio Server Setup Script!"
echo "This script sets up a Factorio server on your Ubuntu-based system."
echo "Warning: Review this script at https://github.com/your-repo/blog before running, and back up your system."
read -p "Do you want to proceed? (yes/no): " proceed
if [ "$proceed" != "yes" ]; then
    echo "Setup aborted."
    exit 1
fi

# Step 1: Non-root user (recommended)
echo "Step 1: Creating a non-root user (recommended for security)."
read -p "Do you want to create a new non-root user? (yes/no): " create_user
if [ "$create_user" == "yes" ]; then
    read -p "Enter username: " username
    read -s -p "Enter password: " password
    echo
    # Create user and set password
    if ! adduser --disabled-password --gecos "" "$username"; then
        echo "Error: Failed to create user $username."
        exit 1
    fi
    echo "$username:$password" | chpasswd
    usermod -aG sudo "$username"
    echo "User $username created. Copying script to $username's home directory..."
    # Copy script to new user's home
    if ! cp "$SCRIPT_PATH" /home/"$username"/factorio_setup_script.sh; then
        echo "Error: Failed to copy script to /home/$username/factorio_setup_script.sh."
        exit 1
    fi
    chown "$username:$username" /home/"$username"/factorio_setup_script.sh
    chmod +x /home/"$username"/factorio_setup_script.sh
    echo "Switching to $username..."
    # Run script as new user
    if ! su - "$username" -c "bash /home/$username/factorio_setup_script.sh"; then
        echo "Error: Failed to run script as $username."
        exit 1
    fi
    exit 0
fi

# Step 2: Install Factorio
echo "Step 2: Installing Factorio headless server."
mkdir -p ~/factorio
if ! wget -O factorio.tar.xz https://factorio.com/get-download/stable/headless/linux64; then
    echo "Error: Failed to download Factorio."
    exit 1
fi
tar -xJf factorio.tar.xz -C ~/factorio --strip-components=1
rm factorio.tar.xz
mkdir -p ~/factorio/saves ~/factorio/mods

# Step 3: Save file
echo "Step 3: Setting up the save file."
read -p "Create a new save or use an existing one? (new/existing): " save_choice
if [ "$save_choice" == "new" ]; then
    read -p "Enter save name (e.g., world1): " save_name
    if ! ~/factorio/bin/x64/factorio --create ~/factorio/saves/"$save_name".zip; then
        echo "Error: Failed to create save file."
        exit 1
    fi
else
    echo "Upload your save to ~/factorio/saves/ using SCP or SFTP."
    echo "Example: scp your-save.zip $USER@your-vps-ip:~/factorio/saves/"
    read -p "Enter the save file name (e.g., my-save.zip): " save_file
    if [ ! -f ~/factorio/saves/"$save_file" ]; then
        echo "Error: Save file ~/factorio/saves/$save_file not found."
        exit 1
    fi
fi

# Step 4: Mods
echo "Step 4: Mods (optional)."
read -p "Do you want to use mods? (yes/no): " use_mods
if [ "$use_mods" == "yes" ]; then
    echo "Download mods from https://mods.factorio.com/ and place them in ~/factorio/mods/."
    echo "Example: Upload via SCP or SFTP to ~/factorio/mods/."
    echo "Press Enter when done or to skip."
    read
fi

# Step 5: Auto-start service
echo "Step 5: Auto-start on reboot (optional)."
read -p "Do you want the server to auto-start on reboot? (yes/no): " auto_start
if [ "$auto_start" == "yes" ]; then
    cat << EOF | sudo tee /etc/systemd/system/factorio.service > /dev/null
[Unit]
Description=Factorio Server
After=network.target

[Service]
ExecStart=/home/$USER/factorio/bin/x64/factorio --start-server-load-latest
Restart=always
User=$USER

[Install]
WantedBy=multi-user.target
EOF
    if ! sudo systemctl enable factorio; then
        echo "Error: Failed to enable Factorio service."
        exit 1
    fi
    if ! sudo systemctl start factorio; then
        echo "Error: Failed to start Factorio service."
        exit 1
    fi
    echo "Factorio service enabled and started."
fi

# Step 6: Firewall
echo "Step 6: Firewall setup (manual action required)."
echo "Factorio uses UDP port 34197."
echo "- For VPS: Open port 34197/UDP in your provider’s control panel."
echo "- For local Ubuntu: Run 'sudo ufw allow 34197/udp'."
echo "Press Enter to continue."
read

# Final instructions
echo "Setup complete!"
echo "If auto-start is enabled, the server is running."
echo "Manual start: ~/factorio/bin/x64/factorio --start-server-load-latest"
echo "Connect to your server at your-vps-ip:34197."
echo "Check logs if needed: journalctl -u factorio"
