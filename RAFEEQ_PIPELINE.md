# RAFIQ AL-DARB — Autonomous Rebuild Pipeline

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
| 6 | Mushaf viewer, dynamic page fetch + cache | 🔶 | Switched from raster scans to **vector SVG pages** (quranpedia/quran-svg, CC0-1.0, pinned commit b91d39e). `MushafPageService`: memory+disk cache, integrity-validated (rejects truncated pages), offline after first view. `MushafPageView`: SvgPicture + InteractiveViewer, glyphs recoloured via srcIn so night mode is a real night mode. Whole mushaf ≈350MB raw / ~24MB brotli vs the 233MB PNG zip purged in T1. **Not yet compile-verified — needs `flutter analyze`.** |
| 7 | Real ayah coordinates (replace fake JSON) | 🔶 | **Resolved with real data.** `scripts/build_mushaf_svg.py` extracts the `ayahPolygon` hit layer shipped inside the source SVGs → `assets/data/mushaf/hafs_kfqc_polygons.json` (0.73MB, normalized 0..1 per-page viewBox). **6,236/6,236 ayahs covered, verified against quran_local.db.** Polygons, not boxes: 4,221 ayahs (68%) span multiple lines, so a union bounding box would mis-highlight most of the Quran. Hit-testing is even-odd ray cast per ring. Abandoned the earlier `build_ayah_coords.py` (quran.com-images `glyph_ayah_bbox` is declared but ships **zero rows**). QuranFlash was explicitly ruled out — reverse-engineering a licensed product. **Not yet compile-verified.** |
| 8 | Ayah sciences bottom sheet (real SQLite tafseer/i'rab/meanings) | ⏳ | |
| 9 | Professional dropdowns (reciters/translations) | ⏳ | |
| 10 | 10 authentic adhans (no music) | ⏳ | rafeeq-api/downloads/adhans = 10 real MP3s verified (ID3, 0.4–1.9MB) |
| 11 | Custom adhan MP3 from device | ⏳ | |
| 12 | Adhan UI + karaoke sync | ⏳ | |
| 13 | Android native alarm (exact alarms, wakelock, mute/stop actions) | ⏳ | |
| 14 | Library: catalog / offline PDFs / viewer | ⏳ | |
| 15 | 9 Hadith books hub (hierarchical) | ⏳ | hadith.db has 9 collections, 36,461 hadiths — rebuilt clean |
| 16 | Azkar + Tasbeeh (dedup, haptics) | ⏳ | |
| 17 | New Muslim guide | ⏳ | |
| 18 | Thematic Quran search | ⏳ | |
| 19 | Security & offline guest mode | ⏳ | R2 keys were hardcoded in client — removed |
| 20 | Final build + git | ⏳ | |

## Build Log
- [T1 started] Reconnaissance complete. Identified all fake/bloat sources. Beginning purge.

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
