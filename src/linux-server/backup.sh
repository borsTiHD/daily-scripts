#!/bin/bash
####################################
#
# Backup to FTP server script with Telegram notification.
# Create script in /usr/local/bin/backup.sh
# Make executable with 'chmod +x /usr/local/bin/backup.sh'
#
# Add cronjob with 'crontab -e'
# Example: Run every day at 3am
# 0 3 * * * /usr/local/bin/backup.sh
#
####################################

# Directories to backup (add or remove directories as needed)
backup_directories=(
    "/opt/sinusbot"
    "/home/teamspeak/teamspeak3-server_linux_amd64"
    "/home/steam/PalworldBackup"
)

# Excluded directories and files (add or remove exclusions as needed)
excluded_items=(
    "/opt/sinusbot/data/store/*"
    "/opt/sinusbot/TeamSpeak3-Client-linux_amd64/*"
    "/opt/sinusbot/TeamSpeak3-Client-linux_amd64-3.5.6.run"
)

# FTP server settings
ftp_server="ftp.example.com"
ftp_user="username"
ftp_password="password"
ftp_directory="/backup"

# Telegram bot settings
telegram_bot_token="YOUR_TELEGRAM_BOT_TOKEN"
telegram_chat_id="YOUR_TELEGRAM_CHAT_ID"

# Function to send notification via Telegram
send_telegram_notification() {
    local message="$1"
    curl -s -X POST https://api.telegram.org/bot$telegram_bot_token/sendMessage -d "chat_id=$telegram_chat_id" -d "text=$message"
}

# Create temporary directory for storing the backup
tmp_dir=$(mktemp -d)
trap "rm -rf $tmp_dir" EXIT

# Create archive filename
day=$(date +%Y-%m-%d)
hostname=$(hostname -s)
archive_file="$hostname-$day.tar.gz"

# Construct backup file paths
backup_files=$(printf "%s " "${backup_directories[@]}")

# Construct exclude arguments for tar
exclude_args=""
for item in "${excluded_items[@]}"; do
    exclude_args+="--exclude=$item "
done

# Print start status message
echo "Backing up $backup_files to FTP server: $ftp_server"
date
echo

# Backup the files using tar to a temporary directory
tar $exclude_args -zcf "$tmp_dir/$archive_file" "${backup_directories[@]}"

# Upload the backup to FTP server
curl -s -T "$tmp_dir/$archive_file" ftp://$ftp_user:$ftp_password@$ftp_server/$ftp_directory/ && \
    send_telegram_notification "[F4P] - Backup uploaded successfully - [✅]" || \
    send_telegram_notification "[F4P] - Failed to upload backup - [❌]"

# Print end status message
echo
echo "Backup finished"
date
