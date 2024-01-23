#!/bin/bash

# Zielverzeichnis
backupDir=~/PalworldBackup

# Quellverzeichnis
sourceDir=~/Steam/steamapps/common/PalServer/Pal/Saved

# Überprüfen, ob das Zielverzeichnis existiert
if [ ! -d "$backupDir" ]; then
    echo "Das Zielverzeichnis existiert nicht. Es wird angelegt."
    mkdir -p "$backupDir"
fi

# Archivname mit aktuellem Datum
baseArchiveName="Palworld-Backup-$(date +%Y-%m-%d)"
archiveExtension=".tar.gz"

# Archivnummer
archiveNum=1
archiveName="$baseArchiveName-$archiveNum$archiveExtension"

# Überprüfen, ob der Archivname bereits existiert, und gegebenenfalls eine fortlaufende Nummer hinzufügen
while [ -e "$backupDir/$archiveName" ]; do
    ((archiveNum++))
    archiveName="$baseArchiveName-$archiveNum$archiveExtension"
done

# Archiv erstellen
tar -czvf "$backupDir/$archiveName" -C "$sourceDir" .

echo "Sicherung abgeschlossen. Archiv erstellt: $backupDir/$archiveName"
