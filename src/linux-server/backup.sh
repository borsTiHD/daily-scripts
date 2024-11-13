#!/bin/bash
####################################
#
# Version: 1.0
# Author: borsTiHD
#
# Description:
# Backup to FTP server script with Telegram notification.
# Create script in /usr/local/bin/backup.sh
# Make executable with 'chmod +x /usr/local/bin/backup.sh'
#
# Required packages: curl, tar
#
# Usage:
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

# Array of Docker volumes to backup
volumes_to_backup=(
    "p08wsso0swko4sgsc0oco4gc_server-data"
)

# FTP server settings
ftp_server="ftp.example.com"
ftp_user="username"
ftp_password="password"
ftp_directory="/backup/freaks4posts"

# Number of latest backups to keep on FTP server
num_backups_to_keep=8

# Telegram bot settings
telegram_bot_token="YOUR_TELEGRAM_BOT_TOKEN"
telegram_chat_id="YOUR_TELEGRAM_CHAT_ID"

# Function to send notification via Telegram
send_telegram_notification() {
    local message="$1"
    curl -s -X POST https://api.telegram.org/bot$telegram_bot_token/sendMessage -d "chat_id=$telegram_chat_id" -d "text=$message"
}

# Function for the backup process
perform_backup() {
    local ftp_server="$1"
    local ftp_user="$2"
    local ftp_password="$3"
    local ftp_directory="$4"

    # Create temporary directory for storing the backup
    local tmp_dir=$(mktemp -d)
    trap "rm -rf $tmp_dir" EXIT

    # Create archive filename
    local day=$(date +%Y-%m-%d)
    local hostname=$(hostname -s)
    local archive_file="$hostname-$day.tar.gz"

    # Construct backup file paths
    local backup_files=$(printf "%s " "${backup_directories[@]}")

    # Construct exclude arguments for tar
    local exclude_args=""
    for item in "${excluded_items[@]}"; do
        exclude_args+="--exclude=$item "
    done

    # Print start status message
    echo "Backing up $backup_files to FTP server: $ftp_server"
    date
    echo

    # Backup the files using tar to a temporary directory
    tar $exclude_args -zcf "$tmp_dir/$archive_file" "${backup_directories[@]}" || { echo "Error: Failed to create backup archive."; return 1; }

    # Upload the backup to FTP server
    curl -s -T "$tmp_dir/$archive_file" ftp://$ftp_user:$ftp_password@$ftp_server/$ftp_directory/ || { echo "Error: Failed to upload backup to FTP server."; return 1; }

    return 0
}

# Function to cleanup old backups on FTP server, keeping only the newest x backups
cleanup_old_backups() {

    # TODO: Implement cleanup using lftp - NOT WORKING RIGHT NOW!!!

    local ftp_server="$1"
    local ftp_user="$2"
    local ftp_password="$3"
    local ftp_directory="$4"
    local num_backups_to_keep="$5"

    echo "Connecting to FTP server to cleanup old backups..."
    lftp -c "open -u $ftp_user,$ftp_password $ftp_server; cd $ftp_directory; ls -t | tail -n +$((num_backups_to_keep + 1)) | xargs -I {} rm {}" || { echo "Error: Failed to cleanup old backups on FTP server."; return 1; }

#     # Connect to FTP server
#     echo "Connecting to FTP server to cleanup old backups..."
#     ftp -inv $ftp_server <<EOF
#     user $ftp_user $ftp_password
#     cd $ftp_directory
#     ls -t | awk "NR>$num_backups_to_keep" | while read filename; do
#         echo "Deleting old backup: $filename"
#         rm $filename
#     done
#     bye
# EOF
}

# Function to backup Docker Compose volume
backup_docker_volume() {
    local volume_name=$1
    local day=$(date +%Y-%m-%d)
    local backup_file_name="${volume_name}-backup-${day}.tar.gz"

    # Create temporary directory for storing the backup
    local tmp_dir=$(mktemp -d)
    trap "rm -rf $tmp_dir" EXIT

    echo "Starting backup for volume: $volume_name..."
    docker run --rm -v ${volume_name}:/data -v $tmp_dir:/backup alpine tar czf /backup/${backup_file_name} -C /data .

    if [ $? -eq 0 ]; then
        echo "Backup for volume $volume_name completed successfully."
        send_telegram_notification "[F4P] - Backup for volume $volume_name completed successfully - [✅]"
    else
        echo "Error: Failed to backup volume $volume_name."
        send_telegram_notification "[F4P] - Failed to backup volume $volume_name - [❌]"
        return 1
    fi

    # Upload the backup to FTP server
    curl -s -T "$tmp_dir/$backup_file_name" ftp://$ftp_user:$ftp_password@$ftp_server/$ftp_directory/ || { echo "Error: Failed to upload backup to FTP server."; return 1; }

    return 0
}

# Perform backup
perform_backup "$ftp_server" "$ftp_user" "$ftp_password" "$ftp_directory" && \
    send_telegram_notification "[F4P] - Backup uploaded successfully - [✅]" || \
    send_telegram_notification "[F4P] - Failed to upload backup - [❌]"

# Cleanup old backups on FTP server, keeping only the newest x backups
# cleanup_old_backups "$ftp_server" "$ftp_user" "$ftp_password" "$ftp_directory" "$num_backups_to_keep" && \
#     send_telegram_notification "[F4P] - Old backups cleanup successful - [✅]" || \
#     send_telegram_notification "[F4P] - Failed to cleanup old backups - [❌]"

# Perform Docker Compose volume backups
for volume in "${volumes_to_backup[@]}"; do
    backup_docker_volume "$volume"
done

# Print end status message
echo
echo "Backup finished"
date
