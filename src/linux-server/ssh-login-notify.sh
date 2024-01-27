#!/bin/bash
####################################
#
# Notify on every ssh login with Telegram notification.
# Create script in /etc/profile.d/ssh-login-notify.sh
# Make executable with 'chmod +x /etc/profile.d/ssh-login-notify.sh'
#
####################################

# Konfiguration für den Telegram-Bot
TELEGRAM_BOT_TOKEN="YOUR_TELEGRAM_BOT_TOKEN"
CHAT_ID="YOUR_TELEGRAM_CHAT_ID"

# Funktion zum Versenden einer Nachricht über den Telegram-Bot
send_telegram_message() {
    message="$1"
    curl -s -X POST https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage -d chat_id=$CHAT_ID -d text="$message"
}

# Hauptfunktion zum Sammeln von SSH-Login-Informationen und Versenden über Telegram
main() {
    # Benutzername des eingeloggten Benutzers
    username=$(whoami)

    # IP-Adresse des eingeloggten Benutzers
    ip_address=$(echo $SSH_CONNECTION | awk '{print $1}')

    # Zeitpunkt des Logins
    login_time=$(date)

    # Nachricht mit den gesammelten Informationen
    message="[F4P] 🤖 - SSH-Login: ✅ Benutzer: $username, IP-Adresse: $ip_address, Zeitpunkt: $login_time"

    # Nachricht über Telegram-Bot senden
    send_telegram_message "$message"
}

# Aufruf der Hauptfunktion
main
