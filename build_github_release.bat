@echo off
rem The GitHub release APK - the only build that carries the support link.
rem
rem «ده لينك الباي بال حطه بس في التطبيق اللي هيبقى على جيت هب» (2026-09-19).
rem AppConfig.supportUrl stays empty in the source, so any other build
rem (a Play build, a plain `flutter build apk`) shows no «ادعم التطبيق» button.
rem Builds, then signs with the real key (trap #41) - never publish the raw
rem `flutter build apk` output.
rem
rem --target-platform drops x86_64. Measured on 2026-09-20: the three-ABI
rem APK is 305,608,798 B and this one is 269,711,318 B, so the ABI no real
rem phone has was costing 34.2 MiB of every install. Debug builds are left
rem alone, because emulator-5554 is an x86_64 image and that is where this
rem project verifies everything. arm64-only would be 238,171,972 B; that
rem drops 32-bit phones, so it is the owner's call, not a default.
cd /d "%~dp0rafeeq_app" || exit /b 1
call flutter build apk --release --target-platform android-arm,android-arm64 --dart-define=RAFEEQ_SUPPORT_URL=https://paypal.me/Tito320 || exit /b 1
cd /d "%~dp0" || exit /b 1
py -3 scripts\sign_release.py || exit /b 1
