# RAFIQ AL-DARB — Autonomous Rebuild Pipeline

> Mission: Rebuild "Rafeeq Al-Darb" as a masterpiece mix of Sakinati + Ayat + QuranFlash + Al-Quran Al-Azeem.
> Rules: ZERO mock data • flutter analyze gate after every task • real SQLite/API/R2 only • no stopping.

**Working app:** `rafeeq_app/` (Flutter 3.38.7, Dart 3.10)
**Content origin (real, no secrets):** `rafeeq-api/` local mirror (hosted via GitHub raw) + bundled real SQLite + verified public APIs (api.quran.com, api.alquran.cloud, api.aladhan.com, cdn.islamic.network).

| # | Task | Status | Notes / Verification |
|---|------|--------|----------------------|
| 1 | Purge: 400MB bloat, fake data, manifest, pubspec | ✅ | Deleted: quran_images.zip 233MB, hadith.db.bak 44MB, fake .m4a adhans 19MB, build/.dart_tool/node_modules, 60+ junk files, R2 keys + serviceAccountKey.json. Preserved real data: hadith9 JSONs→rafeeq-api/staging, 17 books→rafeeq-api/downloads/books, quran_local.db bundled. Manifest permissions verified (INTERNET/EXACT_ALARM/FS_MEDIA_PLAYBACK/POST_NOTIFICATIONS). Clean pubspec (no firebase/minio/video). `flutter analyze`: 0 issues |
| 2 | UI/UX research + master theme | ⏳ | |
| 3 | Real DB pipeline: quran_sciences.db schema + populate from real API data | ⏳ | |
| 4 | Offline download engine (dio + path_provider + progress UI + Android notification) | ⏳ | |
| 5 | Authentic i18n via easy_localization (real ar/en JSON) | ⏳ | |
| 6 | Mushaf viewer, dynamic page fetch + cache | ⏳ | |
| 7 | Real ayah coordinates (replace fake JSON) | ⏳ | old pipeline_temp/quranflash_coords.json was FAKE (hand-invented) |
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
