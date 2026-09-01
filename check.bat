@echo off
REM Double-click to run the Flutter check once and write scripts\_check_output.txt
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\check.ps1" %*
echo.
pause
