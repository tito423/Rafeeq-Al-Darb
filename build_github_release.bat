@echo off
rem The GitHub release APK - the only build that carries the support link.
rem
rem «ده لينك الباي بال حطه بس في التطبيق اللي هيبقى على جيت هب» (2026-09-19).
rem AppConfig.supportUrl stays empty in the source, so any other build
rem (a Play build, a plain `flutter build apk`) shows no «ادعم التطبيق» button.
rem Builds, then signs with the real key (trap #41) - never publish the raw
rem `flutter build apk` output.
rem
rem EVERY architecture ships. «اهم حاجة ان التطبيق يشتغل مع اي نوع من
rem انواع الاندرويد فوق سبعة ويشتغل على اي نوع من معمارية من معمارية
rem التليفونات» (2026-09-20). An earlier build of 3.45.0 passed
rem --target-platform android-arm,android-arm64 to save 34 MiB; it
rem produced an APK that INSTALLED on an x86_64 device and then died on
rem launch, because the plugins still shipped x86_64 .so files while the
rem Flutter engine did not. Compatibility first: no --target-platform.
cd /d "%~dp0rafeeq_app" || exit /b 1
call flutter build apk --release --dart-define=RAFEEQ_SUPPORT_URL=https://paypal.me/Tito320 || exit /b 1
cd /d "%~dp0" || exit /b 1
py -3 scripts\sign_release.py || exit /b 1
