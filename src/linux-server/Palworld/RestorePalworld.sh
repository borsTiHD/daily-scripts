#!/bin/bash

# Zielverzeichnis
backupDir=~/PalworldBackup

# Quellverzeichnis
sourceDir=~/Steam/steamapps/common/PalServer/Pal/Saved

# Überprüfen, ob das Zielverzeichnis existiert
if [ ! -d "$backupDir" ]; then
    echo "Das Zielverzeichnis existiert nicht. Wiederherstellung nicht möglich."
    exit 1
fi

# Liste der vorhandenen Archive (mit und ohne fortlaufende Nummern)
archives=($(ls "$backupDir" | grep -E '^Palworld-Backup-[0-9]{4}-[0-9]{2}-[0-9]{2}(-[0-9]+)?\.tar\.gz$'))

# Überprüfen, ob Archive vorhanden sind
if [ ${#archives[@]} -eq 0 ]; then
    echo "Es sind keine Archive zum Wiederherstellen vorhanden."
    exit 1
fi

# Liste der vorhandenen Archive anzeigen
echo "Verfügbare Archive zum Wiederherstellen:"
for ((i=0; i<${#archives[@]}; i++)); do
    echo "$(($i+1)). ${archives[$i]}"
done

# Benutzereingabe für die Auswahl eines Archivs
read -p "Geben Sie die Nummer des zu wiederherstellenden Archivs ein: " selection

# Überprüfen, ob die Auswahl gültig ist
if [[ ! "$selection" =~ ^[0-9]+$ || "$selection" -lt 1 || "$selection" -gt ${#archives[@]} ]]; then
    echo "Ungültige Auswahl. Das Skript wird beendet."
    exit 1
fi

# Ausgewähltes Archiv
selectedArchive="${archives[$(($selection-1))]}"

# Pfad zum ausgewählten Archiv
archivePath="$backupDir/$selectedArchive"

# Benutzereingabe für das Leeren des Zielverzeichnisses
read -p "Möchten Sie das Zielverzeichnis vor der Wiederherstellung leeren? (ja/nein): " emptyDirectory

# Überprüfen, ob das Zielverzeichnis geleert werden soll
if [ "$emptyDirectory" = "ja" ]; then
    echo "Das Zielverzeichnis wird geleert."
    rm -rf "$sourceDir"/*
else
    echo "Das Zielverzeichnis wird nicht geleert. Bestehende Dateien können überschrieben werden."
fi

# Wiederherstellung durch Entpacken des Archivs ins Quellverzeichnis
tar -xzvf "$archivePath" -C "$sourceDir" --strip-components=1

echo "Wiederherstellung abgeschlossen. Das Quellverzeichnis wurde durch das ausgewählte Archiv ersetzt: $selectedArchive"
