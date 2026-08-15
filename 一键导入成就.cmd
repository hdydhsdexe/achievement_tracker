@echo off
setlocal
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\save_importer\one-click-import.ps1"
set "ImporterExitCode=%ERRORLEVEL%"
echo.
pause
exit /b %ImporterExitCode%
