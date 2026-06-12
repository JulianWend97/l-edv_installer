# L-EDV Admin Toolkit

<p align="center">
  <img src="https://img.shields.io/badge/PowerShell-5.0%2B-blue?logo=powershell" alt="PowerShell 5.0+">
  <img src="https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4?logo=windows" alt="Windows 10 | 11">
  <img src="https://img.shields.io/badge/Rechte-Administrator-red" alt="Administrator">
  <img src="https://img.shields.io/badge/Version-1.9-brightgreen" alt="Version 1.9">
  <img src="https://img.shields.io/badge/Lizenz-Intern-lightgrey" alt="Lizenz">
</p>

> **Professionelles Windows-Administrationstool für den IT-Support** – entwickelt und gewartet von [L-EDV](https://www.l-edv.de).  
> Alle gängigen Einrichtungs-, Wartungs- und Diagnoseaufgaben in einer einzigen, übersichtlichen GUI.

---

## Inhaltsverzeichnis

- [Überblick](#überblick)
- [Voraussetzungen](#voraussetzungen)
- [Installation & Start](#installation--start)
- [Ordnerstruktur](#ordnerstruktur)
- [Tabs im Detail](#tabs-im-detail)
  - [LEDV Installer](#-ledv-installer)
  - [Wartung](#-wartung)
  - [System](#-system)
  - [Legacy Panels](#-legacy-panels)
  - [Software](#-software)
  - [Debloat](#-debloat)
  - [Abschluss](#-abschluss)
  - [Tools](#-tools)
  - [Portable Apps](#-portable-apps)
  - [Offline Installers](#-offline-installers)
- [Als EXE kompilieren](#als-exe-kompilieren)
- [Logging](#logging)
- [Häufige Fragen](#häufige-fragen)
- [Autoren](#autoren)

---

## Überblick

Das **L-EDV Admin Toolkit** ist eine Windows-Forms-GUI-Anwendung, die den kompletten Workflow bei der Einrichtung, Wartung und Übergabe von Windows-Systemen abdeckt. Es ersetzt das manuelle Öffnen von Dutzenden Systemdialogen, Skripten und Tools durch eine einzige, einheitliche Oberfläche.

**Kernfunktionen auf einen Blick:**

- Vollständige **Notebook-Einrichtung** mit Softwareinstallation via Chocolatey und Winget
- **System-Tweaks & Debloat** (Bloatware, Telemetrie, Xbox, Explorer, Taskleiste)
- **Wartung & Reparatur** (SFC, DISM, Netzwerk-Reset, Temp-Bereinigung)
- **TeamViewer-Verwaltung** (Host entfernen, QuickSupport bereitstellen)
- **Portable Apps & Offline-Installer** automatisch erkannt und als Buttons dargestellt
- **Abschlussprotokoll & Handout** (TXT + HTML) für die Kundenübergabe
- **Vollständiges Logging** aller Aktionen in `logs\tool.log`
- **Preset-System** für eigene Installations-Voreinstellungen
- Kompilierbar als **standalone EXE** via PS2EXE

---

## Voraussetzungen

| Anforderung | Details |
|---|---|
| Betriebssystem | Windows 10 (Build 19041+) oder Windows 11 |
| PowerShell | Version 5.0 oder höher (vorinstalliert ab Win10) |
| Rechte | **Administratorrechte** erforderlich (UAC-Abfrage automatisch) |
| .NET Framework | 4.5+ (standardmäßig auf allen unterstützten Windows-Versionen vorhanden) |
| Internetverbindung | Für Software-Downloads (Chocolatey, Sysinternals, TeamViewer QS) optional |

---

## Installation & Start

Das Toolkit benötigt **keine Installation**. Einfach den Ordner auf den Zielrechner kopieren und starten.

### Option A – PS.cmd (empfohlen)

```
Doppelklick auf PS.cmd
```

`PS.cmd` prüft automatisch die Administratorrechte, legt fehlende Ordner an und startet die GUI.

### Option B – PowerShell direkt

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\AdminToolkit.ps1"
```

### Option C – Als EXE (nach Kompilierung)

```
Doppelklick auf L-EDV-AdminToolkit.exe
```

> Siehe Abschnitt [Als EXE kompilieren](#als-exe-kompilieren) für die Erstellung der EXE.

---

## Ordnerstruktur

Nach dem ersten Start wird folgende Struktur automatisch angelegt:

```
📁 Toolkit-Ordner\
│
├── AdminToolkit.ps1          ← Haupt-GUI-Skript (PowerShell Windows Forms)
├── PS.cmd                    ← Starter: Admin-Check + ExecutionPolicy Bypass
├── Build-EXE.ps1             ← Hilfsskript zum Kompilieren der EXE (optional)
├── L-EDV-AdminToolkit.exe    ← Kompilierte EXE (nach Build, optional)
├── ledv_presets.json         ← Gespeicherte eigene Presets (LEDV Installer)
│
├── 📁 logs\
│   └── tool.log              ← Vollständiges Aktionsprotokoll mit Zeitstempel
│
├── 📁 portable_apps\         ← Portable EXE-Dateien hier ablegen
│   ├── Advanced IP Scanner\
│   │   └── scanner.exe       → Wird automatisch als Button erkannt
│   ├── CPU-Z\
│   │   └── cpuz_x64.exe
│   └── ...                   → Unterordner werden intelligent ausgewertet
│
├── 📁 installers\            ← Offline-Installer hier ablegen
│   ├── Firefox_Setup.exe     → Wird als Installer-Button angezeigt
│   ├── Office2021.msi        → .msi wird silent via msiexec ausgeführt
│   └── ...
│
└── 📁 L-EDV-Dateien\         ← Kundendaten und Ausgabedateien
    ├── TeamViewerQS_x64.exe  ← TeamViewer QuickSupport (wird heruntergeladen)
    ├── AdminToolkit-<Datum>.log  ← Sitzungsprotokoll je Toolkit-Start
    ├── Protokoll-<Kunde>-<Datum>.log  ← Systeminformationen je Einrichtung
    ├── Handout-<Kunde>-<Datum>.txt   ← Übergabeprotokoll als Text
    └── Handout-<Kunde>-<Datum>.html  ← Übergabeprotokoll als druckbare HTML
```

### Ordner im Detail

#### `logs\`
Enthält `tool.log` – jede Aktion im Toolkit wird hier mit Datum, Uhrzeit und Status protokolliert. Nützlich für die Nachverfolgung was auf einem System gemacht wurde. Das Log wird nie automatisch geleert.

#### `portable_apps\`
Der Toolkit scannt diesen Ordner beim Start automatisch nach `.exe`-Dateien. Unterordner werden unterstützt – aus jedem Unterordner wird die wahrscheinlichste Hauptanwendung intelligent ausgewählt (z.B. `Wireshark64.exe` statt `WiresharkCrashpad.exe`). Jede erkannte App erscheint als klickbarer Button im Tab **Portable Apps**.

**Empfohlene Tools für diesen Ordner:**
- Advanced IP Scanner
- CPU-Z / GPU-Z
- CrystalDiskInfo
- HWiNFO
- TreeSize Portable
- WinDirStat
- Wireshark

#### `installers\`
Für Offline-Installationsdateien (`.exe`, `.msi`). Der Tab **Offline Installers** erkennt alle Dateien automatisch. `.msi`-Dateien werden mit `/qn /norestart` (silent) ausgeführt, `.exe`-Dateien direkt gestartet. Nützlich wenn kein Internet verfügbar ist oder spezifische Versionen benötigt werden.

#### `L-EDV-Dateien\`
Zentraler Ausgabeordner für alle kundenbezogenen Dateien. Wird bei der **Selbstlöschungs-Funktion** (Wartung-Tab) bewusst erhalten, damit Protokolle und Handouts nicht verloren gehen.

#### `ledv_presets.json`
JSON-Datei mit eigenen Preset-Konfigurationen aus dem LEDV Installer. Kann direkt bearbeitet werden. Wird beim Löschen eines Presets automatisch aktualisiert.

---

## Tabs im Detail

### 🔧 LEDV Installer

> **Zweck:** Vollständige Einrichtung eines neuen Windows-Notebooks für einen Kunden – Software, Tweaks und Protokoll in einem Durchgang.

**Software installieren (linke Seite)**

Alle Software wird via **Chocolatey** installiert. Chocolatey wird beim ersten Durchlauf automatisch eingerichtet, falls nicht vorhanden. Die Installation läuft im **Hintergrund** – die GUI bleibt während der gesamten Installation bedienbar.

| Checkbox | Paket |
|---|---|
| Firefox | `firefox` |
| Google Chrome | `googlechrome` |
| Thunderbird | `thunderbird` |
| LibreOffice | `libreoffice-fresh` |
| Adobe Reader | `adobereader` |
| VLC | `vlc` |
| IrfanView | `irfanview` |
| Notepad++ | `notepadplusplus` |
| 7-Zip | `7zip` |
| PDF24 | `pdf24` |
| Greenshot | `greenshot` |
| Microsoft Teams | `microsoft-teams` |
| TreeSize Free | `treesizefree` |
| TeraCopy | `teracopy` |

**System Tweaks (rechte Seite)**

| Option | Beschreibung |
|---|---|
| Bloatware entfernen | Xbox, Bing, News, Solitaire, Duolingo, Spotify, Clipchamp uvm. |
| Edge Desktop-Verknüpfung blockieren | Verhindert automatische Edge-Shortcuts nach Updates |
| App-Vorschläge deaktivieren | ContentDeliveryManager silent installs aus |
| Optimierungen | Fast Startup aus, Long Paths ein, Explorer → Dieser PC |
| Wi-Fi Sense | Automatische WLAN-Vorschläge deaktivieren |
| F8 Boot-Menü | Erweitertes Startmenü (Legacy Boot Policy) aktivieren |
| OneDrive entfernen | ⚠️ Vorsicht – entfernt OneDrive vollständig |
| Desktop-Icons einblenden | Dieser PC und Benutzerordner auf Desktop |
| TeamViewer QuickSupport | Herunterladen + Desktop-Verknüpfung erstellen |
| Systemprotokoll | Systeminformationen auf Netzlaufwerk speichern |
| Systemwiederherstellung | Aktiviert mit 5% Speicher auf C:\ |
| Windows Updates | PSWindowsUpdate installiert alle offenen Updates |

**Profile**

Schnell-Vorauswahl per Klick – setzt alle Checkboxen auf die typische Konfiguration für den jeweiligen Einsatzbereich:

| Profil | Inhalt |
|---|---|
| Basis Privatkunde | Firefox, 7-Zip, PDF24, VLC + Basis-Tweaks |
| Homeoffice | + Chrome, Thunderbird, LibreOffice, Adobe, Teams |
| Schule / Studium | + Chrome, LibreOffice, VLC |
| Nur Wartung | 7-Zip, Notepad++, TreeSize + Wartungs-Tweaks |

**Eigene Presets**

Über die Preset-Zeile können eigene Konfigurationen gespeichert, geladen und gelöscht werden. Presets werden in `ledv_presets.json` im Toolkit-Ordner gespeichert und bleiben zwischen Sitzungen erhalten.

**Ausfüren**

Kundennamen eingeben → **Ausgewählte Installation starten**. Der Name wird für das Sitzungsprotokoll und die Netzlaufwerk-Ablage verwendet. Die Installation läuft asynchron im Hintergrund (Runspace), der Fortschritt wird in der Statusleiste angezeigt.

---

### 🔨 Wartung

> **Zweck:** Diagnose, Reparatur und Netzwerk-Fehlerbehebung ohne externe Tools.

**System-Reparatur (linke Seite)**

| Button | Aktion |
|---|---|
| SFC Scan | `sfc /scannow` – prüft und repariert Windows-Systemdateien |
| DISM Repair | `DISM /Online /Cleanup-Image /RestoreHealth` |
| SFC + DISM | Beide Schritte nacheinander in einem externen Fenster |
| Temp-Dateien löschen | `%TEMP%`, `C:\Windows\Temp`, SoftwareDistribution\Download |
| Datenträgerbereinigung | `cleanmgr.exe` (klassischer Dialog) |
| Festplatten-Check | `chkdsk C: /f /r` (wird beim nächsten Start ausgeführt) |
| Taskmanager | Direktstart |
| Systemwiederherstellung aktivieren | Aktiviert VSS auf C:\ mit 5% Kontingent |
| Wiederherstellungspunkt erstellen | Erstellt sofort einen Checkpoint |
| Windows Update öffnen | Einstellungen → Windows Update |
| Registry-Backup aktivieren | Periodisches Backup via `EnablePeriodicBackup` |

**Netzwerk (rechte Seite)**

| Button | Aktion |
|---|---|
| Netzwerk zurücksetzen | `netsh int ip reset` + Winsock Reset + DNS Flush + Release/Renew |
| DNS Cache leeren | `ipconfig /flushdns` |
| IP-Konfiguration anzeigen | `ipconfig /all` in eigenem Fenster |
| Ping-Test google.com | Prüft Internet-Erreichbarkeit (3 Pings) |
| Netzwerkverbindungen | `ncpa.cpl` |
| Hosts-Datei bearbeiten | Notepad als Administrator |
| Tracert | `tracert google.com` in CMD-Fenster |
| Systeminfo-Fenster | CPU, RAM, Windows-Version, Laufwerke, Netzwerk, Uptime |

**Toolkit-Verwaltung**

- **Toolkit-Ordner nach Schließen löschen** – Erstellt ein CMD-Skript das nach dem Schließen der GUI alle Toolkit-Dateien entfernt. Der Ordner `L-EDV-Dateien\` bleibt erhalten. Nützlich um das Tool nach der Einrichtung spurlos zu entfernen.

---

### 💻 System

> **Zweck:** Schnellzugriff auf alle wichtigen Windows-Systemdialoge und -konsolen.

**Shell & Systemsteuerung (linke Seite)**

Direktzugriff auf: Shell:Startup, Common Startup, Systemsteuerung, msinfo32, Programme & Features, Netzwerkverbindungen, Windows Update, Firewall, Energieoptionen, Datum & Uhrzeit, Maus-Einstellungen, Sounds, Anzeigeeinstellungen, Umgebungsvariablen.

**Windows Verwaltungskonsolen (rechte Seite)**

Direktzugriff auf: Computer Management, Geräte-Manager, Datenträgerverwaltung, Dienste, Gruppenrichtlinien, Registrierungs-Editor, Ereignisanzeige, Aufgabenplanung, Leistungsmonitor, Ressourcenmonitor, Systemeigenschaften, Drucker & Scanner, Benutzerkonten, Windows Security.

**Integrierte Module**

Schnellzugriff auf andere Toolkit-Tabs sowie direktes Öffnen der Log-Datei und des Toolkit-Ordners.

---

### 🗂️ Legacy Panels

> **Zweck:** Sammlung aller klassischen Windows-Verwaltungsdialoge, die in modernen Windows-Versionen versteckt oder schwer zu finden sind.

24 Buttons für selten genutzte aber wichtige Konsolen:

Computer Management, Systemsteuerung (klassisch), Drucker-Verwaltung (`printmanagement.msc`), Systemeigenschaften, Datenträgerverwaltung, Geräte-Manager, Dienste, Lokale Sicherheitsrichtlinie (`secpol.msc`), Ereignisanzeige, Zertifikate (`certmgr.msc`), Gruppenrichtlinien, Freigegebene Ordner (`fsmgmt.msc`), Aufgabenplanung, Leistungsmonitor, WMI-Verwaltung (`wmimgmt.msc`), Lokale Benutzer (`lusrmgr.msc`), ODBC 32-bit, ODBC 64-bit, IE Optionen (`inetcpl.cpl`), DirectX Diagnose (`dxdiag`), Drucker Spooler, Systemkonfiguration (`msconfig`), Registrierungs-Editor, Ressourcenmonitor.

---

### 📦 Software

> **Zweck:** TeamViewer-Verwaltung, Übersicht installierter Software und Winget-Integration.

**TeamViewer Verwaltung**

| Button | Beschreibung |
|---|---|
| TeamViewer HOST entfernen | Stoppt Dienste, beendet Prozesse, deinstalliert via Registry, entfernt Dateien und Registry-Reste |
| TeamViewer QuickSupport installieren | Lädt `TeamViewerQS_x64.exe` herunter, speichert in `L-EDV-Dateien\`, erstellt Desktop-Verknüpfung |
| TV QuickSupport starten | Startet vorhandene QS-Installation direkt |
| Host weg + QS | Kombiniert: Host entfernen + QS sicherstellen in einem Klick |

**Installierte Software**

ListView mit allen installierten Programmen – ausgelesen direkt aus der Registry (deutlich schneller als `Win32_Product`). Zeigt Name, Version, Publisher und Installationsdatum. Echtzeit-Suchfunktion hebt Treffer farblich hervor. Export als CSV möglich.

**Winget – Windows Package Manager**

| Button | Beschreibung |
|---|---|
| Alle Updates installieren | `winget upgrade --all --silent` in externem Fenster |
| Update-Liste anzeigen | Zeigt veraltete Programme |
| Verfügbar prüfen | Prüft ob Winget installiert ist |

**Autostart-Programme anzeigen**

Übersicht aller Autostart-Einträge aus Registry-Run-Keys (`HKCU`, `HKLM`, WOW6432Node) und Startup-Ordnern in einem lesbaren Fenster.

---

### 🧹 Debloat

> **Zweck:** Systematisches Entfernen von Bloatware und Anpassen von Windows-Einstellungen für einen saubereren, schnelleren Betrieb. Vor jeder Anwendung wird automatisch ein Wiederherstellungspunkt erstellt.

Der Debloat-Tab ist in **6 Unterbereiche** gegliedert:

#### Bloatware

Entfernt vorinstallierte Windows-Apps via `Remove-AppxPackage` (alle Benutzer) und `Remove-AppxProvisionedPackage` (neue Benutzerprofile). Jede App ist einzeln per Checkbox wählbar.

Enthaltene Apps (Auswahl): Clipchamp, Cortana, Dev Home, Feedback Hub, Maps, News, Teams (vorinstalliert), Mixed Reality Portal, Movies & TV, Groove Music, Office Hub, Outlook Neu, Paint 3D, People, Power Automate, Skype, Solitaire Collection, Sway, MSN Wetter, Widgets News Feed, Your Phone, 3D Viewer, Duolingo, Spotify, Xbox App, Xbox Game Bar, CandyCrush, Minecraft.

#### Datenschutz

| Bereich | Optionen |
|---|---|
| Telemetrie | Windows Telemetrie deaktivieren, Diagnosedaten auf Minimum |
| Tracking | Aktivitätsverlauf, Standortverfolgung, Feedback-Anfragen aus |
| Werbung | Werbe-ID, App-Vorschläge, Consumer Features, Cloud-Inhalte aus |
| Suche | Bing im Startmenü, Cortana, Windows Copilot deaktivieren |
| Dienste | Offline Maps, Wi-Fi Sense deaktivieren |

#### Xbox Gaming

Einzeln wählbar: Xbox App, Xbox Game Bar, Xbox Dienste (GipSvc, GameSave, NetApiSvc), Game DVR Aufzeichnung, Game Mode, Xbox Speech Overlay, Solitaire & Xbox-Spiele, Minecraft.

> ⚠️ Rot markierte Optionen können Spiele oder Xbox-Funktionen beeinträchtigen.

#### Rechtsklick

| Gruppe | Optionen |
|---|---|
| Kontextmenü | Klassisches Win10-Rechtsklick-Menü, „Task beenden" im Taskleisten-Rechtsklick |
| Explorer | Öffnet „Dieser PC", Galerie entfernen, OneDrive aus Seitenleiste, Dateiendungen anzeigen, Versteckte Dateien, AutoPlay aus, Systemsteuerung kleine Symbole, Edge-Shortcut blockieren |
| Taskleiste | Suchfeld, Task-Ansicht, Kontakte, Widgets, Copilot, Chat-Button (Teams) ausblenden, Icons links |

#### Reparaturen

Schnellzugriff auf SFC, DISM, Temp-Bereinigung, DNS-Cache, Netzwerk-Reset und Windows-Update-Konfiguration (Feature-Updates um 365 Tage verzögern) – direkt aus dem Debloat-Tab ohne Wechsel zu Wartung.

#### Systeminfo

Zeigt kompakte Systeminformationen (Hostname, Windows-Version, RAM, CPU) und ermöglicht den Export als TXT-Datei.

---

### ✅ Abschluss

> **Zweck:** Abschlusskontrolle nach der Einrichtung und Erstellung des Übergabeprotokolls für den Kunden.

**Abschluss-Check**

Erstellt einen vollständigen Systemreport mit:
- Computername, Hersteller, Modell, Seriennummer
- Windows-Version (korrekte Win10/Win11-Erkennung via Build-Nummer)
- RAM, CPU, letzter Boot, Pending-Reboot-Status
- Alle physischen Laufwerke mit Gesundheitsstatus
- Windows Defender Status und letzte Signaturen
- BitLocker-Status aller Volumes
- Geräte mit Fehlern (ConfigManagerErrorCode ≠ 0)
- TeamViewer QuickSupport Status

**Handout-Formular**

Öffnet ein separates Formular zur Erstellung des Kundenübergabeprotokolls:

- Kunde, Benutzer, Passwort (optional, mit Warnung), Techniker, Bestätigung, Bemerkungen
- Vorschau in Echtzeit
- Speichert als **TXT** und **HTML** in `L-EDV-Dateien\`
- HTML ist druckbereit (L-EDV-Farbschema, strukturierte Tabellen)

Das Protokoll enthält automatisch alle durch das Toolkit protokollierten Aktionen (installierte Software, angewendete Tweaks, Systemänderungen) aus dem Sitzungslog.

---

### 🛠️ Tools

> **Zweck:** Installation und Start von Diagnose- und Analyse-Tools.

**Sysinternals**

| Tool | Beschreibung |
|---|---|
| Autoruns | Download von sysinternals.com → `%ProgramFiles%\Sysinternals\Autoruns64.exe` |
| TCPView | Echtzeitanzeige aller Netzwerkverbindungen mit Prozess-Zuordnung |
| Komplette Suite | Alle ~70 Sysinternals-Tools (~16 MB) nach `%ProgramFiles%\Sysinternals\` |

**Zusatz-Software (Chocolatey)**

TreeSize Free, TeraCopy, Notepad++, 7-Zip, VLC, Firefox, Google Chrome, PDF24 – jeweils mit eigenem Installationsbutton.

---

### 📱 Portable Apps

> **Zweck:** Schnellzugriff auf portable Tools ohne Installation – ideal für den USB-Stick-Betrieb.

Der Tab scannt beim Start automatisch den Ordner `portable_apps\` rekursiv nach `.exe`-Dateien. Aus jedem Unterordner wird intelligent die wahrscheinlichste Hauptanwendung ausgewählt (Ausschlussliste für Hilfsprozesse wie `uninstall`, `crashpad`, `helper`, `updater`; Präferenz für `64`-bit, Namensübereinstimmung mit Ordner).

Jede erkannte Anwendung wird als Button mit Name und Dateigröße dargestellt. **Neu laden (Refresh)** aktualisiert die Ansicht nach dem Hinzufügen neuer Apps.

**Empfohlene portable Tools:**
- Advanced IP Scanner
- CPU-Z / GPU-Z
- CrystalDiskInfo / CrystalDiskMark
- HWiNFO64
- WinDirStat / TreeSize Portable
- Wireshark
- Process Hacker
- HxD Hex Editor

---

### 💿 Offline Installers

> **Zweck:** Softwareinstallation ohne Internetverbindung oder mit spezifischen Versionen.

Scannt den Ordner `installers\` nach `.exe`- und `.msi`-Dateien. Hilfsprozesse (`uninstall`, `updater`, `redist`) werden automatisch ausgeblendet.

- `.msi`-Dateien werden mit `/qn /norestart` (vollständig silent) ausgeführt
- `.exe`-Dateien werden direkt gestartet
- Unterordner werden unterstützt – der relative Pfad wird als Untertitel angezeigt

---

## Als EXE kompilieren

Das Toolkit kann mit **PS2EXE** zu einer standalone EXE kompiliert werden. Die Ordnerstruktur (`portable_apps\`, `logs\`, etc.) bleibt dabei im gleichen Verzeichnis wie die EXE.

### PS2EXE installieren

```powershell
Install-Module -Name PS2EXE -Scope CurrentUser -Force
```

### EXE erstellen

```powershell
.\Build-EXE.ps1
```

Oder manuell:

```powershell
Invoke-PS2EXE `
  -InputFile  ".\AdminToolkit.ps1" `
  -OutputFile ".\L-EDV-AdminToolkit.exe" `
  -RequireAdmin `
  -NoConsole `
  -Title       "L-EDV Admin Toolkit" `
  -Description "L-EDV Windows Admin Toolkit" `
  -Company     "L-EDV" `
  -Version     "2.0.0.0"
```

### Ergebnis

```
📁 Toolkit-Ordner\
├── L-EDV-AdminToolkit.exe   ← Doppelklick → UAC → GUI
├── portable_apps\
├── logs\
├── installers\
├── L-EDV-Dateien\
└── ledv_presets.json
```

> `AdminToolkit.ps1` und `PS.cmd` werden nach dem Build nicht mehr benötigt, können aber zur Weiterentwicklung im Ordner bleiben.

---

## Logging

Alle Aktionen werden automatisch in zwei Dateien protokolliert:

| Datei | Inhalt |
|---|---|
| `logs\tool.log` | Kumulatives Gesamtprotokoll über alle Sitzungen |
| `L-EDV-Dateien\AdminToolkit-<Datum>.log` | Protokoll der aktuellen Sitzung (wird für Handout ausgewertet) |

**Log-Format:**
```
[2026-06-12 14:23:45] [INFO]  L-EDV Admin Toolkit gestartet - Root: C:\Toolkit
[2026-06-12 14:24:01] [INFO]  TV Host: Start Entfernung
[2026-06-12 14:24:03] [INFO]  Deinstalliere: TeamViewer 15
[2026-06-12 14:24:12] [INFO]  TV Host entfernt
[2026-06-12 14:25:30] [INFO]  LEDV Runspace gestartet fuer Mustermann
[2026-06-12 14:25:31] [INFO]  choco: Chocolatey v2.3.0
[2026-06-12 14:27:14] [INFO]  LEDV: Firefox installiert
[2026-06-12 14:30:00] [INFO]  LEDV Runspace: abgeschlossen fuer Mustermann
```

Der **Abschluss-Tab** wertet das Sitzungsprotokoll automatisch aus und listet alle durchgeführten Aktionen im Handout auf.

---

## Häufige Fragen

**Das Toolkit startet nicht – was tun?**  
Sicherstellen dass `PS.cmd` als Administrator ausgeführt wird (Rechtsklick → Als Administrator ausführen). Bei Problemen mit der ExecutionPolicy: `powershell -ExecutionPolicy Bypass -File AdminToolkit.ps1`.

**Chocolatey-Installation schlägt fehl?**  
Internetverbindung prüfen. Unternehmens-Proxy kann die Installation blockieren – in dem Fall Chocolatey manuell installieren oder Offline-Installer für die gewünschte Software in `installers\` ablegen.

**Portable Apps werden nicht erkannt?**  
EXE-Dateien direkt in `portable_apps\` oder in Unterordnern ablegen. Anschließend „Neu laden" klicken. Das Toolkit filtert automatisch Hilfsprozesse heraus – falls eine gewünschte EXE nicht erscheint, im Hauptordner `portable_apps\` ohne Unterordner ablegen.

**Windows Update im LEDV Installer hängt?**  
Das PSWindowsUpdate-Modul wird beim ersten Aufruf heruntergeladen. Je nach Anzahl der Updates kann dieser Vorgang 15–60 Minuten dauern. Die Statusleiste zeigt den Namen jedes installierten Updates an.

**Selbstlöschung versehentlich aktiviert?**  
Im Tab **Wartung** auf „Selbstlöschung abbrechen" klicken – solange die GUI noch geöffnet ist.

**Die kompilierte EXE wird vom Antivirus geblockt?**  
PS2EXE-kompilierte Skripte werden von einigen Antivirus-Produkten fälschlicherweise markiert. Eine Whitelist-Ausnahme für den Toolkit-Ordner oder die EXE in der AV-Software eintragen.

---

## Autoren

**Felix Natterer** & **Julian Wendland**  
[L-EDV IT-Service](https://www.l-edv.de) – Heilbronn

---

<p align="center">
  <sub>L-EDV Admin Toolkit – Internes Werkzeug für den professionellen IT-Support</sub>
</p>
