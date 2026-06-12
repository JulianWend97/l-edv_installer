# Build-EXE.ps1 - einmal ausführen um die EXE zu bauen

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$inputPs1  = Join-Path $scriptDir "AdminToolkit.ps1"
$outputExe = Join-Path $scriptDir "L-EDV-AdminToolkit.exe"
$iconFile  = Join-Path $scriptDir "favicon.ico"   # optional, weglassen wenn kein Icon

$params = @{
    InputFile       = $inputPs1
    OutputFile      = $outputExe
    RequireAdmin    = $true          # UAC-Prompt automatisch
    NoConsole       = $false          # kein schwarzes CMD-Fenster
    Title           = "L-EDV Admin Toolkit"
    Description     = "L-EDV Windows Admin Toolkit"
    Company         = "L-EDV"
    Version         = "2.0.0.0"
    Product         = "L-EDV AdminToolkit"
    Copyright       = "(c) 2026 Felix Natterer, Julian Wendland - L-EDV"
    Icon            = $iconFile    # Zeile aktivieren wenn icon.ico vorhanden
}

Write-Host "Kompiliere AdminToolkit.ps1 -> L-EDV-AdminToolkit.exe ..." -ForegroundColor Cyan
Invoke-PS2EXE @params
Write-Host "Fertig: $outputExe" -ForegroundColor Green