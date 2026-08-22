@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Run-Validated-LegionGo-AMD-26.7.1-Public-Beta-v3.1.ps1"
set "RC=%ERRORLEVEL%"
echo.
if not "%RC%"=="0" echo Installer exited with code %RC%. Review the message above.
exit /b %RC%
