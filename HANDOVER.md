# HANDOVER — Rafiq Al-Darb (رفيق الدرب)

**For:** the next AI agent picking up this project (Antigravity IDE, Cline, or any other).
**Read this file completely before touching anything.**

| | |
|---|---|
| **Last updated** | 2026-09-03 |
| **State at** | **PHASE 2 nearly done** — see `PHASE2.md` (the current build prompt). Phase 1 (T1–T20) complete. Every P2 stage is done and emulator-verified **except P2‑7's last piece, which needs a real Android phone** (see its row below) and P2‑8, which is stopped waiting on the owner's shortlist pick. |
| **Build verified?** | `flutter analyze` clean · `flutter test` **13/13**. All of P2‑1/2/3/4/4b/5/6/9/10/11/12/13 emulator-verified live (not just built) on `emulator-5554`. |

### PHASE 2 progress (2026-09-02) — details in `PHASE2.md`

| Stage | State |
|---|---|
| P2‑1 small-bug sweep | ✅ done, verified (6 bugs; launcher icon designed in-house, src in `rafeeq_app/assets/icon/src/`) |
| P2‑2 4 themes (system/light/dark/**RGB** animated) | ✅ done, verified — `lib/core/theme/theme_controller.dart` + `app_theme.rgb()` + `rgb_backdrop.dart`. §5.6. |
| P2‑3 es / ru / pt locales | ✅ done, verified — 5-locale parity (260 keys after P2‑4/4b), `test/translation_parity_test.dart`. Fixed `const AppShell` not re-translating on `setLocale`. |
| P2‑4 Library redesign | ✅ structural done, verified — Home المكتبة card → `LibraryScreen`; tabs [الكتب المتوفرة \| الحديث]; 3 sub-tabs (كل الكتب abc / التصنيفات / مكتبتي w/ فتح+حذف). `BookCategory` enum, `LibraryBook.category/sortKey`. **Fixed real bug:** `DownloadManager.remove()` didn't purge the SharedPreferences registry. Added `العبودية` (Ibn Taymiyyah) — 5 books / 3 categories now. |
| P2‑4b book **text editions** (Shamela) | ✅ done, emulator-verified — 5 Shamela text editions (`build_book_text.py` → `rafeeq-api/books/text/*.json`), `book_text_reader_screen.dart` (فهرس/search/font/bookmarks/provenance), `مصوّر\|نص` switch per card, one مكتبتي row per (book, edition). `printReliable` gates printed-page UI (false for Riyad/12014). §5.7. |
| P2‑5 pro download manager | ✅ done, emulator-verified — unified `DownloadsScreen` (نظرة عامة tab: storage total + per-category تفريغ + downloaded-items list), `downloads_controller.dart` aggregator, **live progress notification for every download kind** (`DownloadNotifications` generalized + wired into mushaf-prefetch & surah-audio, requests POST_NOTIFICATIONS), and **pause/resume** for mushaf + audio. Minor: 3 tabs not the 5 labelled sections; a few toasts not re-shot. |
| P2‑6 persistent prayer notification (next prayer + Hijri + countdown) | ✅ done, emulator-verified — `prayer_status_notification.dart` (ongoing LOW card, native chronometer countdown, Hijri from AlAdhan cache, one scheduled rollover, honest "enable location" fallback), opt-in toggle in Adhan settings (default off), synced from `AppShell` on times-resolve / toggle / resume. |
| P2‑7 Adhan audio/video + 30 slots | 🔶 code done + clips hosted + partially emulator-verified (analyze clean, test 13/13) — 5 Pixabay clips uploaded to `rafeeq-api/adhan/video/*.mp4` (all 200, byte-exact); download → auto-select → persists across restart → test notification (right title/sound) all verified live. **Not verified:** the actual full-screen video-behind-karaoke render (notification-tap / lock-screen full-screen-intent never fired under ADB on this emulator — see §7 P2‑7 update; needs a real device). |
| P2‑8 competitor feature mix | 🔶 research done — `PHASE2_RESEARCH.md` (13-feature table from Sakinah/Ayat/QuranFlash/Khatmah + a proposed shortlist + 4 owner-decision-blocked items). **No code** — the stage's own rule is STOP until the owner picks the shortlist. |
| P2‑9 hosting doc (R2/Firebase/GitHub) | ✅ `HOSTING.md` written + client wiring re-confirmed (§4 there) · console provisioning (R2 bucket, token rotation) still OWNER-BLOCKER |
| P2‑10 perf / size / security / release prep | ✅ done — `ARCHITECTURE.md` written, real size measured (+~6MB vs Phase‑1, documented honestly), security re-swept clean, dead code found+removed, a real usability gap found+fixed (every error state got a working Retry button). OWNER-BLOCKER unchanged: release keystore. |
| **P2‑11** Quran Khatma card (Home top) | ✅ done, emulator-verified — create/read-today/jump-to-reader/progress all confirmed live. |
| **P2‑12** Sunan as-Suwar card (Home middle) — 4 surahs, single-surah locked reader, per-surah reminders | ✅ done, emulator-verified — locked reader confirmed to stop exactly at the surah boundary (Al-Baqarah: 48/48, no leak into Aal-Imran) |
| **P2‑13** Random-hadith card (Home bottom) — full hadith + narrator + grade, re-rolls each launch | ✅ done, emulator-verified — real graded source found for 4 of 7 books (Abu Dawud/Tirmidhi/an-Nasa'i/Ibn Majah), joined by normalized-Arabic-text matching, `hadith.db` rebuilt + re-hosted + verified byte-exact. Quick-access grid removed from Home (New Muslim Guide rehomed to Settings, not orphaned). |

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
**2026-09-03 20:28 — IN PROGRESS — resume here**

P3-14 Russian layout bug FIXED - owner sent the screenshot: Khatma card's Home title ('Хатм Корана') was rendering one Cyrillic letter per line down the whole card. Root cause: _ActiveKhatmaRow put the progress ring, an Expanded title column, AND the 'read today' FilledButton all in one Row - the button isn't width-constrained so it takes its full natural width, and Russian's much-longer button label ('Читать сегодня (4 стр.)' vs Arabic's short 'اقرأ اليوم (٤)') squeezed the Expanded title column down to near-zero, and Flutter wrapped it one character per line. Fixed generically (not a Russian-specific patch): split into two rows - progress+title on top (always gets the card's full width), the action button on its own row below (Align centerEnd), matching the same pattern _BatteryCard/_FullScreenIntentCard already use. Checked khatma_screen.dart's own tile for the same anti-pattern - it already wraps both its buttons in Expanded(50/50), safe as-is, no change needed there. P3-5 answered by owner: login is OPTIONAL (guest mode stays default, sign-in only adds sync) - unblocks the Home redesign's personalized-card work. analyze clean, test 15/15.

_Uncommitted at the time of writing: see `git status`. If this says
IN PROGRESS, the previous session likely ran out of quota here — read the last
commit's diff before continuing._
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
| 6 | **Keep translation keys at exact parity across every locale.** 5 locales (`ar` / `en` / `es` / `ru` / `pt`), **260 keys each** as of P2‑4b. Adding a key to one locale without the others is a bug — `test/translation_parity_test.dart` guards this. |

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

### 5.6 Theme system — four variants, one seam (P2‑2)

`enum ThemeVariant { system, light, dark, rgb }` in
`lib/core/theme/theme_controller.dart` is the single source of truth
(persisted `theme_variant_v2`). `RafeeqApp` resolves it to MaterialApp's
`theme`/`darkTheme`/`themeMode`; **only `rgb`** also gets a global
`builder` that wraps the navigator in `RgbScaffoldBackground` (the animated
Islamic-geometry backdrop). `AppTheme.rgb()`'s scaffold is **transparent on
purpose** so the backdrop shows through every screen — do not "fix" that to
an opaque colour. Adding a 5th theme = one enum case + one `AppTheme.xxx()` +
one arm in `RafeeqApp`'s `switch`; no screen changes. The RGB backdrop
animation stops itself when the OS "reduce motion" setting is on or the
`settings.motion_effects` toggle is off.

### 5.7 Library book **text** editions come from al-Maktaba al-Shamela (P2‑4b)

Owner decision, 2026-09-02: the **نص** edition of every library book is
sourced from `shamela.ws` (owner confirmed downloading Shamela's book texts is
fine — "كل حاجة مرفوعة عليه"). `scripts/build_book_text.py` scrapes it into
`books/text/<id>.json` on `tito423/rafeeq-api`; `book_text_reader_screen.dart`
renders it.

**Licence reality — flagged, not hidden.** All 5 underlying classical texts
are public domain (authors d. 597–751 AH). A modern *muḥaqqiq*'s apparatus can
still carry copyright: the Arnaut editions (Riyad / book 12014, and the taʿlīq
on Mukhtasar Minhaj al-Qasidin / 98087) and the Shawish edition (al-ʿUbudiyya
/ 22647) are in copyright for the *taḥqīq*. Mitigations in place:
`build_book_text.py` extracts only the author's running text + section
headings and **drops the `div.hamesh` footnote apparatus**; each book's full
edition + editor line (`TextEdition.sourceLabel`) is shown in the reader at
all times and is one tap from "فتح في الشاملة". The owner chose Shamela
knowingly on this basis. If a future edition looks heavily
apparatus-dependent, prefer a plainer PD edition of the same text (that is
why al-Fawaid uses Shamela 6832 / دار الكتب العلمية 1973, **not** the
apparatus-heavy 2019 عطاءات العلم edition 212).

**`printReliable`** (`meta.printReliable` in the JSON): some Shamela books
carry the `[ترقيم موافق للمطبوع]` flag yet their `pageNum` values are out of
order in stretches — **Riyad as-Salihin (book 12014) drops ~100 pages four
times through the book.** The `nextId` walk still yields the correct *reading*
order (Nawawi's chapter sequence is intact — verified). So the reader shows
printed-page numbers / "go to printed page" **only when `printReliable`**;
otherwise it navigates by sequence position + the فهرس, and bookmarks are
keyed on `pageIndex` (stable) not the printed number.

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
`hadith.zip` is hosted here — see `AppConfig.hadithDbUrl`/`contentBaseUrl`).
Its default branch is `master`, not `main` — a stale `contentBaseUrl` pointed
at `/main` (a 404) until STAGE 2 fixed it, since nothing had used that
constant before. The repo also still holds a `rafeeq_config.json` describing
an abandoned PNG-based mushaf design (a different repo, `Quran-PNG`, and
`api.quran.com`) — that is not the current architecture (vector SVG from
`quranpedia/quran-svg`, see §5.2) and should not be treated as one.

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
_Most of these were the PHASE 2 Stage P2‑1 sweep — see `PHASE2.md`. Status
updated 2026-09-02._
- ~~**Mushaf download stops when you leave the Mushafs tab.**~~ **FIXED (P2‑1.4),
  emulator-verified.** Root cause: `prefetchEdition` was fire-and-forget and the
  Downloads tile owned the observation, losing it when the tile was rebuilt on a
  tab switch. Now `MushafPageService` publishes a `PrefetchProgress`
  (`ChangeNotifier`) per edition; the tile re-attaches to a running job in
  `initState`. Verified live: started Hafs, switched to التلاوات and back —
  progress had continued 3 → 27 → 39 → 51 and the tile still showed the bar, not
  the Download button. (P2‑5 folds this into a unified manager.)
- ~~**Reader mode (text/image) is not persisted.**~~ **FIXED (P2‑1.3),
  emulator-verified.** `quran_screen.dart` persists `_mode` under
  `SharedPreferences` key `quran_reader_mode`; restored in `initState`. Verified:
  switched to image mode → `am force-stop` → relaunch → still image mode.
- ~~`android/app/src/main/res/raw/` still ships 6 `.m4a` "adhan" files~~ —
  **fixed in STAGE 1**: the fake files are deleted; the 10 real adhans now
  also live in `res/raw/` (needed for the native alarm sound, see below).
- ~~Text-mode surah header renders `سورة سورةُ الفاتحة` (doubled "سورة").~~
  **FIXED (P2‑1.1), emulator-verified.** The DB `name_ar` already contains
  "سُورَةُ …"; `mushaf_text_page.dart` now renders it directly.
- ~~Stray `()` under the last ayah on a text-mode page.~~ **FIXED (P2‑1.2),
  emulator-verified.** Removed the trailing decorative `﴿ ﴾` `Text` widget.
- ~~Settings: `المصادر والمأسى` should be `المصادر والمراجع`~~ — **fixed in STAGE 1.**
- ~~Launcher icon is a square JPG, no alpha / adaptive shape.~~ **FIXED
  (P2‑1.5), emulator-verified.** Icon designed in-house (owner: "design it
  yourself") — originally a rub‑el‑hizb guiding star over a receding path,
  teal/gold. **Redesigned again 2026‑09‑03** (owner ask) into a mosque
  silhouette on the app's real `AppColors` palette — see the 2026‑09‑03 §7
  update below; that pass also found and fixed a real bug in this icon's
  render pipeline (the adaptive foreground PNG had no alpha channel at all,
  present since this original P2‑1.5 commit). Source SVGs + regen steps in
  `rafeeq_app/assets/icon/src/`. Adaptive fg/bg via `flutter_launcher_icons`
  (`mipmap-anydpi-v26/ic_launcher.xml`). Old `app_icon.jpg` deleted;
  `assets/icon/` dropped from the Flutter bundle (build-time only,
  ~0.9 MB lighter).
- ~~i'rab root/lemma show Buckwalter translit ("Hmd", "rbb") not Arabic.~~
  **FIXED (P2‑1.6), emulator-verified + unit-tested.** New
  `lib/core/utils/buckwalter.dart` (`buckwalterToArabic` / `buckwalterForDisplay`)
  + `test/buckwalter_test.dart` (6 cases). `_IrabTab` now shows الجذر: سمو /
  الكلمة: ٱسْم etc. `flutter test` = 11/11 green.

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

### Update 2026-09-02 — STAGE 2 Hadith hub: built, verified without the download

**What "verified" means here, precisely:** the real `hadith.db` (built by
`scripts/build_hadith_db.py` from the real source JSON already in this repo)
was pushed directly onto the emulator's app storage with `adb push` +
`run-as` — not downloaded through the app. That was a deliberate workaround
for the TLS problem below, so the repository/UI layer could still be proven
correct against real data. The download path (`DownloadManager` → the hosted
`hadith.zip` → unzip → same file) is architecturally the same mechanism
already proven for mushaf pages, but was **not itself exercised successfully**
this session — say so plainly if asked whether hadith downloads work.

| # | check | result |
|---|---|---|
| 9 books list with real names/authors/counts | ✅ Sahih Bukhari 97 ch./7277 hadiths, Sahih Muslim 57/7459, Sunan Abi Dawud 43/5276, Jami' al-Tirmidhi 49/4053, Sunan al-Nasa'i 52/5768, Sunan Ibn Majah 38/4345, Musnad Ahmad 8/1374, Muwatta Malik 61/1985, Sunan al-Darimi 24/3406 — all real counts, no placeholders |
| chapter list numbered/titled correctly | ✅ Bukhari's 97 chapters read 1, 2, 3 … in order with real Arabic **and** English titles ("كتاب بدء الوحى" / "Revelation", etc.) |
| hadith numbering — the "2 → 9 → 99" bug | ✅ **fixed and re-confirmed live**: Bukhari chapter 1 shows exactly its real 7 hadiths (hadith #1 is the famous "actions are by intentions"); chapter 2 crosses the two-digit boundary (8, 9, 10, 11 … 21, 22) with no break |
| hadith detail (Arabic + English narrator/text, Previous/Next) | ✅ real text both languages, navigation works |
| FTS5 search | 🔶 implemented, code-reviewed, **not interactively confirmed** — `adb shell input text` would not put text into the search field this session (Arabic input isn't supported by that adb command at all; even an ASCII term didn't register, cause not diagnosed) |
| the actual hadith.db **download** (network → zip → unzip → open) | ❌ **not verified** — blocked by the TLS problem below on every attempt |
| battery/library "Books" catalog tab | N/A — intentionally an honest placeholder, see the WIP note above |

**The TLS blocker, in detail:** `HandshakeException: CERTIFICATE_VERIFY_FAILED:
unable to get local issuer certificate` on every HTTPS call the app made this
session, including mushaf image-mode fetching (previously verified working in
STAGE 0). Checked and ruled out: the manifest's debug `networkSecurityConfig`
merge is present in the built APK (confirmed via `aapt2 dump xmltree`); the
bundled `proxy_debug_ca.pem`'s SHA-1 fingerprint is byte-identical to the
live Avast Web/Mail Shield root currently in Windows' trust store *and* to
the actual certificate `openssl s_client` observed being served for
`raw.githubusercontent.com` right now (a flat root→leaf chain, no missing
intermediate); a full emulator kill + relaunch did not clear it. The cause is
still unidentified — something about how the Avast interception is or isn't
reaching this specific emulator process changed since STAGE 0, or Dart's
engine and Android's Java networking layer handle the bundled trust anchor
differently in some case not yet isolated (mushaf pages use the same `Dio()`
client as the hadith download, which is why "different HTTP client" isn't the
answer either). Whoever has hands on the host machine next: check whether
Avast Web/Mail Shield's Web Shield is still enabled the same way it was
during STAGE 0, or just test on a physical device to sidestep the whole
question — a phone's own network never goes through the PC's Avast at all.

**Update, later the same day: the TLS blocker is gone and the download is
now actually verified.** The owner disabled Avast Web/Mail Shield entirely
(remotely, via TeamViewer) specifically to unblock this. The very first real
attempt afterward still failed — but with a plain `404`, not a TLS error,
immediately proving Avast really was the whole story. The 404 was a real,
separate bug of its own: `AppConfig.hadithDbUrl` pointed at `hadith/hadith.db`,
which was never pushed to `rafeeq-api` — only `hadith/hadith.zip` was. Fixed
the constant. After that: fresh install → tap download → real ~17 MB
transfer → unzip → the full 9-book list rendering with correct counts,
**repeated twice from a clean install each time**. The "❌ not verified" row
above is now ✅. See the WIP note at the top of this file for the two further
bugs (`setState`/Future, missing FTS5) that this real download testing then
surfaced and got fixed.

### Update 2026-09-02 — STAGE 3 Azkar & Tasbeeh: built and fully verified

Entirely offline (reads the already-bundled `quran_sciences.db`), so none of
this was affected by the TLS problem above.

| # | check | result |
|---|---|---|
| no duplicate azkar within a section | ✅ verified with a real SQL query — 0 duplicate `(section_id, body)` pairs across all 134 sections |
| tasbeeh counter counts on the **first** tap | ✅ **live-verified**: tapping the three-Quls dhikr (real target 3, parsed from its own "( ثلاث مرات )" text) once showed "3 / 1" immediately — the historical bug this check exists for (only counting after a reset) does not reproduce |
| auto-advance at the real target count | ✅ live-verified: the same item auto-advanced to item 4/25 exactly at the 3rd tap |
| fadl/source shown per dhikr | ✅ the bundled `footnote` field, shown under every dhikr's text (e.g. real Abu Dawud/Tirmidhi references) |
| haptics toggle | ✅ live-verified in the settings sheet, persisted |
| custom reminder times (no hardcoded 05:00/16:30) | ✅ live-verified: both reminders default to "متوقف" (off); picking a real time via the Material time picker (not a placeholder) updates the row and arms a real `zonedSchedule` |
| digital tasbeeh (free counter) | ✅ 33/100/1000 targets, matches Home's existing "السبحة" quick-access card |

### Update 2026-09-02 — STAGE 4 translation selector: done, emulator-verified

`AyahSciencesSheet`'s translation tab showed en/fr/ur stacked; now a
persisted dropdown (`translation_lang_provider.dart`) shows one at a time.
Verified live: ayah 1:1's translation tab opened with the dropdown on
English and only the Saheeh International text below it.

### Update 2026-09-02 — STAGE 5 New Muslim Guide: written and emulator-verified

Content lives in `lib/features/new_muslim/data/guide_content.dart` — written
by hand from mainstream, uncontroversial Sunni teaching per the owner's
explicit go-ahead, not fetched or scraped from anywhere.

| # | check | result |
|---|---|---|
| 5 topics, correct real content | ✅ pillars of Islam (5), articles of faith (6), wudu (8 steps), prayer steps (10), Quran intro (3 points) — all standard, universally-agreed teaching |
| reachable from Home | ✅ **and a real pre-existing bug fixed**: the quick-access card called `onNavigate(3)`, which STAGE 2 had silently repointed to Library when it renamed that tab slot — now pushes `NewMuslimGuideScreen` directly |
| Wudu detail renders correctly, in order | ✅ live-verified: all 8 real steps, ending with the Shahada dua shown in a Quran-font phrase box |
| bilingual (ar/en) | ✅ written by hand for each item (not through the easy_localization key system, matching how Quran/azkar/hadith text is content rather than UI chrome) |

### Update 2026-09-02 — STAGE 6 thematic search: built and now fully
### live-verified; 4 real repository-level bugs found and fixed along the way

`lib/features/search/data/topic_tree.dart` — a curated topic tree over real,
independently-verifiable ayah ranges (5 categories: aqeedah, akhlaq,
prophets' stories, rulings, the hereafter), which is the honest way to do
"find ayahs by meaning" without an offline semantic/embedding model this app
doesn't have — mislabeling keyword search as conceptual would itself be a
zero-mock-data violation. A second tab reuses `QuranRepository.search()`.
Reachable from a new icon in the Quran reader's toolbar, returning the
tapped ayah's page number so the reader can jump straight there.

| # | check | result |
|---|---|---|
| topic tree renders, all 5 categories | ✅ live-verified: العقيدة / الأخلاق / قصص الأنبياء / الأحكام / الآخرة all list with their real topics |
| a topic's real ayahs load correctly | ✅ live-verified: "الصبر" (patience) shows exactly the curated set — 2:153, 2:155, 2:156, 2:157, 3:200, 39:10 — correct Arabic text and references |
| keyword search (Quran) | ✅ implemented and re-verifiable via the same normalization now used for hadith search (see Bug #3 below) |
| tapping a result jumps the reader to that page | ✅ **confirmed on a repeat test**: tapping ayah 2:153 in the "الصبر" list navigated to page 23/604, showing that exact ayah at the bottom. The earlier "not confirmed" note reflected real tap-precision uncertainty in that session's testing, not an actual bug |

**Four real, repository-level bugs found while testing this against the now-
unblocked hadith download (all explained in full in the WIP note above,
summarized here since they were caught by Stage 6 code as much as Stage 2's):**
1. `setState(() => _future = someAsyncCall())` returns the assignment's value
   (a `Future`), which `setState` rejects at runtime — found via the hadith
   search box crashing, and it turned out an **identical, independent,
   pre-existing bug** was sitting in `mushaf_page_view.dart`'s `_retry()`
   too. Both fixed with a block body.
2. **`sqflite` on this Android build has no FTS5 module** — both
   `hadiths_fts` and `ayahs_search` (the FTS5 tables this app already
   shipped, built successfully with Python's own sqlite3) fail every query
   on-device with `SQLiteLog: (1) no such module: fts5`. Both
   `HadithRepository.search()` and `QuranRepository.search()` were rewritten
   to plain `LIKE` queries.
3. **The LIKE fix above still didn't actually work for Arabic.** Both
   `arabic` and `text_uthmani` are stored fully diacritized, so an ordinary
   undiacritized query never matches real vocalized text — confirmed
   directly against `hadith.db` with sqlite3 (`LIKE '%عمر%'` → 0 rows despite
   "عُمَرَ" appearing in the very first hadith). Fixed with a new
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
help either — terminals can only be granted click-only access, so commands
could not be typed.

**What that agent verified by hand across all 35 Dart files:** bracket balance,
local imports resolve, `AppColors.x` members exist, `'key'.tr()` keys exist with
ar/en parity 168/168, polygon coverage 6,236/6,236, catalog divergence figures,
pinned CDN bytes. All of that still holds and is now backed by the analyzer.

### Update 2026-09-02 — STAGE 7 (security/guest mode) & STAGE 8 (release)

Condensed here from a longer WIP note; full detail is in git at
`git show 10dbd35:HANDOVER.md`.

**STAGE 7.** Grepped all of `lib/` for `signIn`/`login`/`auth`/`FirebaseAuth`:
there is no authentication code anywhere, so "every offline feature works
without an account" is true by construction — guest mode is the only mode.
`AppConfig` re-confirmed secret-free. **One real gap fixed:**
`rafeeq_app/android/app/google-services.json` (a live Firebase config for
project `rafeeq-aldarb` — real API key + OAuth client id) had been committed
since the first commit and never gitignored. `git rm --cached`'d it (local
file untouched) and extended `rafeeq_app/.gitignore` to also cover `.env`,
`GoogleService-Info.plist`, `android/key.properties`, `*.jks`/`*.keystore`.
Risk note: a Firebase **Android** API key is designed to ship in-client and is
not a server secret (protection is API-key restrictions + Security Rules), but
it shouldn't be in git per this project's own checklist and it is in history
from commit 1 — worth the owner knowing. **Google sign-in itself is still not
built** — no `firebase_auth`/`google_sign_in` in `pubspec.yaml`; finishing it
needs the owner to register a release SHA-1 in the Firebase console (no agent
can do that). Flagged, not half-built.

**STAGE 8.** Ran `flutter clean` → `pub get` → `analyze` → `build apk --release
--split-per-abi` for real: succeeds (armeabi-v7a / arm64-v8a / x86_64 =
35.8 / 37.8 / 39.2 MB); the x86_64 APK installs and runs on a fresh emulator
(Arabic UI intact, honest "enable location" empty state, no fake data). Removed
`android:usesCleartextTraffic="true"` from the **main** manifest — a full `lib/`
grep finds zero `http://` URLs, so it was a leftover (unrelated to the
debug-only `network_security_config`, which handles the Avast TLS root and is a
separate mechanism); release now defaults to disallowing cleartext. **Still
blocked:** the release build is signed with the **debug** keystore (a
`// TODO: Add your own signing config` sits in `android/app/build.gradle.kts`).
Real signing needs the owner's own keystore/alias/passwords — an agent
generating one would lock everyone else out of re-signing updates.

### Update 2026-09-02 (next session) — STAGE 2 Library "Books" catalog finished + emulator-verified end to end

Picked up an in-flight, non-compiling edit (previous session died mid-write in
`library_screen.dart`'s `_BookCard`). Finished it: `_CatalogTab` is now a real
download/open catalog over `lib/features/library/data/book_catalog.dart` — 4
real public-domain classical texts (Riyad as-Salihin, Mukhtasar Minhaj
al-Qasidin, Ibn al-Qayyim's al-Fawaid, Ibn al-Jawzi's Sayd al-Khatir) hosted
as PDFs on archive.org. **All 4 `downloadUrl`s checked with a real `curl -L`
GET on 2026-09-02: HTTP 200, `application/pdf`;** `approxSizeBytes` is each
response's measured Content-Length (the previous session's guesses were off —
al-Fawaid was 15 MB in the catalog, actually 6.29 MB — all four are now exact).
Download reuses the same `DownloadManager` as the hadith DB; `BookReaderScreen`
opens the file with `SfPdfViewer.file`.

**Verified live on the Android emulator (Medium Phone API 36):** المكتبة →
الكتالوج lists the 4 books with real metadata and sizes; tapped تنزيل on
al-Fawaid → real download → the card flipped to فتح → the reader opened the
**real archive.org PDF** (title page: "الفوائد لابن القيم، تحقيق عصام الدين
الصبابطي، دار الحديث القاهرة"). File on disk is exactly 6,285,456 bytes,
`%PDF-1.5`. Then **airplane mode ON**, reopened from the catalog → still
renders, page-scroll to page 2 works. This is T14 done → STAGE 2 done → the
whole 20-task pipeline is now complete.

Catalog is 4 titles, honestly labeled "a starting set" — the owner's list also
named Ibn Taymiyyah, al-Hakim al-Tirmidhi, Ibn Abi al-Dunya, and al-Jaziri's
*al-Fiqh ala al-Madhahib al-Arba'ah* (1941 — needs its own licensing check,
not public-domain by author death). More can be added the same way: one
`LibraryBook` entry per title, `downloadUrl` verified with a real GET.

Also fixed `scripts/checkpoint.ps1` — it read/wrote `HANDOVER.md` through
PowerShell 5.1's ANSI default and **corrupted every Arabic char + em-dash on
each run** (one such corruption, commit `a57ac7b`, was caught and the file
restored from `10dbd35`); it now forces UTF-8 both directions and `cp.bat` is
hardened so a Git-Bash-mangled `/s` can't become a junk commit. **Run `cp.bat`
from PowerShell/cmd, not Git Bash.**

### Update 2026-09-02 — P2‑7 (Adhan audio/video): code done, verification pending the video upload

Owner ruled out YouTube/copyrighted content (the no-scraping rule stands) and
asked for a **licence-clean** mosque video. Got **5 Pixabay clips** (Pixabay
Content License — free commercial use, no attribution): `haram_makkah`,
`kaaba`, `madina_nabawi`, `mosque_prayer`, `mosque_ottoman` (1–5.5 MB each),
staged in `scripts/adhan_video_build/` (gitignored).

Code: `video_player` added; `adhan_video_catalog.dart` +
`adhan_presentation_provider.dart` (`audioOnly|video` + `videoId`, persisted,
default audio; `resolveAdhanVideoPath`); `AdhanFullScreenScreen` gains an
optional `videoPath` → muted looped `VideoPlayer` behind the karaoke text
(BoxFit.cover + scrim), gradient fallback; payload/scheduler/navigation carry
`video`; `adhan_settings_screen` `_PresentationCard` (`صوت | فيديو` +
5-clip download/pick + Pixabay source line + honest "video only while the
screen is on" note); 30-adhan cap (`AdhanCatalogService.maxTotalAdhans` +
`AdhanLimitReached`). +8 keys ×5 (parity 286). `analyze` clean, `test` 13/13.

**Left:** run `python scripts/upload_adhan_videos.py` to host the 5 clips on
`rafeeq-api/adhan/video/` (the in-session `gh api` push was classifier-blocked
— needs owner OK or a manual run), then emulator-verify the pick → download →
"تجربة" → video-behind-karaoke flow and the 30-adhan refusal.

### Update 2026-09-03 — P2‑7 clips uploaded + hosted; download/select/persist
### verified; full-screen video render **not** verified (emulator limitation)

Ran `python scripts/upload_adhan_videos.py` (owner's prompt explicitly said
"ارفع الـ5 فيديوهات … اسأل الأونر أو شغّل السكربت" — read as authorization to
just run it). All 5 uploaded to `tito423/rafeeq-api/adhan/video/<id>.mp4`.
**Every URL independently re-verified** with `curl -sIL`: HTTP 200, and
`Content-Length` byte-identical to the local file (`haram_makkah` 2,307,544 ·
`kaaba` 3,981,671 · `madina_nabawi` 5,515,868 · `mosque_ottoman` 1,717,259 ·
`mosque_prayer` 981,129 — all exact). GitHub raw serves them as
`application/octet-stream` rather than `video/mp4`, same as every other
`rafeeq-api` asset; irrelevant here since `DownloadManager` fetches raw bytes
to a local file before `video_player` ever opens them.

**Verified live on `emulator-5554`** (fresh install, `pm clear` then a normal
relaunch): صوت↔فيديو switch; downloading المسجد النبوي (madina_nabawi, the
largest clip) showed a real progress bar and completed, auto-selecting it
(مختار) — one clip auto-selects when it's the only one downloaded, matching
`AdhanPresentationState` defaulting to the first available; a silent "فيديو
الأذان — تم التنزيل" download-complete notification appeared in the shade;
tapping "تجربة" for الظهر posted a real notification titled "الصلاة — الظهر
(تجربة)" on the correct `radh_full_azan1`-family channel with the expected
Stop/Mute actions; **the video-mode selection (فيديو + المسجد النبوي) survived
a full `am force-stop` + relaunch** — confirms the `adhan_presentation_v1` /
`adhan_video_id_v1` persistence works.

**Not verified this session: the actual full-screen screen showing the video
behind the karaoke text.** This was attempted extensively and is worth
recording in detail so the next session doesn't repeat the same dead ends:

- A live tap on the notification body (the normal "app already running"
  path) reliably dismissed/re-focused the app but never navigated to
  `AdhanFullScreenScreen` — tried with visually-estimated coordinates first
  (several misses traced to a coordinate-scaling mistake: the screenshots
  Claude sees are downscaled 900×2000 from the device's real 1080×2400, so a
  position read off the image has to be **multiplied by 1.2** before sending
  it to `adb shell input tap`; several early attempts skipped that step) and
  then with `uiautomator dump`-verified exact bounds (which worked correctly
  for a native Android permission dialog in the same session) — still no
  navigation, and `adb logcat` around the tap showed **no Flutter/exception
  output at all**, i.e. not a crash, just no observed effect.
- Tried the documented real trigger — **lock the phone, let the alarm fire
  while locked** (`AndroidNotificationCategory.alarm` + `fullScreenIntent:
  true` + `MainActivity`'s `showWhenLocked`/`turnScreenOn`, per the doc
  comment in `adhan_alarm_service.dart`) — repeatedly. First found that
  Android 14+'s `USE_FULL_SCREEN_INTENT` app-op defaults to **reject** and
  has to be explicitly granted (`adb shell appops set <pkg>
  USE_FULL_SCREEN_INTENT allow`); after granting it, still nothing. Then
  found this specific AVD (`Medium Phone API 36`, Android 16) has **no
  keyguard configured by default** (`dumpsys window` → `isKeyguardShowing=
  false` even while `mWakefulness=Asleep`) — Android's fullScreenIntent
  auto-launch is documented to require the device actually be
  **keyguard-locked**, not just screen-off, so this AVD's default state can
  never satisfy it. Set a real PIN with `adb shell locksettings set-pin
  1234` to force a genuine keyguard (`isKeyguardShowing=true` confirmed) and
  tried again — the notification fired (confirmed via `dumpsys notification`)
  but the device stayed asleep with no window regaining focus, and waking it
  afterward went straight back to whatever screen was open before, never the
  full-screen adhan. Cleared the PIN again afterward
  (`locksettings clear --old 1234`) so the emulator was left in its original
  no-lock state.
- Also tried force-stopping the app to exercise the **cold-launch** payload
  path (`main.dart`'s `consumeColdLaunchPayload`) instead of the live-tap
  one — but `am force-stop` turned out to **cancel the app's own ongoing
  test notification** (confirmed via `dumpsys notification` losing the
  entry), so that path couldn't be exercised either without a live
  notification to tap.

**Why this reads as an environment/automation limitation, not a code bug:**
the wiring was re-read end to end (`AdhanPayload.tryParse`, `rootNavigatorKey`
correctly passed to `MaterialApp.navigatorKey`, `onDidReceiveNotificationResponse`'s
`default:` case calling `onOpenAdhan`, `scheduleTest`/`scheduleDaily` sharing
the exact same `_detailsFor`/payload path) and nothing looks wrong; this is
also **the same underlying native alarm/full-screen-intent mechanism STAGE 1
already verified working on this project**, with real device interaction
(lock the phone, alarm fires, full-screen karaoke view appears) — P2‑7 only
adds an optional `videoPath` parameter on top of it. Simulated touch input on
notifications/keyguard is a known-fragile target for scripted ADB interaction
in general. **Next session: verify on a real Android phone** — lock it for
real, fire a "تجربة" test from Adhan settings, and confirm the video plays
behind the karaoke text; that sidesteps every issue hit here (no keyguard
config quirk, no touch-injection uncertainty). If it still doesn't navigate
on a real phone, *then* treat it as a real bug and start from
`adhan_navigation.dart`'s `openAdhanFromPayload`.

30-adhan cap and the honest "video only while the screen is on" note were
visually re-confirmed present in the settings UI; the cap's actual refusal
behavior (importing a 31st adhan) was not re-exercised this session (no
catalog changes were made to it).

### Update 2026-09-03 — launcher icon redesigned: mosque silhouette,
### real `AppColors` palette; a real transparency bug found + fixed

Owner ask: make the launcher icon "لايق يشبه الثيم بتاع التطبيق ويكون فيها
شكل المسجد" (fitting, matching the app's theme, with a mosque shape).
Redesigned `assets/icon/src/{icon_full,icon_fg,icon_bg}.svg` — a flat gold
mosque silhouette (central onion-free hemispherical dome + crescent finial,
two smaller flanking domes, two minarets with balcony rings, an arched
doorway) over a radial background gradient now built from the **actual**
`AppColors` constants (`night` `#071625` → `primaryContainer`-ish `#0F3D33`
→ `primarySoft` `#16A085` at the centre) instead of the previous
hand-picked approximation — this is the literal reason it now "matches the
theme": same numbers as `lib/core/theme/app_colors.dart`, not just a similar
green. Gold gradients (`#F7E7AC`→`#C99E2E`/`#B4841F`) unchanged in spirit
from the original icon.

**A real bug found while doing this (present in the *previous* icon too,
not something this change introduced):** the documented regen command
(`chrome --headless --screenshot=...`) bakes an **opaque white** page
background into the PNG unless `--default-background-color=00000000` is
passed — confirmed by checking a corner pixel's alpha (`A=255`, not `0`) on
both the new render *and* the already-shipped `app_icon_foreground.png`
from the P2‑1.5 commit. For an **adaptive-icon foreground** layer this is a
real defect: without alpha, the foreground fully occludes the background
layer instead of letting it show through outside the mark. It evidently
went unnoticed in P2‑1.5's own verification. Fixed by adding the flag for
the foreground render only (`icon_full`/`icon_bg` don't need transparency,
they're meant to be fully opaque); `assets/icon/src/README.md`'s regen
recipe now includes the flag and a one-line pixel-alpha sanity check so
this can't silently regress again.

**Verified live on `emulator-5554`:** `dart run flutter_launcher_icons` →
`flutter build apk --debug` → install → home screen → app drawer: the
"Rafeeq AlDarb" icon shows the teal→navy gradient (now real `AppColors`
values) genuinely showing through the adaptive mask, with the gold mosque
mark (dome, crescent, two side domes, two minarets, dark doorway arch) all
clearly legible — cropped and zoomed in from a real screenshot to confirm,
not just eyeballed at native size. Also rendered the flat `icon_full.png` at
96×96 and 48×48 (downscaled with .NET `System.Drawing`, since Chrome's
`--window-size` doesn't rescale an SVG's own `width`/`height`) to confirm
the silhouette stays readable at realistic launcher sizes — it does at
both. `flutter analyze` clean after the rebuild. Not re-verified: iOS (no
iOS toolchain on this Windows box — `flutter_launcher_icons` regenerated
the `Assets.xcassets` PNGs the same way as before, un-tested since Phase 1).

### Update 2026-09-02 — P2‑5 (unified download manager) & P2‑6 (persistent prayer card): done, emulator-verified

**P2‑5.** `DownloadNotifications` (in `download_manager.dart`) grew generic
`showProgress`/`showComplete`/`clear` (app icon, determinate bar, ~900 ms
throttle, requests `POST_NOTIFICATIONS`) and is now called from
`MushafPageService.prefetchEdition` and `AyahAudioService.downloadSurah` too —
so **every** download kind posts a live status-bar notification, not just
`DownloadManager` files. `MushafPageService` / `AyahAudioService` also gained
`pause*`/`resume*` (the page/ayah loop idles while paused). New
`downloads/data/downloads_controller.dart` = a read-only `storageSummaryProvider`
aggregator + `freeCategory`. `DownloadsScreen` → 3 tabs
`[نظرة عامة | المصاحف | التلاوات]`; the overview tab shows total storage, a
row per category (size · count · تفريغ with confirm), free-all, and a
downloaded hadith/books item list. Verified live: notification advances +
clears on cancel; `تفريغ` frees + refreshes; **pause froze a mushaf DL at
p.5, resume continued to p.11**. Minor: 3 tabs not the 5 labelled sections;
some toasts not re-shot.

**P2‑6.** New `core/services/prayer_status_notification.dart` — an ongoing
LOW-importance status card: title `${prayer} · ${clock}` (localized + Arabic
digits), a **native chronometer countdown** (ticks with the app killed), body
= Hijri date from **AlAdhan's cached `times.hijriDate`** (localized month name,
not the `hijri` package's calc, which was a month off), one `zonedSchedule`
rollover, and an honest "enable location" card when there are no times. Opt-in
`prayer_status_enabled_provider` (default off) + a `SwitchListTile` in Adhan
settings. `AppShell` is now a `ConsumerStatefulWidget` +
`WidgetsBindingObserver` that re-syncs the card on times-resolve / toggle /
resume. Verified live (mock GPS): card appears with the icon, "الفجر · ٠٥:٠٨",
a countdown ticking 6:06→5:59, "٢٠ ربيع الأول ١٤٤٨ هـ"; toggle off → gone.

### Update 2026-09-02 — P2‑4b book **text editions**: built, hosted, emulator-verified

Every library book now has a **نص** (structured text) edition beside the
**مصوّر** PDF. Source: al-Maktaba al-Shamela (owner's pick — §5.7). Pipeline:
`scripts/build_book_text.py` (walks `shamela.ws/ajax/pageContent`'s `nextId`
chain, strips copy-buttons/anchors/`div.hamesh` footnotes, tags ayat, builds a
فهرس from section titles, computes `printReliable`) → `finalize_book_text.py`
(back-fills `printReliable`) → `upload_book_text.py` (`gh api --input` PUT to
`tito423/rafeeq-api/books/text/<id>.json`; base64 is too big for argv). Build
dir `scripts/book_text_build/` is gitignored — regenerable + hosted, like
`hadith.zip`.

Built & hosted (all raw URLs HTTP 200, byte-size matched): riyad 810p/387§,
sayd_al_khatir 893p/394§, mukhtasar 408p/226§, al_fawaid 209p/105§,
al_ubudiyyah 109p/107§ (~5.6 MB total). 0 empty pages, no HTML leakage, text
fully vocalised, spot-checked against the known openings of each work.

New: `book_text.dart` (model + `...`-noise filter), `book_text_reader_screen.dart`
(page-at-a-time; فهرس drawer w/ filter + level indent + bookmark chips;
in-book search sheet w/ `normalizeArabic`; A+/A− font; per-book bookmarks on
`pageIndex`; always-visible tappable provenance strip; OCR-badge hook).
`LibraryBook.textEdition` / `.textDownloadId` / `.hasText`. `library_screen.dart`
gains a `مصوّر | نص` `SegmentedButton` per card (size + action follow the
selection; independent download/cache per edition); مكتبتي lists one row per
(book, edition). +23 keys ×5 (parity 260). `flutter analyze` clean,
`flutter test` 13/13.

**Emulator-verified (`emulator-5554`):** switch flips size/action; downloaded
صيد الخاطر + رياض + مختصر text editions from rafeeq-api; مكتبتي rows correct;
**صيد الخاطر** (`printReliable`) shows "صفحة N" + فهرس trailing = printed pages;
**رياض** (`!printReliable` — its Shamela `pageNum` drops ~100 four times) shows
sequence only + فهرس trailing = seq #, and the chapter order matched Nawawi
despite that; فهرس jump, font, bookmark toggle/strip/jump, provenance sheet all
work; **airplane-mode** relaunch → نص opens from cache with page + font +
bookmark restored; mukhtasar's 2-level فهرس renders indented.

**Not verified:** in-book *search* query→results — `adb shell input text`
can't inject Arabic (same as the hadith FTS5 search above). Sheet opens; code
reuses Stage 6's verified `normalizeArabic` + `.contains()` path. Needs a real
device or an Arabic IME.

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
   "offline-first" and has been open since STAGE 0.
6. **Fix or work around the TLS blocker (§7)** before trusting any more
   network-verification results — it silently invalidates re-checks of
   already-passed items (mushaf image mode) too, not just new work.
7. ~~**STAGE 2 — Hadith hub.**~~ **DONE 2026-09-02 on the emulator** (verified
   via direct DB injection, not the live download — §7 STAGE 2 table). Still
   open: the download itself (blocked by item 6), FTS5 search interactive
   confirmation, and the Library "Books" catalog (real sources researched,
   owner needs to pick a specific edition per title before anything
   downloads — see the WIP note above).
8. ~~**STAGE 3 — Azkar & Tasbeeh.**~~ **DONE 2026-09-02, fully verified live**
   (§7 STAGE 3 table) — no network involved, so nothing here was blocked by
   item 6.
9. ~~**STAGE 4 — Translation selector.**~~ **DONE 2026-09-02, emulator-verified**
   (§7).
10. ~~**STAGE 5 — New Muslim Guide.**~~ **DONE 2026-09-02, emulator-verified**
    (§7) — content written by hand from mainstream Sunni teaching, per the
    owner's explicit approval.
11. ~~**Fix or work around the TLS blocker.**~~ **RESOLVED 2026-09-02** —
    owner disabled Avast entirely. The real hadith download now works
    end-to-end (§7). Re-verify mushaf image-mode fetching too when next on
    the emulator — it hit the identical TLS error earlier and was never
    re-confirmed after Avast was turned off.
12. ~~**STAGE 6 — Thematic search.**~~ **DONE 2026-09-02, fully live-verified**
    (§7) — the topic tree, a topic's ayahs, keyword search, and
    tap-to-jump-to-page are all confirmed live.
13. **Three bug classes worth a quick sweep before trusting more of this
    codebase:** (a) `setState(() => x = someAsyncCall())` — found twice
    independently (`library_screen.dart`, `mushaf_page_view.dart`) already;
    grep for the shape if adding more. (b) any other spot assuming FTS5
    works — `sqflite` has no FTS5 module on this Android build; both search
    repositories are now `LIKE`-based, but don't add a new FTS5 MATCH query
    without testing it live first. (c) **any Arabic text search must
    normalize both sides** with `lib/core/utils/arabic_normalize.dart` —
    `arabic`/`text_uthmani` columns are stored fully diacritized, so a raw
    `LIKE`/`.contains()` against undiacritized user input silently matches
    nothing; and never load a whole large table into memory at once on this
    device — page it (see `HadithRepository.search()`'s doc for the real OOM
    crash this caused and how it was fixed).
14. **STAGE 2's Library "Books" catalog is still open — the one real
    remaining feature gap.** Owner said to use al-Maktaba al-Shamela or
    another free Islamic-books source (no further STOP AND ASK) — real
    archive.org sources were already found for every named title (see
    WORK_QUEUE Stage 2); `syncfusion_flutter_pdfviewer` is already a pubspec
    dependency (unused so far) suggesting a PDF-based reader was the
    original plan. Still needs: picking a specific edition/tahqiq per title,
    the actual catalog data structure, download wiring (reuse
    `DownloadManager`), and a reader screen.
15. ~~**STAGE 7 — Security & guest mode.**~~ **DONE 2026-09-02** — no
    credentials in the client, no auth code at all (so guest mode is total
    by construction), and a real pre-existing gap fixed (an untracked
    `google-services.json`, see §9). **Still blocked:** actually building
    Google sign-in needs the owner to register a release SHA-1 in the
    already-existing `rafeeq-aldarb` Firebase project's console.
16. ~~**STAGE 8 — Release.**~~ **DONE 2026-09-02** — `flutter clean` → `pub
    get` → `analyze` → `build apk --release --split-per-abi` all succeed and
    the resulting APK installs and runs correctly; a real
    `usesCleartextTraffic="true"` release-security gap was found and fixed
    along the way (§7). **Still blocked:** the release build is signed with
    the debug keystore — real signing needs the owner's own keystore file,
    alias, and passwords; no agent session should generate one itself.

---

## 9. SECURITY — act on this

The Cloudflare R2 **Secret Access Key** was pasted into a chat transcript and
must be treated as public.

**Rotate it:** Cloudflare → R2 → Manage R2 API Tokens → delete the
`rafeeq-aldarb-data` token → create a new one → update `.env`.

No credentials live in the client; `AppConfig` is secret-free. Keep it so.

**2026-09-02:** `rafeeq_app/android/app/google-services.json` (a real
Firebase config for project `rafeeq-aldarb`, incl. a real API key and OAuth
client ID) had been committed since this project's very first commit and was
never gitignored. Untracked it and added it (plus `.env`,
`GoogleService-Info.plist`, `android/key.properties`, `*.jks`/`*.keystore`)
to `rafeeq_app/.gitignore` — see §7's STAGE 7 note for the full account,
including why this one is lower-severity than the R2 key above (Firebase
Android API keys are meant to ship in-app; they still shouldn't sit in git
per this project's own convention, and this one already is in git history
from that first commit).

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
| Hadith (9 books, 40,943 hadiths) | A7med3bdulBaset/hadith-json, built into `hadith.db` by `scripts/build_hadith_db.py`, hosted on `tito423/rafeeq-api` | open |
| Library book **image PDFs** | archive.org public-domain scans (downloaded direct on demand) | PD (authors d. 597–751 AH) |
| Library book **text editions** | al-Maktaba al-Shamela (`shamela.ws`), via `scripts/build_book_text.py` → `rafeeq-api/books/text/*.json` | classical text PD; muḥaqqiq apparatus stripped — owner decision, see §5.7 |
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

