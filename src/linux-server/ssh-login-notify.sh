#!/bin/bash
####################################
#
# Notify on every ssh login with Telegram notification.
# Create script in /etc/profile.d/ssh-login-notify.sh
#   - cp ssh-login-notify.sh /etc/profile.d/ssh-login-notify.sh
# Make executable with 'chmod +x /etc/profile.d/ssh-login-notify.sh'
#
####################################

# Configuration for the Telegram bot
TELEGRAM_BOT_TOKEN="YOUR_TELEGRAM_BOT_TOKEN"
CHAT_ID="YOUR_TELEGRAM_CHAT_ID"

# Function to send a message via the Telegram bot
send_telegram_message() {
    message="$1"
    curl -s -X POST https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage -d chat_id=$CHAT_ID -d text="$message"
}

# Main function to collect SSH login information and send it via Telegram
main() {
    # Username of the logged-in user
    username=$(who | awk '{print $1}')
    username2=$(whoami)

    # # Check if the process with "www-data" is running
    # if pgrep -u www-data > /dev/null; then
    #     echo "Process with 'www-data' is running. Exiting script."
    #     exit 1
    # fi

    # # Ensure $username and $ip_address are not empty and $username2 is not "www-data"
    # if [ -z "$username" ] || [ -z "$ip_address" ] || [ "$username2" = "www-data" ]; then
    #     echo "Invalid login attempt detected. Exiting script."
    #     exit 1
    # fi

    # IP address of the logged-in user
    ip_address=$(echo $SSH_CONNECTION | awk '{print $1}')

    # Login time
    login_time=$(date)

    # Message with the collected information
    message="[F4P] 🤖 - SSH Login: ✅ User: $username, 👻 WhoAmI: $username2, IP Address: $ip_address, Time: $login_time"

    # Send message via Telegram bot
    send_telegram_message "$message"
}

# Call the main function
main