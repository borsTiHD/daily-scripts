#!/bin/bash
####################################
#
# Version: 1.1
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
# Note:
# This script requires a backup.env or .env file with the necessary environment variables.
# You can use the provided backup.env.example as a template.
#
####################################

# Load environment variables from backup.env or .env file
if [ -f backup.env ]; then
    source backup.env
elif [ -f .env ]; then
    source .env
else
    echo "backup.env or .env file not found!"
    exit 1
fi

# Directories to backup (add or remove directories as needed)
backup_directories=(${BACKUP_DIRECTORIES//,/ })

# Excluded directories and files (add or remove exclusions as needed)
excluded_items=(${EXCLUDED_ITEMS//,/ })

# Array of Docker volumes to backup
docker_volumes_to_backup=(${DOCKER_VOLUMES_TO_BACKUP//,/ })

# FTP server settings
ftp_server="$FTP_SERVER"
ftp_user="$FTP_USER"
ftp_password="$FTP_PASSWORD"
ftp_directory="$FTP_DIRECTORY"

# Number of latest backups to keep on FTP server
num_backups_to_keep="$NUM_BACKUPS_TO_KEEP"

# Telegram bot settings
telegram_bot_token="$TELEGRAM_BOT_TOKEN"
telegram_chat_id="$TELEGRAM_CHAT_ID"

# Telegram message settings
telegram_send_success=${TELEGRAM_SEND_SUCCESS:-true}
telegram_send_failure=${TELEGRAM_SEND_FAILURE:-true}
telegram_send_start=${TELEGRAM_SEND_START:-true}
telegram_send_end=${TELEGRAM_SEND_END:-true}
telegram_verbose=${TELEGRAM_VERBOSE:-true}

# Function to send notification via Telegram
send_telegram_notification() {
    local message="$1"
    curl -s -X POST https://api.telegram.org/bot$telegram_bot_token/sendMessage -d "chat_id=$telegram_chat_id" -d "text=$message"
}

# Arrays to store succeeded and failed backups
succeeded_backups=()
failed_backups=()

# Function for the backup process
perform_folder_backups() {
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
    echo -e "Backing up $backup_files to FTP server: $ftp_server\n"
    date
    echo

    # Backup the files using tar to a temporary directory
    tar $exclude_args -zcf "$tmp_dir/$archive_file" "${backup_directories[@]}" || { 
        echo -e "Error: Failed to create backup archive.\n"
        if [ "$telegram_verbose" = true ]; then
            send_telegram_notification "[F4P] - Failed to create backup archive - [❌]"
        fi
        failed_backups+=("$archive_file")
        return 1
    }

    # Upload the backup to FTP server
    curl -s -T "$tmp_dir/$archive_file" ftp://$ftp_user:$ftp_password@$ftp_server/$ftp_directory/ || { 
        echo -e "Error: Failed to upload backup to FTP server.\n"
        if [ "$telegram_verbose" = true ]; then
            send_telegram_notification "[F4P] - Failed to upload backup to FTP server - [❌]"
        fi
        failed_backups+=("$archive_file")
        return 1
    }

    # Send success notification if enabled
    if [ "$telegram_verbose" = true ]; then
        echo -e "Sending success notification to Telegram...\n"
        send_telegram_notification "[F4P] - Backup uploaded successfully - [✅]"
    fi

    succeeded_backups+=("$archive_file")
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

    echo -e "Starting backup for volume: $volume_name...\n"
    docker run --rm -v ${volume_name}:/data -v $tmp_dir:/backup alpine tar czf /backup/${backup_file_name} -C /data .

    if [ $? -eq 0 ]; then
        echo -e "Backup for volume $volume_name completed successfully.\n"
        if [ "$telegram_verbose" = true ]; then
            send_telegram_notification "[F4P] - Backup for volume $volume_name completed successfully - [✅]"
        fi
        succeeded_backups+=("$backup_file_name")
    else
        echo -e "Error: Failed to backup volume $volume_name.\n"
        if [ "$telegram_verbose" = true ]; then
            send_telegram_notification "[F4P] - Failed to backup volume $volume_name - [❌]"
        fi
        failed_backups+=("$backup_file_name")
        return 1
    }

    # Upload the backup to FTP server
    curl -s -T "$tmp_dir/$backup_file_name" ftp://$ftp_user:$ftp_password@$ftp_server/$ftp_directory/ || { 
        echo -e "Error: Failed to upload backup to FTP server.\n"
        if [ "$telegram_verbose" = true ]; then
            send_telegram_notification "[F4P] - Failed to upload backup to FTP server - [❌]"
        fi
        failed_backups+=("$backup_file_name")
        return 1
    }

    return 0
}

# Perform Docker Compose volume backups
perform_docker_backups() {
    for volume in "${docker_volumes_to_backup[@]}"; do
        backup_docker_volume "$volume" || exit 1
    done
}

# Send start notification if enabled
if [ "$telegram_send_start" = true ]; then
    send_telegram_notification "[F4P] - Backup started - [🚀]"
fi

# Perform backups
perform_folder_backups || exit 1
perform_docker_backups || exit 1

# Cleanup old backups on FTP server, keeping only the newest x backups
# cleanup_old_backups "$ftp_server" "$ftp_user" "$ftp_password" "$ftp_directory" "$num_backups_to_keep" && \
#     send_telegram_notification "[F4P] - Old backups cleanup successful - [✅]" || \
#     send_telegram_notification "[F4P] - Failed to cleanup old backups - [❌]"

# Send end notification if enabled
if [ "$telegram_send_end" = true ]; then
    send_telegram_notification "[F4P] - Backup finished - [🏁]"
fi

# Print end status message
echo
echo -e "Backup finished\n"
date

# Log succeeded and failed backups
echo -e "\nSucceeded backups:"
for item in "${succeeded_backups[@]}"; do
    echo -e "  - $item"
done

if [ "$telegram_send_success" = true ] && [ ${#succeeded_backups[@]} -gt 0 ]; then
    send_telegram_notification "[F4P] - Succeeded backups:\n$(printf "  - %s\n" "${succeeded_backups[@]}")"
fi

echo -e "\nFailed backups:"
for item in "${failed_backups[@]}"; do
    echo -e "  - $item"
done

if [ "$telegram_send_failure" = true ] && [ ${#failed_backups[@]} -gt 0 ]; then
    send_telegram_notification "[F4P] - Failed backups:\n$(printf "  - %s\n" "${failed_backups[@]}")"
fi
