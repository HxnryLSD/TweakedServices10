<#
.SYNOPSIS
    Konvertiertes BlackViper Windows 7 Skript fuer Windows 10/11 + Optimierungen.
    
.DESCRIPTION
    Dieses Skript konfiguriert Windows-Dienste basierend auf der BlackViper "Tweaked" Liste.
    Es enthaelt zusaetzliche Bereinigungen fuer Windows 10/11 (Telemetrie, Xbox, Maps).
    
    ACHTUNG: Aenderungen an Diensten koennen die Systemfunktionalitaet beeintraechtigen.
    Erstellen Sie vor der Ausfuehrung einen Wiederherstellungspunkt!

.NOTES
    Start-Modi (Registry Werte):
    2 = Automatisch
    3 = Manuell
    4 = Deaktiviert
#>

# Erfordert Administratorrechte
$CurrentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$CurrentPrincipal = New-Object Security.Principal.WindowsPrincipal($CurrentIdentity)
if (-not $CurrentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[FEHLER] Dieses Skript muss als Administrator ausgefuehrt werden." -ForegroundColor Red
    Write-Host "Bitte PowerShell als Administrator starten und erneut ausfuehren." -ForegroundColor Yellow
    exit 1
}

# OS-Info ermitteln (Win11 ab Build 22000)
$OsInfo = Get-CimInstance -ClassName Win32_OperatingSystem
$BuildNumber = [int]$OsInfo.BuildNumber
$IsWindows11 = $BuildNumber -ge 22000

function Resolve-ServiceRegistryPaths {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ServiceName
    )

    $basePath = "HKLM:\SYSTEM\CurrentControlSet\Services"
    $exactPath = Join-Path -Path $basePath -ChildPath $ServiceName

    if (Test-Path $exactPath) {
        return @($exactPath)
    }

    $instancePaths = Get-ChildItem -Path $basePath -ErrorAction SilentlyContinue |
        Where-Object { $_.PSChildName -like "$ServiceName_*" } |
        Select-Object -ExpandProperty PSPath

    if ($instancePaths) {
        return $instancePaths
    }

    return @()
}

# Funktion zur Konfiguration der Dienste
function Set-ServiceConfiguration {
    param (
        [string]$ServiceName,
        [int]$StartType,       # 2=Auto, 3=Manual, 4=Disabled
        [bool]$DelayedStart = $false
    )

    if ($StartType -notin 2, 3, 4) {
        Write-Host "[FEHLER] Ungueltiger StartType fuer ${ServiceName}: $StartType" -ForegroundColor Red
        return
    }

    $registryPaths = Resolve-ServiceRegistryPaths -ServiceName $ServiceName

    if ($registryPaths.Count -gt 0) {
        foreach ($RegistryPath in $registryPaths) {
            try {
                # Start-Typ setzen
                Set-ItemProperty -Path $RegistryPath -Name "Start" -Value $StartType -ErrorAction Stop

                # DelayedAutoStart handhaben (Nur relevant wenn Start=2)
                if ($StartType -eq 2 -and $DelayedStart) {
                    Set-ItemProperty -Path $RegistryPath -Name "DelayedAutoStart" -Value 1 -ErrorAction SilentlyContinue
                }
                elseif (Get-ItemProperty -Path $RegistryPath -Name "DelayedAutoStart" -ErrorAction SilentlyContinue) {
                    Set-ItemProperty -Path $RegistryPath -Name "DelayedAutoStart" -Value 0 -ErrorAction SilentlyContinue
                }

                $resolvedServiceName = Split-Path -Path $RegistryPath -Leaf

                $modeStr = switch ($StartType) { 2 { "Automatisch" } 3 { "Manuell" } 4 { "Deaktiviert" } default { "Unbekannt" } }
                if ($DelayedStart -and $StartType -eq 2) { $modeStr += " (Verzoegert)" }

                Write-Host "[OK] $resolvedServiceName gesetzt auf: $modeStr" -ForegroundColor Green
            }
            catch {
                Write-Host "[FEHLER] Konnte $ServiceName nicht konfigurieren. Grund: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
    else {
        Write-Host "[INFO] Dienst $ServiceName nicht gefunden (Ignoriert)" -ForegroundColor DarkGray
    }
}

Write-Host "Starte Dienst-Optimierung fuer $($OsInfo.Caption) (Build $BuildNumber)..." -ForegroundColor Cyan
Write-Host "Druecken Sie STRG+C, um abzubrechen, oder eine beliebige Taste zum Fortfahren."
if ($Host.Name -eq "ConsoleHost" -and $Host.UI -and $Host.UI.RawUI) {
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

if (-not (Get-Command -Name "Set-ServiceConfiguration" -CommandType Function -ErrorAction SilentlyContinue)) {
    Write-Host "[WARNUNG] 'Set-ServiceConfiguration' nicht gefunden. Lade kompatiblen Fallback..." -ForegroundColor Yellow

    function Set-ServiceConfiguration {
        param (
            [string]$ServiceName,
            [int]$StartType,
            [bool]$DelayedStart = $false
        )

        if ($StartType -notin 2, 3, 4) {
            Write-Host "[FEHLER] Ungueltiger StartType fuer ${ServiceName}: $StartType" -ForegroundColor Red
            return
        }

        $registryBasePath = "HKLM:\SYSTEM\CurrentControlSet\Services"
        $registryPaths = @()
        $exactPath = Join-Path -Path $registryBasePath -ChildPath $ServiceName

        if (Test-Path $exactPath) {
            $registryPaths = @($exactPath)
        }
        else {
            $registryPaths = Get-ChildItem -Path $registryBasePath -ErrorAction SilentlyContinue |
                Where-Object { $_.PSChildName -like "$ServiceName_*" } |
                Select-Object -ExpandProperty PSPath
        }

        if (-not $registryPaths -or $registryPaths.Count -eq 0) {
            Write-Host "[INFO] Dienst $ServiceName nicht gefunden (Ignoriert)" -ForegroundColor DarkGray
            return
        }

        foreach ($RegistryPath in $registryPaths) {
            try {
                Set-ItemProperty -Path $RegistryPath -Name "Start" -Value $StartType -ErrorAction Stop

                if ($StartType -eq 2 -and $DelayedStart) {
                    Set-ItemProperty -Path $RegistryPath -Name "DelayedAutoStart" -Value 1 -ErrorAction SilentlyContinue
                }
                elseif (Get-ItemProperty -Path $RegistryPath -Name "DelayedAutoStart" -ErrorAction SilentlyContinue) {
                    Set-ItemProperty -Path $RegistryPath -Name "DelayedAutoStart" -Value 0 -ErrorAction SilentlyContinue
                }

                $resolvedServiceName = Split-Path -Path $RegistryPath -Leaf
                $modeStr = switch ($StartType) { 2 { "Automatisch" } 3 { "Manuell" } 4 { "Deaktiviert" } default { "Unbekannt" } }
                if ($DelayedStart -and $StartType -eq 2) { $modeStr += " (Verzoegert)" }

                Write-Host "[OK] $resolvedServiceName gesetzt auf: $modeStr" -ForegroundColor Green
            }
            catch {
                Write-Host "[FEHLER] Konnte $ServiceName nicht konfigurieren. Grund: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
}

# ---------------------------------------------------------
# Originale BlackViper Tweaks (Portiert fuer Win10)
# ---------------------------------------------------------

# Networking & Security
Set-ServiceConfiguration -ServiceName "ALG" -StartType 4 # Default: 3 | Application Layer Gateway (Veraltet, meist unnoetig)
Set-ServiceConfiguration -ServiceName "BFE" -StartType 2 # Default: 2 | Basisfiltermodul (Wichtig für Firewall/VPN)
Set-ServiceConfiguration -ServiceName "BITS" -StartType 3 # Default: 2 (Delayed) | Hintergrunduebertragungsdienst (Updates)
Set-ServiceConfiguration -ServiceName "Dhcp" -StartType 2 # Default: 2 | DHCP-Client (IP-Adresse vom Router beziehen)
Set-ServiceConfiguration -ServiceName "Dnscache" -StartType 2 # Default: 2 | DNS-Client (Namensaufloesung)
Set-ServiceConfiguration -ServiceName "LanmanServer" -StartType 2 # Default: 2 | Server (Datei- und Druckerfreigabe)
Set-ServiceConfiguration -ServiceName "LanmanWorkstation" -StartType 2 # Default: 2 | Arbeitsstationsdienst (Netzwerkverbindungen)
Set-ServiceConfiguration -ServiceName "lmhosts" -StartType 2 # Default: 3 | TCP/IP-NetBIOS-Hilfsprogramm (Legacy-Support)
Set-ServiceConfiguration -ServiceName "MpsSvc" -StartType 2 # Default: 2 | Windows Defender Firewall (Sehr wichtig!)
Set-ServiceConfiguration -ServiceName "NlaSvc" -StartType 2 # Default: 2 | Network Location Awareness (Erkennt Netzwerkstatus)
Set-ServiceConfiguration -ServiceName "nsi" -StartType 2 # Default: 2 | Netzwerkschnittstellenspeicher (Netzwerk-Monitoring)
Set-ServiceConfiguration -ServiceName "WinHttpAutoProxySvc" -StartType 3 # Default: 3 | WinHTTP-Web Proxy (Proxy-Erkennung)

# System Core & Hardware
Set-ServiceConfiguration -ServiceName "AudioSrv" -StartType 2 # Default: 2 | Windows-Audio (Sound-Ausgabe)
Set-ServiceConfiguration -ServiceName "AudioEndpointBuilder" -StartType 2 # Default: 2 | Audio-Endpunkterstellung (Sound-Geraete)
Set-ServiceConfiguration -ServiceName "PlugPlay" -StartType 2 # Default: 2 | Plug & Play (Hardwareerkennung)
Set-ServiceConfiguration -ServiceName "Power" -StartType 2 # Default: 2 | Stromversorgung (Energieverwaltung)
Set-ServiceConfiguration -ServiceName "RpcEptMapper" -StartType 2 # Default: 2 | RPC-Endpunktzuordnung (Kernsystendienst)
Set-ServiceConfiguration -ServiceName "RpcLocator" -StartType 4 # Default: 3 | RPC-Locator (Veraltet)
Set-ServiceConfiguration -ServiceName "SysMain" -StartType 2 # Default: 2 | SysMain/Superfetch (RAM-Optimierung)
Set-ServiceConfiguration -ServiceName "Themes" -StartType 2 # Default: 2 | Designs (Grafik-Oberflaeche)
Set-ServiceConfiguration -ServiceName "ProfSvc" -StartType 2 # Default: 2 | Benutzerprofildienst (User-Login)
Set-ServiceConfiguration -ServiceName "SENS" -StartType 2 # Default: 2 | Benachrichtigungsdienst fuer Systemereignisse
Set-ServiceConfiguration -ServiceName "Schedule" -StartType 2 # Default: 2 | Aufgabenplanung (Geplante Tasks)
Set-ServiceConfiguration -ServiceName "ShellHWDetection" -StartType 2 # Default: 2 | Hardwareerkennung (Autoplay)
Set-ServiceConfiguration -ServiceName "Spooler" -StartType 2 # Default: 2 | Druckwarteschlange (Drucken)
Set-ServiceConfiguration -ServiceName "W32Time" -StartType 3 # Default: 3 | Windows-Zeitgeber (Uhrzeit-Synchronisation)
Set-ServiceConfiguration -ServiceName "Winmgmt" -StartType 2 # Default: 2 | Windows-Verwaltungsinstrumentation (WMI)
Set-ServiceConfiguration -ServiceName "Eventlog" -StartType 2 # Default: 2 | Windows-Ereignisprotokoll (System-Logs)

# Application & Features
Set-ServiceConfiguration -ServiceName "Appinfo" -StartType 3 # Default: 3 | Anwendungsinformationen (Admin-Rechte Abfrage)
Set-ServiceConfiguration -ServiceName "AppMgmt" -StartType 3 # Default: 3 | Anwendungsverwaltung (Software-Verteilung)
Set-ServiceConfiguration -ServiceName "AeLookupSvc" -StartType 3 # Default: 3 | Anwendungserfahrung (Kompatibilitaet)
Set-ServiceConfiguration -ServiceName "AxInstSV" -StartType 3 # Default: 3 | ActiveX-Installer
Set-ServiceConfiguration -ServiceName "BDESVC" -StartType 3 # Default: 3 | BitLocker-Verschluesselung
Set-ServiceConfiguration -ServiceName "wbengine" -StartType 3 # Default: 3 | Blockebenen-Sicherungsmodul (Backups)
Set-ServiceConfiguration -ServiceName "bthserv" -StartType 3 # Default: 3 | Bluetooth-Unterstuetzungsdienst
Set-ServiceConfiguration -ServiceName "CertPropSvc" -StartType 3 # Default: 3 | Zertifikatverteilung (Smartcards)
Set-ServiceConfiguration -ServiceName "COMSysApp" -StartType 3 # Default: 3 | COM+-Systemanwendung
Set-ServiceConfiguration -ServiceName "Browser" -StartType 4 # Default: 3 | Computerbrowser (Veraltet/Unsicher)
Set-ServiceConfiguration -ServiceName "VaultSvc" -StartType 3 # Default: 3 | Anmeldeinformationsverwaltung (Passwort-Tresor)
Set-ServiceConfiguration -ServiceName "CryptSvc" -StartType 2 # Default: 2 | Kryptografiedienste (Signatur-Check)
Set-ServiceConfiguration -ServiceName "defragsvc" -StartType 3 # Default: 3 | Laufwerksoptimierung (Defrag)
Set-ServiceConfiguration -ServiceName "EFS" -StartType 3 # Default: 3 | Verschluesselndes Dateisystem (NTFS Crypto)
Set-ServiceConfiguration -ServiceName "EapHost" -StartType 3 # Default: 3 | EAP-Host (Netzwerkauthentifizierung)
Set-ServiceConfiguration -ServiceName "fdPHost" -StartType 3 # Default: 3 | Funktionssuchanbieter-Host (LAN-Suche)
Set-ServiceConfiguration -ServiceName "FDResPub" -StartType 3 # Default: 3 | Funktionssuch-Ressourcenveroeffentlichung (LAN-Sichtbarkeit)
Set-ServiceConfiguration -ServiceName "hkmsvc" -StartType 3 # Default: 3 | Schluesselverwaltung fuer Integritaet
Set-ServiceConfiguration -ServiceName "iphlpsvc" -StartType 2 # Default: 2 | IP-Hilfsdienst (Wichtig fuer IPv6)
Set-ServiceConfiguration -ServiceName "PolicyAgent" -StartType 3 # Default: 3 | IPsec-Richtlinien-Agent
Set-ServiceConfiguration -ServiceName "KtmRm" -StartType 3 # Default: 3 | Kernel Transaction Manager (KTM)
Set-ServiceConfiguration -ServiceName "MSiSCSI" -StartType 4 # Default: 3 | Microsoft iSCSI-Initiator (Server-Speicher)
Set-ServiceConfiguration -ServiceName "swprv" -StartType 3 # Default: 3 | Softwareschattenkopie-Anbieter (VSS)
Set-ServiceConfiguration -ServiceName "Netlogon" -StartType 4 # Default: 3 | Anmeldedienst (Nur fuer Domainen relevant)
Set-ServiceConfiguration -ServiceName "Netman" -StartType 3 # Default: 3 | Netzwerkverbindungen (Adapter-Verwaltung)
Set-ServiceConfiguration -ServiceName "netprofm" -StartType 3 # Default: 3 | Netzwerklistendienst (Netzwerk-Infos)
Set-ServiceConfiguration -ServiceName "PcaSvc" -StartType 3 # Default: 2 | Programmkompatibilitaets-Assistent
Set-ServiceConfiguration -ServiceName "wercplsupport" -StartType 3 # Default: 3 | Problembehandlung (Systemsteuerung)
Set-ServiceConfiguration -ServiceName "RasAuto" -StartType 3 # Default: 3 | Remotezugriff-Auto-Verbindung
Set-ServiceConfiguration -ServiceName "RasMan" -StartType 3 # Default: 3 | Remotezugriffsverbindung-Manager (VPN)
Set-ServiceConfiguration -ServiceName "TermService" -StartType 3 # Default: 3 | Remotedesktopdienste (Remote-Login)
Set-ServiceConfiguration -ServiceName "RemoteRegistry" -StartType 4 # Default: 4 | Remote-Registrierung (Sicherheitsrisiko)
Set-ServiceConfiguration -ServiceName "seclogon" -StartType 3 # Default: 3 | Sekundaere Anmeldung (Run As...)
Set-ServiceConfiguration -ServiceName "SstpSvc" -StartType 3 # Default: 3 | SSTP-Dienst (VPN)
Set-ServiceConfiguration -ServiceName "wscsvc" -StartType 2 -DelayedStart $true # Default: 2 (Delayed) | Sicherheitscenter
Set-ServiceConfiguration -ServiceName "SSDPSRV" -StartType 3 # Default: 3 | SSDP-Suche (Geraete finden)
Set-ServiceConfiguration -ServiceName "upnphost" -StartType 3 # Default: 3 | UPnP-Geraetehost
Set-ServiceConfiguration -ServiceName "vds" -StartType 3 # Default: 3 | Virtueller Datentraeger (Disk-Management)
Set-ServiceConfiguration -ServiceName "VSS" -StartType 3 # Default: 3 | Volumenschattenkopie (Backups)
Set-ServiceConfiguration -ServiceName "WebClient" -StartType 3 # Default: 3 | WebClient (WebDAV Zugriff)
Set-ServiceConfiguration -ServiceName "WbioSrvc" -StartType 3 # Default: 3 | Biometrischer Dienst (Fingerabdruck)
Set-ServiceConfiguration -ServiceName "wcncsvc" -StartType 3 # Default: 3 | Windows Connect Now (WPS)
Set-ServiceConfiguration -ServiceName "WerSvc" -StartType 3 # Default: 3 | Windows-Fehlerberichterstattung
Set-ServiceConfiguration -ServiceName "Wecsvc" -StartType 3 # Default: 3 | Windows-Ereignissammlung
Set-ServiceConfiguration -ServiceName "FontCache" -StartType 2 # Default: 2 | Schriftartencache
Set-ServiceConfiguration -ServiceName "StiSvc" -StartType 3 # Default: 3 | Bilderfassung (Scanner/Kamera)
Set-ServiceConfiguration -ServiceName "msiserver" -StartType 3 # Default: 3 | Windows Installer (.msi)
Set-ServiceConfiguration -ServiceName "WinRM" -StartType 3 # Default: 3 | Windows-Remoteverwaltung
Set-ServiceConfiguration -ServiceName "wuauserv" -StartType 2 -DelayedStart $true # Default: 3 | Windows Update (Auto-Updates)
Set-ServiceConfiguration -ServiceName "dot3svc" -StartType 3 # Default: 3 | Autom. Konfiguration (LAN 802.1X)
Set-ServiceConfiguration -ServiceName "Wlansvc" -StartType 2 # Default: 2 | Autom. WLAN-Konfiguration
Set-ServiceConfiguration -ServiceName "WwanSvc" -StartType 3 # Default: 3 | Autom. WWAN-Konfiguration (LTE)

# ---------------------------------------------------------
# Windows 10 spezifische Optimierungen (Safe Tweaks)
# ---------------------------------------------------------

Write-Host "`n--- Wende Windows 10 spezifische Optimierungen an ---`n" -ForegroundColor Magenta

# Telemetrie & Tracking
Set-ServiceConfiguration -ServiceName "DiagTrack" -StartType 4 # Default: 2 | Benutzererfahrung und Telemetrie (Tracking)
Set-ServiceConfiguration -ServiceName "dmwappushservice" -StartType 4 # Default: 3 | WAP-Push-Routing (Telemetrie-Hilfsdienst)

# Windows Maps
Set-ServiceConfiguration -ServiceName "MapsBroker" -StartType 3 # Default: 2 (Delayed) | Downloaded Maps Manager (Karten-Dienst)

# Retail Demo
Set-ServiceConfiguration -ServiceName "RetailDemo" -StartType 4 # Default: 3 | Einzelhandelsdemo (Demomodus)

# Xbox Services
Set-ServiceConfiguration -ServiceName "XblAuthManager" -StartType 3 # Default: 3 | Xbox Auth (Nötig für GamePass/Store)
Set-ServiceConfiguration -ServiceName "XblGameSave" -StartType 3 # Default: 3 | Xbox Game Save (Cloud-Saves)
Set-ServiceConfiguration -ServiceName "XboxNetApiSvc" -StartType 3 # Default: 3 | Xbox Live Netzwerkdienst

# Windows Search / Cortana
Set-ServiceConfiguration -ServiceName "WSearch" -StartType 2 -DelayedStart $true # Default: 2 (Delayed) | Windows Search (Indizierung)

# Mixed Reality
Set-ServiceConfiguration -ServiceName "MixedRealityOpenXRSvc" -StartType 3 # Default: 3 | Windows Mixed Reality

# ---------------------------------------------------------
# Windows 11 spezifische Optimierungen (Safe Tweaks)
# ---------------------------------------------------------

if ($IsWindows11) {
    Write-Host "`n--- Wende Windows 11 spezifische Optimierungen an ---`n" -ForegroundColor Magenta

    # User- und Feature-Dienste (auf Manuell belassen, um Ressourcen zu sparen ohne hart zu deaktivieren)
    Set-ServiceConfiguration -ServiceName "BcastDVRUserService" -StartType 3 # GameDVR User Service
    Set-ServiceConfiguration -ServiceName "CaptureService" -StartType 3 # Aufnahme- und Capture-Komponenten
    Set-ServiceConfiguration -ServiceName "PrintWorkflowUserSvc" -StartType 3 # Print Workflow User Service

    # Optional selten genutzte Features deaktivieren
    Set-ServiceConfiguration -ServiceName "Fax" -StartType 4 # Fax-Dienst
    Set-ServiceConfiguration -ServiceName "PhoneSvc" -StartType 4 # Telefoniedienst
}

Write-Host "`nFertig. Bitte System neu starten." -ForegroundColor Cyan

# Warten, bis der Benutzer das Fenster schließt oder eine Taste drückt,
# damit die Konsolenprotokolle angesehen werden können.
Write-Host "Druecken Sie eine beliebige Taste oder schließen Sie das Fenster, um das Skript zu beenden..." -ForegroundColor Yellow
if ($Host.Name -eq "ConsoleHost" -and $Host.UI -and $Host.UI.RawUI) {
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

