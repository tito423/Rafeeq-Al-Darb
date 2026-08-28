@echo off
cd /d "E:\My Projects\Rafiq-Al-Darb\rafeeq_app"
echo Starting build at %TIME%
echo ======================================== >> build_output.txt
echo Build started at %DATE% %TIME% >> build_output.txt
echo ======================================== >> build_output.txt

echo Running flutter build apk --release...
flutter build apk --release >> build_output.txt 2>&1

echo Build completed with exit code %ERRORLEVEL%
echo ======================================== >> build_output.txt
echo Build completed at %DATE% %TIME% with exit code %ERRORLEVEL% >> build_output.txt
echo ======================================== >> build_output.txt

if %ERRORLEVEL% EQU 0 (
    echo SUCCESS: Build completed successfully
    echo Checking for APK files...
    dir /s /b *.apk >> build_output.txt 2>&1
) else (
    echo ERROR: Build failed with exit code %ERRORLEVEL%
    echo Last 20 lines of output:
    tail -20 build_output.txt
)

pause