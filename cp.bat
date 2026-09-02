@echo off
REM Quick checkpoint:
REM   cp "what I just did"          checkpoint (commit) with that note
REM   cp "..." -Done               same, but mark the stage COMPLETE
REM   cp /s      (or: -s, status)  just show where things stand, no commit
REM
REM Note: run this from PowerShell or cmd. Git Bash rewrites a bare "/s" into
REM a path like "S:/", so the status forms below also match that artifact.
setlocal
set "ARG1=%~1"

if /I "%ARG1%"=="/s"       goto :status
if /I "%ARG1%"=="-s"       goto :status
if /I "%ARG1%"=="s"        goto :status
if /I "%ARG1%"=="/status"  goto :status
if /I "%ARG1%"=="-status"  goto :status
if /I "%ARG1%"=="status"   goto :status
if /I "%ARG1%"=="S:/"      goto :status
if /I "%ARG1%"=="S:\"      goto :status

if "%ARG1%"=="" (
  echo Usage: cp "what you just did"   ^|   cp "..." -Done   ^|   cp /s
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\checkpoint.ps1" %*
exit /b %ERRORLEVEL%

:status
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\checkpoint.ps1" -Status
exit /b %ERRORLEVEL%
