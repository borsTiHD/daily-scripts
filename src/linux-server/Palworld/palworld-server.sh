#!/bin/bash

# Konfiguration
SERVER_NAME="palworld_server"
SERVER_PATH="/home/steam/Steam/steamapps/common/PalServer"
SERVER_SCRIPT="./PalServer.sh"
SERVER_PARAMS="-useperfthreads -NoAsyncLoadingThread -UseMultithreadForDS"
LOG_LINES=10  # Anzahl der letzten Log-Einträge, die gedruckt werden sollen

# Funktion zum Starten des Servers
start_server() {
    cd "$SERVER_PATH" || exit
    screen -dmS "$SERVER_NAME" "$SERVER_SCRIPT" $SERVER_PARAMS
    echo "--------------------------------------"
    echo "Der Server wurde gestartet."
    echo "--------------------------------------"
}

# Funktion zum Überprüfen des Serverstatus
check_status() {
    if screen -list | grep -q "$SERVER_NAME"; then
        echo "--------------------------------------"
        echo "Der Server läuft."
        echo "--------------------------------------"
    else
        echo "--------------------------------------"
        echo "Der Server läuft nicht."
        echo "--------------------------------------"
    fi
}

# Funktion zum Stoppen des Servers
stop_server() {
    if screen -list | grep -q "$SERVER_NAME"; then
        screen -S "$SERVER_NAME" -X quit
        echo "--------------------------------------"
        echo "Der Server wurde gestoppt."
        echo "--------------------------------------"
    else
        echo "--------------------------------------"
        echo "Der Server läuft nicht, es gibt keine aktive Session zum Stoppen."
        echo "--------------------------------------"
    fi
}

# Funktion zum Drucken der letzten x Einträge aus der Screen-Session
print_last_logs() {
    if screen -list | grep -q "$SERVER_NAME"; then
        echo "--------------------------------------"
        echo "Die letzten $LOG_LINES Einträge aus der Screen-Session:"
        echo "--------------------------------------"
        screen -S "$SERVER_NAME" -X hardcopy -h "$LOG_LINES" /dev/stdout
        echo "--------------------------------------"
    else
        echo "--------------------------------------"
        echo "Der Server läuft nicht, es gibt keine aktive Session zum Drucken von Logs."
        echo "--------------------------------------"
    fi
}


# Hauptprogramm
echo "--------------------------------------"
echo "Willkommen zum Palworld Server Management Script."
echo "--------------------------------------"

while true; do
    echo "Bitte wählen Sie eine Option:"
    echo "1. Server starten"
    echo "2. Serverstatus abfragen"
    echo "3. Server stoppen"
    echo "4. Letzte $LOG_LINES Logs anzeigen"
    echo "5. Exit"
    echo "--------------------------------------"

    read -rp "Option: " choice

    case $choice in
    1)
        start_server
        ;;
    2)
        check_status
        ;;
    3)
        stop_server
        ;;
    4)
        print_last_logs
        ;;
    5)
        echo "--------------------------------------"
        echo "Auf Wiedersehen!"
        echo "--------------------------------------"
        exit 0
        ;;
    *)
        echo "--------------------------------------"
        echo "Ungültige Option. Bitte erneut eingeben."
        echo "--------------------------------------"
        ;;
    esac
done
