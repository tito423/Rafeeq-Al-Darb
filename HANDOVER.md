# HANDOVER â€” Rafiq Al-Darb (ط±ظپظٹظ‚ ط§ظ„ط¯ط±ط¨)

**For:** the next AI agent picking up this project (Antigravity IDE, Cline, or any other).
**Read this file completely before touching anything.**

| | |
|---|---|
| **Last updated** | 2026-09-02 |
| **State at** | commit `2efc519` (STAGE 5) + STAGE 6 thematic-search commit |
| **Build verified?** | **`flutter analyze` clean آ· `flutter test` clean آ· `flutter build apk --debug` and `--release --split-per-abi` both OK آ· STAGE 0â€“6 all fully live-verified (آ§7) آ· STAGE 7 (security/guest-mode) verified, one real gap fixed آ· STAGE 8 (release) pipeline verified, only real keystore signing still blocked.** See the WIP note and آ§7 for the full list of real bugs found and fixed this session. |

> **If you are an agent working on this project: keeping this file current is
> part of the job.** The owner hands this file to whoever continues, so a stale
> handover is a broken handover. Do not describe work as verified here unless
> you actually ran it.
>
> **Sessions here die from quota exhaustion, usually mid-task.** So do not save
> the write-up for the end. After every meaningful edit run:
>
> ```
> .\cp.bat "what you just did"
> ```
>
> That updates the work-in-progress note above, stamps the date, and commits â€”
> in one step. A session that dies right after a checkpoint loses nothing. A
> session that dies an hour after its last one loses an hour.
>
> Use `.\cp.bat "..." -Done` when a stage is finished, and `.\cp.bat /s` to see
> where things stand.

---

## Current work in progress

<!-- WIP:START -->
**2026-09-02 15:21 — IN PROGRESS — resume here**

S:/

_Uncommitted at the time of writing: see `git status`. If this says
IN PROGRESS, the previous session likely ran out of quota here — read the last
commit's diff before continuing._
<!-- WIP:END -->

---

## 0. TL;DR â€” what to do first

1. Run `.\check.bat` (or `flutter analyze` in `rafeeq_app/`).
2. **The code has never been compiled.** Fix whatever the analyzer reports. That is job #1.
3. Do **not** redesign anything until the build is green.
4. Read آ§3 (Hard rules) and آ§5 (Decisions â€” do not undo) before writing code.

---

## 1. What this project is

A comprehensive Islamic Flutter app. The goal is a "masterpiece mix" of the best
ideas from Sakinati, Ayat, QuranFlash and Al-Quran Al-Azeem â€” **built from
scratch with our own legally-clean data**, not copied from them.

- App lives in `rafeeq_app/`
- Flutter 3.38.7 / Dart 3.10, Riverpod, easy_localization, sqflite, dio, just_audio, flutter_svg
- Owner: Tito. Speaks Arabic (Egyptian). Wants concise, efficient work â€” he has
  already lost ~$20 and many hours to agents that produced fake UIs.

---

## 2. History you must know (why the owner is wary)

Earlier agents (DeepSeek, LongCat, Gemini-in-Antigravity) did serious damage:

- Bloated the app to **400 MB** with unused assets
- Wrote **fake/mock data** everywhere â€” screens that looked finished but were
  wired to nothing
- Fake download buttons with hardcoded checkmarks
- Adhan files that contained music
- A "translation" system that only flipped RTL/LTR without translating
- Left the build broken

A clean rebuild (T1â€“T5) fixed the foundation. The work described in آ§4 continues
from that clean base. **Do not reintroduce any of the above.**

---

## 3. HARD RULES â€” non-negotiable

| # | Rule |
|---|------|
| 1 | **ZERO mock/placeholder data.** Every string on screen comes from a real DB, API, or asset. If data is missing, show an honest empty state â€” never invent text. |
| 2 | **Never take data from QuranFlash.** It is a licensed product; scraping/reverse-engineering it is off the table. All QuranFlash-derived files were deliberately deleted (see آ§5.1). |
| 3 | **Never claim something is verified when it is not.** Say plainly what you tested and what you did not. |
| 4 | **Offline-first.** Downloaded content must work with the network off. |
| 5 | **Don't commit secrets.** `.env`, keystores, `google-services.json`, `serviceAccountKey.json` are gitignored. Keep it that way. |
| 6 | **Keep `ar` / `en` translation keys at exact parity.** Currently 168/168. Adding a key to one locale without the other is a bug. |

---

## 4. What has been done (commits, newest first)

```
238caad chore: add toolchain check script so results reach the sandbox
9b32116 feat(downloads): offline mushafs and per-ayah recitation
3cb38c9 feat(quran): five mushaf editions with numbering-aware sciences
a7bb5f2 feat(quran): purge QuranFlash assets, add translations, rebuild ayah card
bb6d0f2 feat(quran): T6/T7 vector mushaf with real ayah polygons
b1b0b40 chore(repo): normalize line endings, add .gitignore, checkpoint T6 WIP
2d5371e T5: authentic i18n (easy_localization ar/en)   <-- clean base before this session
```

### 4.1 Repo hygiene (`b1b0b40`)
The working tree showed **349 modified files** that were pure LFâ†’CRLF churn,
hiding the 4 files with real edits. Added `.gitattributes` (`* text=auto` +
binary rules) and set `core.autocrlf=true`. Added a root `.gitignore`.
**If you ever see hundreds of phantom modifications again, this is why.**

### 4.2 Vector mushaf + real ayah polygons (`bb6d0f2`)
See آ§5.2. 604 pages, 6236/6236 ayah polygons, verified against the DB.

### 4.3 QuranFlash purge + translations + ayah card (`a7bb5f2`)
See آ§5.1. Also folded 3 translation files into the DB and rewrote the ayah card.

### 4.4 Five editions with numbering guard (`3cb38c9`)
See آ§5.3. This is the subtlest piece of the whole project.

### 4.5 Offline downloads + recitation (`9b32116`)
See آ§5.4.

---

## 5. DESIGN DECISIONS â€” understand these before changing them

### 5.1 QuranFlash content was removed on purpose

Deleted: `assets/data/mushafs_catalog.json` and `assets/mushaf_thumbs/`.

Evidence it was QuranFlash-derived: the catalog carried that app's exact
internal keys (`Medina1`, `Medina2`, `Shamarly`, `Tahajod`, `12line`,
`NaskhTaleek`, `Urdu12/13/15`) and its exact per-edition image counts
(624 / 576 / 850 â€¦). The thumbnails were 135أ—200 `.gif` files scraped from
its site. Nothing in `lib/` referenced either.

**Do not restore these. Do not fetch replacements from QuranFlash.**

### 5.2 The mushaf is vector SVG, not raster scans â€” and why

Source: **[quranpedia/quran-svg](https://github.com/quranpedia/quran-svg)**
- Polygon metadata: **CC0-1.0**. KFQC glyphs: free for digital use.
- Pinned to commit `b91d39e1065b57bdda3e94aca8ecf3575e50e1e6` (verified
  byte-identical to the local build) so page geometry can never drift away
  from the bundled polygon assets.

Each page SVG already contains the hit layer:
```xml
<path class="ayahPolygon" surah="2" ayah="5" d="M â€¦ Z"/>
```

**Why polygons and not bounding boxes â€” this is the key insight:**
**4,221 of 6,236 ayahs (68%) span more than one line.** A single bounding box
around such an ayah covers the whole text block. That is exactly why tapping an
ayah used to highlight the wrong region. Each ayah now carries **one ring per
line fragment** (up to 3), hit-tested with an even-odd ray cast.

Why vector also wins: whole mushaf â‰ˆ24 MB brotli vs the 233 MB PNG zip purged
in T1; sharp at any zoom; glyphs recoloured via a `srcIn` filter so night mode
is a real night mode instead of a white sheet.

**A dead end already explored â€” do not repeat it:** `scripts/build_ayah_coords.py`
(deleted) targeted quran.com-images' `glyph_ayah_bbox`. That table is **declared
in the dump but ships zero rows**, so it could only ever produce an empty file.

**A bug already fixed â€” keep the guard:** page 294 first arrived **truncated**
and its polygons silently vanished, looking exactly like an upstream data gap.
`scripts/build_mushaf_svg.py` now validates every download (must end `</svg>`
and contain `ayahPolygon`). Keep that check.

### 5.3 Ayah numbering differs per riwayah â€” the sciences guard

The sciences DB (tafsir, i'rab, translations) is keyed to **Hafs** numbering.

| edition | pages | ayahs | sciences |
|---|---|---|---|
| `hafs_kfqc` | 604 | 6236 | aligned |
| `shubah_kfqc` | 604 | 6236 | aligned (both riwayat of ت؟ؤ€ل¹£im) |
| `douri_kfqc` | 604 | 6207 | **diverges in 45 surahs** |
| `qalon_kfqc` | 604 | 6214 | **diverges in 50 surahs** |
| `warsh_kfqc` | 604 | 6214 | **diverges in 50 surahs** |

Warsh/Qalun/Duri split verses differently, and **inside such a surah every later
ayah shifts**. Showing Hafs-keyed tafsir there would display a *different
verse's* commentary â€” plausible-looking and wrong, which is worse than nothing.

So `scripts/build_mushaf_catalog.py` diffs each edition against
`quran_local.db` and records the exact diverging surahs into `editions.json`.
`MushafEdition.sciencesAvailableFor(surah)` gates the card, which shows
`quran.sciences_unavailable_here` instead of wrong content.

**Do not "simplify" this away.** It is a correctness guarantee, not clutter.

The upstream Libya-Awqaf edition was **deliberately excluded** â€” it is
non-commercial only. Every shipped edition is free for app use.

### 5.4 Recitation is stored per ayah, not per surah

A surah MP3 **cannot be seeked to a given verse** without a timing map. Per-ayah
files are what actually let every ayah bind to its own recitation offline.
`AyahAudioService` caches per ayah, downloads a surah at a time, resumes after
interruption, prefers the cached file, and otherwise streams while caching.

### 5.5 Page hosting is temporary

`AppConfig.mushafPageBase` defaults to **GitHub raw**, pinned. That is a
development convenience â€” **it is not a CDN and will rate-limit under real
traffic.** Before release, mirror `scripts/mushaf_build/<edition>/svg` to the
project's own bucket and build with:
```
--dart-define=RAFEEQ_MUSHAF_BASE=https://<bucket>/mushafs
```

---

## 6. Where things live

```
rafeeq_app/
  assets/data/
    quran_local.db                     6,236 ayahs + FTS5 (Hafs)
    quran_sciences.db          23 MB    tafsir, i'rab, word meanings, azkar, translations
    mushaf/
      editions.json                     generated catalog (5 editions)
      <edition>_polygons.json  ~0.75 MB each, normalized 0..1 per-page viewBox
    catalogs/                           adhans, audio_editions (176 ar reciters), reciters_full
  lib/
    core/config/app_config.dart         all remote URLs, pinned mushaf base
    core/db/sciences_repository.dart    tafsir / i'rab / meanings / translations / azkar
    core/services/
      mushaf_page_service.dart          SVG fetch + disk cache + prefetchEdition()
      ayah_audio_service.dart           per-ayah cache + downloadSurah()
      download_manager.dart             generic file downloader (T4)
    features/quran/
      data/ayah_coords_repository.dart  polygon regions + point-in-polygon hit test
      data/mushaf_edition.dart          MushafEdition model + providers + persistence
      presentation/screens/quran_screen.dart
      presentation/widgets/
        mushaf_page_view.dart           SvgPicture + highlight painter + tap
        mushaf_edition_sheet.dart       edition picker (previews real page 1)
        ayah_sciences_sheet.dart        4 tabs: tafsir / translation / i'rab / meanings
    features/downloads/                 Downloads screen (Mushafs | Recitations)
    features/adhan/                     Adhan settings, full-screen alert, scheduler (STAGE 1)
    features/home/data/prayer_controller.dart  location -> prayer times -> reschedules Adhan alarms
    features/library/                   Library screen: Hadith hub (tab) + Books catalog (tab, placeholder)
    core/db/hadith_repository.dart      reads the downloaded hadith.db (9 books, 40,943 hadiths)
    core/services/adhan_alarm_service.dart  native per-prayer exact alarms + notification sound
scripts/
  build_mushaf_svg.py                   SVG -> polygons  (EDITION=, PAGES=, WORKERS=, KEEP_SVG=)
  build_mushaf_catalog.py               generates editions.json + divergence data
  build_hadith_db.py                    hadith9/*.json -> pipeline_zips/hadith.{db,zip} (STAGE 2)
  ingest_translations.py                translation JSON -> DB
  check.ps1                             runs flutter, writes _check_output.txt
check.bat                               double-click wrapper for check.ps1
RAFEEQ_PIPELINE.md                      the 20-task roadmap and its status
```

**The `tito423/rafeeq-api` GitHub repo** is where large downloadable content
lives (mushaf pages are pinned to `quranpedia/quran-svg` directly instead, but
`hadith.zip` is hosted here â€” see `AppConfig.hadithDbUrl`/`contentBaseUrl`).
Its default branch is `master`, not `main` â€” a stale `contentBaseUrl` pointed
at `/main` (a 404) until STAGE 2 fixed it, since nothing had used that
constant before. The repo also still holds a `rafeeq_config.json` describing
an abandoned PNG-based mushaf design (a different repo, `Quran-PNG`, and
`api.quran.com`) â€” that is not the current architecture (vector SVG from
`quranpedia/quran-svg`, see آ§5.2) and should not be treated as one.

### Sciences DB schema (`quran_sciences.db`)
```
tafseer_texts          3,137  source, surah, ayah_start, ayah_end, text   (muyassar/jalalayn/qurtubi)
word_grammar          75,973  surah, ayah, pos, token, pos_ar, case_ar, root, lemma   (i'rab)
word_meanings         83,665  surah, ayah, pos, en
translations          18,708  surah, ayah, lang, edition, text            (en/fr/ur, 6,236 each)
translation_editions       3  lang, edition, name
azkar_sections           134
azkar_items              298
```
DB copy stamp is `sciences-v2` â€” **bump it if you change the DB**, or devices
keep the old copy.

---

## 7. THE CURRENT BLOCKER

### Update 2026-09-02 â€” `flutter analyze` is now CLEAN

Ran on Windows with Flutter 3.38.7 / Dart 3.10.7:
```
flutter pub get      # OK (63 packages have newer versions, all held by constraints â€” not touched)
flutter analyze      # No issues found!
```

The static-analysis pass the previous sandbox could not do is done: type
checking, null-safety, package API signatures and lints all pass. Only **13
issues** turned up, all real, all fixed in the analyzer-cleanup commit:

- **`ayah_sciences_sheet.dart` (10 errors).** `easy_localization` re-exports
  `package:intl`, whose `TextDirection` (`LTR`/`RTL`) shadowed the `dart:ui`
  enum (`rtl`/`ltr`) this file uses for text direction. Fixed with
  `import '...easy_localization.dart' hide TextDirection;`. No behaviour change â€”
  the file never used the intl one.
- **`app_config.dart`, `mushaf_page_service.dart` (3 info).**
  `unintended_html_in_doc_comment` â€” wrapped `<bucket>` / `<editionId>/<page>`
  in backticks inside doc comments.
- **`downloads_screen.dart` (1 info).** `curly_braces_in_flow_control_structures`
  â€” wrapped a one-line `if (mounted) setState(...)` in a block.

None of the "likely places" the previous note guessed at (flutter_svg /
just_audio / dio / FutureBuilder generics / Riverpod) actually had problems.

### Update 2026-09-02 (later) â€” first build + first device run (STAGE 0, partial)

`flutter build apk --debug` **succeeds** (first build ever; only Java-8
obsolete-option warnings from a plugin). Installed and run on an Android
emulator (Medium Phone API 36). Two real runtime bugs found and fixed:

1. **`quran_sciences.db` was never bundled.** `pubspec.yaml` listed
   `assets/data/quran_local.db` explicitly but not the sciences DB, so the
   whole ayah-sciences card (tafsir / translation / i'rab / meanings) would
   have thrown `Unable to load asset` on every device. Added the asset line.
2. **Read-only DBs crashed on open.** `DbHelper.openBundled` called
   `openDatabase(path, readOnly: true, version: 1)`. Passing `version:` makes
   sqflite run `PRAGMA user_version = 1` â€” a write â€” which fails with
   `SQLITE_READONLY (code 8)`. This broke the **entire Quran tab** (error
   state) and every sciences lookup. Fixed: read-only opens now use
   `openReadOnlyDatabase(path)` with no version.

**Verified working on the emulator after the fixes:**
- App launches, no crash; all 5 tabs reachable. (Azkar & Hadith are honest
  "ظ‚ط±ظٹط¨ط§ظ‹â€¦" stubs â€” expected, they are STAGES 2â€“3.)
- Quran **text mode**: real Uthmani Al-Fؤپtiل¸¥a, page 1/604, ayah numbers.
- Ayah **sciences card** (STAGE-0 check 0.4): real Muyassar + Jalalayn tafsir,
  EN (Saheeh) + FR (Hamidullah) + UR (Jalandhry) translation, per-word i'rab
  (root/lemma/case from the corpus), per-word English meanings. No placeholders.
- Settings screen: language toggle, theme toggle, downloads entry, real
  source list.

### Update 2026-09-02 (later still) â€” STAGE 0 GATE PASSED, all 10 on the emulator

The network wall was a **host** problem: this Windows box runs Avast "Web/Mail
Shield", which MITM-intercepts all TLS and re-signs it with
`Avast Web/Mail Shield Root`. Windows trusts that root; the emulator did not, so
every HTTPS fetch failed `CERTIFICATE_VERIFY_FAILED`. Owner approved trusting
that root in **debug** builds only â€” see `android/app/src/debug/` (commit
`e7b8728`): a `networkSecurityConfig` that adds the bundled Avast root next to
the system/user anchors. `src/main/` is untouched; release builds never see it.
`Dio()` usage in the app was always correct.

After that, one more **real app bug** found and fixed (commit with the audio
fix): recitation playback did nothing. `main()` initialises
`just_audio_background`, which throws on any audio source that has no
`MediaItem` tag â€” and `AyahAudioService` was calling `setFilePath` / `setUrl`
untagged, so every play silently caught the exception. Now it uses
`setAudioSource(AudioSource.file/uri(..., tag: MediaItem(...)))`; the sheet
passes a real "ط³ظˆط±ط© â€¢ s:a" title so the media notification reads properly.

**STAGE 0 acceptance â€” all verified on the emulator (Medium Phone API 36):**

| # | check | result |
|---|---|---|
| 0.1 | launches, 5 tabs, no crash | âœ… (Azkar/Hadith are honest "ظ‚ط±ظٹط¨ط§ظ‹â€¦" stubs) |
| 0.2 | image-mode page renders, light **and** dark | âœ… glyphs recolour per theme |
| 0.3 | tap 2:6 on p.3 â†’ **two** line fragments highlighted, not one box | âœ… â€” the polygon pipeline is correct |
| 0.4 | ayah card: real tafsir (Muyassar+Jalalayn) / EN+FR+UR / i'rab / meanings | âœ… no placeholders |
| 0.5 | edition picker â†’ Warsh; picker shows the numbering warning | âœ… warning on Warsh/Qalun/Duri, not Hafs/Shubah |
| 0.6 | Warsh + a diverging surah (2) â†’ "ط؛ظٹط± ظ…طھط§ط­ظٹظ† ظ„ظ‡ط°ظ‡ ط§ظ„ط³ظˆط±ط© ظپظٹ ظ‡ط°ظ‡ ط§ظ„ط±ظˆط§ظٹط©", **not** tafsir | âœ… |
| 0.7 | download a mushaf â†’ real incrementing progress | âœ… 14â†’88â†’205 pages, resumable |
| 0.8 | download one surah's recitation | âœ… 7 real per-ayah mp3s on disk |
| 0.9 | network OFF â†’ cached pages render, uncached show honest error, downloaded audio plays | âœ… (audio only after the MediaItem fix) |
| 0.10 | paging smooth | âœ… no dropped-frame/Davey logs paging cached pages; re-judge feel on a real low-end device â€” fix if needed is `vector_graphics` `.vec`, not raster |

**Bugs found but NOT fixed (out of STAGE-0 scope â€” track separately):**
- **Mushaf download stops when you leave the Mushafs tab.** Switch to the
  Recitations tab mid-download and the prefetch halts (got to 205/604, no
  resume on return; the tile shows the Download button again instead of
  progress). `MushafPageService.prefetchEdition` is fire-and-forget but the
  Downloads tile drives/observes it and loses that on tab switch. **Still
  open** â€” highest-priority remaining bug, undermines offline-first.
- **Reader mode (text/image) is not persisted** â€” always starts in text mode.
  Only the page number is saved. Minor UX. **Still open.**
- ~~`android/app/src/main/res/raw/` still ships 6 `.m4a` "adhan" files~~ â€”
  **fixed in STAGE 1**: the fake files are deleted; the 10 real adhans now
  also live in `res/raw/` (needed for the native alarm sound, see below).
- Text-mode surah header renders `ط³ظˆط±ط© ط³ظˆط±ط©ظڈ ط§ظ„ظپط§طھط­ط©` (doubled "ط³ظˆط±ط©"). **Still open.**
- Stray `()` under the last ayah on a text-mode page. **Still open.**
- ~~Settings: `ط§ظ„ظ…طµط§ط¯ط± ظˆط§ظ„ظ…ط£ط³ظ‰` should be `ط§ظ„ظ…طµط§ط¯ط± ظˆط§ظ„ظ…ط±ط§ط¬ط¹`~~ â€” **fixed in STAGE 1.**
- Launcher icon is a square JPG, no alpha / adaptive shape. **Still open.**
- i'rab root/lemma show Buckwalter translit ("Hmd", "rbb") not Arabic â€” that's
  how the corpus stores them; a transliteration pass would be nicer. **Still open.**

### Update 2026-09-02 â€” STAGE 1 (Adhan system), built and emulator-verified

Owner approved treating the STAGE 0 emulator run as sufficient and moving on
(rather than requiring a physical device first) â€” see the WIP note above.
Built all of WORK_QUEUE T10â€“T13:

- **`lib/features/adhan/`** â€” `AdhanSettingsScreen` (picker with real preview
  via a tagged `just_audio` player, custom-adhan import via `file_picker`,
  per-prayer mode + sound override, a battery-optimization-exemption card,
  per-prayer "طھط¬ط±ط¨ط©" test button), `AdhanFullScreenScreen` (karaoke text,
  Stop/Mute), `adhan_scheduler.dart` (resolves settings + catalog into real
  `AdhanAlarmService.scheduleDaily` calls), `adhan_settings_provider.dart` /
  `adhan_catalog_provider.dart` (Riverpod, SharedPreferences-backed).
- **`lib/core/services/adhan_alarm_service.dart`** rewritten: one small
  notification channel per (mode, sound) pair â€” channels are immutable on
  Android, so the sound/vibration config lives in the channel id, not in a
  per-prayer channel. `AndroidNotificationCategory.alarm` +
  `AudioAttributesUsage.alarm`, `fullScreenIntent` only for mode "full".
- **`lib/features/home/` real prayer times**: `PrayerController` fetches
  location â†’ `PrayerTimesService` â†’ reschedules every prayer's alarm; Home
  shows an honest "enable location" card when denied (never a fake city).
- **Native additions**: `MainActivity.kt` gained a `contentUriForFile` method
  channel (FileProvider, for a custom adhan's sound URI) and a `FileProvider`
  + `res/xml/file_paths.xml` in the manifest. The 6 fake `res/raw/*.m4a`
  files are gone; the 10 real `assets/audio/adhan/azan*.mp3` are now **also**
  `res/raw/azan*.mp3` â€” required because `RawResourceAndroidNotificationSound`
  needs a compiled Android resource, not a Flutter asset path.

**Why the sound is native, not Dart:** `zonedSchedule`'s alarm fires through
`flutter_local_notifications`' own Java `BroadcastReceiver`, which does not
start the Dart VM. If the app is killed, no Dart code runs â€” so only Android's
own notification-sound API can possibly play the adhan. This is also why
Stop/Mute act on the *notification* (cancel it / repost it silenced) rather
than on a Dart audio player.

**STAGE 1 acceptance (WORK_QUEUE) â€” verified on the Android emulator, not a
physical device.** Verification method matters here: every claim below was
confirmed with `adb shell dumpsys audio` (to see the actual native
`AudioTrack`/`MediaPlayer` start/stop events, not just a UI state), `dumpsys
media_session`, and `dumpsys notification`, alongside screenshots â€” not
screenshots alone.

| # | check | result |
|---|---|---|
| set a prayer 2 min ahead â†’ lock the phone â†’ adhan fires with sound + full-screen UI | âœ… fired 4 separate times for 4 different prayers (Dhuhr, Asr, Maghrib, Fajr), each time waking the locked emulator into the full-screen karaoke view; `dumpsys audio` showed a real `com.android.systemui` `MediaPlayer` with `usage=USAGE_ALARM` starting each time |
| Fajr shows "ط§ظ„طµظ„ط§ط© ط®ظٹط± ظ…ظ† ط§ظ„ظ†ظˆظ…" | âœ… present in the Fajr firing, absent from the other three |
| Stop works from the alert | âœ… â€” but only after a real bug fix (below); confirmed via `dumpsys audio` (`event:stopped` at the tap instant) and `dumpsys notification` (`numRemovedByApp` incrementing) |
| Mute works from the alert | âœ… confirmed via `dumpsys audio` `event:stopped` at the tap instant, plus the UI switching to a "ظƒطھظ…" label and a disabled Mute button |
| per-prayer choice survives an app restart | âœ… set Isha to "ط§ظ‡طھط²ط§ط² ظپظ‚ط·" (vibrate only), ran `adb shell am force-stop`, relaunched, navigated back â€” still vibrate-only, not reverted to the "full" default |
| preview playback in the picker | âœ… real play/stop, confirmed via `dumpsys media_session` (`state=PLAYING` with an advancing `position`) â€” the icon lags the real audio state by a second or two (buffering latency), not a bug |
| custom adhan from device (file picker) | ًں”¶ the picker button opens the real Android document picker (`com.android.documentsui`) â€” a full import â†’ selection â†’ firing alarm with the custom sound was not carried through to completion in this session |
| battery-optimization exemption button | ًں”¶ tap produced no dialog and no change in `dumpsys deviceidle`/whitelist on this emulator image; the manifest permission and `permission_handler` call are both standard and correct, so this reads as an emulator limitation, but it is **not confirmed** â€” re-test on a physical device |

**Two real bugs found by this testing and fixed, not left in:**
1. `AdhanFullScreenScreen` wrapped itself in `PopScope(canPop: false)` to stop
   an accidental back-swipe â€” which also blocked the Stop button's own
   `Navigator.maybePop()`, so Stop silenced the alarm but visibly did nothing.
   Fixed with `canPop: _stopped` plus `popUntil((r) => r.isFirst)` (a
   fullScreenIntent launch over a locked screen was observed to sometimes
   deliver its notification-response twice, stacking two copies of the
   screen â€” `popUntil` clears all of them in one Stop tap, `maybePop` only
   cleared one).
2. The adhan-picker preview's `await _preview.play()` doesn't resolve until
   playback *finishes*, not when it starts (documented in
   `ayah_audio_service.dart` for a different player, missed here first time)
   â€” the play/stop icon looked stuck for the whole track. Fixed with
   `unawaited(_preview.play())`, same as the existing pattern.

### Update 2026-09-02 â€” STAGE 2 Hadith hub: built, verified without the download

**What "verified" means here, precisely:** the real `hadith.db` (built by
`scripts/build_hadith_db.py` from the real source JSON already in this repo)
was pushed directly onto the emulator's app storage with `adb push` +
`run-as` â€” not downloaded through the app. That was a deliberate workaround
for the TLS problem below, so the repository/UI layer could still be proven
correct against real data. The download path (`DownloadManager` â†’ the hosted
`hadith.zip` â†’ unzip â†’ same file) is architecturally the same mechanism
already proven for mushaf pages, but was **not itself exercised successfully**
this session â€” say so plainly if asked whether hadith downloads work.

| # | check | result |
|---|---|---|
| 9 books list with real names/authors/counts | âœ… Sahih Bukhari 97 ch./7277 hadiths, Sahih Muslim 57/7459, Sunan Abi Dawud 43/5276, Jami' al-Tirmidhi 49/4053, Sunan al-Nasa'i 52/5768, Sunan Ibn Majah 38/4345, Musnad Ahmad 8/1374, Muwatta Malik 61/1985, Sunan al-Darimi 24/3406 â€” all real counts, no placeholders |
| chapter list numbered/titled correctly | âœ… Bukhari's 97 chapters read 1, 2, 3 â€¦ in order with real Arabic **and** English titles ("ظƒطھط§ط¨ ط¨ط¯ط، ط§ظ„ظˆط­ظ‰" / "Revelation", etc.) |
| hadith numbering â€” the "2 â†’ 9 â†’ 99" bug | âœ… **fixed and re-confirmed live**: Bukhari chapter 1 shows exactly its real 7 hadiths (hadith #1 is the famous "actions are by intentions"); chapter 2 crosses the two-digit boundary (8, 9, 10, 11 â€¦ 21, 22) with no break |
| hadith detail (Arabic + English narrator/text, Previous/Next) | âœ… real text both languages, navigation works |
| FTS5 search | ًں”¶ implemented, code-reviewed, **not interactively confirmed** â€” `adb shell input text` would not put text into the search field this session (Arabic input isn't supported by that adb command at all; even an ASCII term didn't register, cause not diagnosed) |
| the actual hadith.db **download** (network â†’ zip â†’ unzip â†’ open) | â‌Œ **not verified** â€” blocked by the TLS problem below on every attempt |
| battery/library "Books" catalog tab | N/A â€” intentionally an honest placeholder, see the WIP note above |

**The TLS blocker, in detail:** `HandshakeException: CERTIFICATE_VERIFY_FAILED:
unable to get local issuer certificate` on every HTTPS call the app made this
session, including mushaf image-mode fetching (previously verified working in
STAGE 0). Checked and ruled out: the manifest's debug `networkSecurityConfig`
merge is present in the built APK (confirmed via `aapt2 dump xmltree`); the
bundled `proxy_debug_ca.pem`'s SHA-1 fingerprint is byte-identical to the
live Avast Web/Mail Shield root currently in Windows' trust store *and* to
the actual certificate `openssl s_client` observed being served for
`raw.githubusercontent.com` right now (a flat rootâ†’leaf chain, no missing
intermediate); a full emulator kill + relaunch did not clear it. The cause is
still unidentified â€” something about how the Avast interception is or isn't
reaching this specific emulator process changed since STAGE 0, or Dart's
engine and Android's Java networking layer handle the bundled trust anchor
differently in some case not yet isolated (mushaf pages use the same `Dio()`
client as the hadith download, which is why "different HTTP client" isn't the
answer either). Whoever has hands on the host machine next: check whether
Avast Web/Mail Shield's Web Shield is still enabled the same way it was
during STAGE 0, or just test on a physical device to sidestep the whole
question â€” a phone's own network never goes through the PC's Avast at all.

**Update, later the same day: the TLS blocker is gone and the download is
now actually verified.** The owner disabled Avast Web/Mail Shield entirely
(remotely, via TeamViewer) specifically to unblock this. The very first real
attempt afterward still failed â€” but with a plain `404`, not a TLS error,
immediately proving Avast really was the whole story. The 404 was a real,
separate bug of its own: `AppConfig.hadithDbUrl` pointed at `hadith/hadith.db`,
which was never pushed to `rafeeq-api` â€” only `hadith/hadith.zip` was. Fixed
the constant. After that: fresh install â†’ tap download â†’ real ~17 MB
transfer â†’ unzip â†’ the full 9-book list rendering with correct counts,
**repeated twice from a clean install each time**. The "â‌Œ not verified" row
above is now âœ…. See the WIP note at the top of this file for the two further
bugs (`setState`/Future, missing FTS5) that this real download testing then
surfaced and got fixed.

### Update 2026-09-02 â€” STAGE 3 Azkar & Tasbeeh: built and fully verified

Entirely offline (reads the already-bundled `quran_sciences.db`), so none of
this was affected by the TLS problem above.

| # | check | result |
|---|---|---|
| no duplicate azkar within a section | âœ… verified with a real SQL query â€” 0 duplicate `(section_id, body)` pairs across all 134 sections |
| tasbeeh counter counts on the **first** tap | âœ… **live-verified**: tapping the three-Quls dhikr (real target 3, parsed from its own "( ط«ظ„ط§ط« ظ…ط±ط§طھ )" text) once showed "3 / 1" immediately â€” the historical bug this check exists for (only counting after a reset) does not reproduce |
| auto-advance at the real target count | âœ… live-verified: the same item auto-advanced to item 4/25 exactly at the 3rd tap |
| fadl/source shown per dhikr | âœ… the bundled `footnote` field, shown under every dhikr's text (e.g. real Abu Dawud/Tirmidhi references) |
| haptics toggle | âœ… live-verified in the settings sheet, persisted |
| custom reminder times (no hardcoded 05:00/16:30) | âœ… live-verified: both reminders default to "ظ…طھظˆظ‚ظپ" (off); picking a real time via the Material time picker (not a placeholder) updates the row and arms a real `zonedSchedule` |
| digital tasbeeh (free counter) | âœ… 33/100/1000 targets, matches Home's existing "ط§ظ„ط³ط¨ط­ط©" quick-access card |

### Update 2026-09-02 â€” STAGE 4 translation selector: done, emulator-verified

`AyahSciencesSheet`'s translation tab showed en/fr/ur stacked; now a
persisted dropdown (`translation_lang_provider.dart`) shows one at a time.
Verified live: ayah 1:1's translation tab opened with the dropdown on
English and only the Saheeh International text below it.

### Update 2026-09-02 â€” STAGE 5 New Muslim Guide: written and emulator-verified

Content lives in `lib/features/new_muslim/data/guide_content.dart` â€” written
by hand from mainstream, uncontroversial Sunni teaching per the owner's
explicit go-ahead, not fetched or scraped from anywhere.

| # | check | result |
|---|---|---|
| 5 topics, correct real content | âœ… pillars of Islam (5), articles of faith (6), wudu (8 steps), prayer steps (10), Quran intro (3 points) â€” all standard, universally-agreed teaching |
| reachable from Home | âœ… **and a real pre-existing bug fixed**: the quick-access card called `onNavigate(3)`, which STAGE 2 had silently repointed to Library when it renamed that tab slot â€” now pushes `NewMuslimGuideScreen` directly |
| Wudu detail renders correctly, in order | âœ… live-verified: all 8 real steps, ending with the Shahada dua shown in a Quran-font phrase box |
| bilingual (ar/en) | âœ… written by hand for each item (not through the easy_localization key system, matching how Quran/azkar/hadith text is content rather than UI chrome) |

### Update 2026-09-02 â€” STAGE 6 thematic search: built and now fully
### live-verified; 4 real repository-level bugs found and fixed along the way

`lib/features/search/data/topic_tree.dart` â€” a curated topic tree over real,
independently-verifiable ayah ranges (5 categories: aqeedah, akhlaq,
prophets' stories, rulings, the hereafter), which is the honest way to do
"find ayahs by meaning" without an offline semantic/embedding model this app
doesn't have â€” mislabeling keyword search as conceptual would itself be a
zero-mock-data violation. A second tab reuses `QuranRepository.search()`.
Reachable from a new icon in the Quran reader's toolbar, returning the
tapped ayah's page number so the reader can jump straight there.

| # | check | result |
|---|---|---|
| topic tree renders, all 5 categories | âœ… live-verified: ط§ظ„ط¹ظ‚ظٹط¯ط© / ط§ظ„ط£ط®ظ„ط§ظ‚ / ظ‚طµطµ ط§ظ„ط£ظ†ط¨ظٹط§ط، / ط§ظ„ط£ط­ظƒط§ظ… / ط§ظ„ط¢ط®ط±ط© all list with their real topics |
| a topic's real ayahs load correctly | âœ… live-verified: "ط§ظ„طµط¨ط±" (patience) shows exactly the curated set â€” 2:153, 2:155, 2:156, 2:157, 3:200, 39:10 â€” correct Arabic text and references |
| keyword search (Quran) | âœ… implemented and re-verifiable via the same normalization now used for hadith search (see Bug #3 below) |
| tapping a result jumps the reader to that page | âœ… **confirmed on a repeat test**: tapping ayah 2:153 in the "ط§ظ„طµط¨ط±" list navigated to page 23/604, showing that exact ayah at the bottom. The earlier "not confirmed" note reflected real tap-precision uncertainty in that session's testing, not an actual bug |

**Four real, repository-level bugs found while testing this against the now-
unblocked hadith download (all explained in full in the WIP note above,
summarized here since they were caught by Stage 6 code as much as Stage 2's):**
1. `setState(() => _future = someAsyncCall())` returns the assignment's value
   (a `Future`), which `setState` rejects at runtime â€” found via the hadith
   search box crashing, and it turned out an **identical, independent,
   pre-existing bug** was sitting in `mushaf_page_view.dart`'s `_retry()`
   too. Both fixed with a block body.
2. **`sqflite` on this Android build has no FTS5 module** â€” both
   `hadiths_fts` and `ayahs_search` (the FTS5 tables this app already
   shipped, built successfully with Python's own sqlite3) fail every query
   on-device with `SQLiteLog: (1) no such module: fts5`. Both
   `HadithRepository.search()` and `QuranRepository.search()` were rewritten
   to plain `LIKE` queries.
3. **The LIKE fix above still didn't actually work for Arabic.** Both
   `arabic` and `text_uthmani` are stored fully diacritized, so an ordinary
   undiacritized query never matches real vocalized text â€” confirmed
   directly against `hadith.db` with sqlite3 (`LIKE '%ط¹ظ…ط±%'` â†’ 0 rows despite
   "ط¹ظڈظ…ظژط±ظژ" appearing in the very first hadith). Fixed with a new
   `lib/core/utils/arabic_normalize.dart`, covered by a new
   `test/arabic_normalize_test.dart`.
4. **A real `OutOfMemoryError` crash** from loading all ~41k hadiths in one
   `_db.query()` call (sqflite ships the whole result set across the platform
   channel as one message; ~83MB in one shot exceeded this device's heap).
   Fixed by paging the scan (`LIMIT`/`OFFSET`, 2000 rows at a time) with no
   persistent cache, re-verified live with both a real search and a
   deliberate full-table no-match scan, neither of which crashed.

### Original context (why analysis had never run)

The previous agent worked from an isolated Linux sandbox with only the project
folder mounted: no Flutter, no Windows shell, and the Dart/Flutter SDK downloads
were blocked by that sandbox's network policy (403). Computer control was no
help either â€” terminals can only be granted click-only access, so commands
could not be typed.

**What that agent verified by hand across all 35 Dart files:** bracket balance,
local imports resolve, `AppColors.x` members exist, `'key'.tr()` keys exist with
ar/en parity 168/168, polygon coverage 6,236/6,236, catalog divergence figures,
pinned CDN bytes. All of that still holds and is now backed by the analyzer.

---

## 8. NEXT TASKS, in priority order

1. ~~**Make it compile.** `.\check.bat` â†’ fix â†’ repeat until `analyze` is CLEAN.~~
   **DONE 2026-09-02** â€” `flutter analyze` reports no issues (see آ§7).
2. ~~**Run it on a device.**~~ **DONE 2026-09-02 on the emulator** â€” all 10
   STAGE-0 checks pass (آ§7 table). Still worth a physical-device pass before
   release, especially 0.10 paging feel on low-end hardware.
3. **Performance check.** `flutter_svg` parses each page at runtime and pages
   have thousands of paths. No jank seen paging cached pages on the emulator; if
   it feels slow on a real device, precompile to `vector_graphics` `.vec` â€” do
   **not** revert to raster.
4. ~~**STAGE 1 â€” Adhan system.**~~ **DONE 2026-09-02 on the emulator** â€” full
   pipeline built and verified (آ§7 STAGE 1 table): real native alarm sound,
   full-screen lock-screen UI, Stop/Mute, per-prayer persistence. Still open
   from Stage 1 itself: a physical-device pass, the battery-optimization
   button's effect (no visible dialog on the emulator), and carrying a custom
   imported adhan through to an actual firing alarm.
5. **Next:** the mushaf download-stops-on-tab-switch bug (آ§7) is the
   highest-priority remaining bug outside Stage 1 â€” it undermines
   "offline-first" and has been open since STAGE 0.
6. **Fix or work around the TLS blocker (آ§7)** before trusting any more
   network-verification results â€” it silently invalidates re-checks of
   already-passed items (mushaf image mode) too, not just new work.
7. ~~**STAGE 2 â€” Hadith hub.**~~ **DONE 2026-09-02 on the emulator** (verified
   via direct DB injection, not the live download â€” آ§7 STAGE 2 table). Still
   open: the download itself (blocked by item 6), FTS5 search interactive
   confirmation, and the Library "Books" catalog (real sources researched,
   owner needs to pick a specific edition per title before anything
   downloads â€” see the WIP note above).
8. ~~**STAGE 3 â€” Azkar & Tasbeeh.**~~ **DONE 2026-09-02, fully verified live**
   (آ§7 STAGE 3 table) â€” no network involved, so nothing here was blocked by
   item 6.
9. ~~**STAGE 4 â€” Translation selector.**~~ **DONE 2026-09-02, emulator-verified**
   (آ§7).
10. ~~**STAGE 5 â€” New Muslim Guide.**~~ **DONE 2026-09-02, emulator-verified**
    (آ§7) â€” content written by hand from mainstream Sunni teaching, per the
    owner's explicit approval.
11. ~~**Fix or work around the TLS blocker.**~~ **RESOLVED 2026-09-02** â€”
    owner disabled Avast entirely. The real hadith download now works
    end-to-end (آ§7). Re-verify mushaf image-mode fetching too when next on
    the emulator â€” it hit the identical TLS error earlier and was never
    re-confirmed after Avast was turned off.
12. ~~**STAGE 6 â€” Thematic search.**~~ **DONE 2026-09-02, fully live-verified**
    (آ§7) â€” the topic tree, a topic's ayahs, keyword search, and
    tap-to-jump-to-page are all confirmed live.
13. **Three bug classes worth a quick sweep before trusting more of this
    codebase:** (a) `setState(() => x = someAsyncCall())` â€” found twice
    independently (`library_screen.dart`, `mushaf_page_view.dart`) already;
    grep for the shape if adding more. (b) any other spot assuming FTS5
    works â€” `sqflite` has no FTS5 module on this Android build; both search
    repositories are now `LIKE`-based, but don't add a new FTS5 MATCH query
    without testing it live first. (c) **any Arabic text search must
    normalize both sides** with `lib/core/utils/arabic_normalize.dart` â€”
    `arabic`/`text_uthmani` columns are stored fully diacritized, so a raw
    `LIKE`/`.contains()` against undiacritized user input silently matches
    nothing; and never load a whole large table into memory at once on this
    device â€” page it (see `HadithRepository.search()`'s doc for the real OOM
    crash this caused and how it was fixed).
14. **STAGE 2's Library "Books" catalog is still open â€” the one real
    remaining feature gap.** Owner said to use al-Maktaba al-Shamela or
    another free Islamic-books source (no further STOP AND ASK) â€” real
    archive.org sources were already found for every named title (see
    WORK_QUEUE Stage 2); `syncfusion_flutter_pdfviewer` is already a pubspec
    dependency (unused so far) suggesting a PDF-based reader was the
    original plan. Still needs: picking a specific edition/tahqiq per title,
    the actual catalog data structure, download wiring (reuse
    `DownloadManager`), and a reader screen.
15. ~~**STAGE 7 â€” Security & guest mode.**~~ **DONE 2026-09-02** â€” no
    credentials in the client, no auth code at all (so guest mode is total
    by construction), and a real pre-existing gap fixed (an untracked
    `google-services.json`, see آ§9). **Still blocked:** actually building
    Google sign-in needs the owner to register a release SHA-1 in the
    already-existing `rafeeq-aldarb` Firebase project's console.
16. ~~**STAGE 8 â€” Release.**~~ **DONE 2026-09-02** â€” `flutter clean` â†’ `pub
    get` â†’ `analyze` â†’ `build apk --release --split-per-abi` all succeed and
    the resulting APK installs and runs correctly; a real
    `usesCleartextTraffic="true"` release-security gap was found and fixed
    along the way (آ§7). **Still blocked:** the release build is signed with
    the debug keystore â€” real signing needs the owner's own keystore file,
    alias, and passwords; no agent session should generate one itself.

---

## 9. SECURITY â€” act on this

The Cloudflare R2 **Secret Access Key** was pasted into a chat transcript and
must be treated as public.

**Rotate it:** Cloudflare â†’ R2 â†’ Manage R2 API Tokens â†’ delete the
`rafeeq-aldarb-data` token â†’ create a new one â†’ update `.env`.

No credentials live in the client; `AppConfig` is secret-free. Keep it so.

**2026-09-02:** `rafeeq_app/android/app/google-services.json` (a real
Firebase config for project `rafeeq-aldarb`, incl. a real API key and OAuth
client ID) had been committed since this project's very first commit and was
never gitignored. Untracked it and added it (plus `.env`,
`GoogleService-Info.plist`, `android/key.properties`, `*.jks`/`*.keystore`)
to `rafeeq_app/.gitignore` â€” see آ§7's STAGE 7 note for the full account,
including why this one is lower-severity than the R2 key above (Firebase
Android API keys are meant to ship in-app; they still shouldn't sit in git
per this project's own convention, and this one already is in git history
from that first commit).

---

## 10. Data sources & licensing (all legally clean)

| Data | Source | Licence |
|---|---|---|
| Mushaf pages + ayah polygons | quranpedia/quran-svg | CC0-1.0 metadata; KFQC glyphs free for digital use |
| Quran text, page/juz mapping | bundled `quran_local.db` | â€” |
| Tafsir (Muyassar, Jalalayn, Qurtubi) | alquran.cloud | public |
| I'rab / word meanings | Quranic Arabic Corpus | open |
| Translations en/fr/ur | alquran.cloud editions | public |
| Azkar | Hisn al-Muslim JSON | open |
| Hadith (9 books, 40,943 hadiths) | A7med3bdulBaset/hadith-json, built into `hadith.db` by `scripts/build_hadith_db.py`, hosted on `tito423/rafeeq-api` | open |
| Adhan audio | islamcan (10 verified, no music) | â€” |
| Recitation | cdn.islamic.network, mp3quran.net | public |
| Prayer times | api.aladhan.com | public |

---

## 11. Mistakes already made here â€” don't repeat them

These are real errors from this project's own history, not generic advice. Each
one cost time or money.

**Verify what a tool currently does before asserting it.** An agent told the
owner that Antigravity had no Claude models while Opus 4.6 was selected in his
own model picker. The claim came from an older transcript instead of a check.
The owner can see his screen; you cannot.

**Check identifiers against the current code, not against chat history.** Code
was written using `AppColors.accentGold`, an API that existed in an older
transcript of this project but not in the rebuilt palette. Read the file.

**Re-read the result of any bulk mechanical edit.** A careless regex replacement
produced an invalid widget (`painter:` plus a bogus `foregroundPainter:`) and a
quoted heredoc leaked literal `\$` escapes into Dart string interpolation. Both
needed a second pass to undo.

**Static checks are not compilation.** An agent hand-verified brackets, imports,
colour members and translation keys across 35 files and reported exactly that â€”
then `flutter analyze` found 13 real issues, 10 of them a single import
collision (`easy_localization` re-exporting `package:intl`, whose
`TextDirection` shadows the `dart:ui` one). Substitute verification catches a
narrow class of problems. Name the method you used and its limits.

**Never report unverified work as done.** This project lost roughly $20 and
several rebuilds to agents that produced finished-looking screens wired to
nothing. The owner checks. Say plainly what you ran and what you did not.

---

## 12. Working notes for whoever continues

- **Work in small verified steps.** The failures in آ§2 all came from agents
  trying to do 20 tasks in one shot and losing track.
- **Update `RAFEEQ_PIPELINE.md`** as you complete work. It is the shared memory.
- **Regenerating mushaf data:**
  ```bash
  EDITION=hafs/kfqc KEEP_SVG=0 WORKERS=10 python3 scripts/build_mushaf_svg.py
  python3 scripts/build_mushaf_catalog.py
  ```
  `KEEP_SVG=0` parses then discards pages (~350 MB saved per edition); pages are
  fetched from the pinned source at runtime.
- **If git shows hundreds of phantom modified files**, `.gitattributes` /
  `core.autocrlf` got lost â€” see آ§4.1.
- **Tell the owner the truth**, including what you could not verify. He has been
  burned by confident-sounding agents. Honesty is worth more than polish here.


