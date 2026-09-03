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
building"). **Owner picked the full first batch (all 4) + both second-batch
items** (2026‑09‑03).

### ✅ First batch — DONE, emulator-verified

- **#1 memorization repeat-loop** — `AyahAudioService.playQueue`/
  `playRepeated`/`stopQueue`; repeat dialog (count/gap chips) in the ayah
  sheet's "⋮" menu. Verified live: 3 real playbacks with the chosen gap via
  `dumpsys audio` timestamps.
- **#2 share ayah as image** — `ayah_share_card.dart` (`RepaintBoundary` →
  PNG → `share_plus`' native chooser). Verified live: real thumbnail +
  reference text in the Android share sheet.
- **#7 per-ayah private notes** — `ayah_notes_store.dart`
  (`SharedPreferences`-backed). Verified live: note persists, menu item
  relabels + turns gold when a note exists.
- **#3 multi-tafsir compare view** — a list↔columns toggle in `_TafseerTab`.
  Verified live: 3 real sources (Qurtubi/Jalalayn/Muyassar) side by side.

### ✅ Second batch — DONE, emulator-verified

- **#4 topical audio playlists** — reuses Stage 6's `topic_tree.dart` data;
  a "play all" + per-ayah play buttons in the topics tab, via the same
  `playQueue`. Verified live: sequential real playback advancing ayah to
  ayah.
- **#9 more translation languages** — **not yet started** (this one needs a
  `quran_sciences.db` rebuild + new `ingest_translations.py` run, a bigger
  content-pipeline task than the others; the owner picked it but it's still
  open — pick up next).

**#11** (app-locking permission model) — owner did **not** pick this one to
explore; untouched. #10 (prayer widget) still suggested as its own later
stage.

### Research/design pass on #8, #12, #13 (2026‑09‑03) — findings, no code

Owner approved *researching/designing* these three (not building). Findings:

#### #8 — tajweed-colour mushaf: reframed, now genuinely buildable (for text mode)

Getting a tajweed-**colour vector mushaf image** (matching the existing
`quranpedia/quran-svg` pipeline's *pages*) turned out to be the wrong target:
`quran-svg` doesn't expose per-character glyph paths, only per-ayah/per-line
polygons, so there's no clean way to recolour individual letters within its
existing SVGs — that would need an entirely different upstream *image*
source (candidates found: [mushafdatabase/MushafDatabase-Ligature-Based-SVG](https://github.com/mushafdatabase/MushafDatabase-Ligature-Based-SVG)
and [zeeyado/quran-ebook](https://github.com/zeeyado/quran-ebook), the latter
baking tajweed colour into an OpenType COLR/CPAL font) — a real project of
its own, licence terms not yet checked.

**But P2‑8's own mushaf **text mode** got redesigned this session** (real
Unicode text, not fixed vector paths) — and for *text*, a clean, real,
CC‑licensed data source exists: [cpfair/quran-tajweed](https://github.com/cpfair/quran-tajweed)
ships `output/tajweed.hafs.uthmani-pause-sajdah.json`, one entry per
surah/ayah with named tajweed rules and **character start/end indices**,
under **CC BY 4.0** (redistributable with attribution — compatible with this
project's licensing bar). Applying it is a text-coloring problem, not a new
mushaf edition: split each ayah's `textUthmani` into `TextSpan`s at the
annotated indices and colour by rule, inside `mushaf_text_page.dart`'s
existing `Text.rich`. **Recommended next step, not yet built:** verify the
JSON's ayah text matches this project's own `quran_local.db` text
byte-for-byte (Uthmani encodings vary source to source — a mismatch would
misalign every colour boundary), then add it as a text-mode toggle. Effort
**S–M** once that alignment is confirmed; the "6th mushaf edition" framing
from the original research row was the wrong shape for this — it's a
text-mode feature, not an edition.

#### #12 — group/shared khatma: real design, still owner-blocked on the accounts question

A group khatma (create a group, split 30 Juz, sync live) fundamentally needs
**a persistent identity per member across their own devices** — Rafiq has
**zero auth today** (HANDOVER §7 STAGE 7: no `firebase_auth`/`google_sign_in`
in `pubspec.yaml`, confirmed by grep, "guest mode is the only mode"). Two
honest options, not one clean "small feature":

1. **Anonymous, device-local identity** (Firebase Anonymous Auth or a random
   UUID) — no sign-in flow to build, but a group member who reinstalls the
   app or switches phones **loses their slot in the group permanently**. Bad
   UX for a feature people would use across Ramadan.
2. **Real sign-in** (finish the Google Sign-In that STAGE 7 registered a
   Firebase project for but never built — `rafeeq-aldarb` already exists,
   just needs the owner to register a release SHA‑1 in its console, same
   blocker STAGE 7 already flagged) — survives reinstalls, the honest choice
   for real UX, but is real new scope: an auth flow, a privacy-policy
   question (this project has had none), and it turns "guest mode only" into
   "guest mode **and** accounts," a bigger architectural line to cross than
   anything else in Phase 2 so far.

**Backend:** the existing `rafeeq-aldarb` Firebase project (already
registered, never used) makes **Firestore** the path of least new
infrastructure — group documents are small and low-frequency
(`{code, members: {uid: {name, progress}}, juzAssignments}`, updated once
per reading session, not streamed), comfortably inside the free tier
P2‑9's `HOSTING.md` already budgets for (1 GiB / 50k reads/day) — no new
service to provision, "just" turn on what's sitting unused.

**Not building this**: it needs the owner to explicitly decide (1) real
Google Sign-In now (register that release SHA‑1), not just "researched" —
this is the same blocker STAGE 7 already surfaced, now with a second feature
riding on it — and (2) confirm using the existing Firebase project's
Firestore is acceptable. Effort **L**: new auth flow + Firestore
integration + create/join-group UI + a juz-distribution algorithm + a
member-progress view. Recommend scheduling as its own stage after P2‑9
(hosting) is settled, not folded into P2‑8.

#### #13 — live Quran radio: a real source exists, but it's currently unreliable — don't ship it as-is

`mp3quran.net` — **already this project's own trusted recitation source**
(HANDOVER §10) — publishes an official `/api/v3/radios` endpoint listing
~190 live stations with real stream URLs, so the *source* itself is legitimate
and already-vetted. But every stream URL it currently returns points at
`backup.qurango.net` (a third-party relay, not mp3quran.net's own audio CDN
that `ayahAudioUrls`/`surahAudioUrl` already use reliably) — **tested live,
repeatedly**: the exact same station URL returned `200`, then `500`, then
`200` again across consecutive requests seconds apart, and one station
(`alafasy`) `404`'d outright. That's not a licensing problem, it's a
**reliability** one: a "radio" feature built on this endpoint would
frequently fail to play, which is worse than not having the feature.
**Recommendation:** don't build against `backup.qurango.net` as the primary
URL. Before building, either (a) ask mp3quran.net (or check their site
source/app) for their actual production CDN domain for radio, the way this
project already found reliable per-ayah/per-surah URLs from them, or
(b) build it anyway but with an explicit, honest "الإذاعة غير متاحة الآن —
حاول لاحقًا" fallback and a retry, treating intermittent failure as a
normal, expected state for a live stream rather than something to hide.
Effort **S** once a reliable URL is confirmed; unchanged from the original
estimate, just now backed by an actual reliability test instead of a guess.

---

## Word-meanings tab — real Arabic-gloss source check (2026‑09‑03, owner-initiated)

Not a P2‑8 item — a live bug report on the *existing* `_MeaningsTab` (ayah
sciences sheet, "معاني الكلمات"): it showed a bare position number next to
an **English** word gloss (`word_meanings.en`, Quranic Arabic Corpus) with
no Arabic word shown at all, so there was no way to tell which meaning
belonged to which word short of counting. **Fixed same session:** the tab
now joins that data with `word_grammar.token` (already loaded for the
الإعراب tab, same `pos` key) and shows small word-chip cards — Arabic word
+ its English meaning — instead of a bare numbered list.

**Owner then clarified the deeper ask:** "معاني الكلمات" should mean a real
**Arabic** explanation of the word (غريب القرآن-style), not an English
translation dressed up next to the Arabic word. Checked whether a free,
legitimately-licensed Arabic source exists:

- **KSU's own "Ayat" app** (the same app P2‑8 researched) ships exactly this
  — Arabic word meanings per ayah — and **cites its source directly**:
  "معاني الكلمات لحسنين مخلوف" (the real title is *كلمات القرآن: تفسير
  وبيان*, Sheikh Hassanein Muhammad Makhlouf, twice Grand Mufti of Egypt,
  d. 1990).
- **Checked whether it's actually protected, not assumed:** confirmed d. 1990
  (multiple independent Arabic sources agree), confirmed the book is
  **still actively published and sold today** by more than one commercial
  publisher (دار ابن حزم and others — real, current print runs, not an
  out-of-print relic), and found **no evidence anywhere** of a waqf-style
  free-distribution waiver the way some government mushaf print runs
  carry. Under Egyptian copyright (life + 50) that's protected until
  **2040**; under life‑+70 regimes, **2060**. Categorically different from
  the P2‑4b Shamela decision — there, only a *modern taḥqīq's apparatus*
  around a 700-plus-year-dead author's text was in question and could be
  stripped out; here the **entire content** is Makhlouf's own 20th-century
  authored work, no public-domain layer underneath to extract.
- **Owner decision, told directly: do not use it.** Confirmed correct — this
  is not a source Rafiq is allowed to scrape or redistribute.

**The one real free alternative found:** *al-Mufradat fī Gharīb al-Qurʾān*
by al-Rāghib al-Iṣfahānī (d. 502 AH / 1108 CE) — genuinely old enough to be
unambiguously public domain, and available on `shamela.ws` (the project's
already-approved source, §5.7). The catch: it's organized **alphabetically
by root**, not by ayah, so using it means matching each Quranic word's
existing `word_grammar.root` (already in the DB, Buckwalter-encoded) to the
matching root entry in the lexicon — real new build tooling, not a drop-in
data file.

**Owner decision (2026‑09‑03): leave this feature alone for now** rather
than build the root-matching pipeline immediately — wait for a better,
more directly ayah-aligned free source to turn up first. The `_MeaningsTab`
UI fix (Arabic word + its English gloss, paired and legible) ships as-is in
the meantime; it's still honest — real English-translation data, just
finally shown next to the word it belongs to — it just isn't the Arabic
explanation feature the owner actually wants long-term.
