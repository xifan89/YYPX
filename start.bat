@echo off
cd /d "%~dp0"
echo Starting server...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0server.ps1"
pause
