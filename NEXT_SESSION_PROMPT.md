# Rafiq Al-Darb — new session handoff

You are picking up work on **Rafiq Al-Darb** (رفيق الدرب / "Rafeeq Al-Darb"), a
personal, **sideloaded** Android Islamic app built in **Flutter**. It's the
owner's own app on his own GitHub repo — not a store app. Read this whole prompt
before touching anything.

---

## Hard rules (never violate)

1. **Zero mock/placeholder data.** Every feature uses real content or is not
   shipped. Never fabricate URLs, API responses, DB rows, or sample text. If a
   real source can't be found/verified, say so and stop — don't invent one.
2. **Never use or reference QuranFlash** (licensing). Mushaf content comes from
   the sources already wired (see below).
3. **No secrets in the repo.** R2 keys etc. live in `scripts/.env` (gitignored).
   Never commit or print credentials.
4. **Arabic is the default locale and RTL.** 6 locales: ar (default), en, es, ru,
   pt, fr. A test (`test/translation_parity_test.dart`) enforces identical key
   sets and no empty values across all 6 — add/remove a key in ALL six or the
   suite fails. Religious content (adhkar, adhan phrases, tasbeeh presets) stays
   in Arabic across locales by existing convention.
5. **Be honest in reports.** If something is unverified (e.g. needs the owner's
   real device), say exactly that. Don't claim done what you couldn't test.

---

## Workflow (follow every time)

1. Implement the change.
2. `flutter analyze` → must be **"No issues found"**.
3. `flutter test` → must be **21/21 passing**.
4. **Checkpoint** with the repo's script, from the repo root, ASCII-only message:
   ```
   cd "E:\My Projects\Rafiq-Al-Darb"; .\cp.bat "what you did (ASCII only)"
   ```
   (`cp.bat /s` shows status. Messages are long-form and descriptive by
   convention — explain the why, not just the what.)
5. **Live-verify on the emulator** (`emulator-5554` is usually running) before
   claiming a UI change works. Drive it with `adb` (`adb exec-out screencap -p`,
   `adb shell input tap X Y`). Screenshots are 1080x2400.
6. **Release** (the owner treats each version as a GitHub release — but confirm
   with him before publishing, it's a public/irreversible action):
   ```
   cd "E:\My Projects\Rafiq-Al-Darb"
   # (from rafeeq_app) flutter build apk --release   -> build/app/outputs/flutter-apk/app-release.apk (~235MB)
   cp app-release.apk RafeeqAlDarb-vX.Y.Z.apk
   gh release create vX.Y.Z <apk> --repo tito423/Rafeeq-Al-Darb --target master --title "..." --notes-file <notes>
   ```
   Latest release: **v2.1.16**. Release tags are `v2.1.x`; the pubspec `version:`
   (3.0.0+1) is independent — don't sync them, follow the `v2.1.x` tag series.

---

## Environment gotchas

- **Two shells**: PowerShell is primary (Windows 11), Bash tool also available
  (Git Bash / POSIX). The working dir toggles between `E:\My Projects\Rafiq-Al-Darb`
  (repo root — where `cp.bat`, `scripts/`, `gh` run) and its `rafeeq_app/`
  subfolder (where `flutter` runs). Watch which one you're in.
- **Python**: use **`py`** (Python 3.12 has boto3), NOT `python`/`python3`.
- **R2 hosting**: bucket `rafeeq-content`, creds in `scripts/.env`
  (`R2_ENDPOINT`/`R2_ACCESS_KEY_ID`/`R2_SECRET_ACCESS_KEY`), public base
  `https://pub-39dbef68a1a845d5ba669b43a59516b9.r2.dev`. `AppConfig.contentBaseUrl`
  points here. Upload scripts are in `scripts/r2_upload_*.py` (all use `.env` +
  boto3 + head_object verify).
- **Emulator limits**: it now decodes the splash video fine (API 36), BUT it does
  NOT honor `fullScreenIntent` over a foregrounded app and has no audible audio,
  so the lock-screen adhan launch + adhan audio/subtitle sync CANNOT be verified
  there — those need the owner's real device. Debug builds also throw a startup
  ANR on this emulator (tap "Wait"); release builds are fine. A concurrent heavy
  task (e.g. an R2 upload) on the same machine makes the ANR more likely.

---

## What was just shipped (this session → v2.1.16)

- **P3-52 Full-Screen Azan Player** (`adhan_full_screen_screen.dart`): live-overlay
  — silent looping video bg (or gradient fallback) + `just_audio` playing the
  adhan + karaoke subtitles synced off `positionStream` (`azan_subtitle.dart`
  distributes phrases across the recording's real duration). The `full`-mode
  notification is a SILENT `fullScreenIntent` trigger (channel `radh_full_silent`)
  so the screen owns the audio (no double-play); `audio` mode keeps native sound.
- **P3-53 Part 1** lock-screen: removed the "video only while screen on" note
  (+ `video_note` key from all 6 locales); programmatic `setShowWhenLocked`/
  `setTurnScreenOn` in `MainActivity.onCreate`; `WakelockPlus` scoped to the
  adhan player only.
- **P3-53 Part 2** downloads: `DownloadManager` is now a FIFO queue
  (`maxConcurrent = 1`, `_pump`), and ONE aggregated progress notification
  replaces the per-file flood.
- **P3-53 Part 3** perf: `_LiveClock` self-timing widget (adhan clock no longer
  repaints the whole stack), `RepaintBoundary` on the video, `cached_network_image`
  + capped `memCacheWidth` on the new mushaf image path.
- **P3-53 Part 5** luxury covers: `quran_book_cover_thumbnail.dart` — leather
  board + gold frame + medallion + ribbon + 3D shadow, per-edition colours;
  replaced the Fatiha-page thumbnail in the edition picker and downloads tile
  (deleted `mushaf_first_page_preview.dart`).
- **P3-53 Part 4** editions: the app already had 5 SVG riwāyāt (hafs/shubah/douri/
  qalon/warsh from `quranpedia/quran-svg`, pinned). Added a **raster (image-scan)
  edition path** and shipped the **Colored Tajweed mushaf** — all 604 Dar
  Al-Maarifa pages hosted on R2 at `mushaf/tajweed/NNN.jpg`, sourced from
  `github.com/Imomzoda8/tajweed-quran-images`, uploaded via
  `scripts/r2_upload_tajweed_pages.py`. See the raster-edition memory for the
  architecture (`MushafEdition.imagePath`/`isRaster`/`imagePageUrl`,
  `AppConfig.mushafImageUrl`, the `MushafPageView` raster branch,
  `prefetchEdition`'s `imagePath` branch, and `quran_screen` forcing image mode).

---

## Open items (do these next)

1. **Shamarly mushaf edition** — the owner wants it; NOT done because no free
   per-page image source was found (the `Mr-DDDAlKilanny/Shamarly` GitHub repo's
   `shamerly.zip` is a 2 MB stub, not 604 pages; Archive.org only has PDF/JP2
   book scans). The pipeline is ready: a black-gold cover slot + `الشمرلي`
   medallion override are already reserved in `quran_book_cover_thumbnail.dart`.
   **To finish once the owner provides page images (or a working per-page URL):**
   upload them to R2 at `mushaf/shamarly/NNN.jpg` (copy
   `scripts/r2_upload_tajweed_pages.py`), then add a `shamarly` entry to
   `rafeeq_app/assets/data/mushaf/editions.json` with `"image_path": "shamarly"`.
   That's it — the reader/download/cover all key off `image_path`.
2. **Owner real-device verification** (can't be done on the emulator):
   - Lock-screen adhan: fire a prayer Test in "Adhan + full screen" mode →
     screen should wake and show the player over the lock screen with audio +
     line-by-line synced subtitles; Mute/Dismiss work.
   - Download queue: start several downloads (e.g. the Tajweed edition's 604
     pages) → they run one-at-a-time with a single progress notification, no
     freeze.

---

## Key files (recent work)

- `rafeeq_app/lib/features/adhan/presentation/screens/adhan_full_screen_screen.dart`
- `rafeeq_app/lib/features/adhan/data/azan_subtitle.dart`
- `rafeeq_app/lib/core/services/adhan_alarm_service.dart` (silent `full` channel)
- `rafeeq_app/lib/core/services/download_manager.dart` (FIFO queue + aggregate notif)
- `rafeeq_app/android/app/src/main/kotlin/com/tito/rafeeq_aldarb/MainActivity.kt`
- `rafeeq_app/lib/features/quran/data/mushaf_edition.dart` (imagePath/isRaster)
- `rafeeq_app/lib/features/quran/presentation/widgets/mushaf_page_view.dart` (raster branch)
- `rafeeq_app/lib/features/quran/presentation/widgets/quran_book_cover_thumbnail.dart`
- `rafeeq_app/lib/core/services/mushaf_page_service.dart` (raster cache/prefetch)
- `rafeeq_app/lib/features/quran/presentation/screens/quran_screen.dart` (raster forces image mode)
- `rafeeq_app/assets/data/mushaf/editions.json`
- `scripts/r2_upload_tajweed_pages.py` (R2 upload template)
