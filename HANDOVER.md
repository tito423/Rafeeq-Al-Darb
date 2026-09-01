# HANDOVER — Rafiq Al-Darb (رفيق الدرب)

**For:** the next AI agent picking up this project (Antigravity IDE, Cline, or any other).
**Written by:** the previous agent, at commit `238caad`.
**Read this file completely before touching anything.**

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

**Nothing in commits `bb6d0f2` → `9b32116` has been compiled.**

The previous agent worked from an isolated Linux sandbox with only the project
folder mounted: no Flutter, no Windows shell, and the Dart/Flutter SDK downloads
were blocked by that sandbox's network policy (403). Computer control was no
help either — terminals can only be granted click-only access, so commands
could not be typed.

**What WAS verified across all 35 Dart files:**
- bracket/paren/bracket balance (comment- and string-aware)
- every local import resolves to a real file
- every `AppColors.x` member exists
- every `'key'.tr()` exists in `ar.json`; ar/en parity 168/168
- polygon coverage 6,236/6,236 against `quran_local.db`
- catalog divergence figures recomputed from the built polygon sets
- pinned CDN URL returns the exact bytes of the local build

**What was NOT verified:** type checking, widget-tree validity at runtime,
null-safety, package API signatures, and anything runtime.

### Likely places the analyzer will complain
Check these first — they are the newest and least-exercised:
1. `flutter_svg` API: `SvgPicture.string(..., colorFilter:, placeholderBuilder:)`
2. `just_audio` / `dio` signatures in `ayah_audio_service.dart`
3. `FutureBuilder<String>` generics in `mushaf_page_view.dart`
4. The collection-`if`/`else ...[ ]` block in `ayah_sciences_sheet.dart`
5. Riverpod `StateNotifierProvider` usage in `mushaf_edition.dart`
6. Unused imports/locals left after refactors

---

## 8. NEXT TASKS, in priority order

1. **Make it compile.** `.\check.bat` → fix → repeat until `analyze` is CLEAN.
2. **Run it on a device.** Verify, in this order:
   - Quran tab → switch to image mode → a page renders
   - **Tap an ayah → the highlight lands on the right words** (test a
     multi-line ayah, e.g. 2:6 on page 3 — it must highlight *two* line
     fragments, not one big box)
   - Ayah card shows real tafsir / EN + FR translation / i'rab / meanings
   - Switch to Warsh → open a diverging surah → card must show the
     "unavailable for this riwayah" notice, **not** tafsir
   - Settings → Downloads → download a mushaf and a surah's recitation,
     then turn off the network and confirm both still work
3. **Performance check.** `flutter_svg` parses each page at runtime and pages
   have thousands of paths. If paging feels slow, precompile to
   `vector_graphics` `.vec` — do **not** revert to raster.
4. **Then** continue `RAFEEQ_PIPELINE.md` tasks 8–20 (adhan, library, hadith,
   azkar, new-Muslim guide, thematic search, release).

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

## 11. Working notes for whoever continues

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

