@echo off
chcp 65001 >nul
setlocal EnableExtensions
title L-EDV Admin Toolkit

set "SCRIPT_DIR=%~dp0"
set "SCRIPT_FILE=%SCRIPT_DIR%AdminToolkit.ps1"

cd /d "%SCRIPT_DIR%"

net session >nul 2>&1
if not "%errorlevel%"=="0" (
    echo Starte L-EDV Admin Toolkit mit Administratorrechten...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

if not exist "%SCRIPT_DIR%logs" mkdir "%SCRIPT_DIR%logs"
if not exist "%SCRIPT_DIR%portable_apps" mkdir "%SCRIPT_DIR%portable_apps"

if not exist "%SCRIPT_FILE%" (
    echo AdminToolkit.ps1 wurde nicht gefunden:
    echo %SCRIPT_FILE%
    pause
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_FILE%" -ScriptRoot "%SCRIPT_DIR%"
exit /b %errorlevel%
