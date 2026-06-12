#Requires -Version 5.0
# L-EDV Admin Toolkit v2
# (c) 2026 Felix Natterer - L-EDV
# UTF-8 ohne BOM, CRLF, PowerShell 5+

param([string]$ScriptRoot = "")
Set-StrictMode -Off
$ErrorActionPreference = "SilentlyContinue"

# ============================================================
# PFADE
# ============================================================
if ($ScriptRoot -eq "" -or -not (Test-Path $ScriptRoot)) {
    $ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
    if ($ScriptRoot -eq "") { $ScriptRoot = $PSScriptRoot }
    if ($ScriptRoot -eq "") { $ScriptRoot = (Get-Location).Path }
}
$Script:RootDir         = $ScriptRoot
$Script:LogDir          = Join-Path $Script:RootDir "logs"
$Script:LogFile         = Join-Path $Script:LogDir  "tool.log"
$Script:PortableDir     = Join-Path $Script:RootDir "portable_apps"
$Script:OfflineInstallerDir = Join-Path $Script:RootDir "installers"
$Script:LedvFilesDir    = Join-Path $Script:RootDir "L-EDV-Dateien"
$Script:QuickSupportExe = Join-Path $Script:LedvFilesDir "TeamViewerQS_x64.exe"
$Script:RunLogFile      = Join-Path $Script:LedvFilesDir ("AdminToolkit-" + (Get-Date -Format "yyyy-MM-dd_HH-mm-ss") + ".log")
$Script:SelfDeleteScript = $null

foreach ($d in @($Script:LogDir, $Script:PortableDir, $Script:OfflineInstallerDir, $Script:LedvFilesDir)) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}

# Admin-Rechte sind fuer Registry-, DISM-, Treiber- und Installationsaufgaben erforderlich.
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    $self = if ($PSCommandPath) { $PSCommandPath } elseif ($MyInvocation.MyCommand.Path) { $MyInvocation.MyCommand.Path } else { $null }
    if ($self) {
        Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$self`" -ScriptRoot `"$Script:RootDir`"" -Verb RunAs
        exit
    }
}

# ============================================================
# LOGGING
# ============================================================
function Write-Log {
    param([string]$Msg, [string]$Lvl = "INFO")
    $ts   = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$ts] [$Lvl] $Msg"
    try { Add-Content -Path $Script:LogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue } catch {}
    try { Add-Content -Path $Script:RunLogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue } catch {}
}

function Enable-BaseDesktopIcons {
    $adv = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Set-ItemProperty -Path $adv -Name "HideIcons" -Type DWord -Value 0 -ErrorAction SilentlyContinue

    $desktopIconRoots = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\ClassicStartMenu"
    )
    foreach ($root in $desktopIconRoots) {
        if (-not (Test-Path $root)) { New-Item -Path $root -Force | Out-Null }
        Set-ItemProperty -Path $root -Name "{20D04FE0-3AEA-1069-A2D8-08002B30309D}" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $root -Name "{59031a47-3f72-44a7-89c5-5595fe6b30ee}" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue
    }
    Write-Log "Desktop-Symbole gesetzt: Dieser PC und Benutzerordner"
}

Enable-BaseDesktopIcons

# ============================================================
# ASSEMBLIES
# ============================================================
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# ============================================================
# FARBEN
# ============================================================
$cBG      = [System.Drawing.ColorTranslator]::FromHtml("#1a1a1a")
$cPanel   = [System.Drawing.ColorTranslator]::FromHtml("#242424")
$cPanel2  = [System.Drawing.ColorTranslator]::FromHtml("#2e2e2e")
$cAccent  = [System.Drawing.ColorTranslator]::FromHtml("#7d1e2e")
$cAccent2 = [System.Drawing.ColorTranslator]::FromHtml("#5c1520")
$cText    = [System.Drawing.ColorTranslator]::FromHtml("#eee4e3")
$cSub     = [System.Drawing.ColorTranslator]::FromHtml("#888888")
$cBorder  = [System.Drawing.ColorTranslator]::FromHtml("#333333")
$cWarn    = [System.Drawing.ColorTranslator]::FromHtml("#e05050")
$cOK      = [System.Drawing.ColorTranslator]::FromHtml("#4caf88")
$cBlue    = [System.Drawing.ColorTranslator]::FromHtml("#3a7bd5")

# ============================================================
# FONTS
# ============================================================
$fMain   = New-Object System.Drawing.Font("Segoe UI", 9)
$fSmall  = New-Object System.Drawing.Font("Segoe UI", 8)
$fTitle  = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$fBold   = New-Object System.Drawing.Font("Segoe UI", 9,  [System.Drawing.FontStyle]::Bold)
$fMono   = New-Object System.Drawing.Font("Consolas", 8)

Write-Log "L-EDV Admin Toolkit gestartet - Root: $Script:RootDir"

# ============================================================
# HAUPT-FORMULAR
# ============================================================
$Form = New-Object System.Windows.Forms.Form
$Form.Text            = "L-EDV Admin Toolkit  |  IT-Support"
$Form.Size            = New-Object System.Drawing.Size(1100, 740)
$Form.MinimumSize     = New-Object System.Drawing.Size(1100, 740)
$Form.StartPosition   = "CenterScreen"
$Form.BackColor       = $cBG
$Form.ForeColor       = $cText
$Form.FormBorderStyle = "Sizable"
$Form.Font            = $fMain

# ============================================================
# HEADER
# ============================================================
$pHeader = New-Object System.Windows.Forms.Panel
$pHeader.Location  = New-Object System.Drawing.Point(0, 0)
$pHeader.Size      = New-Object System.Drawing.Size(1100, 58)
$pHeader.BackColor = $cPanel
$pHeader.Anchor    = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$Form.Controls.Add($pHeader)

$stripe = New-Object System.Windows.Forms.Panel
$stripe.Location  = New-Object System.Drawing.Point(0, 0)
$stripe.Size      = New-Object System.Drawing.Size(1100, 4)
$stripe.BackColor = $cAccent
$pHeader.Controls.Add($stripe)

$lblLogo = New-Object System.Windows.Forms.Label
$lblLogo.Text      = "L-EDV"
$lblLogo.Font      = $fTitle
$lblLogo.ForeColor = $cAccent
$lblLogo.Location  = New-Object System.Drawing.Point(14, 8)
$lblLogo.Size      = New-Object System.Drawing.Size(110, 32)
$pHeader.Controls.Add($lblLogo)

$lblHeaderSub = New-Object System.Windows.Forms.Label
$lblHeaderSub.Text      = "Windows Admin Toolkit  |  IT-Support"
$lblHeaderSub.Font      = $fSmall
$lblHeaderSub.ForeColor = $cSub
$lblHeaderSub.Location  = New-Object System.Drawing.Point(16, 40)
$lblHeaderSub.Size      = New-Object System.Drawing.Size(350, 14)
$pHeader.Controls.Add($lblHeaderSub)

$lblCopy = New-Object System.Windows.Forms.Label
$lblCopy.Text      = "(c) 2026 Felix Natterer - L-EDV"
$lblCopy.Font      = $fSmall
$lblCopy.ForeColor = $cSub
$lblCopy.Location  = New-Object System.Drawing.Point(820, 42)
$lblCopy.Size      = New-Object System.Drawing.Size(260, 14)
$pHeader.Controls.Add($lblCopy)

$hLineH = New-Object System.Windows.Forms.Panel
$hLineH.Location  = New-Object System.Drawing.Point(0, 58)
$hLineH.Size      = New-Object System.Drawing.Size(1100, 1)
$hLineH.BackColor = $cBorder
$Form.Controls.Add($hLineH)

# ============================================================
# SIDEBAR
# ============================================================
$pSidebar = New-Object System.Windows.Forms.Panel
$pSidebar.Location  = New-Object System.Drawing.Point(0, 59)
$pSidebar.Size      = New-Object System.Drawing.Size(168, 620)
$pSidebar.BackColor = $cPanel
$Form.Controls.Add($pSidebar)

$vLine = New-Object System.Windows.Forms.Panel
$vLine.Location  = New-Object System.Drawing.Point(168, 59)
$vLine.Size      = New-Object System.Drawing.Size(1, 620)
$vLine.BackColor = $cBorder
$Form.Controls.Add($vLine)

# ============================================================
# CONTENT AREA
# ============================================================
$pContent = New-Object System.Windows.Forms.Panel
$pContent.Location  = New-Object System.Drawing.Point(169, 59)
$pContent.Size      = New-Object System.Drawing.Size(931, 620)
$pContent.BackColor = $cBG
$Form.Controls.Add($pContent)

# ============================================================
# STATUSBAR
# ============================================================
$pStatus = New-Object System.Windows.Forms.Panel
$pStatus.Location  = New-Object System.Drawing.Point(0, 679)
$pStatus.Size      = New-Object System.Drawing.Size(1100, 58)
$pStatus.BackColor = $cPanel
$Form.Controls.Add($pStatus)

$hLineSt = New-Object System.Windows.Forms.Panel
$hLineSt.Location  = New-Object System.Drawing.Point(0, 0)
$hLineSt.Size      = New-Object System.Drawing.Size(1100, 1)
$hLineSt.BackColor = $cBorder
$pStatus.Controls.Add($hLineSt)

$Script:lblStatus = New-Object System.Windows.Forms.Label
$Script:lblStatus.Text      = "Bereit."
$Script:lblStatus.Font      = $fMono
$Script:lblStatus.ForeColor = $cSub
$Script:lblStatus.Location  = New-Object System.Drawing.Point(14, 6)
$Script:lblStatus.Size      = New-Object System.Drawing.Size(700, 16)
$pStatus.Controls.Add($Script:lblStatus)

$Script:lblAction = New-Object System.Windows.Forms.Label
$Script:lblAction.Text      = ""
$Script:lblAction.Font      = $fSmall
$Script:lblAction.ForeColor = $cAccent
$Script:lblAction.Location  = New-Object System.Drawing.Point(14, 24)
$Script:lblAction.Size      = New-Object System.Drawing.Size(700, 14)
$pStatus.Controls.Add($Script:lblAction)

$Script:progBar = New-Object System.Windows.Forms.ProgressBar
$Script:progBar.Location = New-Object System.Drawing.Point(14, 42)
$Script:progBar.Size     = New-Object System.Drawing.Size(700, 8)
$Script:progBar.Minimum  = 0
$Script:progBar.Maximum  = 100
$pStatus.Controls.Add($Script:progBar)

$lblLogInfo = New-Object System.Windows.Forms.Label
$lblLogInfo.Text      = "Log: $Script:LogFile"
$lblLogInfo.Font      = $fSmall
$lblLogInfo.ForeColor = $cSub
$lblLogInfo.Location  = New-Object System.Drawing.Point(730, 20)
$lblLogInfo.Size      = New-Object System.Drawing.Size(360, 14)
$pStatus.Controls.Add($lblLogInfo)

function Set-Status {
    param([string]$Msg, [int]$Pct = -1, [string]$Col = "sub")
    $Script:lblStatus.Text = $Msg
    $Script:lblStatus.ForeColor = switch ($Col) {
        "ok"   { $cOK }
        "warn" { $cWarn }
        "err"  { $cWarn }
        default{ $cSub }
    }
    if ($Pct -ge 0) { $Script:progBar.Value = [Math]::Min([Math]::Max($Pct,0),100) }
    $Script:lblAction.Text = $Msg
    $Form.Refresh()
    [System.Windows.Forms.Application]::DoEvents()
}

# ============================================================
# GUI HILFSFUNKTIONEN
# ============================================================
function Make-Hdr {
    param($P, [string]$T, [int]$X, [int]$Y, [int]$W)
    $pan = New-Object System.Windows.Forms.Panel
    $pan.Location  = New-Object System.Drawing.Point($X, $Y)
    $pan.Size      = New-Object System.Drawing.Size($W, 22)
    $pan.BackColor = $cAccent2
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text      = "  $T"
    $lbl.Dock      = "Fill"
    $lbl.Font      = $fBold
    $lbl.ForeColor = $cText
    $lbl.TextAlign = "MiddleLeft"
    $pan.Controls.Add($lbl)
    $P.Controls.Add($pan)
}

function Make-Btn {
    param($P, [string]$T, [int]$X, [int]$Y, [int]$W, [int]$H, [System.Drawing.Color]$BG, [scriptblock]$Clk)
    $b = New-Object System.Windows.Forms.Button
    $b.Text      = $T
    $b.Location  = New-Object System.Drawing.Point($X, $Y)
    $b.Size      = New-Object System.Drawing.Size($W, $H)
    $b.Font      = $fBold
    $b.BackColor = $BG
    $b.ForeColor = $cText
    $b.FlatStyle = "Flat"
    $b.FlatAppearance.BorderColor = $cBorder
    $b.FlatAppearance.BorderSize  = 1
    $b.Cursor    = [System.Windows.Forms.Cursors]::Hand
    if ($Clk) { $b.Add_Click($Clk) }
    $P.Controls.Add($b)
    return $b
}

function Make-Lbl {
    param($P, [string]$T, [int]$X, [int]$Y, [int]$W, [int]$H = 16, $F = $null, [System.Drawing.Color]$FG = [System.Drawing.Color]::Empty)
    $l = New-Object System.Windows.Forms.Label
    $l.Text      = $T
    $l.Location  = New-Object System.Drawing.Point($X, $Y)
    $l.Size      = New-Object System.Drawing.Size($W, $H)
    $l.Font      = if ($F) { $F } else { $fSmall }
    $l.ForeColor = if ($FG -ne [System.Drawing.Color]::Empty) { $FG } else { $cSub }
    $P.Controls.Add($l)
    return $l
}

function Make-Scroll {
    param($P, [int]$X, [int]$Y, [int]$W, [int]$H)
    $sp = New-Object System.Windows.Forms.Panel
    $sp.Location    = New-Object System.Drawing.Point($X, $Y)
    $sp.Size        = New-Object System.Drawing.Size($W, $H)
    $sp.BackColor   = $cBG
    $sp.AutoScroll  = $true
    $sp.BorderStyle = "None"
    $P.Controls.Add($sp)
    return $sp
}

# ============================================================
# TAB-SYSTEM
# ============================================================
$Script:Pages   = @{}
$Script:SideBtns= @{}

$tabNames = @("System","Legacy Panels","Software","Tools","Portable Apps","Offline Installer","Wartung","Debloat","LEDV Installer","Abschluss")

$ty = 12
foreach ($tn in $tabNames) {
    $tb = New-Object System.Windows.Forms.Button
    $tb.Text      = "  $tn"
    $tb.Location  = New-Object System.Drawing.Point(0, $ty)
    $tb.Size      = New-Object System.Drawing.Size(168, 36)
    $tb.Font      = $fBold
    $tb.FlatStyle = "Flat"
    $tb.FlatAppearance.BorderSize  = 0
    $tb.BackColor = $cPanel
    $tb.ForeColor = $cSub
    $tb.TextAlign = "MiddleLeft"
    $tb.Cursor    = [System.Windows.Forms.Cursors]::Hand
    $pSidebar.Controls.Add($tb)
    $Script:SideBtns[$tn] = $tb

    $pg = New-Object System.Windows.Forms.Panel
    $pg.Location   = New-Object System.Drawing.Point(0, 0)
    $pg.Size       = New-Object System.Drawing.Size(931, 620)
    $pg.BackColor  = $cBG
    $pg.Visible    = $false
    $pContent.Controls.Add($pg)
    $Script:Pages[$tn] = $pg

    $ty += 38
}

function Switch-Tab {
    param([string]$N)
    foreach ($k in $Script:Pages.Keys) {
        $Script:Pages[$k].Visible = ($k -eq $N)
        if ($k -eq $N) {
            $Script:SideBtns[$k].BackColor = $cAccent
            $Script:SideBtns[$k].ForeColor = [System.Drawing.Color]::White
        } else {
            $Script:SideBtns[$k].BackColor = $cPanel
            $Script:SideBtns[$k].ForeColor = $cSub
        }
    }
    Write-Log "Tab: $N"
}

# Tab-Clicks - direkt mit String-Argument, kein closure-Bug
$Script:SideBtns["System"].Add_Click(        { Switch-Tab "System" })
$Script:SideBtns["Legacy Panels"].Add_Click( { Switch-Tab "Legacy Panels" })
$Script:SideBtns["Software"].Add_Click(      { Switch-Tab "Software" })
$Script:SideBtns["Tools"].Add_Click(         { Switch-Tab "Tools" })
$Script:SideBtns["Portable Apps"].Add_Click( { Switch-Tab "Portable Apps" })
$Script:SideBtns["Offline Installer"].Add_Click({ Switch-Tab "Offline Installer" })
$Script:SideBtns["Wartung"].Add_Click(       { Switch-Tab "Wartung" })
$Script:SideBtns["Debloat"].Add_Click(       { Switch-Tab "Debloat" })
$Script:SideBtns["LEDV Installer"].Add_Click({ Switch-Tab "LEDV Installer" })
$Script:SideBtns["Abschluss"].Add_Click(     { Switch-Tab "Abschluss" })

# ============================================================
# TAB: SYSTEM
# ============================================================
$pgS  = $Script:Pages["System"]
$spS  = Make-Scroll $pgS 0 0 925 615

Make-Hdr $spS "Shell & Systemsteuerung" 8 8 440
Make-Hdr $spS "Windows Verwaltungskonsolen" 458 8 440

# Linke Spalte
Make-Btn $spS "Shell:Startup oeffnen"    8  38 210 32 $cPanel2 { Start-Process "explorer.exe" "shell:startup"; Write-Log "shell:startup"; Set-Status "shell:startup geöffnet" 100 "ok" } | Out-Null
Make-Btn $spS "Autostart (Alle User)"  228  38 210 32 $cPanel2 { Start-Process "explorer.exe" "shell:common startup"; Write-Log "common startup"; Set-Status "Common Startup geoeffnet" 100 "ok" } | Out-Null
Make-Btn $spS "Systemsteuerung"          8  78 210 32 $cPanel2 { Start-Process "control.exe"; Write-Log "Systemsteuerung"; Set-Status "Systemsteuerung geoeffnet" 100 "ok" } | Out-Null
Make-Btn $spS "Systeminfo (msinfo32)"  228  78 210 32 $cPanel2 { Start-Process "msinfo32.exe"; Write-Log "msinfo32"; Set-Status "msinfo32 geoeffnet" 100 "ok" } | Out-Null
Make-Btn $spS "Programme & Features"     8 118 210 32 $cPanel2 { Start-Process "appwiz.cpl"; Write-Log "appwiz.cpl"; Set-Status "Programme & Features geoeffnet" 100 "ok" } | Out-Null
Make-Btn $spS "Netzwerkverbindungen"   228 118 210 32 $cPanel2 { Start-Process "ncpa.cpl"; Write-Log "ncpa.cpl"; Set-Status "Netzwerkverbindungen geoeffnet" 100 "ok" } | Out-Null
Make-Btn $spS "Windows Update"           8 158 210 32 $cPanel2 { Start-Process "ms-settings:windowsupdate"; Write-Log "WinUpdate"; Set-Status "Windows Update geoeffnet" 100 "ok" } | Out-Null
Make-Btn $spS "Firewall"               228 158 210 32 $cPanel2 { Start-Process "firewall.cpl"; Write-Log "Firewall"; Set-Status "Firewall geoeffnet" 100 "ok" } | Out-Null
Make-Btn $spS "Energieoptionen"          8 198 210 32 $cPanel2 { Start-Process "powercfg.cpl"; Write-Log "powercfg"; Set-Status "Energieoptionen geoeffnet" 100 "ok" } | Out-Null
Make-Btn $spS "Datum & Uhrzeit"        228 198 210 32 $cPanel2 { Start-Process "timedate.cpl"; Write-Log "timedate"; Set-Status "Datum & Uhrzeit geoeffnet" 100 "ok" } | Out-Null
Make-Btn $spS "Maus-Einstellungen"       8 238 210 32 $cPanel2 { Start-Process "main.cpl"; Write-Log "main.cpl"; Set-Status "Maus geoeffnet" 100 "ok" } | Out-Null
Make-Btn $spS "Sounds"                 228 238 210 32 $cPanel2 { Start-Process "mmsys.cpl"; Write-Log "mmsys"; Set-Status "Sounds geoeffnet" 100 "ok" } | Out-Null
Make-Btn $spS "Anzeigeeinstellungen"     8 278 210 32 $cPanel2 { Start-Process "ms-settings:display"; Write-Log "display"; Set-Status "Anzeige geoeffnet" 100 "ok" } | Out-Null
Make-Btn $spS "Umgebungsvariablen"     228 278 210 32 $cPanel2 { Start-Process "rundll32.exe" "sysdm.cpl,EditEnvironmentVariables"; Write-Log "EnvVars"; Set-Status "Umgebungsvariablen geoeffnet" 100 "ok" } | Out-Null

# Rechte Spalte
Make-Btn $spS "Computer Management"    458  38 210 32 $cPanel2 { Start-Process "compmgmt.msc"; Write-Log "compmgmt"; Set-Status "compmgmt geoeffnet" 100 "ok" } | Out-Null
Make-Btn $spS "Geraete-Manager"        678  38 210 32 $cPanel2 { Start-Process "devmgmt.msc"; Write-Log "devmgmt"; Set-Status "devmgmt geoeffnet" 100 "ok" } | Out-Null
Make-Btn $spS "Datentraegerverwaltung" 458  78 210 32 $cPanel2 { Start-Process "diskmgmt.msc"; Write-Log "diskmgmt"; Set-Status "diskmgmt geoeffnet" 100 "ok" } | Out-Null
Make-Btn $spS "Dienste"                678  78 210 32 $cPanel2 { Start-Process "services.msc"; Write-Log "services"; Set-Status "Dienste geoeffnet" 100 "ok" } | Out-Null
Make-Btn $spS "Gruppenrichtlinien"     458 118 210 32 $cPanel2 { Start-Process "gpedit.msc"; Write-Log "gpedit"; Set-Status "gpedit geoeffnet" 100 "ok" } | Out-Null
Make-Btn $spS "Registrierungs-Editor"  678 118 210 32 $cPanel2 { Start-Process "regedit.exe"; Write-Log "regedit"; Set-Status "regedit geoeffnet" 100 "ok" } | Out-Null
Make-Btn $spS "Ereignisanzeige"        458 158 210 32 $cPanel2 { Start-Process "eventvwr.msc"; Write-Log "eventvwr"; Set-Status "eventvwr geoeffnet" 100 "ok" } | Out-Null
Make-Btn $spS "Aufgabenplanung"        678 158 210 32 $cPanel2 { Start-Process "taskschd.msc"; Write-Log "taskschd"; Set-Status "taskschd geoeffnet" 100 "ok" } | Out-Null
Make-Btn $spS "Leistungsmonitor"       458 198 210 32 $cPanel2 { Start-Process "perfmon.msc"; Write-Log "perfmon"; Set-Status "perfmon geoeffnet" 100 "ok" } | Out-Null
Make-Btn $spS "Ressourcenmonitor"      678 198 210 32 $cPanel2 { Start-Process "resmon.exe"; Write-Log "resmon"; Set-Status "resmon geoeffnet" 100 "ok" } | Out-Null
Make-Btn $spS "Systemeigenschaften"    458 238 210 32 $cPanel2 { Start-Process "sysdm.cpl"; Write-Log "sysdm"; Set-Status "sysdm geoeffnet" 100 "ok" } | Out-Null
Make-Btn $spS "Drucker & Scanner"      678 238 210 32 $cPanel2 { Start-Process "ms-settings:printers"; Write-Log "printers"; Set-Status "Drucker geoeffnet" 100 "ok" } | Out-Null
Make-Btn $spS "Benutzerkonten"         458 278 210 32 $cPanel2 { Start-Process "netplwiz.exe"; Write-Log "netplwiz"; Set-Status "Benutzerkonten geoeffnet" 100 "ok" } | Out-Null
Make-Btn $spS "Windows Security"       678 278 210 32 $cPanel2 { Start-Process "ms-settings:windowsdefender"; Write-Log "defender"; Set-Status "Security geoeffnet" 100 "ok" } | Out-Null

Make-Hdr $spS "Integrierte Module" 8 328 890

Make-Btn $spS "Debloat Modul oeffnen" 8 358 210 32 $cAccent2 {
    Switch-Tab "Debloat"
    Write-Log "Integriertes Debloat Modul geoeffnet"
    Set-Status "Debloat Modul geoeffnet" 100 "ok"
} | Out-Null

Make-Btn $spS "LEDV Installer Modul oeffnen" 228 358 230 32 $cAccent2 {
    Switch-Tab "LEDV Installer"
    Write-Log "Integrierter LEDV Installer geoeffnet"
    Set-Status "LEDV Installer Modul geoeffnet" 100 "ok"
} | Out-Null

Make-Btn $spS "Log-Datei oeffnen" 458 358 210 32 $cPanel2 {
    Start-Process "notepad.exe" $Script:LogFile
    Write-Log "Log geoeffnet"; Set-Status "Log geoeffnet" 100 "ok"
} | Out-Null

Make-Btn $spS "Toolkit-Ordner oeffnen" 678 358 210 32 $cPanel2 {
    Start-Process "explorer.exe" $Script:RootDir
    Write-Log "Toolkit-Ordner geoeffnet"; Set-Status "Toolkit-Ordner geoeffnet" 100 "ok"
} | Out-Null

# ============================================================
# TAB: LEGACY PANELS
# ============================================================
$pgL = $Script:Pages["Legacy Panels"]
$spL = Make-Scroll $pgL 0 0 925 615

Make-Hdr $spL "Klassische Windows-Verwaltungskonsolen" 8 8 900

# Alle Buttons direkt definiert - KEIN foreach/closure Bug
Make-Btn $spL "Computer Management"        8  38 212 32 $cPanel2 { Start-Process "compmgmt.msc";   Write-Log "compmgmt";   Set-Status "compmgmt geoeffnet"   100 "ok" } | Out-Null
Make-Btn $spL "Systemsteuerung klassisch" 228  38 212 32 $cPanel2 { Start-Process "control.exe";    Write-Log "control";    Set-Status "control geoeffnet"    100 "ok" } | Out-Null
Make-Btn $spL "Drucker-Verwaltung"        448  38 212 32 $cPanel2 { Start-Process "printmanagement.msc"; Write-Log "printmgmt"; Set-Status "Drucker-Verwaltung geoeffnet" 100 "ok" } | Out-Null
Make-Btn $spL "Systemeigenschaften"       668  38 212 32 $cPanel2 { Start-Process "sysdm.cpl";     Write-Log "sysdm";      Set-Status "sysdm geoeffnet"      100 "ok" } | Out-Null

Make-Btn $spL "Datentraegerverwaltung"      8  78 212 32 $cPanel2 { Start-Process "diskmgmt.msc";  Write-Log "diskmgmt";   Set-Status "diskmgmt geoeffnet"   100 "ok" } | Out-Null
Make-Btn $spL "Geraete-Manager"           228  78 212 32 $cPanel2 { Start-Process "devmgmt.msc";   Write-Log "devmgmt";    Set-Status "devmgmt geoeffnet"    100 "ok" } | Out-Null
Make-Btn $spL "Dienste"                   448  78 212 32 $cPanel2 { Start-Process "services.msc";  Write-Log "services";   Set-Status "Dienste geoeffnet"    100 "ok" } | Out-Null
Make-Btn $spL "Sicherheitsrichtlinie"     668  78 212 32 $cPanel2 { Start-Process "secpol.msc";    Write-Log "secpol";     Set-Status "secpol geoeffnet"     100 "ok" } | Out-Null

Make-Btn $spL "Ereignisanzeige"             8 118 212 32 $cPanel2 { Start-Process "eventvwr.msc";  Write-Log "eventvwr";   Set-Status "eventvwr geoeffnet"   100 "ok" } | Out-Null
Make-Btn $spL "Zertifikate (certmgr)"     228 118 212 32 $cPanel2 { Start-Process "certmgr.msc";   Write-Log "certmgr";    Set-Status "certmgr geoeffnet"    100 "ok" } | Out-Null
Make-Btn $spL "Gruppenrichtlinien"        448 118 212 32 $cPanel2 { Start-Process "gpedit.msc";    Write-Log "gpedit";     Set-Status "gpedit geoeffnet"     100 "ok" } | Out-Null
Make-Btn $spL "Freigegebene Ordner"       668 118 212 32 $cPanel2 { Start-Process "fsmgmt.msc";    Write-Log "fsmgmt";     Set-Status "fsmgmt geoeffnet"     100 "ok" } | Out-Null

Make-Btn $spL "Aufgabenplanung"             8 158 212 32 $cPanel2 { Start-Process "taskschd.msc";  Write-Log "taskschd";   Set-Status "taskschd geoeffnet"   100 "ok" } | Out-Null
Make-Btn $spL "Leistungsmonitor"          228 158 212 32 $cPanel2 { Start-Process "perfmon.msc";   Write-Log "perfmon";    Set-Status "perfmon geoeffnet"    100 "ok" } | Out-Null
Make-Btn $spL "WMI-Verwaltung"            448 158 212 32 $cPanel2 { Start-Process "wmimgmt.msc";   Write-Log "wmimgmt";    Set-Status "wmimgmt geoeffnet"    100 "ok" } | Out-Null
Make-Btn $spL "Lokale Benutzer"           668 158 212 32 $cPanel2 { Start-Process "lusrmgr.msc";   Write-Log "lusrmgr";    Set-Status "lusrmgr geoeffnet"    100 "ok" } | Out-Null

Make-Btn $spL "ODBC 32-bit"                 8 198 212 32 $cPanel2 { Start-Process "C:\Windows\SysWOW64\odbcad32.exe"; Write-Log "odbc32"; Set-Status "ODBC 32bit geoeffnet" 100 "ok" } | Out-Null
Make-Btn $spL "ODBC 64-bit"               228 198 212 32 $cPanel2 { Start-Process "C:\Windows\System32\odbcad32.exe"; Write-Log "odbc64"; Set-Status "ODBC 64bit geoeffnet" 100 "ok" } | Out-Null
Make-Btn $spL "IE Optionen (inetcpl)"     448 198 212 32 $cPanel2 { Start-Process "inetcpl.cpl";   Write-Log "inetcpl";    Set-Status "inetcpl geoeffnet"    100 "ok" } | Out-Null
Make-Btn $spL "DirectX Diagnose"          668 198 212 32 $cPanel2 { Start-Process "dxdiag.exe";    Write-Log "dxdiag";     Set-Status "dxdiag geoeffnet"     100 "ok" } | Out-Null

Make-Btn $spL "Drucker (Spooler)"           8 238 212 32 $cPanel2 { Start-Process "control.exe" "printers"; Write-Log "printers"; Set-Status "Drucker geoeffnet" 100 "ok" } | Out-Null
Make-Btn $spL "Systemkonfiguration"       228 238 212 32 $cPanel2 { Start-Process "msconfig.exe";  Write-Log "msconfig";   Set-Status "msconfig geoeffnet"   100 "ok" } | Out-Null
Make-Btn $spL "Registrierungs-Editor"     448 238 212 32 $cPanel2 { Start-Process "regedit.exe";   Write-Log "regedit";    Set-Status "regedit geoeffnet"    100 "ok" } | Out-Null
Make-Btn $spL "Ressourcenmonitor"         668 238 212 32 $cPanel2 { Start-Process "resmon.exe";    Write-Log "resmon";     Set-Status "resmon geoeffnet"     100 "ok" } | Out-Null

# ============================================================
# TAB: SOFTWARE
# ============================================================
$pgSW = $Script:Pages["Software"]
$spSW = Make-Scroll $pgSW 0 0 925 615

Make-Hdr $spSW "TeamViewer Verwaltung" 8 8 900

Make-Lbl $spSW "TeamViewer HOST vollstaendig entfernen (Dienste, Prozesse, Dateien, Registry):" 8 38 880 14

$Script:btnRemoveTvHost = Make-Btn $spSW "TeamViewer HOST entfernen" 8 60 260 34 $cAccent2 {
    Set-Status "TeamViewer Host wird entfernt..." 10
    Write-Log "TV Host: Start Entfernung"

    Get-Process "TeamViewer*" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

    foreach ($sn in @("TeamViewer","TeamViewer_Service","TeamViewer_Desktop")) {
        $sv = Get-Service $sn -ErrorAction SilentlyContinue
        if ($sv) {
            Stop-Service $sn -Force -ErrorAction SilentlyContinue
            Set-Service  $sn -StartupType Disabled -ErrorAction SilentlyContinue
            Write-Log "Dienst gestoppt: $sn"
        }
    }

    $ukeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )
    foreach ($uk in $ukeys) {
        if (Test-Path $uk) {
            Get-ChildItem $uk -ErrorAction SilentlyContinue | ForEach-Object {
                $dn  = (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).DisplayName
                $uns = (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).UninstallString
                if ($dn -like "*TeamViewer*" -and $dn -notlike "*QuickSupport*" -and $uns) {
                    Set-Status "Entferne: $dn" 30
                    Write-Log "Deinstalliere: $dn"
                    if ($uns -match "msiexec") {
                        $guid = [regex]::Match($uns, "\{[^}]+\}").Value
                        if ($guid) { Start-Process "msiexec.exe" "/x $guid /quiet /norestart" -Wait -ErrorAction SilentlyContinue }
                    } else {
                        $exe = ($uns.Trim('"')).Split(' ')[0]
                        if (Test-Path $exe) { Start-Process $exe "/S" -Wait -ErrorAction SilentlyContinue }
                    }
                }
            }
        }
    }

    foreach ($tp in @("$env:ProgramFiles\TeamViewer","${env:ProgramFiles(x86)}\TeamViewer")) {
        if (Test-Path $tp) { Remove-Item $tp -Recurse -Force -ErrorAction SilentlyContinue; Write-Log "Entfernt: $tp" }
    }
    foreach ($rp in @("HKLM:\SOFTWARE\TeamViewer","HKLM:\SOFTWARE\WOW6432Node\TeamViewer")) {
        if (Test-Path $rp) { Remove-Item $rp -Recurse -Force -ErrorAction SilentlyContinue; Write-Log "Registry entfernt: $rp" }
    }

    Write-Log "TV Host entfernt"
    Set-Status "TeamViewer Host entfernt" 100 "ok"
    [System.Windows.Forms.MessageBox]::Show("TeamViewer Host vollstaendig entfernt.","L-EDV","OK","Information") | Out-Null
}

$Script:btnInstallTvQs = Make-Btn $spSW "TeamViewer QuickSupport installieren" 278 60 260 34 $cPanel2 {
    Set-Status "TV QuickSupport wird heruntergeladen..." 10
    Write-Log "TV QuickSupport: Download"
    $sd  = $Script:LedvFilesDir
    $exe = $Script:QuickSupportExe
    $url = "https://customdesignservice.teamviewer.com/download/windows/v15/6mes7x8/TeamViewerQS_x64.exe"
    if (-not (Test-Path $sd)) { New-Item -ItemType Directory -Path $sd -Force | Out-Null }
    try {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        (New-Object System.Net.WebClient).DownloadFile($url, $exe)
        $sh  = New-Object -ComObject WScript.Shell
        $lnk = $sh.CreateShortcut("C:\Users\Public\Desktop\Fernwartung-L-EDV.lnk")
        $lnk.TargetPath       = $exe
        $lnk.Description      = "L-EDV Fernwartung"
        $lnk.WorkingDirectory = $sd
        $lnk.Save()
        Write-Log "TV QS installiert: $exe"
        Set-Status "TeamViewer QuickSupport bereit" 100 "ok"
        [System.Windows.Forms.MessageBox]::Show("TeamViewer QuickSupport heruntergeladen:`n$exe`n`nDesktop-Verknuepfung erstellt.","L-EDV","OK","Information") | Out-Null
    } catch {
        Write-Log "TV QS Fehler: $_" "ERROR"
        Set-Status "TV QS Fehler: $_" 0 "err"
        [System.Windows.Forms.MessageBox]::Show("Fehler: $_","Fehler","OK","Error") | Out-Null
    }
}

$Script:btnStartTvQs = Make-Btn $spSW "TV QuickSupport starten" 548 60 200 34 $cPanel2 {
    $exe = $Script:QuickSupportExe
    if (Test-Path $exe) {
        Start-Process $exe
        Write-Log "TV QS gestartet"; Set-Status "TV QuickSupport gestartet" 100 "ok"
    } else {
        Set-Status "TV QS nicht gefunden - bitte zuerst installieren" 0 "warn"
    }
}

Make-Btn $spSW "Host weg + QS" 758 60 150 34 $cOK {
    Write-Log "TeamViewer Sollzustand: Host entfernen, QuickSupport sicherstellen"
    $Script:btnRemoveTvHost.PerformClick()
    $qsExe = $Script:QuickSupportExe
    if (Test-Path $qsExe) {
        Write-Log "TV QuickSupport bereits vorhanden: $qsExe"
        Set-Status "TeamViewer Host entfernt, QuickSupport vorhanden" 100 "ok"
    } else {
        $Script:btnInstallTvQs.PerformClick()
    }
} | Out-Null

Make-Hdr $spSW "Affinity Suite entfernen" 8 106 900
Make-Lbl $spSW "Entfernt Affinity Photo, Designer, Publisher (alle Versionen) aus Programmen und AppData:" 8 136 880 14

Make-Btn $spSW "Affinity Suite vollstaendig entfernen" 8 158 280 34 $cAccent2 {
    Set-Status "Affinity Suite wird entfernt..." 10
    Write-Log "Affinity: Start"
    $found = $false

    $ukeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
    )
    foreach ($uk in $ukeys) {
        if (Test-Path $uk) {
            Get-ChildItem $uk -ErrorAction SilentlyContinue | ForEach-Object {
                $props = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
                $dn    = $props.DisplayName
                if ($dn -like "*Affinity*" -or $dn -like "*Serif*") {
                    $found = $true; $uns = $props.UninstallString
                    Set-Status "Entferne: $dn" 30; Write-Log "Entferne: $dn"
                    if ($uns) {
                        if ($uns -match "msiexec") {
                            $guid = [regex]::Match($uns, "\{[^}]+\}").Value
                            if ($guid) { Start-Process "msiexec.exe" "/x $guid /quiet /norestart" -Wait -ErrorAction SilentlyContinue }
                        } else {
                            $exe = ($uns.Trim('"')).Split(' ')[0]
                            if (Test-Path $exe) { Start-Process $exe "/SILENT /VERYSILENT /SUPPRESSMSGBOXES" -Wait -ErrorAction SilentlyContinue }
                        }
                    }
                }
            }
        }
    }
    Get-AppxPackage -AllUsers "*Affinity*" -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue

    foreach ($d in @("$env:APPDATA\Affinity","$env:LOCALAPPDATA\Affinity","$env:APPDATA\Serif","$env:ProgramFiles\Affinity","${env:ProgramFiles(x86)}\Affinity")) {
        if (Test-Path $d) { Remove-Item $d -Recurse -Force -ErrorAction SilentlyContinue; Write-Log "Entfernt: $d" }
    }

    Write-Log "Affinity entfernt: $found"
    Set-Status "Affinity Suite entfernt" 100 "ok"
    $msg = if ($found) { "Affinity Suite vollstaendig entfernt." } else { "Keine Affinity-Installation gefunden." }
    [System.Windows.Forms.MessageBox]::Show($msg,"L-EDV","OK","Information") | Out-Null
} | Out-Null

# ============================================================
# CHOCOLATEY HELPER FUNKTION
# ============================================================
function Get-ChocoExe {
    # 1) Umgebungsvariable (gesetzt oder frisch erweitert)
    $fromEnv = if ($env:ChocolateyInstall) { Join-Path $env:ChocolateyInstall "bin\choco.exe" } else { $null }
    if ($fromEnv -and (Test-Path $fromEnv)) { return $fromEnv }
    # 2) Standard-Installationspfad als Fallback
    $default = "C:\ProgramData\chocolatey\bin\choco.exe"
    if (Test-Path $default) { return $default }
    # 3) PATH-Suche
    $fromPath = Get-Command "choco" -ErrorAction SilentlyContinue
    if ($fromPath) { return $fromPath.Source }
    return $null
}

function Invoke-Choco {
    param([string]$Pkg, [string]$Disp)
    Write-Log "Choco install: $Pkg"
    Set-Status "Installiere $Disp..." 20

    if (-not (Get-ChocoExe)) {
        Set-Status "Chocolatey wird eingerichtet..." 10
        try {
            Set-ExecutionPolicy Bypass -Scope Process -Force
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
            # Invoke-WebRequest statt WebClient - zuverlaessiger auf modernen Systemen
            $installScript = (Invoke-WebRequest -Uri 'https://community.chocolatey.org/install.ps1' -UseBasicParsing).Content
            Invoke-Expression $installScript
            # Umgebungsvariable in der laufenden Session nachladen
            $env:ChocolateyInstall = "C:\ProgramData\chocolatey"
            $env:PATH = "$env:ChocolateyInstall\bin;" + $env:PATH
            Write-Log "Chocolatey installiert"
        } catch {
            Write-Log "Chocolatey fehlgeschlagen: $_" "ERROR"
            Set-Status "Chocolatey-Installation fehlgeschlagen" 0 "err"
            [System.Windows.Forms.MessageBox]::Show("Chocolatey konnte nicht installiert werden:`n$_","Fehler","OK","Error") | Out-Null
            return $false
        }
    }

    $choco = Get-ChocoExe
    if (-not $choco) {
        Write-Log "choco.exe nicht gefunden nach Installation" "ERROR"
        Set-Status "choco.exe nicht gefunden" 0 "err"
        return $false
    }
    & $choco install $Pkg -fy --no-progress 2>&1 | ForEach-Object { Write-Log "choco: $_" }
    Write-Log "$Disp installiert"
    Set-Status "$Disp installiert" 100 "ok"
    return $true
}

# ============================================================
# TAB: TOOLS
# ============================================================
$pgT = $Script:Pages["Tools"]
$spT = Make-Scroll $pgT 0 0 925 615

Make-Hdr $spT "Sysinternals Tools" 8 8 450
Make-Hdr $spT "Zusatz-Software" 466 8 450

# Sysinternals - direkte Buttons ohne loop
Make-Lbl $spT "Autoruns (Autostart-Analyse)" 8 38 440 14
Make-Btn $spT "Autoruns installieren + starten" 8 56 220 32 $cPanel2 {
    Set-Status "Autoruns wird geladen..." 10
    Write-Log "Autoruns: Download"
    $zip = "$env:TEMP\Autoruns.zip"
    $dir = "$env:TEMP\Autoruns"
    $dst = "$env:ProgramFiles\Sysinternals"
    try {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        (New-Object System.Net.WebClient).DownloadFile("https://download.sysinternals.com/files/Autoruns.zip", $zip)
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory $dir -Force | Out-Null }
        Expand-Archive $zip $dir -Force
        if (-not (Test-Path $dst)) { New-Item -ItemType Directory $dst -Force | Out-Null }
        $exe = Get-ChildItem $dir -Filter "Autoruns64.exe" -Recurse | Select-Object -First 1
        if ($exe) {
            Copy-Item $exe.FullName "$dst\Autoruns64.exe" -Force
            Start-Process "$dst\Autoruns64.exe"
            Write-Log "Autoruns gestartet: $dst\Autoruns64.exe"
            Set-Status "Autoruns installiert und gestartet" 100 "ok"
        }
    } catch { Write-Log "Autoruns Fehler: $_" "ERROR"; Set-Status "Autoruns Fehler: $_" 0 "err"; [System.Windows.Forms.MessageBox]::Show("Fehler: $_","Fehler","OK","Error") | Out-Null }
} | Out-Null

Make-Lbl $spT "TCPView (Netzwerkverbindungen live)" 8 96 440 14
Make-Btn $spT "TCPView installieren + starten" 8 114 220 32 $cPanel2 {
    Set-Status "TCPView wird geladen..." 10
    Write-Log "TCPView: Download"
    $zip = "$env:TEMP\TCPView.zip"
    $dir = "$env:TEMP\TCPView"
    $dst = "$env:ProgramFiles\Sysinternals"
    try {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        (New-Object System.Net.WebClient).DownloadFile("https://download.sysinternals.com/files/TCPView.zip", $zip)
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory $dir -Force | Out-Null }
        Expand-Archive $zip $dir -Force
        if (-not (Test-Path $dst)) { New-Item -ItemType Directory $dst -Force | Out-Null }
        $exe = Get-ChildItem $dir -Filter "tcpview64.exe" -Recurse | Select-Object -First 1
        if (-not $exe) { $exe = Get-ChildItem $dir -Filter "Tcpview.exe" -Recurse | Select-Object -First 1 }
        if ($exe) {
            Copy-Item $exe.FullName "$dst\$($exe.Name)" -Force
            Start-Process "$dst\$($exe.Name)"
            Write-Log "TCPView gestartet"
            Set-Status "TCPView installiert und gestartet" 100 "ok"
        }
    } catch { Write-Log "TCPView Fehler: $_" "ERROR"; Set-Status "TCPView Fehler: $_" 0 "err"; [System.Windows.Forms.MessageBox]::Show("Fehler: $_","Fehler","OK","Error") | Out-Null }
} | Out-Null

Make-Lbl $spT "Sysinternals Suite (alle Tools ~16MB)" 8 154 440 14
Make-Btn $spT "Komplette Suite installieren" 8 172 220 32 $cPanel2 {
    Set-Status "Sysinternals Suite wird geladen (~16MB)..." 5
    Write-Log "Sysinternals Suite: Download"
    $zip = "$env:TEMP\SysinternalsSuite.zip"
    $dst = "$env:ProgramFiles\Sysinternals"
    try {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        (New-Object System.Net.WebClient).DownloadFile("https://download.sysinternals.com/files/SysinternalsSuite.zip", $zip)
        if (-not (Test-Path $dst)) { New-Item -ItemType Directory $dst -Force | Out-Null }
        Expand-Archive $zip $dst -Force
        Write-Log "Sysinternals Suite installiert: $dst"
        Set-Status "Sysinternals Suite installiert: $dst" 100 "ok"
        [System.Windows.Forms.MessageBox]::Show("Sysinternals Suite installiert nach:`n$dst","L-EDV","OK","Information") | Out-Null
    } catch { Write-Log "Suite Fehler: $_" "ERROR"; Set-Status "Suite Fehler: $_" 0 "err"; [System.Windows.Forms.MessageBox]::Show("Fehler: $_","Fehler","OK","Error") | Out-Null }
} | Out-Null

Make-Btn $spT "Sysinternals-Ordner oeffnen" 238 172 200 32 $cPanel2 {
    $dst = "$env:ProgramFiles\Sysinternals"
    if (Test-Path $dst) { Start-Process "explorer.exe" $dst } else { Set-Status "Sysinternals noch nicht installiert" 0 "warn" }
} | Out-Null

# Zusatz-Software direkt (kein loop - kein closure bug)
Make-Lbl $spT "TreeSize Free" 466 38 440 14
Make-Btn $spT "TreeSize Free installieren" 466 56 220 32 $cPanel2 {
    $ok = Invoke-Choco "treesizefree" "TreeSize Free"
    if ($ok) { [System.Windows.Forms.MessageBox]::Show("TreeSize Free installiert.","L-EDV","OK","Information") | Out-Null }
} | Out-Null

Make-Lbl $spT "TeraCopy" 466 96 440 14
Make-Btn $spT "TeraCopy installieren" 466 114 220 32 $cPanel2 {
    $ok = Invoke-Choco "teracopy" "TeraCopy"
    if ($ok) { [System.Windows.Forms.MessageBox]::Show("TeraCopy installiert.","L-EDV","OK","Information") | Out-Null }
} | Out-Null

Make-Lbl $spT "Notepad++" 466 154 440 14
Make-Btn $spT "Notepad++ installieren" 466 172 220 32 $cPanel2 {
    $ok = Invoke-Choco "notepadplusplus" "Notepad++"
    if ($ok) { [System.Windows.Forms.MessageBox]::Show("Notepad++ installiert.","L-EDV","OK","Information") | Out-Null }
} | Out-Null

Make-Lbl $spT "7-Zip" 466 212 440 14
Make-Btn $spT "7-Zip installieren" 466 230 220 32 $cPanel2 {
    $ok = Invoke-Choco "7zip" "7-Zip"
    if ($ok) { [System.Windows.Forms.MessageBox]::Show("7-Zip installiert.","L-EDV","OK","Information") | Out-Null }
} | Out-Null

Make-Lbl $spT "VLC Media Player" 466 270 440 14
Make-Btn $spT "VLC installieren" 466 288 220 32 $cPanel2 {
    $ok = Invoke-Choco "vlc" "VLC"
    if ($ok) { [System.Windows.Forms.MessageBox]::Show("VLC installiert.","L-EDV","OK","Information") | Out-Null }
} | Out-Null

Make-Lbl $spT "Firefox" 466 328 440 14
Make-Btn $spT "Firefox installieren" 466 346 220 32 $cPanel2 {
    $ok = Invoke-Choco "firefox" "Firefox"
    if ($ok) { [System.Windows.Forms.MessageBox]::Show("Firefox installiert.","L-EDV","OK","Information") | Out-Null }
} | Out-Null

Make-Lbl $spT "Google Chrome" 466 386 440 14
Make-Btn $spT "Chrome installieren" 466 404 220 32 $cPanel2 {
    $ok = Invoke-Choco "googlechrome" "Google Chrome"
    if ($ok) { [System.Windows.Forms.MessageBox]::Show("Google Chrome installiert.","L-EDV","OK","Information") | Out-Null }
} | Out-Null

Make-Lbl $spT "PDF24" 466 444 440 14
Make-Btn $spT "PDF24 installieren" 466 462 220 32 $cPanel2 {
    $ok = Invoke-Choco "pdf24" "PDF24"
    if ($ok) { [System.Windows.Forms.MessageBox]::Show("PDF24 installiert.","L-EDV","OK","Information") | Out-Null }
} | Out-Null

# ============================================================
# TAB: PORTABLE APPS
# ============================================================
$pgP = $Script:Pages["Portable Apps"]

Make-Hdr $pgP "Portable Apps" 8 8 900
Make-Lbl $pgP ("Ordner: " + $Script:PortableDir + "  (Unterordner werden rekursiv durchsucht)") 8 38 880 14

Make-Btn $pgP "Ordner oeffnen" 8 60 180 28 $cPanel2 {
    if (-not (Test-Path $Script:PortableDir)) { New-Item -ItemType Directory $Script:PortableDir -Force | Out-Null }
    Start-Process "explorer.exe" $Script:PortableDir
    Write-Log "Portable-Ordner geoeffnet"
} | Out-Null

Make-Btn $pgP "Neu laden (Refresh)" 196 60 160 28 $cPanel2 { Load-PortableApps } | Out-Null

$Script:pGrid = New-Object System.Windows.Forms.Panel
$Script:pGrid.Location   = New-Object System.Drawing.Point(8, 96)
$Script:pGrid.Size       = New-Object System.Drawing.Size(905, 510)
$Script:pGrid.BackColor  = $cBG
$Script:pGrid.AutoScroll = $true
$pgP.Controls.Add($Script:pGrid)

function Load-PortableApps {
    $Script:pGrid.Controls.Clear()
    if (-not (Test-Path $Script:PortableDir)) { New-Item -ItemType Directory $Script:PortableDir -Force | Out-Null }
    $allExes = Get-ChildItem $Script:PortableDir -Filter "*.exe" -File -Recurse -ErrorAction SilentlyContinue
    $badNamePattern = '(?i)(unins|uninstall|setup|install|update|updater|helper|crash|crashsender|crashpad|report|reporter|redist|vc_redist|vcredist|runtime|service|svc|driver|diskspd|diskspdx|lang|launcherhelper)'
    $goodNamePattern = '(?i)(64|x64|portable|gui|app|main|diskmark|diskinfo|cpuz|gpuz|advanced_ip_scanner|ipscan|wireshark|tcpview|autoruns)'
    $groups = @{}
    foreach ($exe in $allExes) {
        $rel = $exe.FullName.Substring($Script:PortableDir.Length).TrimStart("\")
        $parts = $rel -split "\\"
        $key = if ($parts.Count -gt 1) { $parts[0] } else { "__root__\" + $exe.Name }
        if (-not $groups.ContainsKey($key)) { $groups[$key] = New-Object System.Collections.ArrayList }
        [void]$groups[$key].Add($exe)
    }

    $exes = New-Object System.Collections.ArrayList
    foreach ($key in ($groups.Keys | Sort-Object)) {
        $candidates = @($groups[$key] | Where-Object { $_.Name -notmatch $badNamePattern })
        if ($candidates.Count -eq 0) { $candidates = @($groups[$key]) }
        $folderName = if ($key -like "__root__\*") { "" } else { $key }
        $folderClean = ($folderName -replace '[^a-zA-Z0-9]', '').ToLowerInvariant()
        $ranked = $candidates | ForEach-Object {
            $base = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
            $baseClean = ($base -replace '[^a-zA-Z0-9]', '').ToLowerInvariant()
            $score = 0
            if ($_.Name -match $badNamePattern) { $score -= 1000 }
            if ($_.Name -match $goodNamePattern) { $score += 80 }
            if ([Environment]::Is64BitOperatingSystem -and $_.Name -match '(?i)(64|x64)') { $score += 60 }
            if (-not [Environment]::Is64BitOperatingSystem -and $_.Name -match '(?i)(32|x86)') { $score += 60 }
            if ($folderClean -and ($baseClean -eq $folderClean -or $folderClean.Contains($baseClean) -or $baseClean.Contains($folderClean))) { $score += 120 }
            if ($base -match '(?i)(cmd|cli|console|test|benchmark|sender|service|helper)') { $score -= 80 }
            [PSCustomObject]@{ File = $_; Score = $score; NameLength = $_.BaseName.Length }
        } | Sort-Object @{Expression="Score";Descending=$true}, @{Expression="NameLength";Descending=$false}, Name
        if ($ranked) { [void]$exes.Add($ranked[0].File) }
    }

    if ($exes.Count -eq 0) {
        $lbl = New-Object System.Windows.Forms.Label
        $lbl.Text      = "Keine startbaren .exe-Dateien in portable_apps oder Unterordnern gefunden." + [Environment]::NewLine + "Portable Apps als Unterordner ablegen und dann 'Neu laden' klicken."
        $lbl.Font      = $fMono
        $lbl.ForeColor = $cSub
        $lbl.Location  = New-Object System.Drawing.Point(16, 16)
        $lbl.Size      = New-Object System.Drawing.Size(860, 40)
        $Script:pGrid.Controls.Add($lbl)
        return
    }

    $col = 0; $row = 0
    foreach ($exe in $exes) {
        $x   = $col * 205
        $y   = $row * 78
        $ep  = $exe.FullName
        $rel = $exe.FullName.Substring($Script:PortableDir.Length).TrimStart("\")
        $parts = $rel -split "\\"
        $an  = if ($parts.Count -gt 1) { $parts[0] } else { [System.IO.Path]::GetFileNameWithoutExtension($exe.Name) }
        $sub = if ($parts.Count -gt 1) { "Startet: " + $exe.Name } else { "Direkt im portable_apps Ordner" }
        $sz  = [string]::Format("{0:N0} KB", ($exe.Length / 1KB))

        $pan = New-Object System.Windows.Forms.Panel
        $pan.Location  = New-Object System.Drawing.Point($x, $y)
        $pan.Size      = New-Object System.Drawing.Size(198, 72)
        $pan.BackColor = $cPanel2

        $btn = New-Object System.Windows.Forms.Button
        $btn.Text      = $an
        $btn.Location  = New-Object System.Drawing.Point(1, 1)
        $btn.Size      = New-Object System.Drawing.Size(196, 52)
        $btn.Font      = $fBold
        $btn.BackColor = $cPanel2
        $btn.ForeColor = $cText
        $btn.FlatStyle = "Flat"
        $btn.FlatAppearance.BorderSize  = 0
        $btn.Cursor    = [System.Windows.Forms.Cursors]::Hand
        $btn.Tag       = $ep   # Pfad im Tag speichern - kein closure-Bug
        $btn.TextAlign = "MiddleCenter"

        $btn.Add_Click({
            $path = $this.Tag
            try {
                Start-Process $path
                Write-Log "Portable gestartet: $path"
                Set-Status ("Gestartet: " + (Split-Path $path -Leaf)) 100 "ok"
            } catch {
                Write-Log "Portable Fehler: $path - $_" "ERROR"
                Set-Status "Fehler: $_" 0 "err"
            }
        })

        $lblSz = New-Object System.Windows.Forms.Label
        $lblSz.Text      = "$sub  |  $sz"
        $lblSz.Font      = $fSmall
        $lblSz.ForeColor = $cSub
        $lblSz.Location  = New-Object System.Drawing.Point(1, 55)
        $lblSz.Size      = New-Object System.Drawing.Size(196, 14)
        $lblSz.TextAlign = "MiddleCenter"

        $pan.Controls.Add($btn)
        $pan.Controls.Add($lblSz)
        $Script:pGrid.Controls.Add($pan)

        $col++
        if ($col -ge 4) { $col = 0; $row++ }
    }
    Set-Status ($exes.Count.ToString() + " Portable App(s) geladen") 100 "ok"
    Write-Log ("Portable Apps: " + $exes.Count + " geladen")
}

# ============================================================
# TAB: OFFLINE INSTALLER
# ============================================================
$pgOI = $Script:Pages["Offline Installer"]
Make-Hdr $pgOI "Offline Installer" 8 8 900
Make-Lbl $pgOI ("Ordner: " + $Script:OfflineInstallerDir + "  (.msi und .exe werden rekursiv erkannt)") 8 38 880 14

Make-Btn $pgOI "Ordner oeffnen" 8 60 180 28 $cPanel2 {
    if (-not (Test-Path $Script:OfflineInstallerDir)) { New-Item -ItemType Directory $Script:OfflineInstallerDir -Force | Out-Null }
    Start-Process "explorer.exe" $Script:OfflineInstallerDir
    Write-Log "Offline-Installer-Ordner geoeffnet"
} | Out-Null

Make-Btn $pgOI "Neu laden" 196 60 160 28 $cPanel2 { Load-OfflineInstallers } | Out-Null

$Script:pOfflineGrid = New-Object System.Windows.Forms.Panel
$Script:pOfflineGrid.Location = New-Object System.Drawing.Point(8, 96)
$Script:pOfflineGrid.Size = New-Object System.Drawing.Size(905, 510)
$Script:pOfflineGrid.BackColor = $cBG
$Script:pOfflineGrid.AutoScroll = $true
$pgOI.Controls.Add($Script:pOfflineGrid)

function Start-OfflineInstaller {
    param([string]$Path)
    try {
        Write-Log "Offline Installer gestartet: $Path"
        Set-Status ("Starte Offline Installer: " + (Split-Path $Path -Leaf)) 25
        if ($Path -match "\.msi$") {
            Start-Process "msiexec.exe" "/i `"$Path`" /qn /norestart" -Wait
        } else {
            Start-Process $Path -Wait
        }
        Write-Log "Offline Installer beendet: $Path"
        Set-Status "Offline Installer beendet" 100 "ok"
    } catch {
        Write-Log "Offline Installer Fehler: $Path - $_" "ERROR"
        Set-Status "Offline Installer Fehler" 0 "err"
        [System.Windows.Forms.MessageBox]::Show("Installer konnte nicht gestartet werden:`n$Path`n`n$_","Fehler","OK","Error") | Out-Null
    }
}

function Load-OfflineInstallers {
    $Script:pOfflineGrid.Controls.Clear()
    if (-not (Test-Path $Script:OfflineInstallerDir)) { New-Item -ItemType Directory $Script:OfflineInstallerDir -Force | Out-Null }
    $items = Get-ChildItem $Script:OfflineInstallerDir -Recurse -File -Include *.exe,*.msi -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch '(?i)(unins|uninstall|updater|helper|crash|redist|vcredist)' } |
        Sort-Object DirectoryName, Name
    if ($items.Count -eq 0) {
        Make-Lbl $Script:pOfflineGrid "Keine Installer gefunden. Lege .exe oder .msi Dateien in den Ordner installers." 16 16 820 20 $fMono $cSub | Out-Null
        return
    }
    $col=0; $row=0
    foreach ($item in $items) {
        $x=$col*295; $y=$row*72
        $rel=$item.FullName.Substring($Script:OfflineInstallerDir.Length).TrimStart("\")
        $panel=New-Object System.Windows.Forms.Panel
        $panel.Location=New-Object System.Drawing.Point($x,$y)
        $panel.Size=New-Object System.Drawing.Size(286,66)
        $panel.BackColor=$cPanel2
        $btn=New-Object System.Windows.Forms.Button
        $btn.Text=[System.IO.Path]::GetFileNameWithoutExtension($item.Name)
        $btn.Tag=$item.FullName
        $btn.Location=New-Object System.Drawing.Point(1,1)
        $btn.Size=New-Object System.Drawing.Size(284,42)
        $btn.Font=$fBold; $btn.BackColor=$cPanel2; $btn.ForeColor=$cText; $btn.FlatStyle="Flat"; $btn.FlatAppearance.BorderSize=0
        $btn.Add_Click({ Start-OfflineInstaller $this.Tag })
        $lbl=New-Object System.Windows.Forms.Label
        $lbl.Text=$rel
        $lbl.Font=$fSmall; $lbl.ForeColor=$cSub; $lbl.Location=New-Object System.Drawing.Point(6,45); $lbl.Size=New-Object System.Drawing.Size(274,16)
        $panel.Controls.Add($btn); $panel.Controls.Add($lbl); $Script:pOfflineGrid.Controls.Add($panel)
        $col++; if($col -ge 3){$col=0;$row++}
    }
    Write-Log ("Offline Installer geladen: " + $items.Count)
    Set-Status ($items.Count.ToString() + " Offline Installer geladen") 100 "ok"
}

# ============================================================
# TAB: WARTUNG
# ============================================================
$pgW = $Script:Pages["Wartung"]
$spW = Make-Scroll $pgW 0 0 925 615

Make-Hdr $spW "System-Reparatur" 8 8 450
Make-Hdr $spW "Netzwerk" 466 8 450

Make-Btn $spW "SFC Scan" 8 38 140 32 $cPanel2 {
    Write-Log "SFC Scan"
    Start-Process "powershell.exe" "-NoProfile -Command `"sfc /scannow; Write-Host 'Fertig!' -ForegroundColor Green; pause`"" -Verb RunAs
    Set-Status "SFC Scan gestartet (externes Fenster)" 50 "ok"
} | Out-Null

Make-Btn $spW "DISM Repair" 156 38 140 32 $cPanel2 {
    Write-Log "DISM"
    Start-Process "powershell.exe" "-NoProfile -Command `"DISM /Online /Cleanup-Image /RestoreHealth; Write-Host 'Fertig!' -ForegroundColor Green; pause`"" -Verb RunAs
    Set-Status "DISM gestartet" 50 "ok"
} | Out-Null

Make-Btn $spW "SFC + DISM" 304 38 140 32 $cPanel2 {
    Write-Log "SFC+DISM"
    Start-Process "powershell.exe" "-NoProfile -Command `"Write-Host 'SFC...' -ForegroundColor Cyan; sfc /scannow; Write-Host 'DISM...' -ForegroundColor Cyan; DISM /Online /Cleanup-Image /RestoreHealth; Write-Host 'Fertig!' -ForegroundColor Green; pause`"" -Verb RunAs
    Set-Status "SFC + DISM gestartet" 50 "ok"
} | Out-Null

Make-Btn $spW "Temp-Dateien loeschen" 8 78 210 32 $cPanel2 {
    Write-Log "Temp-Bereinigung"
    Set-Status "Temp-Dateien werden geloescht..." 10
    $cnt = 0
    foreach ($p in @("$env:TEMP","C:\Windows\Temp","C:\Windows\SoftwareDistribution\Download")) {
        if (Test-Path $p) {
            $cnt += (Get-ChildItem $p -Recurse -Force -ErrorAction SilentlyContinue).Count
            Remove-Item "$p\*" -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log "Temp geloescht: $p"
        }
    }
    Set-Status ("Temp-Bereinigung: " + $cnt + " Elemente entfernt") 100 "ok"
    [System.Windows.Forms.MessageBox]::Show("$cnt Elemente geloescht.","L-EDV","OK","Information") | Out-Null
} | Out-Null

Make-Btn $spW "Datentraegerbereinigung" 228 78 210 32 $cPanel2 {
    Write-Log "cleanmgr"
    Start-Process "cleanmgr.exe" "/sageset:1"
    Set-Status "Datentraegerbereinigung gestartet" 100 "ok"
} | Out-Null

Make-Btn $spW "Festplatten-Check (chkdsk C:)" 8 118 210 32 $cPanel2 {
    Write-Log "chkdsk"
    Start-Process "cmd.exe" "/k chkdsk C: /f /r" -Verb RunAs
    Set-Status "chkdsk gestartet" 50 "ok"
} | Out-Null

Make-Btn $spW "Taskmanager" 228 118 210 32 $cPanel2 {
    Start-Process "taskmgr.exe"; Write-Log "taskmgr"; Set-Status "Taskmanager geoeffnet" 100 "ok"
} | Out-Null

Make-Btn $spW "Systemwiederherst. aktivieren" 8 158 210 32 $cPanel2 {
    Write-Log "Systemwiederherstellung aktivieren"
    Set-Status "Systemwiederherstellung wird aktiviert..." 20
    Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
    & vssadmin resize shadowstorage /on=c: /for=c: /maxsize=5% 2>&1 | Out-Null
    Write-Log "Systemwiederherstellung aktiviert"
    Set-Status "Systemwiederherstellung aktiviert" 100 "ok"
    [System.Windows.Forms.MessageBox]::Show("Systemwiederherstellung aktiviert (5% Speicher).","L-EDV","OK","Information") | Out-Null
} | Out-Null

Make-Btn $spW "Wiederherstellungspunkt" 228 158 210 32 $cPanel2 {
    Write-Log "Wiederherstellungspunkt erstellen"
    Set-Status "Wiederherstellungspunkt wird erstellt..." 20
    try {
        Checkpoint-Computer -Description ("L-EDV " + (Get-Date -Format "yyyy-MM-dd HH:mm")) -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Log "Wiederherstellungspunkt erstellt"; Set-Status "Wiederherstellungspunkt erstellt" 100 "ok"
        [System.Windows.Forms.MessageBox]::Show("Wiederherstellungspunkt erfolgreich erstellt.","L-EDV","OK","Information") | Out-Null
    } catch {
        Write-Log "Wiederherst.-Punkt Fehler: $_" "ERROR"; Set-Status "Fehler: $_" 0 "err"
        [System.Windows.Forms.MessageBox]::Show("Fehler: $_","Fehler","OK","Error") | Out-Null
    }
} | Out-Null

Make-Btn $spW "Windows Update oeffnen" 8 198 210 32 $cPanel2 {
    Start-Process "ms-settings:windowsupdate"; Write-Log "WU"; Set-Status "Windows Update geoeffnet" 100 "ok"
} | Out-Null

Make-Btn $spW "Registrierungsbackup aktivieren" 228 198 210 32 $cPanel2 {
    Write-Log "RegBackup aktivieren"
    $rp = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Configuration Manager"
    if (Test-Path $rp) {
        Set-ItemProperty -Path $rp -Name "EnablePeriodicBackup" -Type DWord -Value 1 -ErrorAction SilentlyContinue
        Write-Log "RegBackup aktiviert"; Set-Status "Registrierungsbackup aktiviert" 100 "ok"
        [System.Windows.Forms.MessageBox]::Show("Periodisches Registrierungsbackup aktiviert.","L-EDV","OK","Information") | Out-Null
    }
} | Out-Null

# Netzwerk rechts
Make-Btn $spW "Netzwerk zuruecksetzen" 466 38 210 32 $cPanel2 {
    Write-Log "Netzwerk-Reset"
    Start-Process "cmd.exe" "/k netsh int ip reset && netsh winsock reset && ipconfig /flushdns && ipconfig /release && ipconfig /renew && echo FERTIG - Bitte neu starten!" -Verb RunAs
    Set-Status "Netzwerk-Reset gestartet" 50 "ok"
} | Out-Null

Make-Btn $spW "DNS Cache leeren" 686 38 196 32 $cPanel2 {
    & ipconfig /flushdns | Out-Null
    Write-Log "DNS Cache geleert"; Set-Status "DNS Cache geleert" 100 "ok"
    [System.Windows.Forms.MessageBox]::Show("DNS Cache geleert.","L-EDV","OK","Information") | Out-Null
} | Out-Null

Make-Btn $spW "IP-Konfiguration anzeigen" 466 78 210 32 $cPanel2 {
    Write-Log "ipconfig /all"
    $info = & ipconfig /all | Out-String
    $f2 = New-Object System.Windows.Forms.Form
    $f2.Text = "IP-Konfiguration - $env:COMPUTERNAME"
    $f2.Size = New-Object System.Drawing.Size(720, 520)
    $f2.BackColor = $cBG; $f2.StartPosition = "CenterScreen"
    $tb2 = New-Object System.Windows.Forms.TextBox
    $tb2.Multiline = $true; $tb2.ScrollBars = "Both"; $tb2.ReadOnly = $true
    $tb2.Dock = "Fill"; $tb2.BackColor = $cPanel; $tb2.ForeColor = $cText; $tb2.Font = $fMono; $tb2.Text = $info
    $f2.Controls.Add($tb2); $f2.ShowDialog() | Out-Null
} | Out-Null

Make-Btn $spW "Ping-Test google.com" 686 78 196 32 $cPanel2 {
    Write-Log "Ping-Test"
    $ok = Test-Connection "google.com" -Count 3 -Quiet -ErrorAction SilentlyContinue
    if ($ok) {
        Set-Status "Ping google.com: OK" 100 "ok"
        [System.Windows.Forms.MessageBox]::Show("Internetverbindung OK (google.com erreichbar).","L-EDV","OK","Information") | Out-Null
    } else {
        Set-Status "Ping fehlgeschlagen" 0 "err"
        [System.Windows.Forms.MessageBox]::Show("Ping zu google.com fehlgeschlagen!","L-EDV","OK","Warning") | Out-Null
    }
} | Out-Null

Make-Btn $spW "Netzwerkverbindungen" 466 118 210 32 $cPanel2 {
    Start-Process "ncpa.cpl"; Write-Log "ncpa"; Set-Status "Netzwerkverbindungen geoeffnet" 100 "ok"
} | Out-Null

Make-Btn $spW "Hosts-Datei bearbeiten" 686 118 196 32 $cPanel2 {
    Start-Process "notepad.exe" "C:\Windows\System32\drivers\etc\hosts" -Verb RunAs
    Write-Log "Hosts-Datei"; Set-Status "Hosts-Datei geoeffnet" 100 "ok"
} | Out-Null

Make-Btn $spW "Tracert (google.com)" 466 158 210 32 $cPanel2 {
    Start-Process "cmd.exe" "/k tracert google.com"
    Write-Log "tracert"; Set-Status "Tracert gestartet" 50 "ok"
} | Out-Null

Make-Btn $spW "Systeminfo-Fenster" 686 158 196 32 $cPanel2 {
    Write-Log "Systeminfo"
    Set-Status "Systeminfo wird geladen..." 10
    $ci  = Get-ComputerInfo -ErrorAction SilentlyContinue
    $nl  = [Environment]::NewLine
    $out = "=== SYSTEM ===$nl"
    $out += "Hostname : $env:COMPUTERNAME$nl"
    $out += "Benutzer : $env:USERNAME$nl"
    if ($ci) {
        $out += "Windows  : $($ci.WindowsProductName) Build $($ci.OsBuildNumber)$nl"
        $out += "RAM      : $([math]::Round($ci.CsTotalPhysicalMemory / 1GB, 1)) GB$nl"
        $out += "CPU      : $($ci.CsProcessors[0].Name)$nl"
        $out += "Geraet   : $($ci.CsManufacturer) $($ci.CsModel)$nl"
    }
    $disks = Get-PhysicalDisk -ErrorAction SilentlyContinue
    $out += "$nl=== LAUFWERKE ===$nl"
    foreach ($d in $disks) { $out += "$($d.FriendlyName)  $([math]::Round($d.Size/1GB,0)) GB  [$($d.MediaType)]$nl" }
    $net = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.PrefixOrigin -ne "WellKnown" }
    $out += "$nl=== NETZWERK ===$nl"
    foreach ($n in $net) { $out += "$($n.InterfaceAlias): $($n.IPAddress)/$($n.PrefixLength)$nl" }
    $boot = (Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue).LastBootUpTime
    if ($boot) { $out += "$nl=== LAUFZEIT ===$nlLetzter Start: $boot${nl}Laufzeit: $((Get-Date) - $boot)$nl" }

    $fSI = New-Object System.Windows.Forms.Form
    $fSI.Text = "Systeminfo - $env:COMPUTERNAME"
    $fSI.Size = New-Object System.Drawing.Size(700, 500)
    $fSI.BackColor = $cBG; $fSI.StartPosition = "CenterScreen"
    $tbSI = New-Object System.Windows.Forms.TextBox
    $tbSI.Multiline = $true; $tbSI.ScrollBars = "Both"; $tbSI.ReadOnly = $true
    $tbSI.Dock = "Fill"; $tbSI.BackColor = $cPanel; $tbSI.ForeColor = $cText; $tbSI.Font = $fMono; $tbSI.Text = $out
    $fSI.Controls.Add($tbSI); $fSI.ShowDialog() | Out-Null
    Set-Status "Systeminfo angezeigt" 100 "ok"
} | Out-Null

# Selbstloesch
Make-Hdr $spW "Toolkit-Verwaltung" 8 248 900

Make-Btn $spW "Toolkit-Ordner nach Schliessen loeschen" 8 278 280 32 $cAccent2 {
    $r = [System.Windows.Forms.MessageBox]::Show(
        "ACHTUNG: Toolkit-Ordner wird nach GUI-Schliessen geloescht!" + [Environment]::NewLine + $Script:RootDir + [Environment]::NewLine + "Fortfahren?",
        "Selbstloeschung","YesNo","Warning")
    if ($r -eq "Yes") {
        $del = "$env:TEMP\ledv_del.cmd"
        $root = $Script:RootDir
        $content = "@echo off" + [Environment]::NewLine + "timeout /t 3 /nobreak >nul" + [Environment]::NewLine + "rd /s /q `"$root`"" + [Environment]::NewLine + "del `"%~f0`""
        [System.IO.File]::WriteAllText($del, $content, [System.Text.Encoding]::ASCII)
        $Script:SelfDeleteScript = $del
        Write-Log "Selbstloeschung geplant: $del"
        Set-Status "Toolkit wird nach Schliessen geloescht" 100 "warn"
        [System.Windows.Forms.MessageBox]::Show("OK. Ordner wird nach dem Schliessen geloescht.","L-EDV","OK","Information") | Out-Null
    }
} | Out-Null

Make-Btn $spW "Selbstloeschung abbrechen" 298 278 200 32 $cPanel2 {
    $Script:SelfDeleteScript = $null
    Write-Log "Selbstloeschung abgebrochen"; Set-Status "Selbstloeschung abgebrochen" 100 "ok"
} | Out-Null

# ============================================================
# TAB: DEBLOAT - integriert aus debloat.ps1
# ============================================================
$pgDB = $Script:Pages["Debloat"]
Make-Hdr $pgDB "Debloat und System-Tweaks" 8 8 900

function New-ADTCheck {
    param($Parent,[string]$Text,[int]$X,[int]$Y,[int]$W,[bool]$Checked,[System.Drawing.Color]$FG = [System.Drawing.Color]::Empty)
    $cb = New-Object System.Windows.Forms.CheckBox
    $cb.Text = $Text; $cb.Checked = $Checked
    $cb.Location = New-Object System.Drawing.Point($X,$Y)
    $cb.Size = New-Object System.Drawing.Size($W,20)
    $cb.ForeColor = if ($FG -ne [System.Drawing.Color]::Empty) { $FG } else { $cText }
    $cb.FlatStyle = "Flat"
    $Parent.Controls.Add($cb)
    return $cb
}

$Script:DebloatPages = @{}
$Script:DebloatNavButtons = @{}
$Script:ActiveDebloatTab = "Bloatware"
$dbNavX = 8
foreach ($tn in @("Bloatware","Datenschutz","Xbox Gaming","Rechtsklick","Reparaturen","Systeminfo")) {
    $nb = Make-Btn $pgDB $tn $dbNavX 38 140 30 $cPanel2 { }
    $Script:DebloatNavButtons[$tn] = $nb
    $tp = New-Object System.Windows.Forms.Panel
    $tp.Location = New-Object System.Drawing.Point(8, 78)
    $tp.Size = New-Object System.Drawing.Size(900, 458)
    $tp.BackColor = $cBG
    $tp.Visible = $false
    $pgDB.Controls.Add($tp)
    $Script:DebloatPages[$tn] = $tp
    $dbNavX += 148
}

function Switch-DebloatPage {
    param([string]$Name)
    $Script:ActiveDebloatTab = $Name
    foreach ($key in $Script:DebloatPages.Keys) {
        $Script:DebloatPages[$key].Visible = ($key -eq $Name)
        if ($key -eq $Name) {
            $Script:DebloatNavButtons[$key].BackColor = $cAccent
            $Script:DebloatNavButtons[$key].ForeColor = [System.Drawing.Color]::White
        } else {
            $Script:DebloatNavButtons[$key].BackColor = $cPanel2
            $Script:DebloatNavButtons[$key].ForeColor = $cText
        }
    }
    Write-Log "Debloat Unterbereich: $Name"
}

$Script:DebloatNavButtons["Bloatware"].Add_Click({ Switch-DebloatPage "Bloatware" })
$Script:DebloatNavButtons["Datenschutz"].Add_Click({ Switch-DebloatPage "Datenschutz" })
$Script:DebloatNavButtons["Xbox Gaming"].Add_Click({ Switch-DebloatPage "Xbox Gaming" })
$Script:DebloatNavButtons["Rechtsklick"].Add_Click({ Switch-DebloatPage "Rechtsklick" })
$Script:DebloatNavButtons["Reparaturen"].Add_Click({ Switch-DebloatPage "Reparaturen" })
$Script:DebloatNavButtons["Systeminfo"].Add_Click({ Switch-DebloatPage "Systeminfo" })
Switch-DebloatPage "Bloatware"

$Script:DebloatApply = Make-Btn $pgDB "Ausgewaehlten Debloat-Tab anwenden" 8 550 270 36 $cAccent { Invoke-AdminDebloatApply } 
Make-Btn $pgDB "Alle Standard-Debloat-Tweaks anwenden" 288 550 270 36 $cAccent2 {
    foreach ($n in @("Bloatware","Datenschutz","Xbox Gaming","Rechtsklick")) { Switch-DebloatPage $n; Invoke-AdminDebloatApply $true }
    [System.Windows.Forms.MessageBox]::Show("Standard-Debloat abgeschlossen.`nNeustart empfohlen.","L-EDV","OK","Information") | Out-Null
} | Out-Null

$Script:dbBloat = @{}
$bloatDefs = @(
    @("Clipchamp","*Microsoft.Clipchamp*",$true),@("Cortana","*Microsoft.549981C3F5F10*",$true),@("Dev Home","*Microsoft.Windows.DevHome*",$true),
    @("Feedback Hub","*Microsoft.WindowsFeedbackHub*",$true),@("Get Help und Tipps","*Microsoft.GetHelp*",$true),@("Kamera-App","*Microsoft.WindowsCamera*",$false),
    @("Mail und Kalender","*microsoft.windowscommunicationsapps*",$false),@("Maps","*Microsoft.WindowsMaps*",$true),@("Microsoft News","*Microsoft.News*",$true),
    @("Microsoft Teams vorinstalliert","*MicrosoftTeams*",$true),@("Mixed Reality Portal","*Microsoft.MixedReality.Portal*",$true),@("Movies und TV","*Microsoft.ZuneVideo*",$true),
    @("Groove Music","*Microsoft.ZuneMusic*",$true),@("Sticky Notes","*Microsoft.MicrosoftStickyNotes*",$false),@("Office Hub","*Microsoft.MicrosoftOfficeHub*",$true),
    @("Outlook neue Version","*Microsoft.OutlookForWindows*",$true),@("Paint 3D","*Microsoft.MSPaint*",$true),@("People","*Microsoft.People*",$true),
    @("Power Automate","*Microsoft.PowerAutomateDesktop*",$true),@("Skype","*Microsoft.SkypeApp*",$true),@("Solitaire Collection","*MicrosoftSolitaireCollection*",$true),
    @("Sway","*Microsoft.Office.Sway*",$true),@("Microsoft To-Do","*Microsoft.Todos*",$false),@("MSN Wetter","*Microsoft.BingWeather*",$true),
    @("Widgets News Feed","*MicrosoftWindows.Client.WebExperience*",$true),@("Your Phone","*Microsoft.YourPhone*",$true),@("3D Viewer","*Microsoft.Microsoft3DViewer*",$true),
    @("Duolingo","*Duolingo*",$true),@("Spotify","*SpotifyAB.SpotifyMusic*",$true),@("Xbox App","*Microsoft.GamingApp*",$false),
    @("Xbox Game Bar","*Microsoft.XboxGamingOverlay*",$false),@("CandyCrush","*CandyCrush*",$true),@("Minecraft","*Minecraft*",$true)
)
$col=0;$row=0
foreach ($d in $bloatDefs) {
    $cb = New-ADTCheck $Script:DebloatPages["Bloatware"] $d[0] (14+($col*296)) (18+($row*22)) 284 $false
    $Script:dbBloat[$d[1]] = $cb
    $col++; if ($col -ge 3) { $col=0; $row++ }
}
Make-Btn $Script:DebloatPages["Bloatware"] "Alle auswaehlen" 14 410 140 26 $cPanel2 { foreach($cb in $Script:dbBloat.Values){$cb.Checked=$true} } | Out-Null
Make-Btn $Script:DebloatPages["Bloatware"] "Keine auswaehlen" 162 410 140 26 $cPanel2 { foreach($cb in $Script:dbBloat.Values){$cb.Checked=$false} } | Out-Null

$Script:dbPriv = @{}
Make-Hdr $Script:DebloatPages["Datenschutz"] "Telemetrie und Tracking" 10 10 430
Make-Hdr $Script:DebloatPages["Datenschutz"] "Werbung und Cloud" 450 10 430
$privDefs = @(
    @("Telemetry","Windows Telemetrie deaktivieren",$true,14,40),@("DiagData","Diagnosedaten auf Minimum setzen",$true,14,64),@("ActivityHist","Aktivitaetsverlauf deaktivieren",$true,14,88),
    @("Location","Standortverfolgung deaktivieren",$true,14,112),@("Feedback","Feedback-Anfragen deaktivieren",$true,14,136),@("TailoredExp","Personalisierte Erfahrungen deaktivieren",$true,14,160),
    @("InputPersonal","Eingabepersonalisierung deaktivieren",$true,14,184),@("WiFiSense","Wi-Fi Sense deaktivieren",$false,14,208),@("ErrorReport","Fehlerberichterstattung deaktivieren",$true,14,232),
    @("AdvID","Werbe-ID deaktivieren",$true,464,40),@("AppSuggest","App-Vorschlaege und stille Installs aus",$true,464,64),@("ConsumerFeat","Consumer Features deaktivieren",$true,464,88),
    @("CloudCont","Cloud-Inhalte im Startmenue aus",$true,464,112),@("BingSearch","Bing-Suche im Startmenue deaktivieren",$true,464,136),@("Cortana","Cortana deaktivieren",$true,464,160),
    @("Copilot","Windows Copilot deaktivieren",$true,464,184),@("MapSvc","Offline Maps Dienst deaktivieren",$true,464,208)
)
foreach($d in $privDefs){ $Script:dbPriv[$d[0]] = New-ADTCheck $Script:DebloatPages["Datenschutz"] $d[1] $d[3] $d[4] 410 $false }

$Script:dbXbox = @{}
Make-Hdr $Script:DebloatPages["Xbox Gaming"] "Xbox-Dienste und Gaming-Funktionen" 10 10 870
$xboxDefs = @(
    @("XboxApp","Xbox App entfernen",$false,$true),@("XboxGameBar","Xbox Game Bar entfernen",$true,$false),@("XboxGBSvc","Xbox Game Bar Dienst deaktivieren",$true,$false),
    @("XboxIdent","Xbox Identity Provider entfernen",$false,$true),@("XboxSpeech","Xbox Speech Overlay entfernen",$true,$false),@("XboxGamSave","Xbox Game Save Dienst deaktivieren",$false,$false),
    @("XboxNetApi","Xbox Live Networking deaktivieren",$false,$false),@("GameDVR","Game DVR Aufzeichnung deaktivieren",$true,$false),@("GameMode","Game Mode deaktivieren",$false,$false),
    @("XboxSolitar","Solitaire und Xbox-Spiele entfernen",$true,$false),@("XboxMinecr","Minecraft vorinstalliert entfernen",$true,$false),@("FullscOpt","Vollbild-Optimierungen deaktivieren",$false,$false)
)
$col=0;$row=0
foreach($d in $xboxDefs){ $fg=if($d[3]){$cWarn}else{$cText}; $Script:dbXbox[$d[0]]=New-ADTCheck $Script:DebloatPages["Xbox Gaming"] $d[1] (14+($col*430)) (40+($row*24)) 410 $false $fg; $col++; if($col -ge 2){$col=0;$row++} }
Make-Lbl $Script:DebloatPages["Xbox Gaming"] "! Rot markierte Optionen koennen Spiele oder Xbox-Apps beeintraechtigen." 14 350 840 18 $fSmall $cWarn | Out-Null

$Script:dbExplorer = @{}
$pgRC = $Script:DebloatPages["Rechtsklick"]
Make-Hdr $pgRC "Kontextmenue" 10 10 870; Make-Hdr $pgRC "Explorer und Startmenue" 10 120 430; Make-Hdr $pgRC "Taskleiste" 450 120 430
$Script:dbExplorer["ClassicRC"] = New-ADTCheck $pgRC "Klassisches Rechtsklick-Menue (Win10-Stil)" 14 45 500 $false
$Script:dbExplorer["EndTask"] = New-ADTCheck $pgRC "Task beenden im Rechtsklick auf Taskleiste aktivieren" 14 69 500 $false
$explDefs = @(
    @("ExplorerThisPC","Explorer oeffnet Dieser PC statt Schnellzugriff",14,154,$true),@("HideGallery","Galerie aus Explorer-Seitenbereich entfernen",14,178,$true),@("HideODSidebar","OneDrive aus Explorer-Seitenbereich entfernen",14,202,$true),
    @("ShowFileExt","Dateiendungen immer anzeigen",14,226,$true),@("ShowHidden","Versteckte Dateien anzeigen",14,250,$false),@("DisableAutoplay","AutoPlay fuer Wechseldatentraeger deaktivieren",14,274,$true),
    @("CtrlPanel","Systemsteuerung: Kleine Symbole klassisch",14,298,$true),@("DisableEdgeSC","Edge Desktop-Shortcut nach Updates blockieren",14,322,$true),
    @("HideSearch","Suchfeld in Taskleiste ausblenden",464,154,$true),@("HideTaskView","Task-Ansicht-Button ausblenden",464,178,$true),@("HidePeople","Kontakte-Button ausblenden",464,202,$true),
    @("HideWidgets","Widgets-Button ausblenden",464,226,$false),@("HideCopilot","Copilot-Button ausblenden",464,250,$true),@("HideChat","Chat-Button Teams ausblenden",464,274,$true),@("TaskbarLeft","Taskleisten-Icons linksbuendig",464,298,$false)
)
foreach($d in $explDefs){ $Script:dbExplorer[$d[0]] = New-ADTCheck $pgRC $d[1] $d[2] $d[3] 410 $false }

$pgRep = $Script:DebloatPages["Reparaturen"]
Make-Hdr $pgRep "System-Reparatur" 10 10 430; Make-Hdr $pgRep "Netzwerk" 450 10 430; Make-Hdr $pgRep "Windows Update" 10 200 870
Make-Btn $pgRep "SFC Scan" 14 44 190 30 $cPanel2 { Start-Process "powershell.exe" "-NoProfile -Command `"sfc /scannow; pause`"" -Verb RunAs; Write-Log "Debloat: SFC gestartet" } | Out-Null
Make-Btn $pgRep "DISM Repair" 214 44 190 30 $cPanel2 { Start-Process "powershell.exe" "-NoProfile -Command `"DISM /Online /Cleanup-Image /RestoreHealth; pause`"" -Verb RunAs; Write-Log "Debloat: DISM gestartet" } | Out-Null
Make-Btn $pgRep "Temp-Dateien loeschen" 14 86 190 30 $cPanel2 { foreach($p in @("$env:TEMP","C:\Windows\Temp")){Remove-Item "$p\*" -Recurse -Force -ErrorAction SilentlyContinue}; Write-Log "Debloat: Temp geloescht"; Set-Status "Temp-Dateien geloescht" 100 "ok" } | Out-Null
Make-Btn $pgRep "DNS Cache leeren" 454 44 190 30 $cPanel2 { ipconfig /flushdns | Out-Null; Write-Log "Debloat: DNS Cache geleert"; Set-Status "DNS Cache geleert" 100 "ok" } | Out-Null
Make-Btn $pgRep "Netzwerk Reset" 654 44 190 30 $cPanel2 { Start-Process "cmd.exe" "/k netsh int ip reset && netsh winsock reset && ipconfig /flushdns && echo Neustart empfohlen" -Verb RunAs; Write-Log "Debloat: Netzwerk Reset gestartet" } | Out-Null
Make-Btn $pgRep "Windows Updates konfigurieren" 14 236 230 30 $cPanel2 { $wu="HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"; if(-not(Test-Path $wu)){New-Item $wu -Force|Out-Null}; Set-ItemProperty $wu "DeferFeatureUpdatesPeriodInDays" -Type DWord -Value 365 -ErrorAction SilentlyContinue; Set-Status "Feature-Updates verzoegert" 100 "ok"; Write-Log "Debloat: Windows Update konfiguriert" } | Out-Null

$pgInfo = $Script:DebloatPages["Systeminfo"]
$Script:dbInfo = New-Object System.Windows.Forms.TextBox
$Script:dbInfo.Multiline=$true; $Script:dbInfo.ScrollBars="Both"; $Script:dbInfo.ReadOnly=$true; $Script:dbInfo.BackColor=$cPanel; $Script:dbInfo.ForeColor=$cText; $Script:dbInfo.Font=$fMono
$Script:dbInfo.Location=New-Object System.Drawing.Point(10,40); $Script:dbInfo.Size=New-Object System.Drawing.Size(870,380); $Script:dbInfo.Text="Klicke auf Systeminfo laden."
$pgInfo.Controls.Add($Script:dbInfo)
Make-Hdr $pgInfo "System-Informationen" 10 10 870
Make-Btn $pgInfo "Systeminfo laden" 10 430 160 28 $cPanel2 { $ci=Get-ComputerInfo -ErrorAction SilentlyContinue; $nl=[Environment]::NewLine; $Script:dbInfo.Text="Hostname: $env:COMPUTERNAME$nlWindows : $($ci.WindowsProductName) Build $($ci.OsBuildNumber)$nlRAM     : $([math]::Round($ci.CsTotalPhysicalMemory/1GB,1)) GB$nlCPU     : $($ci.CsProcessors[0].Name)$nl"; Set-Status "Systeminfo geladen" 100 "ok" } | Out-Null
Make-Btn $pgInfo "Als TXT exportieren" 180 430 160 28 $cPanel2 { $sfd=New-Object System.Windows.Forms.SaveFileDialog; $sfd.Filter="Textdatei (*.txt)|*.txt"; $sfd.FileName="$env:COMPUTERNAME-sysinfo.txt"; if($sfd.ShowDialog() -eq "OK"){$Script:dbInfo.Text|Out-File $sfd.FileName -Encoding UTF8; Write-Log "Systeminfo exportiert: $($sfd.FileName)"} } | Out-Null

function Invoke-AdminDebloatApply {
    param([bool]$Silent = $false)
    $tab = $Script:ActiveDebloatTab
    Write-Log "Debloat integriert: $tab startet"
    Set-Status "Debloat: $tab wird angewendet..." 5
    try { Checkpoint-Computer -Description "L-EDV Debloat $(Get-Date -Format 'yyyy-MM-dd')" -RestorePointType "MODIFY_SETTINGS" -ErrorAction SilentlyContinue } catch {}
    if ($tab -eq "Bloatware") {
        $items = $Script:dbBloat.GetEnumerator() | Where-Object { $_.Value.Checked }
        $total = [Math]::Max(($items | Measure-Object).Count,1); $done=0
        foreach($item in $items){ Set-Status "Entferne: $($item.Value.Text)" ([int](($done/$total)*90)+5); Get-AppxPackage -AllUsers $item.Key -ErrorAction SilentlyContinue|Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue|Where-Object{$_.PackageName -like $item.Key}|Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue; Write-Log "Debloat App entfernt: $($item.Value.Text)"; $done++ }
    }
    if ($tab -eq "Datenschutz") {
        $c=$Script:dbPriv
        if($c["Telemetry"].Checked){$p="HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"; if(-not(Test-Path $p)){New-Item $p -Force|Out-Null}; Set-ItemProperty $p AllowTelemetry -Type DWord -Value 0 -ErrorAction SilentlyContinue}
        if($c["DiagData"].Checked){$p="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection"; if(-not(Test-Path $p)){New-Item $p -Force|Out-Null}; Set-ItemProperty $p MaxTelemetryAllowed -Type DWord -Value 1 -ErrorAction SilentlyContinue}
        if($c["ActivityHist"].Checked){$p="HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"; if(-not(Test-Path $p)){New-Item $p -Force|Out-Null}; Set-ItemProperty $p EnableActivityFeed -Type DWord -Value 0 -ErrorAction SilentlyContinue; Set-ItemProperty $p PublishUserActivities -Type DWord -Value 0 -ErrorAction SilentlyContinue}
        if($c["Location"].Checked){$p="HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors"; if(-not(Test-Path $p)){New-Item $p -Force|Out-Null}; Set-ItemProperty $p DisableLocation -Type DWord -Value 1 -ErrorAction SilentlyContinue}
        if($c["AdvID"].Checked){$p="HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo"; if(-not(Test-Path $p)){New-Item $p -Force|Out-Null}; Set-ItemProperty $p DisabledByGroupPolicy -Type DWord -Value 1 -ErrorAction SilentlyContinue}
        if($c["AppSuggest"].Checked){$p="HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; foreach($k in @("ContentDeliveryAllowed","OemPreInstalledAppsEnabled","PreInstalledAppsEnabled","SilentInstalledAppsEnabled","SystemPaneSuggestionsEnabled","SubscribedContent-338388Enabled","SubscribedContent-338389Enabled")){Set-ItemProperty $p $k -Type DWord -Value 0 -ErrorAction SilentlyContinue}}
        if($c["ConsumerFeat"].Checked){$p="HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"; if(-not(Test-Path $p)){New-Item $p -Force|Out-Null}; Set-ItemProperty $p DisableWindowsConsumerFeatures -Type DWord -Value 1 -ErrorAction SilentlyContinue}
        if($c["BingSearch"].Checked){$p="HKCU:\Software\Policies\Microsoft\Windows\Explorer"; if(-not(Test-Path $p)){New-Item $p -Force|Out-Null}; Set-ItemProperty $p DisableSearchBoxSuggestions -Type DWord -Value 1 -ErrorAction SilentlyContinue}
        if($c["Cortana"].Checked){$p="HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"; if(-not(Test-Path $p)){New-Item $p -Force|Out-Null}; Set-ItemProperty $p AllowCortana -Type DWord -Value 0 -ErrorAction SilentlyContinue}
        if($c["Copilot"].Checked){$p="HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"; if(-not(Test-Path $p)){New-Item $p -Force|Out-Null}; Set-ItemProperty $p TurnOffWindowsCopilot -Type DWord -Value 1 -ErrorAction SilentlyContinue; Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" ShowCopilotButton -Type DWord -Value 0 -ErrorAction SilentlyContinue}
        if($c["MapSvc"].Checked){Stop-Service MapsBroker -ErrorAction SilentlyContinue; Set-Service MapsBroker -StartupType Disabled -ErrorAction SilentlyContinue}
    }
    if ($tab -eq "Xbox Gaming") {
        $c=$Script:dbXbox
        if($c["XboxApp"].Checked){Get-AppxPackage -AllUsers "*Microsoft.GamingApp*" -ErrorAction SilentlyContinue|Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue}
        if($c["XboxGameBar"].Checked){Get-AppxPackage -AllUsers "*Microsoft.XboxGamingOverlay*" -ErrorAction SilentlyContinue|Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue}
        if($c["XboxIdent"].Checked){Get-AppxPackage -AllUsers "*Microsoft.XboxIdentityProvider*" -ErrorAction SilentlyContinue|Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue}
        if($c["XboxSpeech"].Checked){Get-AppxPackage -AllUsers "*Microsoft.XboxSpeech*" -ErrorAction SilentlyContinue|Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue}
        if($c["XboxGBSvc"].Checked){Stop-Service XboxGipSvc,xbgm -ErrorAction SilentlyContinue; Set-Service XboxGipSvc -StartupType Disabled -ErrorAction SilentlyContinue; Set-Service xbgm -StartupType Disabled -ErrorAction SilentlyContinue}
        if($c["XboxGamSave"].Checked){Stop-Service XblGameSave -ErrorAction SilentlyContinue; Set-Service XblGameSave -StartupType Disabled -ErrorAction SilentlyContinue}
        if($c["XboxNetApi"].Checked){Stop-Service XboxNetApiSvc -ErrorAction SilentlyContinue; Set-Service XboxNetApiSvc -StartupType Disabled -ErrorAction SilentlyContinue}
        if($c["GameDVR"].Checked){Set-ItemProperty "HKCU:\System\GameConfigStore" GameDVR_Enabled -Type DWord -Value 0 -ErrorAction SilentlyContinue; $p="HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"; if(-not(Test-Path $p)){New-Item $p -Force|Out-Null}; Set-ItemProperty $p AllowGameDVR -Type DWord -Value 0 -ErrorAction SilentlyContinue}
        if($c["GameMode"].Checked){Set-ItemProperty "HKCU:\Software\Microsoft\GameBar" AutoGameModeEnabled -Type DWord -Value 0 -ErrorAction SilentlyContinue}
    }
    if ($tab -eq "Rechtsklick") {
        $c=$Script:dbExplorer
        if($c["ClassicRC"].Checked){$p="HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"; if(-not(Test-Path $p)){New-Item $p -Force|Out-Null}; Set-ItemProperty $p "(Default)" -Value "" -Type String -Force -ErrorAction SilentlyContinue}
        if($c["EndTask"].Checked){$p="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings"; if(-not(Test-Path $p)){New-Item $p -Force|Out-Null}; Set-ItemProperty $p TaskbarEndTask -Type DWord -Value 1 -ErrorAction SilentlyContinue}
        if($c["ExplorerThisPC"].Checked){Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" LaunchTo -Type DWord -Value 1 -ErrorAction SilentlyContinue}
        if($c["ShowFileExt"].Checked){Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" HideFileExt -Type DWord -Value 0 -ErrorAction SilentlyContinue}
        if($c["ShowHidden"].Checked){Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" Hidden -Type DWord -Value 1 -ErrorAction SilentlyContinue}
        if($c["HideSearch"].Checked){Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" SearchboxTaskbarMode -Type DWord -Value 0 -ErrorAction SilentlyContinue}
        if($c["HideTaskView"].Checked){Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" ShowTaskViewButton -Type DWord -Value 0 -ErrorAction SilentlyContinue}
        if($c["HideWidgets"].Checked){Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" TaskbarDa -Type DWord -Value 0 -ErrorAction SilentlyContinue}
        if($c["HideCopilot"].Checked){Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" ShowCopilotButton -Type DWord -Value 0 -ErrorAction SilentlyContinue}
        if($c["HideChat"].Checked){Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" TaskbarMn -Type DWord -Value 0 -ErrorAction SilentlyContinue}
        if($c["TaskbarLeft"].Checked){Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" TaskbarAl -Type DWord -Value 0 -ErrorAction SilentlyContinue}
        if($c["DisableEdgeSC"].Checked){Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" DisableEdgeDesktopShortcutCreation -Type DWord -Value 1 -ErrorAction SilentlyContinue}
        if($c["DisableAutoplay"].Checked){Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" NoDriveTypeAutoRun -Type DWord -Value 255 -ErrorAction SilentlyContinue}
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue; Start-Sleep -Milliseconds 800; Start-Process explorer.exe
    }
    Write-Log "Debloat integriert: $tab abgeschlossen"
    Set-Status "Debloat abgeschlossen - Neustart empfohlen" 100 "ok"
    if (-not $Silent) { [System.Windows.Forms.MessageBox]::Show("Ausgewaehlte Tweaks wurden angewendet.`nNeustart empfohlen.","L-EDV Debloat","OK","Information") | Out-Null }
}

# ============================================================
# TAB: LEDV INSTALLER - integriert aus ledvinstaller.ps1
# ============================================================
$pgI = $Script:Pages["LEDV Installer"]
$spI = Make-Scroll $pgI 0 0 925 615
Make-Hdr $spI "L-EDV Installer - Notebook Einrichtung" 8 8 900

$Script:ledvChecks = @{}
Make-Hdr $spI "Software installieren" 8 40 430
Make-Hdr $spI "System Tweaks" 466 40 430
$swDefs = @(
    @("Firefox","Firefox","firefox",8,74,$true),@("Chrome","Google Chrome","googlechrome",8,98,$false),@("Thunderbird","Thunderbird","thunderbird",8,122,$false),
    @("Libre","LibreOffice","libreoffice-fresh",8,146,$false),@("Adobe","Adobe Reader","adobereader",8,170,$false),@("VLC","VLC","vlc",8,194,$false),@("Irfan","IrfanView","irfanview",8,218,$false),
    @("Notepad","Notepad++","notepadplusplus",228,74,$true),@("7zip","7-Zip","7zip",228,98,$true),@("PDF24","PDF24","pdf24",228,122,$true),
    @("Greenshot","Greenshot","greenshot",228,146,$true),@("Teams","Microsoft Teams","microsoft-teams",228,170,$false),@("TreeSize","TreeSize Free","treesizefree",228,194,$false),@("TeraCopy","TeraCopy","teracopy",228,218,$false)
)
foreach($d in $swDefs){ $Script:ledvChecks[$d[0]] = New-ADTCheck $spI $d[1] $d[3] $d[4] 200 $false }
$Script:ledvPackages = @{}; foreach($d in $swDefs){ if($d[2]){$Script:ledvPackages[$d[0]]=@($d[1],$d[2])} }

$twDefs = @(
    @("Bloatware","Bloatware entfernen (Xbox, Bing, ...)",$true),@("EdgeSC","Edge Desktop-Verknuepfung blockieren",$true),@("AppSuggest","App-Vorschlaege deaktivieren",$true),
    @("Annoyances","Optimierungen (Fast Startup, Explorer ...)",$true),@("Wifi","Wi-Fi Sense deaktivieren",$false),@("F8","F8 Boot-Menue aktivieren",$false),
    @("OneDrive","OneDrive entfernen (VORSICHT!)",$false),@("DesktopIcons","Desktop-Icons einblenden",$true),@("TVQS","TeamViewer QuickSupport bereitstellen",$true),
    @("Protocols","Systemprotokoll auf Netzlaufwerk speichern",$true),@("SysRestore","Systemwiederherstellung aktivieren",$true),@("Updates","Windows Updates installieren",$false)
)
$y=74
foreach($d in $twDefs){ $fg=if($d[0] -eq "OneDrive"){$cWarn}else{$cText}; $Script:ledvChecks[$d[0]] = New-ADTCheck $spI $d[1] 474 $y 410 $false $fg; $y += 24 }

function Set-LedvInstallProfile {
    param([string]$Profile)
    foreach ($cb in $Script:ledvChecks.Values) { $cb.Checked = $false }
    $selection = switch ($Profile) {
        "Basis" { @("Firefox","7zip","PDF24","VLC","TVQS","DesktopIcons","Protocols","SysRestore") }
        "Homeoffice" { @("Firefox","Chrome","Thunderbird","Libre","Adobe","7zip","PDF24","Teams","TVQS","DesktopIcons","Protocols","SysRestore") }
        "Schule" { @("Firefox","Chrome","Libre","PDF24","7zip","VLC","TVQS","DesktopIcons","Protocols","SysRestore") }
        "Wartung" { @("7zip","Notepad","TreeSize","TVQS","DesktopIcons","Protocols","SysRestore") }
        default { @() }
    }
    foreach ($key in $selection) { if ($Script:ledvChecks.ContainsKey($key)) { $Script:ledvChecks[$key].Checked = $true } }
    Write-Log "LEDV Profil gewaehlt: $Profile"
    Set-Status "Profil gesetzt: $Profile" 100 "ok"
}

Make-Hdr $spI "Profile" 8 330 888
Make-Btn $spI "Basis Privatkunde" 16 360 160 28 $cPanel2 { Set-LedvInstallProfile "Basis" } | Out-Null
Make-Btn $spI "Homeoffice" 184 360 140 28 $cPanel2 { Set-LedvInstallProfile "Homeoffice" } | Out-Null
Make-Btn $spI "Schule / Studium" 332 360 150 28 $cPanel2 { Set-LedvInstallProfile "Schule" } | Out-Null
Make-Btn $spI "Nur Wartung" 490 360 130 28 $cPanel2 { Set-LedvInstallProfile "Wartung" } | Out-Null
Make-Btn $spI "Auswahl leeren" 628 360 130 28 $cPanel2 { foreach ($cb in $Script:ledvChecks.Values) { $cb.Checked = $false }; Set-Status "Auswahl geleert" 100 "ok" } | Out-Null

Make-Hdr $spI "Ausfuehren" 8 400 888
Make-Lbl $spI "Kundenname:" 16 436 100 16 $fSmall $cSub | Out-Null
$Script:txLedvCustomer = New-Object System.Windows.Forms.TextBox
$Script:txLedvCustomer.Location = New-Object System.Drawing.Point(116,432)
$Script:txLedvCustomer.Size = New-Object System.Drawing.Size(240,24)
$Script:txLedvCustomer.BackColor = $cPanel2; $Script:txLedvCustomer.ForeColor = $cText; $Script:txLedvCustomer.BorderStyle = "FixedSingle"
$spI.Controls.Add($Script:txLedvCustomer)
Make-Btn $spI "Ausgewaehlte Installation starten" 370 428 260 36 $cAccent { Invoke-AdminLedvInstall } | Out-Null

function Invoke-AdminDownloadTVQS {
    $dir=$Script:LedvFilesDir; if(-not(Test-Path $dir)){New-Item -ItemType Directory -Path $dir -Force|Out-Null}
    $exe=$Script:QuickSupportExe; $url="https://customdesignservice.teamviewer.com/download/windows/v15/6mes7x8/TeamViewerQS_x64.exe"
    [System.Net.ServicePointManager]::SecurityProtocol=[System.Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $url -OutFile $exe -UseBasicParsing -ErrorAction Stop
    $sh=New-Object -ComObject WScript.Shell; $lnk=$sh.CreateShortcut("C:\Users\Public\Desktop\Fernwartung-L-EDV.lnk"); $lnk.TargetPath=$exe; $lnk.WorkingDirectory=$dir; $lnk.Save()
    Write-Log "LEDV: TeamViewer QuickSupport bereitgestellt: $exe"
}

function Invoke-AdminLedvInstall {
    $name=$Script:txLedvCustomer.Text.Trim()
    if(-not $name){[System.Windows.Forms.MessageBox]::Show("Bitte Kundennamen eingeben.","Hinweis","OK","Warning")|Out-Null; return}
    Write-Log "LEDV integriert: Start fuer $name"
    Set-Status "LEDV Installation startet..." 2
    if($Script:ledvChecks["Protocols"].Checked){$ts=Get-Date -Format "yyyyMMdd_HHmm"; $lf=Join-Path $Script:LogDir ("Protokoll-$name-$ts.log"); Get-ComputerInfo|Out-File $lf -Encoding UTF8 -ErrorAction SilentlyContinue; Write-Log "LEDV: Protokoll lokal $lf"}
    $selected = @($Script:ledvPackages.Keys | Where-Object { $Script:ledvChecks[$_].Checked })
    if ($selected.Count -gt 0 -and -not (Get-ChocoExe)) {
        Set-Status "Chocolatey wird eingerichtet..." 8
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol=[System.Net.SecurityProtocolType]::Tls12
        $installScript = (Invoke-WebRequest -Uri 'https://community.chocolatey.org/install.ps1' -UseBasicParsing).Content
        Invoke-Expression $installScript
        $env:ChocolateyInstall = "C:\ProgramData\chocolatey"
        $env:PATH="$env:ChocolateyInstall\bin;$env:PATH"
        Write-Log "LEDV: Chocolatey eingerichtet"
    }
    $total=[Math]::Max($selected.Count,1); $done=0
    foreach($key in $selected){$disp=$Script:ledvPackages[$key][0]; $pkg=$Script:ledvPackages[$key][1]; Set-Status "Installiere $disp..." ([int](($done/$total)*50)+15); Invoke-Choco $pkg $disp | Out-Null; $done++}
    if($Script:ledvChecks["TVQS"].Checked){Set-Status "TeamViewer QuickSupport wird bereitgestellt..." 70; try{Invoke-AdminDownloadTVQS}catch{Write-Log "LEDV: TV QS Fehler $_" "ERROR"; [System.Windows.Forms.MessageBox]::Show("TeamViewer QS konnte nicht geladen werden:`n$_","Fehler","OK","Warning")|Out-Null}}
    if($Script:ledvChecks["DesktopIcons"].Checked){Enable-BaseDesktopIcons}
    if($Script:ledvChecks["Bloatware"].Checked){foreach($pkg in @("*Microsoft.BingNews*","*Microsoft.GetHelp*","*Microsoft.People*","*Microsoft.SkypeApp*","*Microsoft.YourPhone*","*Microsoft.ZuneMusic*","*Microsoft.ZuneVideo*","*Microsoft.Clipchamp*","*MicrosoftSolitaireCollection*","*Microsoft.PowerAutomateDesktop*","*Duolingo*","*CandyCrush*","*Spotify*")){Get-AppxPackage -AllUsers $pkg -ErrorAction SilentlyContinue|Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue}}
    if($Script:ledvChecks["EdgeSC"].Checked){Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" DisableEdgeDesktopShortcutCreation -Type DWord -Value 1 -ErrorAction SilentlyContinue}
    if($Script:ledvChecks["AppSuggest"].Checked){$p="HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; foreach($k in @("ContentDeliveryAllowed","OemPreInstalledAppsEnabled","PreInstalledAppsEnabled","SilentInstalledAppsEnabled","SystemPaneSuggestionsEnabled")){Set-ItemProperty $p $k -Type DWord -Value 0 -ErrorAction SilentlyContinue}}
    if($Script:ledvChecks["Wifi"].Checked){$p="HKLM:\SOFTWARE\Microsoft\WcmSvc\wifinetworkmanager\config"; if(-not(Test-Path $p)){New-Item $p -Force|Out-Null}; Set-ItemProperty $p AutoConnectAllowedOEM -Type DWord -Value 0 -ErrorAction SilentlyContinue; Set-ItemProperty $p WiFISenseAllowed -Type DWord -Value 0 -ErrorAction SilentlyContinue}
    if($Script:ledvChecks["F8"].Checked){bcdedit /set "{current}" BootMenuPolicy Legacy | Out-Null}
    if($Script:ledvChecks["OneDrive"].Checked){taskkill.exe /F /IM OneDrive.exe 2>$null; $s="$env:SystemRoot\System32\OneDriveSetup.exe"; if(Test-Path $s){& $s /uninstall 2>$null}}
    if($Script:ledvChecks["Annoyances"].Checked){Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" LongPathsEnabled -Type DWord -Value 1 -ErrorAction SilentlyContinue; Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" HiberbootEnabled -Type DWord -Value 0 -ErrorAction SilentlyContinue; Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" SearchboxTaskbarMode -Type DWord -Value 0 -ErrorAction SilentlyContinue; Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" LaunchTo -Type DWord -Value 1 -ErrorAction SilentlyContinue}
    if($Script:ledvChecks["SysRestore"].Checked){Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue; vssadmin resize shadowstorage /on=c: /for=c: /maxsize=5% 2>$null}
    if($Script:ledvChecks["Updates"].Checked){Install-PackageProvider -Name NuGet -Force -ErrorAction SilentlyContinue|Out-Null; Install-Module PSWindowsUpdate -Force -ErrorAction SilentlyContinue|Out-Null; Get-WindowsUpdate -AcceptAll -Install -AutoReboot -ErrorAction SilentlyContinue}
    Write-Log "LEDV integriert: abgeschlossen fuer $name"
    Set-Status "LEDV Installation abgeschlossen - Neustart empfohlen" 100 "ok"
    [System.Windows.Forms.MessageBox]::Show("Installation fuer '$name' abgeschlossen.`nBitte Notebook neu starten.","L-EDV Installer","OK","Information") | Out-Null
}

# ============================================================
# TAB: ABSCHLUSS
# ============================================================
$pgA = $Script:Pages["Abschluss"]
Make-Hdr $pgA "Abschluss-Check und Uebergabeprotokoll" 8 8 900

$Script:txtCompletion = New-Object System.Windows.Forms.TextBox
$Script:txtCompletion.Multiline = $true
$Script:txtCompletion.ScrollBars = "Both"
$Script:txtCompletion.ReadOnly = $true
$Script:txtCompletion.BackColor = $cPanel
$Script:txtCompletion.ForeColor = $cText
$Script:txtCompletion.Font = $fMono
$Script:txtCompletion.Location = New-Object System.Drawing.Point(8, 86)
$Script:txtCompletion.Size = New-Object System.Drawing.Size(900, 455)
$pgA.Controls.Add($Script:txtCompletion)

function Get-CompletionReportText {
    $nl = [Environment]::NewLine
    $ci = Get-ComputerInfo -ErrorAction SilentlyContinue
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
    $bios = Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $disks = Get-PhysicalDisk -ErrorAction SilentlyContinue
    $missing = Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue | Where-Object { $_.ConfigManagerErrorCode -ne 0 }
    $defender = Get-MpComputerStatus -ErrorAction SilentlyContinue
    $bitlocker = Get-BitLockerVolume -ErrorAction SilentlyContinue
    $pending = Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"
    $qs = if (Test-Path $Script:QuickSupportExe) { "OK - $Script:QuickSupportExe" } else { "Nicht vorhanden" }

    $out = "L-EDV Abschluss-Check" + $nl
    $out += "Datum       : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" + $nl
    $out += "Computer    : $env:COMPUTERNAME" + $nl
    $out += "Benutzer    : $env:USERNAME" + $nl
    $out += "Hersteller  : $($cs.Manufacturer)" + $nl
    $out += "Modell      : $($cs.Model)" + $nl
    $out += "Seriennr.   : $($bios.SerialNumber)" + $nl
    if ($ci) { $out += "Windows     : $($ci.WindowsProductName) Build $($ci.OsBuildNumber)" + $nl }
    if ($cs) { $out += "RAM         : $([math]::Round($cs.TotalPhysicalMemory / 1GB, 1)) GB" + $nl }
    $out += "Letzter Boot: $($os.LastBootUpTime)" + $nl
    $out += "Pending Reboot: $pending" + $nl + $nl
    $out += "Laufwerke:" + $nl
    foreach ($d in $disks) { $out += " - $($d.FriendlyName) | $([math]::Round($d.Size/1GB,0)) GB | $($d.MediaType) | $($d.HealthStatus)" + $nl }
    $out += $nl + "Sicherheit:" + $nl
    if ($defender) {
        $out += " - Defender Echtzeitschutz: $($defender.RealTimeProtectionEnabled)" + $nl
        $out += " - Defender Signaturen   : $($defender.AntivirusSignatureLastUpdated)" + $nl
    } else { $out += " - Defender Status nicht abrufbar" + $nl }
    $out += $nl + "BitLocker:" + $nl
    if ($bitlocker) { foreach ($b in $bitlocker) { $out += " - $($b.MountPoint) $($b.VolumeStatus) $($b.ProtectionStatus)" + $nl } } else { $out += " - Nicht abrufbar / nicht aktiv" + $nl }
    $out += $nl + "Geraete mit Fehlern:" + $nl
    if ($missing) { foreach ($m in $missing) { $out += " - [$($m.ConfigManagerErrorCode)] $($m.Name)" + $nl } } else { $out += " - Keine fehlenden/fehlerhaften Geraete gefunden" + $nl }
    $out += $nl + "Toolkit:" + $nl
    $out += " - TeamViewerQS: $qs" + $nl
    $out += " - Logdatei    : $Script:RunLogFile" + $nl
    return $out
}

Make-Btn $pgA "Check ausfuehren" 8 46 170 30 $cAccent {
    $Script:txtCompletion.Text = Get-CompletionReportText
    Write-Log "Abschluss-Check ausgefuehrt"
    Set-Status "Abschluss-Check erstellt" 100 "ok"
} | Out-Null

Make-Btn $pgA "Protokoll speichern" 188 46 170 30 $cPanel2 {
    if (-not $Script:txtCompletion.Text) { $Script:txtCompletion.Text = Get-CompletionReportText }
    $file = Join-Path $Script:LedvFilesDir ("Abschluss-" + $env:COMPUTERNAME + "-" + (Get-Date -Format "yyyy-MM-dd_HH-mm-ss") + ".txt")
    $Script:txtCompletion.Text | Out-File $file -Encoding UTF8
    Write-Log "Abschlussprotokoll gespeichert: $file"
    Set-Status "Abschlussprotokoll gespeichert" 100 "ok"
    [System.Windows.Forms.MessageBox]::Show("Gespeichert:`n$file","L-EDV","OK","Information") | Out-Null
} | Out-Null

Make-Btn $pgA "Windows Aktivierung" 368 46 170 30 $cPanel2 {
    Start-Process "cscript.exe" "$env:windir\system32\slmgr.vbs /xpr"
    Write-Log "Windows Aktivierungsstatus geoeffnet"
} | Out-Null

Make-Btn $pgA "Fehlende Geraete" 548 46 170 30 $cPanel2 {
    Start-Process "devmgmt.msc"
    Write-Log "Geraete-Manager aus Abschluss geoeffnet"
} | Out-Null

# ============================================================
# FORM RESIZE
# ============================================================
$Form.Add_Resize({
    $cw = $Form.ClientSize.Width
    $ch = $Form.ClientSize.Height
    $pHeader.Width   = $cw
    $stripe.Width    = $cw
    $hLineH.Width    = $cw
    $pSidebar.Height = $ch - 59 - 58
    $vLine.Height    = $ch - 59 - 58
    $pContent.Width  = $cw - 169
    $pContent.Height = $ch - 59 - 58
    $pStatus.Width   = $cw
    $pStatus.Top     = $ch - 58
    foreach ($pg in $Script:Pages.Values) {
        $pg.Width  = $pContent.Width
        $pg.Height = $pContent.Height
    }
})

# ============================================================
# FORM CLOSE
# ============================================================
$Form.Add_FormClosed({
    Write-Log "L-EDV Admin Toolkit beendet"
    if ($Script:SelfDeleteScript -and (Test-Path $Script:SelfDeleteScript)) {
        Write-Log "Selbstloeschung: $Script:SelfDeleteScript"
        Start-Process "cmd.exe" ("/c `"" + $Script:SelfDeleteScript + "`"") -WindowStyle Hidden
    }
})

# ============================================================
# START
# ============================================================
Switch-Tab "System"
Load-PortableApps
Load-OfflineInstallers
Write-Log "GUI bereit"
Set-Status ("L-EDV Admin Toolkit bereit  |  " + $Script:RootDir) 0

[void]$Form.ShowDialog()
