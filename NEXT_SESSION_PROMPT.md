# Rafeeq Al-Darb (رفيق الدرب) — New-Session Prompt

You are continuing work on an existing, mature Flutter app for a single owner
(personal-use, sideloaded APK — no Play Store). Read this whole file before
touching anything. The project is at `E:\My Projects\Rafiq-Al-Darb`; the Flutter
app is in the `rafeeq_app/` subfolder. Current app version `3.0.0+1`, latest
GitHub release **v2.1.13** on `tito423/Rafeeq-Al-Darb`.

The app: an Arabic-first Islamic companion — Quran (text + image mushaf,
tafsir/translation/i'rab/word-meanings), prayer times + adhan, adhkar, tasbeeh,
hadith library + a large book library, khatma tracker, qibla compass. 6 UI
locales: ar (default/RTL), en, es, ru, pt, fr.

---

## HARD RULES — never violate these (the owner cares about them deeply)

1. **Zero mock / placeholder / invented data.** Every ayah, hadith, tafsir,
   book, prayer time, translation must be real and sourced. Never fabricate a
   translation, a hadith grade, a book attribution, or "verified" status. If you
   can't source something honestly, say so — don't invent it.
2. **Never scrape or use QuranFlash** (or its derivative 17-mushaf catalog /
   thumbnails). This has been purged before; do not reintroduce it. The app ships
   only its own legitimately-sourced 5 mushaf editions.
3. **Never claim something is "verified" / "works" unless you actually tested
   it.** Distinguish clearly between "code compiles / analyze passes" and
   "behaviour confirmed live." Be explicit about what you did NOT verify.
4. **Offline-first.** Content is bundled or downloaded on demand, then works
   with no network. Don't add features that silently require connectivity.
5. **No secrets in the repo.** R2 credentials live only in `scripts/.env`
   (gitignored). Never echo, commit, or paste them. If the owner pastes a secret
   in chat, store it to `.env` only and flag it.
6. **Translation-key parity across all 6 locales.** Any new `.tr()` key must
   exist in all of `assets/translations/{ar,en,es,ru,pt,fr}.json`. The test
   `test/translation_parity_test.dart` enforces identical key sets + no empty
   values — it MUST stay green.
7. **Religious content stays Arabic** (Quran text, adhkar, hadith, tasbeeh
   phrases) regardless of UI locale. For non-Arabic locales, ADD transliteration
   ("phonetics") alongside — do not translate/replace the Arabic itself.

## WORKFLOW DISCIPLINE (do this every time)

- Run `flutter analyze` after every change; keep it at **"No issues found."**
- Run `flutter test` — must stay **21/21 passing**.
- **Live-verify on the emulator** (`emulator-5554`) for any UI/behaviour change:
  build `--release`, install, drive it with adb + screenshots. The real device
  is the owner's (not available to you) — say so when a fix needs it.
- Checkpoint after meaningful work with `cp.bat "message"` (run from PowerShell,
  NOT git bash). **Commit messages must be ASCII-only** — embedding Arabic/RTL
  text breaks cmd.exe arg parsing. `cp.bat` appends the Co-Authored-By line.
- Ship a build the way it's always done: `flutter build apk --release`, then
  `gh release create vX.Y.Z <apk> --repo tito423/Rafeeq-Al-Darb --title ... --notes ...`.
  The APK is ~230 MB (too big for direct transfer — GitHub Releases is the
  delivery channel). Give the owner the release URL.
- Content hosting is Cloudflare R2 (`rafeeq-content` bucket, public r2.dev
  domain `https://pub-39dbef68a1a845d5ba669b43a59516b9.r2.dev`). Upload scripts
  live in `scripts/` (boto3, one script per batch, verify with head_object +
  live curl). Book text editions are **gzip-compressed on R2** (standing rule);
  the app detects gzip by magic bytes and decompresses.

## ENVIRONMENT NOTES / GOTCHAS

- Windows. Two shells: PowerShell (use for `cp.bat`) and Git Bash (use for adb,
  curl, python). In Git Bash, adb remote paths need `//sdcard/...` (double slash)
  to avoid MSYS path mangling; Python needs Windows-style paths (`C:/...` not
  `/c/...`).
- Native Python has no `ffmpeg` — install `imageio-ffmpeg` (pip) and use its
  bundled binary via `imageio_ffmpeg.get_ffmpeg_exe()`.
- The emulator's **video decoder is unreliable** — `video_player` shows the
  fallback instead of playing MP4s. Video playback must be confirmed on the real
  device, not the emulator.
- Console can't print Arabic (cp1256) — write Arabic output to a file and read
  it, don't `print()` it.
- adb taps: the display is 900x2000 but the real framebuffer is 1080x2400
  (×1.2). Prefer `uiautomator dump` + exact `bounds` over guessing tap coords.

## WHAT'S DONE RECENTLY (v2.1.5 → v2.1.13, "P3-44"…"P3-50")

- Library expanded to ~208 books across 6 classical authors (Ibn Abi al-Dunya,
  al-Hakim al-Tirmidhi, Ibn Taymiyyah, Ibn al-Qayyim, Ibn al-Jawzi, al-Nawawi),
  gzip on R2, categorized, catalog-wired.
- Round-8+ UI fixes: back-button→Home, light-theme header, location 3-tier
  fallback, RTL mushaf scrollbar, azkar/tasbeeh settings split, autostart-
  settings deep link, surah-header sukun (U+06E1→standard) display fix.
- **Notification crash fixed at root**: R8 was stripping Gson generics the
  flutter_local_notifications v18 needs — added ProGuard keep rules
  (`android/app/proguard-rules.pro`) + explicit `isMinifyEnabled`.
- **Download stall fixed**: `Dio()` had no timeouts → stalled connections hung
  forever. Added connect/receive/send timeouts in AyahAudioService,
  DownloadManager, MushafPageService.
- **Download foreground service** (`DownloadForegroundService.kt`, dataSync type)
  so downloads survive backgrounding; reference-counted via
  `DownloadForegroundServiceBridge`.
- **Persistent prayer card is now a real foreground service** (specialUse type,
  flutter_local_notifications `startForegroundService`) — non-dismissible,
  survives app close. Manifest declares the service + FOREGROUND_SERVICE_SPECIAL_USE.
- **Adhan full-screen routing fix**: a fullScreenIntent auto-launch doesn't set
  `didNotificationLaunchApp`, so `consumeColdLaunchPayload()` now falls back to
  the OS active-notifications query; AppShell retries on resume.
- **Ayah translation tab fixed**: the bundled `quran_sciences.db` had lost its
  `translations`/`translation_editions` tables in an earlier rebuild — recovered
  37,416 rows (6 langs) from git commit `51fb678`, merged in, bumped copy stamp
  to `sciences-v4`.
- **Mushaf running-header overlap fixed** (top margin reserved).
- **Tasbeeh reworked**: shows N/target, targets 33/100/1000/no-limit chips,
  1000-milestone celebration; vibrate-on-count removed; **Qibla background
  haptic bug fixed** (compass buzz was firing from the kept-alive Prayer tab —
  now gated on `activeTabProvider` + app-resumed).
- Hadith detail: removed "صحيح من الصحيحين" badge, hide English name in Arabic,
  fixed RTL next/prev arrows (was fighting Flutter's icon auto-mirroring).
- **10 adhan background videos** (copyright-free Pixabay, Content License) on R2.
- **Tasbeeh phonetics** (transliteration) for non-Arabic locales.
- Full-screen mushaf now truly immersive (hides system bars).
- **Splash**: owner's AI-generated intro video restored with the **Gemini
  watermark removed** (ffmpeg delogo); "first splash" lattice screen deleted
  (now just icon→video); **permission prompts moved to AFTER the splash**,
  location asked first.

## OPEN / NEEDS THE OWNER'S REAL DEVICE (can't verify on emulator)

- Confirm the AI **splash video actually plays** on device (emulator can't
  decode). Same for the 10 adhan background videos downloading/playing.
- Adhan **Stop/Mute** buttons, notification **persistence after swipe/kill**,
  and background reliability on aggressive OEM skins (owner's Honor) — need the
  battery-optimization exemption + autostart grants; verify on device.
- The native `ScheduledNotificationBootReceiver` crash class is guarded on the
  Dart side + ProGuard-fixed; confirm no boot crash on device.

## KNOWN-DEFERRED / LARGER WORK NOT YET DONE

- **Full translation/phonetics sweep**: transliteration is currently only on the
  Tasbeeh phrases. Extending "how to read the Arabic" to the whole Adhkar (Hisn
  al-Muslim) and Quran datasets is a large content-generation task — do it as a
  dedicated, careful pass (correct Latin + Cyrillic), not a rushed guess.
- **Dynamic runtime adhan video** (muezzin + chosen video + synced adhan text,
  full-screen on lock screen) — the full-screen adhan already plays a video with
  karaoke-style synced text; making it fully per-choice dynamic is the larger
  remaining part.
- **Ibn Qudamah / Najm al-Din identity mismatch** flagged in PHASE3.md — needs
  the owner's decision before mining that author's works.

## SOURCE-OF-TRUTH FILES

- `PHASE3.md` — the running detailed log of every round (read the tail for the
  latest state and rationale).
- `HANDOVER.md` — hosting, data pipeline, and historical findings.
- `scripts/` — all data/build/upload pipelines (fetch_authors_batch,
  build_book_text, build_sciences_db, ingest_translations, r2_upload_*, etc.).
- `test/translation_parity_test.dart` — the guard that must stay green.

## HOW TO START

Ask the owner what to work on, or pick from the OPEN list. Do NOT assume prior
approval for anything destructive, for pushing, or for spending on a new build —
follow the owner's lead. When they send device screenshots, treat those as the
real bug reports and root-cause them (read the actual code/DB, don't guess), fix,
build, release, and be honest about what you verified vs. what needs their device.
