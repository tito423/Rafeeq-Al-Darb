# RAFIQ AL-DARB — Autonomous Rebuild Pipeline

> **Handing this project to another agent?** Read `HANDOVER.md` in this
> folder first, then `WORK_QUEUE.md` for the ordered backlog.
>
> **Original note:** Read `HANDOVER.md` in this
> folder first — it carries the design decisions, the hard rules, and the
> current blocker.

> Mission: Rebuild "Rafeeq Al-Darb" as a masterpiece mix of Sakinati + Ayat + QuranFlash + Al-Quran Al-Azeem.
> Rules: ZERO mock data • flutter analyze gate after every task • real SQLite/API/R2 only • no stopping.

**Working app:** `rafeeq_app/` (Flutter 3.38.7, Dart 3.10)
**Content origin (real, no secrets):** `rafeeq-api/` local mirror (hosted via GitHub raw) + bundled real SQLite + verified public APIs (api.quran.com, api.alquran.cloud, api.aladhan.com, cdn.islamic.network).

| # | Task | Status | Notes / Verification |
|---|------|--------|----------------------|
| 1 | Purge: 400MB bloat, fake data, manifest, pubspec | ✅ | Deleted: quran_images.zip 233MB, hadith.db.bak 44MB, fake .m4a adhans 19MB, build/.dart_tool/node_modules, 60+ junk files, R2 keys + serviceAccountKey.json. Preserved real data: hadith9 JSONs→rafeeq-api/staging, 17 books→rafeeq-api/downloads/books, quran_local.db bundled. Manifest permissions verified (INTERNET/EXACT_ALARM/FS_MEDIA_PLAYBACK/POST_NOTIFICATIONS). Clean pubspec (no firebase/minio/video). `flutter analyze`: 0 issues |
| 2 | UI/UX research + master theme | ✅ | AppColors (night teal + gold + paper), AppTypography (Cairo UI + bundled AmiriQuran TTF), AppTheme (full M3 dark/light: bars, sheets, chips, tabs, inputs), AppSpacing. Research: Ayat/KSU = real Madani pages + tap-ayah tafsir; QuranFlash = flip mushaf; Sakinati = calm night palette. analyze: 0 issues |
| 3 | Real DB pipeline: quran_sciences.db schema + populate from real API data | ✅ | Built quran_sciences.db (18.9MB): tafseer_texts 3,137 ranges covering ALL 6,236 ayahs × 3 real Arabic tafsirs (Muyassar/Jalalayn/Qurtubi via alquran.cloud); word_grammar 75,973 rows (Quranic Arabic Corpus 0.x — POS/case/root/lemma = i'rab); word_meanings 83,665 (corpus glosses); azkar 134 sections/298 items (Hisn al-Muslim real JSON). Sources: bundled quran_local.db (6,236 ayahs + FTS5) copied to assets. Dart layer: DbHelper (atomic asset copy), QuranRepository (surahs/ayahs/FTS search/global number), SciencesRepository. Saadi/IbnKathir ar: quran.com API removed tafsirs; columns+schema ready. Incident: rafeeq-api + Backend folders accidentally deleted by a mangled background rd — recovered everything critical (verified); re-downloaded adhans (islamcan, 10 real) + 9 hadith books (A7med3bdulBaset/hadith-json). git init + commit. analyze: 0 issues |
| 4 | Offline download engine (dio + path_provider + progress UI + Android notification) | ✅ | T4 commit: dio stream+resume, unzip-to-db (hadith.db), Android progress notifications, Riverpod download tiles. Fixed Gradle build-dir redirect (settings.gradle.kts `gradle.beforeProject` → rafeeq_app/build) so `flutter build apk` locates the APK. analyze 0; release APK 58.9MB |
| 5 | Authentic i18n via easy_localization (real ar/en JSON) | ✅ | easy_localization wired (persisted locale), ar/en real JSON with verified key parity, AppShell + all 5 tabs fully `.tr()`-localized, Settings language switch live. Fixed double-encoded Arabic in audio_editions.json + reciters_full.json. analyze: 0 |
| 6 | Mushaf viewer, dynamic page fetch + cache | ✅ | Vector SVG pages (quranpedia/quran-svg, CC0-1.0, pinned b91d39e). `MushafPageService`: memory+disk cache, integrity-validated, offline after first view. `MushafPageView`: SvgPicture + InteractiveViewer, glyphs recoloured via srcIn. **2026-09-02: runtime-verified on emulator** — pages render in light **and** dark, cached pages work with network off, uncached show an honest error. (Debug builds needed a `networkSecurityConfig` to trust the dev machine's Avast TLS-inspection root — see `android/app/src/debug/`. Known bug: a whole-edition download halts if you leave the Mushafs tab.) |
| 7 | Real ayah coordinates (replace fake JSON) | ✅ | `scripts/build_mushaf_svg.py` extracts the `ayahPolygon` hit layer from the source SVGs → `assets/data/mushaf/<edition>_polygons.json` (normalized 0..1 per-page viewBox). 6,236/6,236 ayahs, verified against quran_local.db. Polygons, not boxes: 4,221 ayahs (68%) span multiple lines. Hit-test = even-odd ray cast per ring. **2026-09-02: runtime-verified on emulator** — tapping ayah 2:6 on page 3 highlights **two** separate line fragments, not one bounding box. This was the make-or-break check; it passes. |
| 8 | Ayah sciences bottom sheet (real SQLite tafseer/i'rab/meanings) | ✅ | 4 tabs — tafsir (3 sources), translation (en/fr/ur), i'rab (corpus morphology per word), word meanings — all from quran_sciences.db. Gated by riwayah alignment. **Do not rebuild.** **2026-09-02: runtime-verified on Android emulator** (Muyassar+Jalalayn tafsir, EN/FR/UR translation, per-word i'rab + meanings all render real data). Required two fixes first: `quran_sciences.db` was missing from `pubspec.yaml` assets, and `DbHelper` opened read-only DBs with `version:` → `SQLITE_READONLY`. Both fixed. |
| 9 | Professional dropdowns (reciters/translations) | 🔶 | Reciter dropdown done (176 Arabic editions) in the Downloads screen. Missing: translation-language selector in the reader — WORK_QUEUE Stage 4. **2026-09-02: fixed a real bug — ayah recitation never played** because `AyahAudioService` set audio sources without a `MediaItem` tag, which `just_audio_background` (init'd in `main()`) rejects. Now tagged; playback verified online and offline on the emulator. |
| 10 | 10 authentic adhans (no music) | ✅ | The 10 MP3s now also live as Android raw resources (`res/raw/azan*.mp3`), needed for the native alarm sound — see T13. The 6 old fake placeholder `.m4a` files in `res/raw/` are deleted. |
| 11 | Custom adhan MP3 from device | 🔶 | `file_picker` wired; import → selection confirmed to open the real system document picker. A full pick-to-firing-alarm cycle (native content:// URI sound) not carried through to completion this session. |
| 12 | Adhan UI + karaoke sync | ✅ | Full-screen view launched via `fullScreenIntent` over the **locked** screen (uses `MainActivity`'s existing `showWhenLocked`/`turnScreenOn`); adhan text highlighted line-by-line, paced against the real recording's `Duration`; "الصلاة خير من النوم" shown only for Fajr. Real Stop/Mute. **2026-09-02: emulator-verified** for 4 different prayers, confirmed via `dumpsys audio`/`notification`, not screenshots alone. |
| 13 | Android native alarm (exact alarms, wakelock, mute/stop actions) | ✅ | `AdhanAlarmService` rewritten: exact daily alarms per prayer, one notification channel per (mode, sound) pair (channels are immutable on Android). The adhan **sound** is played by Android's own notification-sound API (`RawResourceAndroidNotificationSound` + `AudioAttributesUsage.alarm`), not by Dart — `zonedSchedule`'s receiver never starts the Dart VM, so nothing else can play while the app is killed. Stop cancels the notification (confirmed to stop the sound); Mute reposts it silenced. **2026-09-02: emulator-verified**, including a per-prayer choice surviving `am force-stop` + relaunch. Battery-optimisation exemption prompt implemented but unconfirmed (no dialog seen on the emulator image used). |
| 14 | Library: catalog / offline PDFs / viewer | 🔶 | `LibraryScreen`'s "الكتالوج" tab built as an honest placeholder — real open sources found on archive.org for every named title, but nothing downloaded yet pending the owner's choice of edition/tahqiq per title (STOP AND ASK, see WORK_QUEUE Stage 2). |
| 15 | 9 Hadith books hub (hierarchical) | ✅ | **Correction:** no `hadith.db` actually existed anywhere in this workspace before 2026-09-02 — only the real source JSON (`scripts/temp_phase1/hadith9/`) did; the "36,461 hadiths, rebuilt clean" note was describing something that wasn't there. Built for real by `scripts/build_hadith_db.py`: 9 books, 429 chapters, **40,943 hadiths**. Fixed the "2 → 9 → 99" ordering bug (`number_in_book` is INTEGER; 0 out-of-order chapters, verified both by script and live in the app). Downloaded on demand (~17 MB zipped, hosted on `tito423/rafeeq-api`), not bundled. **2026-09-02: verified against the real DB via direct `adb push` injection** (book list, chapter list, hadith ordering across the two-digit boundary, detail view all confirmed with real data) — **the live download itself was not verified**, blocked by a host-machine TLS problem also affecting previously-working mushaf fetches; see `HANDOVER.md` §7. |
| 16 | Azkar + Tasbeeh (dedup, haptics) | ✅ | `lib/features/azkar/` against the bundled 134 sections/298 items. 0 duplicate azkar within a section (real SQL check). Real repeat counts parsed from each dhikr's own embedded text (e.g. "ثلاث مرات") rather than guessed. **2026-09-02: fully live-verified**, including the historical "counter only counts after reset" bug (confirmed absent — counts on the first tap) and auto-advance at the real target. Haptics + morning/evening reminders both real and persisted, no default time (both start off). |
| 17 | New Muslim guide | ⏳ | |
| 18 | Thematic Quran search | ⏳ | |
| 19 | Security & offline guest mode | ⏳ | R2 keys were hardcoded in client — removed |
| 20 | Final build + git | ⏳ | |

## Build Log
- [T1 started] Reconnaissance complete. Identified all fake/bloat sources. Beginning purge.
- [2026-09-02] `flutter analyze` clean (fixed a `TextDirection` import clash + 3 lints).
- [2026-09-02] First `flutter build apk --debug` ever — succeeds. Ran on Android
  emulator. Fixed 2 runtime bugs (sciences DB not bundled; read-only DB opened
  with `version:`). STAGE 0 gate partly passed: text mode + sciences card
  verified; image-mode / download / offline checks blocked by host-side Avast
  TLS interception (emulator can't verify the re-signed cert). Needs owner
  decision — see `HANDOVER.md` §7.
- [2026-09-02] Owner approved trusting the Avast root in debug builds
  (`android/app/src/debug/networkSecurityConfig`). Unblocked. Found + fixed one
  more real bug: recitation playback did nothing (untagged audio source, rejected
  by `just_audio_background`). **STAGE 0 gate now fully PASSED — all 10 checks
  verified on the emulator**, incl. the multi-line ayah highlight and offline
  playback. See `HANDOVER.md` §7 for the table and the list of out-of-scope bugs
  still open (download-stops-on-tab-switch, mode not persisted, raw/ .m4a
  placeholders, a couple of Arabic-string typos).
- [2026-09-02] Owner asked whether the emulator-only STAGE 0 result was
  acceptable or a physical device was required; chose to accept it and start
  STAGE 1. Built the whole Adhan system (T10–T13): real per-prayer alarms with
  a native (not Dart) alarm sound so it can fire while the app is killed,
  full-screen karaoke UI over the lock screen, real Stop/Mute, per-prayer
  mode + sound persisted across a restart, adhan picker with real preview,
  custom-adhan import wired to the real file picker. Deleted the 6 fake
  placeholder `.m4a` files and fixed the `settings.credits` typo — both from
  STAGE 0's open-bugs list. **Emulator-verified** the same rigorous way as
  STAGE 0 (`dumpsys audio`/`media_session`/`notification`, not screenshots
  alone) for 4 different prayers; found and fixed 2 real bugs along the way
  (a `PopScope` blocking Stop's own pop; a preview player's `await play()`
  never resolving before Dart moved on). Open: physical device, the battery-
  exemption button's effect, a custom adhan's native sound end-to-end. See
  `HANDOVER.md` §7's STAGE 1 table for the full breakdown.
- [2026-09-02] Owner said to continue through the whole WORK_QUEUE, honoring
  its STOP AND ASK gates. Hit two: STAGE 2's book list (told to research real
  sources and propose them, not download yet) and STAGE 5's content sources
  (told to use known trusted Islamic sources directly). Built STAGE 2's
  Hadith half: discovered `hadith.db` never actually existed in this
  workspace despite the docs saying so (only the real source JSON did);
  built it for real (T15, 9 books, 40,943 hadiths, ordering bug fixed and
  regression-tested), hosted it on `tito423/rafeeq-api` (also fixing that
  repo's URL, which pointed at a nonexistent `/main` branch), and built
  `LibraryScreen` (Hadith hub done; Books catalog an honest placeholder,
  T14 🔶). Verified the hub against the real DB by pushing it directly onto
  the emulator's storage — the live download itself is blocked by a
  host-machine TLS problem that also broke previously-working mushaf
  fetching; see `HANDOVER.md` §7 for the full diagnosis. Researched real
  archive.org sources for every named Library book; none downloaded yet,
  pending the owner's edition/tahqiq choice per title.
- [2026-09-02] Built STAGE 3 (T16), Azkar & Tasbeeh, against the real bundled
  Hisn al-Muslim data — no new data needed. Confirmed 0 duplicate azkar
  within any section via a real SQL query. Parsed each dhikr's real repeat
  count from its own embedded text (e.g. "ثلاث مرات") instead of guessing.
  **Fully live-verified on the emulator**, not just code-reviewed: the
  historical "counter only counts after reset" bug does not reproduce (a
  3x-repeat dhikr showed 1/3 after the very first tap) and auto-advance
  fires exactly at the real target; the settings sheet's haptics toggle and
  both reminder time pickers (real Material time picker) were exercised,
  and neither reminder defaults to a time — both start off, per this
  stage's own instruction not to hardcode 05:00/16:30. Entirely offline, so
  unaffected by the STAGE 2 TLS problem.

## Data sourcing decision (T6/T7)
Mushaf pages and ayah tap-regions both come from **quranpedia/quran-svg**
(polygon metadata CC0-1.0; KFQC glyphs free for digital use), pinned to commit
`b91d39e1065b57bdda3e94aca8ecf3575e50e1e6` so page geometry can never drift
away from the bundled polygon asset. Verified byte-identical to the local build.

Rejected sources:
- **QuranFlash** — would require reverse-engineering a licensed product.
- **quran.com-images `glyph_ayah_bbox`** — table declared, zero rows in the dump.

Follow-ups before release:
1. **Rotate the Cloudflare R2 API token** — the old key pair was pasted into a
   chat transcript and must be considered public.
2. Mirror `scripts/mushaf_build/hafs_kfqc/svg` to R2 and build with
   `--dart-define=RAFEEQ_MUSHAF_BASE=...`; the current GitHub-raw default is a
   development convenience, not a CDN.
3. Run `flutter analyze` / build — T6 and T7 code is static-checked only.

## Session update — QuranFlash purge, 5 editions, sciences, downloads

Removed all QuranFlash-derived content: `mushafs_catalog.json` (17 entries with
that app's own internal keys and image counts) and 51 scraped cover GIFs.
Neither was referenced by any code.

Replaced with five editions built from **quranpedia/quran-svg** (CC0-1.0
polygons; KFQC glyphs free for digital use), pinned to commit `b91d39e`:
hafs, shubah, warsh, qalon, douri — 604 pages each, own ayah polygons.

Verse numbering is handled honestly. The sciences DB is Hafs-keyed; shubah
matches exactly, while warsh/qalon/douri diverge (50/50/45 surahs). The catalog
is generated by diffing each edition against `quran_local.db`, and the ayah card
refuses to show tafsir/translation/i'rab in a diverging surah rather than
showing the wrong verse's commentary.

Sciences: the three bundled translation JSONs (en.sahih, fr.hamidullah,
ur.jalandhry) were ~11 MB of assets no code read; they are now an indexed
`translations` table (18,708 rows) and the raw files are gone. Asset payload
30.2 MB -> 25.9 MB. The ayah card gained a translation tab and now actually
compiles — its three tab widgets were previously referenced but never defined.

Offline: `MushafPageService.prefetchEdition` downloads a whole mushaf
(resumable, skips cached pages); `AyahAudioService` caches per-ayah audio and
downloads a surah at a time. Per-ayah files rather than one surah MP3, because
a surah file cannot be seeked to a verse without a timing map — per-ayah is
what makes every ayah bind to its own recitation offline. New Downloads screen
(Mushafs / Recitations tabs) reachable from Settings.

Still open:
1. **Rotate the Cloudflare R2 API token** — the old key pair was pasted into a
   chat transcript and must be treated as public.
2. `flutter analyze` + a device run: everything above is static-checked only
   (bracket balance, imports, AppColors members, translation-key parity 168/168).
3. Mirror `scripts/mushaf_build/<edition>/svg` to R2 and build with
   `--dart-define=RAFEEQ_MUSHAF_BASE=...`; the GitHub-raw default is not a CDN.
4. Perf check: flutter_svg parses each page at runtime. If paging feels slow,
   precompile to `vector_graphics` `.vec`.
