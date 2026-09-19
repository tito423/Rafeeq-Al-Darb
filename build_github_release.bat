@echo off
rem The GitHub release APK - the only build that carries the donation link.
rem
rem «ده لينك الباي بال حطه بس في التطبيق اللي هيبقى على جيت هب» (2026-09-19).
rem AppConfig.donationUrl stays empty in the source, so any other build
rem (a Play build, a plain `flutter build apk`) shows no donation button.
rem Builds, then signs with the real key (trap #41) - never publish the raw
rem `flutter build apk` output.
cd /d "%~dp0rafeeq_app" || exit /b 1
call flutter build apk --release --dart-define=RAFEEQ_DONATION_URL=https://paypal.me/Tito320 || exit /b 1
cd /d "%~dp0" || exit /b 1
py -3 scripts\sign_release.py || exit /b 1
