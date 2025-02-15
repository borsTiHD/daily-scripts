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
# The file should be in the same directory as the script or in the script directory.
# You can use the provided backup.env.example as a template.
#
# To specify a custom environment file, pass the file path as an argument:
# /usr/local/bin/backup.sh /path/to/custom.env
#
####################################

# Load environment variables from provided argument or backup.env/.env file
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
env_file="${1:-}"

if [ -n "$env_file" ] && [ -f "$env_file" ]; then
    source "$env_file"
elif [ -f "$SCRIPT_DIR/backup.env" ]; then
    source "$SCRIPT_DIR/backup.env"
elif [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
else
    tmp_log_file="backup.log"
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    error="[❌] Environment file not found! Please provide one as an argument or create backup.env/.env in the script directory. Exiting..."
    message="[$timestamp] [ERROR] $error"
    echo -e "$message" | tee -a "$tmp_log_file"
    exit 1
fi

# Write logs to file
write_logs="${WRITE_LOGS:-true}"
log_file="${LOG_FILE_PATH:-backup.log}"

# Array of log levels
log_levels=("DEBUG" "INFO" "WARN" "ERROR")

# Function to write logs
log_message() {
    local log_level_param="$1"
    local message_param="$2"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local log_level=${log_level_param:-INFO}
    local message="[$timestamp] [$log_level] $message_param"
    if [ "$write_logs" = true ]; then
        echo -e "$message" | tee -a "$log_file"
    else
        echo -e "$message"
    fi
}

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

# Backup settings
num_days_of_backups_to_keep="$NUM_DAYS_OF_BACKUPS_TO_KEEP" # Number of days of backups to keep on FTP server
delete_old_backups="$DELETE_OLD_BACKUPS"

# Telegram bot settings
telegram_bot_token="$TELEGRAM_BOT_TOKEN"
telegram_chat_id="$TELEGRAM_CHAT_ID"

# Telegram message settings
telegram_send_report=${TELEGRAM_SEND_REPORT:-true}
telegram_send_info=${TELEGRAM_SEND_INFO:-true}
telegram_send_success=${TELEGRAM_SEND_SUCCESS:-true}
telegram_send_failure=${TELEGRAM_SEND_FAILURE:-true}
telegram_send_start=${TELEGRAM_SEND_START:-true}
telegram_send_end=${TELEGRAM_SEND_END:-true}
telegram_verbose=${TELEGRAM_VERBOSE:-true}
telegram_message_prefix=${TELEGRAM_MESSAGE_PREFIX:-"[BACKUP] - "}

# Arrays to store succeeded and failed backups
succeeded_backups=()
failed_backups=()

# Arrays to store succeeded and failed deleted files on FTP server
succeeded_deleted_files=()
failed_deleted_files=()
deletion_failed=false

# Function to send notification via Telegram
send_telegram_notification() {
    local message="$1"
    echo "[📢] Telegram notification sent: $message"
    formatted_message=$(printf "%b" "$message")
    curl -s -X POST https://api.telegram.org/bot$telegram_bot_token/sendMessage -d "chat_id=$telegram_chat_id" -d "text=${telegram_message_prefix}${formatted_message}"
    echo
}

# Function for the backup process
perform_folder_backups() {
    # Create temporary directory for storing the backup
    local tmp_dir=$(mktemp -d)
    trap "rm -rf $tmp_dir" EXIT

    # Create archive filename
    local day=$(date +%Y-%m-%d)
    local hostname=$(hostname) # short: $(hostname -s)
    local archive_file="${day}-files-${hostname}.tar.gz"

    # Construct exclude arguments for tar
    local exclude_args=""
    for item in "${excluded_items[@]}"; do
        exclude_args+="--exclude=$item "
    done

    # Print start status message
    log_message "${log_levels[1]}" "[🚀] Backing up the following files to FTP server: $ftp_server"
    for file in "${backup_directories[@]}"; do
        log_message "${log_levels[1]}" "  - $file"
    done

    # Send info notification if enabled
    if [ "$telegram_send_info" = true ]; then
        message="Starting backups for the following paths [🚀]:\n"
        for path in "${backup_directories[@]}"; do
            message+="  - $path\n"
        done
        send_telegram_notification "$message"
    fi

    # Backup the files using tar to a temporary directory
    tar $exclude_args -zcf "$tmp_dir/$archive_file" "${backup_directories[@]}" || { 
        log_message "${log_levels[3]}" "[❌] Error: Failed to create backup archive"
        if [ "$telegram_verbose" = true ]; then
            send_telegram_notification "Failed to create backup archive - [❌]"
        fi
        failed_backups+=("$archive_file")
        return 1
    }

    # Upload the backup to FTP server
    curl -s -T "$tmp_dir/$archive_file" ftp://$ftp_user:$ftp_password@$ftp_server/$ftp_directory/ || { 
        log_message "${log_levels[3]}" "[❌] Error: Failed to upload backup to FTP server"
        if [ "$telegram_verbose" = true ]; then
            send_telegram_notification "Failed to upload backup to FTP server - [❌]"
        fi
        failed_backups+=("$archive_file")
        return 1
    }

    # Send success notification if enabled
    if [ "$telegram_verbose" = true ]; then
        log_message "${log_levels[1]}" "[✅] Sending success notification to Telegram..."
        send_telegram_notification "Backup uploaded successfully - [✅]"
    fi

    succeeded_backups+=("$archive_file")
    return 0
}

# Function to backup Docker Compose volume
backup_docker_volume() {
    local volume_name=$1
    local day=$(date +%Y-%m-%d)
    local backup_file_name="${day}-docker-${volume_name}.tar.gz"

    # Create temporary directory for storing the backup
    local tmp_dir=$(mktemp -d)
    trap "rm -rf $tmp_dir" EXIT

    log_message "${log_levels[1]}" "[🚀] Starting backup for volume: $volume_name..."
    docker run --rm -v ${volume_name}:/data -v $tmp_dir:/backup alpine tar czf /backup/${backup_file_name} -C /data .

    # Check if backup was successful
    if [ $? -eq 0 ]; then
        log_message "${log_levels[1]}" "[✅] Backup completed successfully for volume: $volume_name "
        if [ "$telegram_verbose" = true ]; then
            send_telegram_notification "Backup completed successfully for volume [✅]: $volume_name"
        fi
        succeeded_backups+=("$backup_file_name")
    else
        log_message "${log_levels[3]}" "[❌] Error: Failed to backup volume: $volume_name"
        if [ "$telegram_verbose" = true ]; then
            send_telegram_notification "Failed to backup volume [❌]: $volume_name"
        fi
        failed_backups+=("$backup_file_name")
        return 1
    fi

    # Upload the backup to FTP server
    if curl -s -T "$tmp_dir/$backup_file_name" ftp://$ftp_user:$ftp_password@$ftp_server/$ftp_directory/; then
        log_message "${log_levels[1]}" "[✅] Backup uploaded to FTP server successfully: $volume_name"
        if [ "$telegram_verbose" = true ]; then
            send_telegram_notification "Backup uploaded to FTP server successfully [✅]: $volume_name"
        fi
    else
        log_message "${log_levels[3]}" "[❌] Error: Failed to upload backup volume $volume_name to FTP server"
        if [ "$telegram_verbose" = true ]; then
            send_telegram_notification "Failed to upload backup to FTP server [❌]: $volume_name"
        fi
        failed_backups+=("$backup_file_name")
        return 1
    fi

    return 0
}

# Perform Docker Compose volume backups
perform_docker_backups() {
    # Print start status message
    log_message "${log_levels[1]}" "[🚀] Backing up the following docker volumes to FTP server: $ftp_server"
    for volume in "${docker_volumes_to_backup[@]}"; do
        log_message "${log_levels[1]}" "  - $volume"
    done

    # Send info notification if enabled
    if [ "$telegram_send_info" = true ]; then
        message="Starting Docker volume backups [🚀]:\n"
        for volume in "${docker_volumes_to_backup[@]}"; do
            message+="  - $volume\n"
        done
        send_telegram_notification "$message"
    fi
    echo

    for volume in "${docker_volumes_to_backup[@]}"; do
        backup_docker_volume "$volume" || exit 1
    done
}

# Function to cleanup old backups on FTP server, keeping only the newest x backups
cleanup_old_backups() {
    # Print start status message
    log_message "${log_levels[1]}" "[🚀] Starting cleanup of old backups on FTP server: $ftp_server "
    log_message "${log_levels[1]}" "[📅] Number of days of backups to keep: $num_days_of_backups_to_keep"

    # Send info notification if enabled
    if [ "$telegram_send_info" = true ]; then
        send_telegram_notification "Starting cleanup of old backups [🚀]"
    fi

    # Get list of all files on FTP server
    local files=$(curl -s ftp://$ftp_user:$ftp_password@$ftp_server/$ftp_directory/)
    local file_names=$(echo "$files" | awk '{print $NF}') # Extract file names from the list
    local file_count=$(echo "$files" | wc -l) # Count the number of files

    # Print status message
    log_message "${log_levels[1]}" "[📁] Found $file_count backup files on FTP server: $ftp_server"
    log_message "${log_levels[1]}" "[📁] Backup files:\n$file_names"

    # Get oldest files to delete based on the number of days to keep
    # - Filter files with the prefix matching the backup files (e.g., "2021-01-01-*.tar.gz")
    # - Sort files by date (oldest first)
    # - Keep only the newest files for the specified number of days ("num_days_of_backups_to_keep")
    # - Delete the rest of the files from the FTP server
    # - Example: If "num_days_of_backups_to_keep" is 2, and files are:
    #   "2021-01-01-01.tar.gz, 2021-01-01-02.tar.gz, 2021-01-01-03.tar.gz, 2021-01-02-01.tar.gz, 2021-01-02-02.tar.gz"
    #   We will keep: "2021-01-01-02.tar.gz, 2021-01-01-03.tar.gz, 2021-01-02-01.tar.gz, 2021-01-02-02.tar.gz"
    local sorted_files=$(echo "$file_names" | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}-.*\.tar\.gz$' | sort)
    local unique_dates=$(echo "$sorted_files" | grep -oP '^[0-9]{4}-[0-9]{2}-[0-9]{2}' | uniq | tail -n $num_days_of_backups_to_keep)
    local files_to_keep=$(echo "$sorted_files" | grep -E "$(echo "$unique_dates" | tr '\n' '|' | sed 's/|$//')")
    local files_to_delete=$(comm -23 <(echo "$sorted_files") <(echo "$files_to_keep"))

    # Print status message
    log_message "${log_levels[1]}" "[📁] Keeping the following backup files: $files_to_keep"
    log_message "${log_levels[1]}" "[🗑️] Deleting the following backup files: $files_to_delete"

    if [ "$telegram_send_info" = true ]; then
        send_telegram_notification "$(printf "Keeping the following backup files [📁]:\n%s\n\nDeleting the following backup files [🗑️]:\n%s" "$files_to_keep" "$files_to_delete")"
    fi

    # Delete old backup files from FTP server
    for file in $files_to_delete; do
        full_path="$ftp_directory/$file" # Full path to the file on FTP server (e.g. /backup/2021-01-01-01.tar.gz)
        response=$(curl -v --user $ftp_user:$ftp_password ftp://$ftp_server$full_path -Q "DELE $full_path" 2>&1)

        # Check if the file was deleted successfully
        if [[ $response == *"250 DELE command successful"* ]]; then
            log_message "${log_levels[1]}" "[✅] Deleted backup file: $file"
            if [ "$telegram_verbose" = true ]; then
                send_telegram_notification "Deleted backup file [✅]: $file"
            fi
            succeeded_deleted_files+=("$file")
        else
            log_message "${log_levels[3]}" "[❌] Error response: $response"
            log_message "${log_levels[3]}" "[❌] Error: Failed to delete backup file: $file"
            if [ "$telegram_verbose" = true ]; then
                send_telegram_notification "Failed to delete backup file [❌]: $file"
            fi
            failed_deleted_files+=("$file")
        fi
    done

    # Log failed deleted files
    if ((${#failed_deleted_files[@]} > 0)); then
        log_message "${log_levels[3]}" "[❌] Failed to delete the following backup files:"
        for item in "${failed_deleted_files[@]}"; do
            log_message "${log_levels[3]}" "  - $item"
        done

        if [ "$telegram_send_failure" = true ]; then
            message="Failed to delete the following backup files [❌]:\n"
            for item in "${failed_deleted_files[@]}"; do
                message+="  - $item\n"
            done
            send_telegram_notification "$message"
        fi
    fi
}

# Function for creating report
report_info() {
    local report="Backup Report - [🏁]\n"

    # Log succeeded backups
    report+="\n"
    if ((${#succeeded_backups[@]} > 0)); then
        report+="Succeeded backups: [✅]\n"
        for item in "${succeeded_backups[@]}"; do
            report+="  - $item\n"
        done
    else
        report+="No succeeded backups: [❌]\n"
    fi

    # Log failed backups
    report+="\n"
    if ((${#failed_backups[@]} > 0)); then
        report+="Failed backups: [❌]\n"
        for item in "${failed_backups[@]}"; do
            report+="  - $item\n"
        done
    else
        report+="No failed backups: [✅]\n"
    fi

    # Log cleanup status
    report+="\n"
    if [ "$delete_old_backups" = true ]; then
        if [ "$deletion_failed" = false ]; then
            # Log succeeded deleted files
            if ((${#succeeded_deleted_files[@]} > 0)); then
                report+="Deleted old backups: [✅]\n"
                for item in "${succeeded_deleted_files[@]}"; do
                    report+="  - $item\n"
                done
            else
                report+="No old backups deleted: [ℹ️]\n"
            fi

            # Log failed deleted files
            if ((${#failed_deleted_files[@]} > 0)); then
                report+="Failed to delete old backups: [❌]\n"
                for item in "${failed_deleted_files[@]}"; do
                    report+="  - $item\n"
                done
            else
                report+="Cleanup of old backups was successful (or there was nothing to delete): [ℹ️]\n"
            fi
        else
            report+="Failed to delete old backups: [❌]\n"
        fi
    else
        report+="Cleanup of old backups is disabled: [⚠️]\n"
    fi

    # Log report
    echo
    log_message "${log_levels[1]}" "$report"

    # Send report to telegram if enabled
    if [ "$telegram_send_report" = true ]; then
        send_telegram_notification "$report"
    fi
}

# Main process
main() {
    log_message "${log_levels[1]}" "--- Backup script started ---"
    log_message "${log_levels[1]}" "[🚀] Starting backup process..."
    echo
    log_message "${log_levels[1]}" "[📡] FTP server: $ftp_server"
    log_message "${log_levels[1]}" "[📡] FTP path: $ftp_directory"
    log_message "${log_levels[1]}" "[📅] Number of days of backups to keep: $num_days_of_backups_to_keep"
    echo

    # Send start notification if enabled
    if [ "$telegram_send_start" = true ]; then
        send_telegram_notification "Backup started - [🚀]"
    fi

    # Perform backups
    perform_folder_backups
    perform_docker_backups

    # Cleanup old backups on FTP server, keeping only the newest x backups
    if [ "$delete_old_backups" = true ]; then
        # Check if any backup failed
        if ((${#failed_backups[@]} > 0)); then
            log_message "${log_levels[3]}" "[❌] One or more backups failed. Skipping cleanup of old backups."
            if [ "$telegram_send_failure" = true ]; then
                send_telegram_notification "One or more backups failed - [❌]. Skipping cleanup of old backups."
            fi
            deletion_failed=true
        else
            cleanup_old_backups
        fi
    fi

    # Send and log report
    report_info

    # Send end notification if enabled
    echo
    if [ "$telegram_send_end" = true ]; then
        send_telegram_notification "Backup finished - [🏁]"
    fi

    # Print end status message
    echo
    log_message "${log_levels[1]}" "[🏁] Backup finished"
    log_message "${log_levels[1]}" "--- Backup script finished ---"
}

# Run the main process
main