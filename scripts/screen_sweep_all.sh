#!/bin/bash
# Stage C sweep, one screen class per fresh emulator boot: back-to-back
# `wm size` changes made System UI stop responding (29 of 70 shots covered
# by «System UI isn't responding», and the tablet class stuck on the splash)
# on 2026-09-27; on a freshly booted emulator the same class drew at once.
A="/e/DevEnv/Android/Sdk/platform-tools/adb.exe -s emulator-5554"
OUT="$1"; mkdir -p "$OUT"
boot() {
  $A emu kill >/dev/null 2>&1; sleep 6
  powershell -NoProfile -Command "Get-ChildItem E:\DevEnv\avd -Recurse -Filter *.lock -EA 0 | % { try { Remove-Item \$_.FullName -Force -Recurse -EA Stop } catch {} }; \$env:ANDROID_SDK_ROOT='E:\DevEnv\Android\Sdk'; \$env:ANDROID_AVD_HOME='E:\DevEnv\avd'; Start-Process E:\DevEnv\Android\Sdk\emulator\emulator.exe -ArgumentList '-avd','Medium_Phone_API_36.1','-no-audio','-no-snapshot'"
  for i in $(seq 1 90); do $A shell getprop sys.boot_completed 2>/dev/null | grep -q 1 && break; sleep 5; done
  sleep 10
}
for c in phone xiaomi tablet smart tv; do
  boot
  SWEEP_ONLY=$c PYTHONIOENCODING=utf-8 py -3 "$(dirname "$0")/screen_sweep.py" "$OUT"
done
