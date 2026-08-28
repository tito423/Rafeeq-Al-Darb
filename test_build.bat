@echo off
cd /d "E:\My Projects\Rafiq-Al-Darb\rafeeq_app"
echo Starting build at %TIME% > build_log.txt
flutter build apk --release >> build_log.txt 2>&1
echo Build completed with exit code %ERRORLEVEL% >> build_log.txt
echo EXIT_CODE:%ERRORLEVEL% >> build_log.txt