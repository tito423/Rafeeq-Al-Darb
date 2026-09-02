# PHASE2_RESEARCH — P2‑8 competitor feature research (2026-09-03)

**Rule 2 stands while reading this file:** everything below comes from public
app-store listings and marketing pages — ideas and feature *descriptions*
only. Zero data, assets, or scraped content from any of these apps goes into
Rafiq Al-Darb. Every row's "data source needed" column names a source Rafiq
is actually allowed to use (usually one already integrated), never the
competitor itself.

**Apps researched:** سكينة (two distinct apps share this name — see below),
آيات *Ayat* (King Saud University's Electronic Mosshaf project), قرآن فلاش
*QuranFlash*, ختمة *Khatmah* (plus a second app, "Khatma: Group Quran
Tracker", for the group-khatma idea specifically).

**Cross-reference first — don't re-propose what's already spec'd or built.**
Several obvious candidates from these apps are *already* Rafiq features or
already-approved upcoming stages:

| Already covered | Where |
|---|---|
| Personal khatma tracker (daily target, progress ring, days-left, reminder) | **P2‑11**, spec'd, next in the queue after this file |
| Friday-specific reminder for a surah (echoes Khatmah's "read Al-Kahf on Friday" nudge) | **P2‑12** (Sunan as-Suwar) |
| 5 themes incl. a customizable one | **P2‑2**, done |
| Multiple Mushaf editions (Hafs/Shubah/Warsh/Qalun/Duri) | Phase 1, done |
| Multiple reciters, per-ayah audio, offline download | Phase 1 + P2‑5, done |
| Tafsir (2 sources) + translations (en/fr/ur) + i'rab + word meanings | Phase 1, done |
| Du'a / adhkar collection (Hisn al-Muslim, 134 sections/298 items) | Phase 1 (Azkar), done |
| Book text reader with font size control (A+/A−) | P2‑4b, done |
| Bookmarks (per-book) | P2‑4b, done |

---

## Feature research table

| # | Feature | Source app(s) | What it does | Build effort | Fit for Rafiq | Data source needed |
|---|---|---|---|---|---|---|
| 1 | **Memorization repeat-loop** — repeat one ayah/range N times with a gap between reps | Ayat (KSU) | "repeat each Aya multiple times with a customizable time interval" for hifظ drilling | **S** | Strong — builds directly on the existing `AyahAudioService` per-ayah cache, no new content | none (uses audio already on-device) |
| 2 | **Share an ayah as an image** | QuranFlash (also independently on PHASE2.md's own illustrative list) | Render the ayah text (+ translation) as a shareable card image | **S** | Strong — matches the "share current reading" pattern Khatmah also does, no licensing question (it's the app's own bundled Quran text) | none (renders from `quran_local.db`) |
| 3 | **Multi-tafsir compare view** — see two tafsirs side by side instead of tab-switching | QuranFlash ("9 tafsirs… viewed simultaneously") | Toggle the existing `AyahSciencesSheet` tafsir tab between "one at a time" and "stacked/compare" | **S** | Good — cosmetic layout change over data Rafiq already has (Muyassar + Jalalayn) | none |
| 4 | **Topical audio playlists** (e.g. "قبل النوم", "آيات الشفاء") | Sakinah (the audio-focused one, id1503484686) | Curated ayah-range playlists by theme, not full-surah | **S–M** | Good — same honest-curation approach as the existing `topic_tree.dart` (Stage 6), just applied to audio instead of reading; must stay independently verifiable ranges, not "AI picks" | none (reuses bundled reciter audio + `quran_local.db` ranges) |
| 5 | **Listening statistics** ("تقارير وإحصاءات لمدة استماعك") | Sakinah | Minutes listened, streak, per-reciter breakdown | **S–M** | Decent, low priority — pure local telemetry over existing playback events | none (local `SharedPreferences` counters) |
| 6 | **Page-flip animation / double-page view** | QuranFlash | Visual page-turn transition; optional two-page spread in landscape/tablet | **S–M** | Cosmetic-only, real polish item but not core — revisit during P2‑10's usability pass | none |
| 7 | **Per-ayah private notes** (distinct from bookmarks — a free-text note attached to a verse) | QuranFlash ("take notes for each verse") | A small text field saved locally per ayah | **S** | Good, clean local-state feature, no licensing question | none (local storage) |
| 8 | **Colored Tajweed mushaf edition** | Ayat (KSU) — "copy of Mosshaf Al-Tajweed (colored according to Tajweed rules)" | A 6th mushaf edition with rule-colored glyphs | **M–L** | Wanted, but gated on finding a **real CC0/open** tajweed-color dataset compatible with the existing `quranpedia/quran-svg` pipeline (§5.2/5.3's numbering-divergence guard would need re-running against it too) | needs research — not yet identified; **do not build until a clean source is confirmed**, same standard as every other mushaf edition |
| 9 | **More translation languages** (Ayat ships 20+; Rafiq has en/fr/ur) | Ayat (KSU) | Additional Quran-translation languages in the sciences sheet | **M** | Good fit, same trusted source (`alquran.cloud` editions) Rafiq already pulls en/fr/ur from — just more editions to ingest via the existing `ingest_translations.py` | `alquran.cloud` (already-approved source, §10) |
| 10 | **Prayer-time home-screen widget** | Khatmah ("5 widget types") | An Android home-screen widget (glance/AppWidget) showing next prayer + countdown | **L** | Good long-term fit (Rafiq already has the status-bar notification equivalent, P2‑6) but is real native platform work (Glance API / RemoteViews) — a project of its own, not a P2‑8-sized item | none (reuses `PrayerTimesService`) |
| 11 | **"Lock distracting apps" during prayer time** | Sakinah AI (a *different*, newer app also named Sakinah) | Uses Android's accessibility/usage-stats APIs to block other apps until prayer is marked done | **L**, and **privacy-sensitive** | Interesting but a real scope jump — needs an invasive permission (`AccessibilityService` or `UsageStatsManager`+overlay), which itself needs the owner's explicit sign-off before any code is written (it's the kind of permission a security-conscious user should approve deliberately) | none technically, but **OWNER-BLOCKER**: needs explicit approval for the permission model before any spike |
| 12 | **Group / shared khatma** (create a group, split the 30 Juz, track everyone live) | "Khatma: Group Quran Tracker" (a separate app, not the 4 named ones, but directly relevant to P2‑11) | Multi-user real-time khatma with join-codes and sync | **L** | Real feature, but breaks Rafiq's current "no accounts, guest-mode-only, no backend" architecture (§3 rule + HANDOVER §7 STAGE 7's "no auth code anywhere" state) head-on — would need a genuine backend + accounts decision, which is bigger than a P2‑8 feature and overlaps P2‑9's hosting-cost guardrails | **OWNER-BLOCKER**: needs an explicit go-ahead to add real accounts/sync before any design work — flag for a future phase, not P2‑8 |
| 13 | **Quranic radio (24h streaming stations)** | Sakinah | Live-streamed Quran radio channels | **M**, licensing-gated | Needs verified-legal stream sources (station licensing, not just "a URL that works") before it's buildable at all | needs research — not yet identified; do not build until a clean, explicitly-licensed stream source is confirmed |

---

## Proposed shortlist (owner check-in required before building anything)

Per the stage rule ("check in with the owner on the shortlist before
building"), nothing below has been built. Recommended **first batch** —
small, self-contained, no new licensing questions, no architecture changes:

- **#1 memorization repeat-loop**
- **#2 share ayah as image**
- **#7 per-ayah private notes**
- **#3 multi-tafsir compare view**

**Second batch, worth doing but bigger:** **#4 topical audio playlists**,
**#9 more translation languages** (both still S–M, no new licensing risk,
just more content-curation time).

**Explicitly flagged as NOT ready to build** — each needs an owner decision
first, not just engineering time: **#8** (no clean tajweed-colour source
found yet), **#11** and **#12** (both need the owner to explicitly approve a
scope jump — invasive permissions for #11, real accounts/backend for #12 —
before any design work starts), **#13** (no verified-legal radio stream
source found yet). **#10** (prayer widget) is good but native-platform-sized;
suggest scheduling it as its own stage rather than folding into P2‑8.

**Owner: pick which of the first/second batch to build (all of them / a
subset / none), and rule on #8/#11/#12/#13 before they're touched.**
