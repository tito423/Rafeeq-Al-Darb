# Rafiq Al-Darb — colleague handoff prompt (copy/paste into a new session)

You are picking up work on **Rafiq Al-Darb** (رفيق الدرب / "Rafeeq Al-Darb"), a personal, **sideloaded** Android Islamic app built in **Flutter**. It's the owner's own app on his own GitHub repo (`tito423/Rafeeq-Al-Darb`), owner **Tito** — not a store app. Read this whole prompt before touching anything. A fuller copy also lives in `NEXT_SESSION_PROMPT.md` at the repo root.

## Hard rules (never violate)
1. **Zero mock/placeholder data.** Every feature uses real, verified content or is not shipped. Never fabricate URLs, API responses, DB rows, or sample text. If a real source can't be found/verified, say so and stop.
2. **Never use or reference QuranFlash** (licensing).
3. **No secrets in the repo.** R2 keys live in `scripts/.env` (gitignored). Never commit or print credentials.
4. **Arabic is default + RTL.** 6 locales (ar/en/es/ru/pt/fr); `test/translation_parity_test.dart` enforces identical key sets + no empty values — change a key in ALL six. Religious content stays Arabic across locales.
5. **Be honest.** If something is unverified (needs the owner's real device), say exactly that.

## Workflow (every time)
implement → `flutter analyze` (must be "No issues found") → `flutter test` (must be 21/21) → checkpoint from repo root with `cd "E:\My Projects\Rafiq-Al-Darb"; .\cp.bat "ASCII-only descriptive message"` → live-verify on `emulator-5554` via adb (screencap / input tap; screens are 1080x2400) → release **only after confirming with the owner** (public/irreversible): `flutter build apk --release` then `gh release create vX.Y.Z <apk> --repo tito423/Rafeeq-Al-Darb --target master`. Latest is **v2.1.16**; release tags follow `v2.1.x` (independent of pubspec `version:`).

## Environment gotchas
PowerShell primary + Bash tool available; working dir toggles between repo root (`cp.bat`, `scripts/`, `gh`) and `rafeeq_app/` (`flutter`). Use **`py`** not `python` (boto3 is in Python 3.12). R2: bucket `rafeeq-content`, creds in `scripts/.env`, public base `https://pub-39dbef68a1a845d5ba669b43a59516b9.r2.dev` (= `AppConfig.contentBaseUrl`); upload templates in `scripts/r2_upload_*.py`. **Emulator limits:** decodes video fine now, but does NOT honor `fullScreenIntent` over a foregrounded app and has no audible audio → the lock-screen adhan launch + adhan audio/subtitle sync need the owner's real device. Debug builds throw a startup ANR on this emulator (tap "Wait"); release builds are fine.

## Just shipped (this session → v2.1.16)
The P3-52 Full-Screen Azan Player (silent looping video + just_audio + karaoke subtitles synced off positionStream; silent `fullScreenIntent` `full`-mode notification so the screen owns audio); P3-53 Part 1 (removed the Android-limitation note, programmatic showWhenLocked/turnScreenOn in `MainActivity.onCreate`, WakelockPlus scoped to the adhan player); Part 2 (`DownloadManager` is now a FIFO queue, maxConcurrent=1, with ONE aggregated progress notification instead of a per-file flood); Part 3 (self-timing `_LiveClock`, RepaintBoundary on the video, cached_network_image + capped memCacheWidth); Part 5 (`QuranBookCoverThumbnail` luxury leather covers replacing Fatiha-page thumbnails); Part 4 (new **Colored Tajweed** raster edition — 604 pages on R2 at `mushaf/tajweed/NNN.jpg`, via a new `MushafEdition.imagePath`/`isRaster` raster reader path).

## Open items — do these next
1. **Shamarly mushaf edition** (owner wants it; blocked on a real source — no free per-page image set found). The pipeline is ready: a black-gold cover slot + `الشمرلي` medallion override are reserved in `quran_book_cover_thumbnail.dart`. When the owner supplies the 604 page images (or a working per-page URL): upload to R2 at `mushaf/shamarly/NNN.jpg` (copy `scripts/r2_upload_tajweed_pages.py`), then add a `shamarly` entry with `"image_path": "shamarly"` to `rafeeq_app/assets/data/mushaf/editions.json`. Everything else (reader, download, cover) keys off `image_path`.
2. **Owner real-device verification** (impossible on emulator): (a) lock-screen adhan — fire a prayer Test in "Adhan + full screen" mode; screen should wake over the lock screen with audio + line-by-line synced subtitles; Mute/Dismiss work. (b) download queue — start several downloads (e.g. the Tajweed edition); they run one-at-a-time with a single progress notification, no freeze.

Start by asking the owner whether he has the Shamarly page images, and for his real-device results on the two verification items above.
