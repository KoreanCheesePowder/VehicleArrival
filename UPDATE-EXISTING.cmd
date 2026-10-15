@echo off
chcp 65001 >nul
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0UPDATE-EXISTING.ps1"
if errorlevel 1 (echo Update failed. See error above.)
echo.
pause
