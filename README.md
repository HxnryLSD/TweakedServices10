# TweakedServices10

Konvertiertes BlackViper Windows 7 Skript fuer Windows 10/11 + Optimierungen.
    

Dieses Skript konfiguriert Windows-Dienste basierend auf der BlackViper "Tweaked" Liste.
Es enthaelt zusaetzliche Bereinigungen fuer Windows 10/11 (Telemetrie, Xbox, Maps) sowie sichere Windows-11-Erweiterungen.
    
ACHTUNG: Aenderungen an Diensten koennen die Systemfunktionalitaet beeintraechtigen.
Erstellen Sie vor der Ausfuehrung einen Wiederherstellungspunkt!


Start-Modi (Registry Werte):
2 = Automatisch
3 = Manuell
4 = Deaktiviert

## Fehlerbehebung

Wenn die Meldung

`Set-ServiceConfiguration: The term 'Set-ServiceConfiguration' is not recognized ...`

erscheint, wurde meist nur ein Teil des Skripts ausgefuehrt.
Bitte immer das komplette Skript starten (nicht nur markierte Zeilen), z. B.:

`powershell -ExecutionPolicy Bypass -File ".\Tweaked Services Win10 64bit.ps1"`
