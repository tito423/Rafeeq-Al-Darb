# Compatibility — what has actually been run, and where

«اتاكد من خوار توافق التطبيق مع كل البراندات واحجام الشاشات واصدرات اندرويد من
اول ٧».

The app declares `minSdk 24` (Android 7.0) and `targetSdk 36`, and until
2026-09-16 it had only ever been run on **Android 16** — one device, one
version. This file records what has been run since, and is updated as more is.

**Nothing in this file is inferred.** A row says "passes" only if the screen
was looked at.

---

## Android versions

| Version | API | How | Result |
|---|---|---|---|
| **7.0 Nougat** | 24 | `api24` AVD (google_apis x86_64), signed release APK | **passes** — see below |
| 9 Pie | 28 | image downloading | not yet run |
| 12 | 31 | — | not yet run |
| 14 | 34 | — | not yet run |
| **16** | 36 | `Medium_Phone_API_36.1`, and the owner's Honor | passes (the daily driver) |

### Android 7.0 — 2026-09-16

The one that mattered most, because it is the floor and because the signing
lineage puts Android 7–8 on the **old key** (trap #41).

* `adb install -r` of the **signed release APK** → `Success`. That is the v1/v2
  debug-key path working, exactly as `legal/signing_decision.md` describes.
* Cold start: onboarding renders, the seven mushaf editions list from the
  bundled catalogue, Arabic and Latin scripts both set correctly.
* Home, Qur'an and Library tabs all open. The Library's authors list loads from
  its SQLite catalogue — no `no such module: fts5`, no SQLite exception from
  this app at all (the `mmsconfig` one in the log is the system's own).
* The tour, the reader-name sheet and the system permission dialogs all render
  and dismiss.
* `logcat` over the whole run: **no `E/flutter`, no `FATAL EXCEPTION`**.

Not exercised on 7.0 yet: playback, downloads, the adhan alarm, notifications.

## Screen sizes

Emulated with `wm size` / `wm density` on API 36 and the app restarted each
time.

| Width | Size / density | Result |
|---|---|---|
| **320 dp** | 480×854 @ 240 | **passes** — and this is the case the nav labels were changed for: all seven («الرئيسية القرآن الصلاة الأذكار المسبحة المكتبة المزيد») fit on one line each, none clipped |
| 376.6 dp | the owner's Honor, 1224×2700 @ 520 | passes |
| 393 dp | 1080×2400 @ 420 | passes |
| **800 dp** | 1600×2560 @ 320 (tablet) | renders, nothing clipped — but the layout is a stretched phone: lines of Arabic run the full 800 dp, which is a long measure to read. Worth a max-width, not a bug |

## Brands

**Not verifiable here, and this file will not pretend otherwise.** An emulator
runs AOSP; it cannot tell you what Xiaomi's MIUI does to a background service
or what Honor's power manager kills overnight. What can be said:

* **Honor** — the owner's own phone, used daily. The app's OEM-specific
  workaround (`perm_autostart_desc`) names Xiaomi, Honor, Huawei, Oppo, Vivo
  and OnePlus, and exists because those launchers hold their own background
  rules on top of Android's.
* **Xiaomi** — a device exists (`BYKRKJPRC6O7FMHU`) but has not had a build
  since 2026-09-15.
* Everything else is untested. The honest statement for a release note is
  «مُختبَر على Honor وعلى محاكيات أندرويد ٧ و١٦», not «متوافق مع كل الأجهزة».

## How to repeat this

The SDK manager cannot fetch anything on this machine — Avast's TLS
interception breaks its Java HTTPS (trap #13), and it fails with «Failed to
download any source lists». `curl` is unaffected, so the images are fetched by
hand:

```
curl -L -o x86_64-24_r27.zip \
  https://dl.google.com/android/repository/sys-img/google_apis/x86_64-24_r27.zip
```

unzipped into `%LOCALAPPDATA%\Android\Sdk\system-images\android-24\google_apis\`,
with a `package.xml` written beside it so `avdmanager` can see the package, and
then:

```
avdmanager create avd -n api24 -k "system-images;android-24;google_apis;x86_64" -d pixel
```

The file list lives in
`https://dl.google.com/android/repository/sys-img/google_apis/sys-img2-3.xml`.
