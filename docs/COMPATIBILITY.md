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

Run by `scripts/compat_matrix.py` against the **signed release APK**, four
widths each — twelve cells, 84 screenshots, all of them written to
`scripts/compat_out/`.

| Version | API | 320 dp | 360 dp | 411 dp | 800 dp |
|---|---|---|---|---|---|
| **7.0 Nougat** | 24 | pass | pass | pass | pass |
| **9 Pie** | 28 | pass | pass | pass | pass |
| **12** | 31 | pass | pass | pass | pass |
| **14** | 34 | pass | pass | pass | pass |
| **16** | 36 | pass | pass | pass | pass |

Twenty cells, five Android versions, 140 screenshots.

«pass» here means: the signed APK installed, the process was still alive 25 s
after launch, `logcat` had no `FATAL EXCEPTION` and no `E/flutter`, and all
seven tabs opened onto a drawn screen. All five images were fetched by hand (the SDK
manager cannot reach Google from this machine — see the end of this file).

### Android 7.0 — 2026-09-16, in detail

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
| 360 dp | 720×1280 @ 320 | passes |
| 376.6 dp | the owner's Honor, 1224×2700 @ 520 | passes |
| 411 dp | 1080×2400 @ 420 | passes |
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

## The harness

`scripts/compat_matrix.py` is the answer to «اخترع طريقة تختبره بيها». Point it
at an APK and it boots each AVD in turn, installs, grants the runtime
permissions, and at each screen width launches the app, waits, sweeps all seven
tabs, screenshots every one and reads `logcat`:

```
py -3 scripts/compat_matrix.py rafeeq_app/build/app/outputs/flutter-apk/app-release.apk
py -3 scripts/compat_matrix.py <apk> --avd api24 --size 320
```

It writes `scripts/compat_out/report.txt` plus a folder of screenshots per
combination, and exits non-zero if any cell failed.

**It caught itself twice, which is the point.** The first run tapped at 96.5 %
of the screen height and hit Android 7's on-screen navigation bar — every tap
opened RECENTS and two cells were reported "blank" because the screenshot was
the recents screen. The second run still had the runtime permission dialogs up,
so every tap landed on «ALLOW» and the sweep photographed the same home screen
seven times **while reporting a pass**. Both are now handled: the bar's real
position is computed from the density, the permissions are granted with
`pm grant` before the sweep, and a sweep whose screenshots are all identical is
failed as «tabs never changed».

A third self-catch, and the most instructive: the first full matrix reported
three cells «blank» — home and Qur'an at 320 dp, Qur'an at 800 dp. All three
were **false alarms**. The detector sampled nine points and called a screen
blank when they agreed, and at 320 dp those nine landed on white card while
the home screen was drawing perfectly; a page of the Qur'an is mostly one
colour by nature. A check that cries wolf three times in twelve is worse than
no check, so it shrinks the screenshot to a 16×28 grid now, drops the system
bars, and needs 97 % of one colour. Re-run over all 84 saved screenshots:
**none blank**.

And a fourth, on the Android 12 run: a `FATAL EXCEPTION` at 320 dp that the
matrix attributed to the app. It was **not ours** — pid 730, a system process,
and it never reproduced on a clean boot; Android 12's own SystemUI falls over
when `wm size` changes under it. The check reads the six lines under the
exception now and counts it only when they name `com.tito.rafeeq_aldarb`,
because a matrix that cries crash is a matrix nobody reads.

The same run also taught it to **get past onboarding**: a freshly imaged
emulator opens on «اختر مصحفك», which has no bottom bar at all, so the sweep
was tapping empty space and photographing the same screen seven times. Three
of those four cells slipped through because a ticking clock made the
screenshots differ by a pixel — the comparison uses the top 60 % of the screen
now.

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
