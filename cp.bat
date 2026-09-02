@echo off
REM Quick checkpoint:  cp "what I just did"       |  cp /s   to show status
if "%~1"=="/s" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\checkpoint.ps1" -Status
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\checkpoint.ps1" %*
)
