@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-Local.ps1" -Slot 2
if errorlevel 1 pause
