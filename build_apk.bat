@echo off
cd /d e:\My Projects\Rafiq-Al-Darb\rafeeq_app
flutter build apk --release > _apk_build_out.txt 2>&1
echo EXIT_CODE:%%ERRORLEVEL%% >> _apk_build_out.txt

