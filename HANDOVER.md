# HANDOVER — Rafiq Al-Darb (رفيق الدرب)

**For:** the next AI agent picking up this project (Antigravity IDE, Cline, or any other).
**Read this file completely before touching anything.**

| | |
|---|---|
| **Last updated** | 2026-09-02 |
| **State at** | commit `bf8a327` + STAGE 1 (Adhan) commit |
| **Build verified?** | **`flutter analyze` clean · `flutter build apk --debug` OK · STAGE 0 gate PASSED (all 10 checks, §7) · STAGE 1 (Adhan) core pipeline built and verified firing/Stop/Mute/persistence on the Android emulator (§7 STAGE 1 table).** Owner decision 2026-09-02: emulator verification accepted as sufficient for the STAGE 0 gate; a physical-device pass is still open for both stages. |

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
> That updates the work-in-progress note above, stamps the date, and commits —
> in one step. A session that dies right after a checkpoint loses nothing. A
> session that dies an hour after its last one loses an hour.
>
> Use `.\cp.bat "..." -Done` when a stage is finished, and `.\cp.bat /s` to see
> where things stand.

---

## Current work in progress

<!-- WIP:START -->
**2026-09-02 — STAGE 1 (Adhan) core pipeline built and emulator-verified. Next: STAGE 2 (Library & Hadith), or a physical-device pass first.**

Owner was asked whether STAGE 0's emulator-only verification was acceptable or
a physical device was required; owner chose to accept the emulator and proceed
to STAGE 1. Built the whole Adhan system (WORK_QUEUE T10–T13):

- Adhan picker with real preview playback (`AdhanSettingsScreen`), custom
  adhan import via `file_picker`, per-prayer notification mode (full /
  audio-only / vibrate / silent) + per-prayer sound override, all persisted.
- Real prayer times on Home (`PrayerController`): location → AlAdhan API →
  reschedules every prayer's native exact alarm on every fetch and on every
  settings change.
- The Adhan **sound** is played natively by Android's own notification-sound
  API (`RawResourceAndroidNotificationSound` + `AudioAttributesUsage.alarm`),
  not by Dart/just_audio — required because the alarm can fire with the app
  fully killed, and `zonedSchedule`'s receiver never starts the Dart VM. This
  meant moving the 10 real adhans into `android/.../res/raw/` as well as
  assets, and deleting the 6 fake placeholder `.m4a` files that lived there
  (§7's oldest open bug — now actually fixed, not just flagged).
- Full-screen karaoke Adhan screen (`fullScreenIntent`, wakes/shows over the
  lock screen using `MainActivity`'s existing `showWhenLocked`/`turnScreenOn`),
  with real Stop/Mute wired to the same notification.
- Fixed `settings.credits` typo (`المصادر والمأسى` → `المصادر والمراجع`),
  also flagged in §7.

**Verified for real, on the Android emulator** (method: adb screenshots +
`dumpsys audio`/`media_session`/`notification` to confirm actual playback and
cancellation, not just UI appearance — see the STAGE 1 table in §7): alarms
fire with real native sound and the full-screen UI over a **locked** screen
for four different prayers; Stop cancels the notification and audibly stops
the sound in one tap; Mute silences it and updates the UI; a per-prayer mode
change survives a full `am force-stop` + relaunch. Two real bugs were caught
and fixed by this testing, not left in: `Navigator.maybePop()` blocked by its
own `PopScope(canPop: false)` (Stop looked like it did nothing), and the
preview player's `await play()` never resolving before Dart returns (icon
looked stuck — same class of just_audio gotcha already documented in
`ayah_audio_service.dart`, this time in the probe player too).

**Not verified / open:** a physical device (still emulator-only); the battery-
optimization exemption button (`Permission.ignoreBatteryOptimizations`) — the
tap produced no dialog and no whitelist change on this emulator image, most
likely an emulator limitation given the standard API and correct manifest
permission, but unconfirmed; a custom (user-imported) adhan's *native*
background sound via the FileProvider content URI — the file-picker import
flow itself was confirmed to open the real system document picker, but a full
custom file was not carried through to a firing alarm in this session. See
§7's STAGE 1 table for the full breakdown.
<!-- WIP:END -->

---

## 0. TL;DR — what to do first

1. Run `.\check.bat` (or `flutter analyze` in `rafeeq_app/`).
2. **The code has never been compiled.** Fix whatever the analyzer reports. That is job #1.
3. Do **not** redesign anything until the build is green.
4. Read §3 (Hard rules) and §5 (Decisions — do not undo) before writing code.

---

## 1. What this project is

A comprehensive Islamic Flutter app. The goal is a "masterpiece mix" of the best
ideas from Sakinati, Ayat, QuranFlash and Al-Quran Al-Azeem — **built from
scratch with our own legally-clean data**, not copied from them.

- App lives in `rafeeq_app/`
- Flutter 3.38.7 / Dart 3.10, Riverpod, easy_localization, sqflite, dio, just_audio, flutter_svg
- Owner: Tito. Speaks Arabic (Egyptian). Wants concise, efficient work — he has
  already lost ~$20 and many hours to agents that produced fake UIs.

---

## 2. History you must know (why the owner is wary)

Earlier agents (DeepSeek, LongCat, Gemini-in-Antigravity) did serious damage:

- Bloated the app to **400 MB** with unused assets
- Wrote **fake/mock data** everywhere — screens that looked finished but were
  wired to nothing
- Fake download buttons with hardcoded checkmarks
- Adhan files that contained music
- A "translation" system that only flipped RTL/LTR without translating
- Left the build broken

A clean rebuild (T1–T5) fixed the foundation. The work described in §4 continues
from that clean base. **Do not reintroduce any of the above.**

---

## 3. HARD RULES — non-negotiable

| # | Rule |
|---|------|
| 1 | **ZERO mock/placeholder data.** Every string on screen comes from a real DB, API, or asset. If data is missing, show an honest empty state — never invent text. |
| 2 | **Never take data from QuranFlash.** It is a licensed product; scraping/reverse-engineering it is off the table. All QuranFlash-derived files were deliberately deleted (see §5.1). |
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
The working tree showed **349 modified files** that were pure LF→CRLF churn,
hiding the 4 files with real edits. Added `.gitattributes` (`* text=auto` +
binary rules) and set `core.autocrlf=true`. Added a root `.gitignore`.
**If you ever see hundreds of phantom modifications again, this is why.**

### 4.2 Vector mushaf + real ayah polygons (`bb6d0f2`)
See §5.2. 604 pages, 6236/6236 ayah polygons, verified against the DB.

### 4.3 QuranFlash purge + translations + ayah card (`a7bb5f2`)
See §5.1. Also folded 3 translation files into the DB and rewrote the ayah card.

### 4.4 Five editions with numbering guard (`3cb38c9`)
See §5.3. This is the subtlest piece of the whole project.

### 4.5 Offline downloads + recitation (`9b32116`)
See §5.4.

---

## 5. DESIGN DECISIONS — understand these before changing them

### 5.1 QuranFlash content was removed on purpose

Deleted: `assets/data/mushafs_catalog.json` and `assets/mushaf_thumbs/`.

Evidence it was QuranFlash-derived: the catalog carried that app's exact
internal keys (`Medina1`, `Medina2`, `Shamarly`, `Tahajod`, `12line`,
`NaskhTaleek`, `Urdu12/13/15`) and its exact per-edition image counts
(624 / 576 / 850 …). The thumbnails were 135×200 `.gif` files scraped from
its site. Nothing in `lib/` referenced either.

**Do not restore these. Do not fetch replacements from QuranFlash.**

### 5.2 The mushaf is vector SVG, not raster scans — and why

Source: **[quranpedia/quran-svg](https://github.com/quranpedia/quran-svg)**
- Polygon metadata: **CC0-1.0**. KFQC glyphs: free for digital use.
- Pinned to commit `b91d39e1065b57bdda3e94aca8ecf3575e50e1e6` (verified
  byte-identical to the local build) so page geometry can never drift away
  from the bundled polygon assets.

Each page SVG already contains the hit layer:
```xml
<path class="ayahPolygon" surah="2" ayah="5" d="M … Z"/>
```

**Why polygons and not bounding boxes — this is the key insight:**
**4,221 of 6,236 ayahs (68%) span more than one line.** A single bounding box
around such an ayah covers the whole text block. That is exactly why tapping an
ayah used to highlight the wrong region. Each ayah now carries **one ring per
line fragment** (up to 3), hit-tested with an even-odd ray cast.

Why vector also wins: whole mushaf ≈24 MB brotli vs the 233 MB PNG zip purged
in T1; sharp at any zoom; glyphs recoloured via a `srcIn` filter so night mode
is a real night mode instead of a white sheet.

**A dead end already explored — do not repeat it:** `scripts/build_ayah_coords.py`
(deleted) targeted quran.com-images' `glyph_ayah_bbox`. That table is **declared
in the dump but ships zero rows**, so it could only ever produce an empty file.

**A bug already fixed — keep the guard:** page 294 first arrived **truncated**
and its polygons silently vanished, looking exactly like an upstream data gap.
`scripts/build_mushaf_svg.py` now validates every download (must end `</svg>`
and contain `ayahPolygon`). Keep that check.

### 5.3 Ayah numbering differs per riwayah — the sciences guard

The sciences DB (tafsir, i'rab, translations) is keyed to **Hafs** numbering.

| edition | pages | ayahs | sciences |
|---|---|---|---|
| `hafs_kfqc` | 604 | 6236 | aligned |
| `shubah_kfqc` | 604 | 6236 | aligned (both riwayat of ʿĀṣim) |
| `douri_kfqc` | 604 | 6207 | **diverges in 45 surahs** |
| `qalon_kfqc` | 604 | 6214 | **diverges in 50 surahs** |
| `warsh_kfqc` | 604 | 6214 | **diverges in 50 surahs** |

Warsh/Qalun/Duri split verses differently, and **inside such a surah every later
ayah shifts**. Showing Hafs-keyed tafsir there would display a *different
verse's* commentary — plausible-looking and wrong, which is worse than nothing.

So `scripts/build_mushaf_catalog.py` diffs each edition against
`quran_local.db` and records the exact diverging surahs into `editions.json`.
`MushafEdition.sciencesAvailableFor(surah)` gates the card, which shows
`quran.sciences_unavailable_here` instead of wrong content.

**Do not "simplify" this away.** It is a correctness guarantee, not clutter.

The upstream Libya-Awqaf edition was **deliberately excluded** — it is
non-commercial only. Every shipped edition is free for app use.

### 5.4 Recitation is stored per ayah, not per surah

A surah MP3 **cannot be seeked to a given verse** without a timing map. Per-ayah
files are what actually let every ayah bind to its own recitation offline.
`AyahAudioService` caches per ayah, downloads a surah at a time, resumes after
interruption, prefers the cached file, and otherwise streams while caching.

### 5.5 Page hosting is temporary

`AppConfig.mushafPageBase` defaults to **GitHub raw**, pinned. That is a
development convenience — **it is not a CDN and will rate-limit under real
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
scripts/
  build_mushaf_svg.py                   SVG -> polygons  (EDITION=, PAGES=, WORKERS=, KEEP_SVG=)
  build_mushaf_catalog.py               generates editions.json + divergence data
  ingest_translations.py                translation JSON -> DB
  check.ps1                             runs flutter, writes _check_output.txt
check.bat                               double-click wrapper for check.ps1
RAFEEQ_PIPELINE.md                      the 20-task roadmap and its status
```

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
DB copy stamp is `sciences-v2` — **bump it if you change the DB**, or devices
keep the old copy.

---

## 7. THE CURRENT BLOCKER

### Update 2026-09-02 — `flutter analyze` is now CLEAN

Ran on Windows with Flutter 3.38.7 / Dart 3.10.7:
```
flutter pub get      # OK (63 packages have newer versions, all held by constraints — not touched)
flutter analyze      # No issues found!
```

The static-analysis pass the previous sandbox could not do is done: type
checking, null-safety, package API signatures and lints all pass. Only **13
issues** turned up, all real, all fixed in the analyzer-cleanup commit:

- **`ayah_sciences_sheet.dart` (10 errors).** `easy_localization` re-exports
  `package:intl`, whose `TextDirection` (`LTR`/`RTL`) shadowed the `dart:ui`
  enum (`rtl`/`ltr`) this file uses for text direction. Fixed with
  `import '...easy_localization.dart' hide TextDirection;`. No behaviour change —
  the file never used the intl one.
- **`app_config.dart`, `mushaf_page_service.dart` (3 info).**
  `unintended_html_in_doc_comment` — wrapped `<bucket>` / `<editionId>/<page>`
  in backticks inside doc comments.
- **`downloads_screen.dart` (1 info).** `curly_braces_in_flow_control_structures`
  — wrapped a one-line `if (mounted) setState(...)` in a block.

None of the "likely places" the previous note guessed at (flutter_svg /
just_audio / dio / FutureBuilder generics / Riverpod) actually had problems.

### Update 2026-09-02 (later) — first build + first device run (STAGE 0, partial)

`flutter build apk --debug` **succeeds** (first build ever; only Java-8
obsolete-option warnings from a plugin). Installed and run on an Android
emulator (Medium Phone API 36). Two real runtime bugs found and fixed:

1. **`quran_sciences.db` was never bundled.** `pubspec.yaml` listed
   `assets/data/quran_local.db` explicitly but not the sciences DB, so the
   whole ayah-sciences card (tafsir / translation / i'rab / meanings) would
   have thrown `Unable to load asset` on every device. Added the asset line.
2. **Read-only DBs crashed on open.** `DbHelper.openBundled` called
   `openDatabase(path, readOnly: true, version: 1)`. Passing `version:` makes
   sqflite run `PRAGMA user_version = 1` — a write — which fails with
   `SQLITE_READONLY (code 8)`. This broke the **entire Quran tab** (error
   state) and every sciences lookup. Fixed: read-only opens now use
   `openReadOnlyDatabase(path)` with no version.

**Verified working on the emulator after the fixes:**
- App launches, no crash; all 5 tabs reachable. (Azkar & Hadith are honest
  "قريباً…" stubs — expected, they are STAGES 2–3.)
- Quran **text mode**: real Uthmani Al-Fātiḥa, page 1/604, ayah numbers.
- Ayah **sciences card** (STAGE-0 check 0.4): real Muyassar + Jalalayn tafsir,
  EN (Saheeh) + FR (Hamidullah) + UR (Jalandhry) translation, per-word i'rab
  (root/lemma/case from the corpus), per-word English meanings. No placeholders.
- Settings screen: language toggle, theme toggle, downloads entry, real
  source list.

### Update 2026-09-02 (later still) — STAGE 0 GATE PASSED, all 10 on the emulator

The network wall was a **host** problem: this Windows box runs Avast "Web/Mail
Shield", which MITM-intercepts all TLS and re-signs it with
`Avast Web/Mail Shield Root`. Windows trusts that root; the emulator did not, so
every HTTPS fetch failed `CERTIFICATE_VERIFY_FAILED`. Owner approved trusting
that root in **debug** builds only — see `android/app/src/debug/` (commit
`e7b8728`): a `networkSecurityConfig` that adds the bundled Avast root next to
the system/user anchors. `src/main/` is untouched; release builds never see it.
`Dio()` usage in the app was always correct.

After that, one more **real app bug** found and fixed (commit with the audio
fix): recitation playback did nothing. `main()` initialises
`just_audio_background`, which throws on any audio source that has no
`MediaItem` tag — and `AyahAudioService` was calling `setFilePath` / `setUrl`
untagged, so every play silently caught the exception. Now it uses
`setAudioSource(AudioSource.file/uri(..., tag: MediaItem(...)))`; the sheet
passes a real "سورة • s:a" title so the media notification reads properly.

**STAGE 0 acceptance — all verified on the emulator (Medium Phone API 36):**

| # | check | result |
|---|---|---|
| 0.1 | launches, 5 tabs, no crash | ✅ (Azkar/Hadith are honest "قريباً…" stubs) |
| 0.2 | image-mode page renders, light **and** dark | ✅ glyphs recolour per theme |
| 0.3 | tap 2:6 on p.3 → **two** line fragments highlighted, not one box | ✅ — the polygon pipeline is correct |
| 0.4 | ayah card: real tafsir (Muyassar+Jalalayn) / EN+FR+UR / i'rab / meanings | ✅ no placeholders |
| 0.5 | edition picker → Warsh; picker shows the numbering warning | ✅ warning on Warsh/Qalun/Duri, not Hafs/Shubah |
| 0.6 | Warsh + a diverging surah (2) → "غير متاحين لهذه السورة في هذه الرواية", **not** tafsir | ✅ |
| 0.7 | download a mushaf → real incrementing progress | ✅ 14→88→205 pages, resumable |
| 0.8 | download one surah's recitation | ✅ 7 real per-ayah mp3s on disk |
| 0.9 | network OFF → cached pages render, uncached show honest error, downloaded audio plays | ✅ (audio only after the MediaItem fix) |
| 0.10 | paging smooth | ✅ no dropped-frame/Davey logs paging cached pages; re-judge feel on a real low-end device — fix if needed is `vector_graphics` `.vec`, not raster |

**Bugs found but NOT fixed (out of STAGE-0 scope — track separately):**
- **Mushaf download stops when you leave the Mushafs tab.** Switch to the
  Recitations tab mid-download and the prefetch halts (got to 205/604, no
  resume on return; the tile shows the Download button again instead of
  progress). `MushafPageService.prefetchEdition` is fire-and-forget but the
  Downloads tile drives/observes it and loses that on tab switch. **Still
  open** — highest-priority remaining bug, undermines offline-first.
- **Reader mode (text/image) is not persisted** — always starts in text mode.
  Only the page number is saved. Minor UX. **Still open.**
- ~~`android/app/src/main/res/raw/` still ships 6 `.m4a` "adhan" files~~ —
  **fixed in STAGE 1**: the fake files are deleted; the 10 real adhans now
  also live in `res/raw/` (needed for the native alarm sound, see below).
- Text-mode surah header renders `سورة سورةُ الفاتحة` (doubled "سورة"). **Still open.**
- Stray `()` under the last ayah on a text-mode page. **Still open.**
- ~~Settings: `المصادر والمأسى` should be `المصادر والمراجع`~~ — **fixed in STAGE 1.**
- Launcher icon is a square JPG, no alpha / adaptive shape. **Still open.**
- i'rab root/lemma show Buckwalter translit ("Hmd", "rbb") not Arabic — that's
  how the corpus stores them; a transliteration pass would be nicer. **Still open.**

### Update 2026-09-02 — STAGE 1 (Adhan system), built and emulator-verified

Owner approved treating the STAGE 0 emulator run as sufficient and moving on
(rather than requiring a physical device first) — see the WIP note above.
Built all of WORK_QUEUE T10–T13:

- **`lib/features/adhan/`** — `AdhanSettingsScreen` (picker with real preview
  via a tagged `just_audio` player, custom-adhan import via `file_picker`,
  per-prayer mode + sound override, a battery-optimization-exemption card,
  per-prayer "تجربة" test button), `AdhanFullScreenScreen` (karaoke text,
  Stop/Mute), `adhan_scheduler.dart` (resolves settings + catalog into real
  `AdhanAlarmService.scheduleDaily` calls), `adhan_settings_provider.dart` /
  `adhan_catalog_provider.dart` (Riverpod, SharedPreferences-backed).
- **`lib/core/services/adhan_alarm_service.dart`** rewritten: one small
  notification channel per (mode, sound) pair — channels are immutable on
  Android, so the sound/vibration config lives in the channel id, not in a
  per-prayer channel. `AndroidNotificationCategory.alarm` +
  `AudioAttributesUsage.alarm`, `fullScreenIntent` only for mode "full".
- **`lib/features/home/` real prayer times**: `PrayerController` fetches
  location → `PrayerTimesService` → reschedules every prayer's alarm; Home
  shows an honest "enable location" card when denied (never a fake city).
- **Native additions**: `MainActivity.kt` gained a `contentUriForFile` method
  channel (FileProvider, for a custom adhan's sound URI) and a `FileProvider`
  + `res/xml/file_paths.xml` in the manifest. The 6 fake `res/raw/*.m4a`
  files are gone; the 10 real `assets/audio/adhan/azan*.mp3` are now **also**
  `res/raw/azan*.mp3` — required because `RawResourceAndroidNotificationSound`
  needs a compiled Android resource, not a Flutter asset path.

**Why the sound is native, not Dart:** `zonedSchedule`'s alarm fires through
`flutter_local_notifications`' own Java `BroadcastReceiver`, which does not
start the Dart VM. If the app is killed, no Dart code runs — so only Android's
own notification-sound API can possibly play the adhan. This is also why
Stop/Mute act on the *notification* (cancel it / repost it silenced) rather
than on a Dart audio player.

**STAGE 1 acceptance (WORK_QUEUE) — verified on the Android emulator, not a
physical device.** Verification method matters here: every claim below was
confirmed with `adb shell dumpsys audio` (to see the actual native
`AudioTrack`/`MediaPlayer` start/stop events, not just a UI state), `dumpsys
media_session`, and `dumpsys notification`, alongside screenshots — not
screenshots alone.

| # | check | result |
|---|---|---|
| set a prayer 2 min ahead → lock the phone → adhan fires with sound + full-screen UI | ✅ fired 4 separate times for 4 different prayers (Dhuhr, Asr, Maghrib, Fajr), each time waking the locked emulator into the full-screen karaoke view; `dumpsys audio` showed a real `com.android.systemui` `MediaPlayer` with `usage=USAGE_ALARM` starting each time |
| Fajr shows "الصلاة خير من النوم" | ✅ present in the Fajr firing, absent from the other three |
| Stop works from the alert | ✅ — but only after a real bug fix (below); confirmed via `dumpsys audio` (`event:stopped` at the tap instant) and `dumpsys notification` (`numRemovedByApp` incrementing) |
| Mute works from the alert | ✅ confirmed via `dumpsys audio` `event:stopped` at the tap instant, plus the UI switching to a "كتم" label and a disabled Mute button |
| per-prayer choice survives an app restart | ✅ set Isha to "اهتزاز فقط" (vibrate only), ran `adb shell am force-stop`, relaunched, navigated back — still vibrate-only, not reverted to the "full" default |
| preview playback in the picker | ✅ real play/stop, confirmed via `dumpsys media_session` (`state=PLAYING` with an advancing `position`) — the icon lags the real audio state by a second or two (buffering latency), not a bug |
| custom adhan from device (file picker) | 🔶 the picker button opens the real Android document picker (`com.android.documentsui`) — a full import → selection → firing alarm with the custom sound was not carried through to completion in this session |
| battery-optimization exemption button | 🔶 tap produced no dialog and no change in `dumpsys deviceidle`/whitelist on this emulator image; the manifest permission and `permission_handler` call are both standard and correct, so this reads as an emulator limitation, but it is **not confirmed** — re-test on a physical device |

**Two real bugs found by this testing and fixed, not left in:**
1. `AdhanFullScreenScreen` wrapped itself in `PopScope(canPop: false)` to stop
   an accidental back-swipe — which also blocked the Stop button's own
   `Navigator.maybePop()`, so Stop silenced the alarm but visibly did nothing.
   Fixed with `canPop: _stopped` plus `popUntil((r) => r.isFirst)` (a
   fullScreenIntent launch over a locked screen was observed to sometimes
   deliver its notification-response twice, stacking two copies of the
   screen — `popUntil` clears all of them in one Stop tap, `maybePop` only
   cleared one).
2. The adhan-picker preview's `await _preview.play()` doesn't resolve until
   playback *finishes*, not when it starts (documented in
   `ayah_audio_service.dart` for a different player, missed here first time)
   — the play/stop icon looked stuck for the whole track. Fixed with
   `unawaited(_preview.play())`, same as the existing pattern.

### Original context (why analysis had never run)

The previous agent worked from an isolated Linux sandbox with only the project
folder mounted: no Flutter, no Windows shell, and the Dart/Flutter SDK downloads
were blocked by that sandbox's network policy (403). Computer control was no
help either — terminals can only be granted click-only access, so commands
could not be typed.

**What that agent verified by hand across all 35 Dart files:** bracket balance,
local imports resolve, `AppColors.x` members exist, `'key'.tr()` keys exist with
ar/en parity 168/168, polygon coverage 6,236/6,236, catalog divergence figures,
pinned CDN bytes. All of that still holds and is now backed by the analyzer.

---

## 8. NEXT TASKS, in priority order

1. ~~**Make it compile.** `.\check.bat` → fix → repeat until `analyze` is CLEAN.~~
   **DONE 2026-09-02** — `flutter analyze` reports no issues (see §7).
2. ~~**Run it on a device.**~~ **DONE 2026-09-02 on the emulator** — all 10
   STAGE-0 checks pass (§7 table). Still worth a physical-device pass before
   release, especially 0.10 paging feel on low-end hardware.
3. **Performance check.** `flutter_svg` parses each page at runtime and pages
   have thousands of paths. No jank seen paging cached pages on the emulator; if
   it feels slow on a real device, precompile to `vector_graphics` `.vec` — do
   **not** revert to raster.
4. ~~**STAGE 1 — Adhan system.**~~ **DONE 2026-09-02 on the emulator** — full
   pipeline built and verified (§7 STAGE 1 table): real native alarm sound,
   full-screen lock-screen UI, Stop/Mute, per-prayer persistence. Still open
   from Stage 1 itself: a physical-device pass, the battery-optimization
   button's effect (no visible dialog on the emulator), and carrying a custom
   imported adhan through to an actual firing alarm.
5. **Next:** the mushaf download-stops-on-tab-switch bug (§7) is the
   highest-priority remaining bug outside Stage 1 — it undermines
   "offline-first" and has been open since STAGE 0. Then continue
   `WORK_QUEUE.md` STAGE 2+ (library, hadith, azkar, new-Muslim guide,
   thematic search, release).

---

## 9. SECURITY — act on this

The Cloudflare R2 **Secret Access Key** was pasted into a chat transcript and
must be treated as public.

**Rotate it:** Cloudflare → R2 → Manage R2 API Tokens → delete the
`rafeeq-aldarb-data` token → create a new one → update `.env`.

No credentials live in the client; `AppConfig` is secret-free. Keep it so.

---

## 10. Data sources & licensing (all legally clean)

| Data | Source | Licence |
|---|---|---|
| Mushaf pages + ayah polygons | quranpedia/quran-svg | CC0-1.0 metadata; KFQC glyphs free for digital use |
| Quran text, page/juz mapping | bundled `quran_local.db` | — |
| Tafsir (Muyassar, Jalalayn, Qurtubi) | alquran.cloud | public |
| I'rab / word meanings | Quranic Arabic Corpus | open |
| Translations en/fr/ur | alquran.cloud editions | public |
| Azkar | Hisn al-Muslim JSON | open |
| Hadith (9 books) | A7med3bdulBaset/hadith-json | open |
| Adhan audio | islamcan (10 verified, no music) | — |
| Recitation | cdn.islamic.network, mp3quran.net | public |
| Prayer times | api.aladhan.com | public |

---

## 11. Mistakes already made here — don't repeat them

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
colour members and translation keys across 35 files and reported exactly that —
then `flutter analyze` found 13 real issues, 10 of them a single import
collision (`easy_localization` re-exporting `package:intl`, whose
`TextDirection` shadows the `dart:ui` one). Substitute verification catches a
narrow class of problems. Name the method you used and its limits.

**Never report unverified work as done.** This project lost roughly $20 and
several rebuilds to agents that produced finished-looking screens wired to
nothing. The owner checks. Say plainly what you ran and what you did not.

---

## 12. Working notes for whoever continues

- **Work in small verified steps.** The failures in §2 all came from agents
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
  `core.autocrlf` got lost — see §4.1.
- **Tell the owner the truth**, including what you could not verify. He has been
  burned by confident-sounding agents. Honesty is worth more than polish here.

