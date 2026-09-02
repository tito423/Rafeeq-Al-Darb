# WORK QUEUE — Rafiq Al-Darb

**Companion to `HANDOVER.md`. Read that first — especially §3 (hard rules) and
§5 (decisions you must not undo).**

This file is the ordered backlog. It exists because every previous agent that
tried to do the whole roadmap in one pass produced screens that looked finished
and were wired to nothing. Work **one stage at a time**.

---

## Rules of engagement

0. **Checkpoint constantly.** Quota runs out mid-task on this project. After
   every meaningful edit run `.\cp.bat "what you just did"` — it writes a
   work-in-progress note into `HANDOVER.md` and commits, in one step. When a
   stage is finished use `.\cp.bat "..." -Done`. A session that dies right
   after a checkpoint costs nothing; one that dies an hour later costs an hour.
1. **One stage at a time.** Finish it, verify it against its acceptance
   criteria, checkpoint it as done, update `HANDOVER.md` (relevant section) and
   `RAFEEQ_PIPELINE.md`, then start the next.
2. **Acceptance criteria are not optional.** A stage is done when its criteria
   are demonstrably met on a running device — not when the code looks right.
3. **Zero mock data.** If real content is unavailable, ship an honest empty
   state. Never invent text, never hardcode a "downloaded" checkmark.
4. **Never take anything from QuranFlash.** See `HANDOVER.md` §5.1.
5. **Report honestly.** If a stage is half-done or you could not verify it, say
   exactly that in the commit and in `HANDOVER.md`. Do not write "verified"
   for something you did not run.
6. **STOP and ask the owner** if a stage needs a product decision (which books,
   which reciters, what a screen should contain). Do not guess and build.

---

## STAGE 0 — Device verification gate  ⛔ BLOCKS EVERYTHING ELSE

`flutter analyze` is clean, but nothing has ever actually run. Do not build new
features on unverified foundations.

```
cd rafeeq_app
flutter build apk --debug      # first build ever — expect Gradle/manifest work
flutter run
```

**Acceptance criteria — all must pass:**

| # | Check | Expected |
|---|---|---|
| 0.1 | App launches, 5 tabs reachable | no crash |
| 0.2 | Quran tab → image mode → page renders | real mushaf page, correct colours in light **and** dark |
| 0.3 | **Tap ayah 2:6 on page 3** | highlight covers **two separate line fragments**, not one big box |
| 0.4 | Tap any ayah → card opens | real tafsir (3 sources), EN + FR translation, i'rab per word, word meanings — no placeholder text |
| 0.5 | Edition picker → switch to Warsh | pages change; picker shows the numbering warning |
| 0.6 | In Warsh, open a diverging surah (e.g. 7) → tap ayah | card shows the "unavailable for this riwayah" notice, **not** tafsir |
| 0.7 | Settings → Downloads → download a mushaf | real progress, then offline-ready |
| 0.8 | Downloads → download one short surah's recitation | progress completes |
| 0.9 | **Turn network OFF**, reopen app | downloaded mushaf pages render; downloaded ayah audio plays |
| 0.10 | Page turning feels smooth | if visibly slow, note it — fix is `vector_graphics` `.vec`, **not** reverting to raster |

If 0.3 fails the polygon pipeline is wrong — fix that before anything else; it
is the core of the whole reader.

**Commit + update HANDOVER §7/§8 with what actually passed and what did not.**

---

## Corrections to `RAFEEQ_PIPELINE.md`

That table is stale. Before starting Stage 1, fix it:

- **T6, T7 — mark ✅.** Vector mushaf + real polygons are done (6,236/6,236),
  and now analyzer-clean.
- **T8 — mark ✅.** The ayah sciences sheet exists with **four** tabs (tafsir,
  translation, i'rab, meanings) reading from `quran_sciences.db`.
  **Do not rebuild it.**
- **T9 — mark 🔶.** The reciter dropdown exists in the Downloads screen. What is
  missing is a translation-language selector in the *reader*. See Stage 4.

---

## STAGE 1 — Adhan system  (pipeline T10–T13) — ✅ built & emulator-verified 2026-09-02

See `HANDOVER.md` §7's STAGE 1 table for the acceptance-criteria results and
verification method (`dumpsys audio`/`media_session`/`notification`, not
screenshots alone). Open from this stage: a physical-device pass, the
battery-optimization exemption button's effect (no visible dialog on the
emulator image used), and a custom imported adhan's native background sound
was not carried through to an actual firing alarm (the import flow itself —
opening the real system file picker — was confirmed).

The owner has raised this more times than anything else. Treat it as top
priority after Stage 0.

**What exists:** 10 verified adhan MP3s (real, no music, ID3-checked) were
downloaded in T3 and live under the repo's staging area; `adhans.json` catalog
is in `assets/data/catalogs/`. `adhan_alarm_service.dart` and
`prayer_times_service.dart` exist from earlier work.

**Build:**
1. ✅ **Adhan picker with working preview.** Built as a selectable list (not a
   dropdown widget) with a real play/stop preview per row, offline via the
   bundled assets. The 10 files have no verified per-reciter attribution, so
   they're honestly labeled "أذان 1"–"أذان 10" rather than inventing names.
2. 🔶 **Custom adhan from device.** File picker wired and confirmed to open
   the real system document picker; a full pick → import → firing-alarm cycle
   was not carried through to completion in this session.
3. ✅ **Per-prayer notification mode.** All 4 modes, all 5 prayers, persisted —
   confirmed to survive an app restart.
4. ✅/🔶 **Exact background alarms.** All 7 manifest permissions were already
   present; the exact-alarm request is wired in `AdhanAlarmService.initialize()`.
   The battery-optimisation exemption **prompt** is implemented
   (`Permission.ignoreBatteryOptimizations`) but produced no visible dialog on
   the emulator image tested — needs a physical-device check.
5. ✅ **Adhan notification**, ongoing, with working **Stop** and **Mute** —
   both confirmed via `dumpsys audio` to actually stop the native sound, not
   just change the UI.
6. ✅ **Full-screen adhan** with an animated gradient background and the adhan
   text highlighted karaoke-style against the real audio duration, including
   "الصلاة خير من النوم" for Fajr only.

**Acceptance:** set a prayer time 2 minutes ahead, **lock the phone**, and
confirm the adhan fires with sound and the full-screen UI; Stop and Mute work
from the notification; the choice per prayer is respected after an app restart.

---

## STAGE 2 — Library & Hadith  (T14, T15) — Hadith half ✅ done 2026-09-02; Library half pending owner

**Correction:** `hadith.db` and the "17 books in `rafeeq-api/downloads/books`"
did **not** actually exist anywhere in this workspace — only the real source
JSON (`scripts/temp_phase1/hadith9/`) did. See `HANDOVER.md` §7's STAGE 2
update for the full story. `hadith_screen.dart` is gone — replaced by
`LibraryScreen` (`lib/features/library/`), reachable from the same bottom-nav
slot (now labeled "المكتبة" / Library).

**Hadith hub — done:** Book → Chapter → Hadith (real 40,943 hadiths, 9 real
collections), hadith number, fast local FTS5 search. No per-hadith grading
exists in the source data (only Bukhari/Muslim are sahih by collection
definition) — never invent one. Downloaded on demand (~17 MB zipped), not
bundled — see `AppConfig.hadithDbUrl`. **The download itself could not be
verified this session** — see `HANDOVER.md` §7 for the TLS problem blocking
it; the repository/UI layer was verified against the real DB via direct
injection instead.

**Known bug (hadith ordering jumping 2 → 9 → 99) — fixed and regression-tested**
both in `scripts/build_hadith_db.py` (0 out-of-order chapters) and live in the
running app.

**Library "Books" tab — real sources researched, owner confirmation still
needed before downloading anything** (per the STOP AND ASK below). Real, freely
available editions were found on archive.org for Riyad as-Salihin, Mukhtasar
Minhaj al-Qasidin, al-Fiqh ala al-Madhahib al-Arba'ah, and works of Ibn
al-Qayyim, Ibn Taymiyyah, Ibn al-Jawzi, and al-Hakim al-Tirmidhi. All of these
classical texts are public domain (authors died centuries ago); al-Jaziri's
*al-Fiqh* compilation (1941) needs its own licensing check, and a specific
tahqiq/edition still needs picking per title since a modern scholar's
critical edition can carry its own separate copyright even when the
underlying classical text doesn't. Ibn Abi al-Dunya is many short treatises,
not one book — still needs a title-by-title pass. The Library screen's
"الكتالوج" tab currently shows an honest "sources pending confirmation"
message rather than any invented entries.

**⚠️ STOP AND ASK THE OWNER** — still applies to the Books tab specifically:
confirm the exact list and, per title, which edition/tahqiq before downloading
anything.

---

## STAGE 3 — Azkar & Tasbeeh  (T16) — ✅ done 2026-09-02, fully verified live

`lib/features/azkar/` (replaces the old stub). No duplicate azkar within a
section (verified: 0 via a real SQL query). The tasbeeh counter increments on
the **first** tap (live-verified this doesn't reproduce the old only-counts-
after-reset bug), auto-advances at each dhikr's **real** repeat count (parsed
from the dhikr's own text, e.g. "( ثلاث مرات )" — see
`lib/features/azkar/data/azkar_repeat.dart`), and shows the bundled
`footnote` field as its fadl/source. Haptics toggle and morning/evening
reminder times are both real and persisted, with **no default time** — both
start "off" until the user picks one, per this stage's own instruction not to
hardcode 05:00/16:30. See `HANDOVER.md` §7's STAGE 3 table for exactly what
was exercised live vs. code-reviewed.

---

## STAGE 4 — Translation selector in the reader  (rest of T9)

`quran_sciences.db` holds en / fr / ur, all 6,236 ayahs each. The card shows all
of them stacked. Add a language selector so the reader picks which translation
shows, persisted. Keep the existing elegant dropdown style.

---

## STAGE 5 — New Muslim guide  (T17)
Visual guide: how to pray (illustrated steps), wudu, pillars of Islam and iman,
basic daily supplications — in the app's active language.
**STOP AND ASK** about content sources before writing religious instruction.

## STAGE 6 — Thematic Quran search  (T18)
Topic tree (aqeedah, akhlaq, stories of the prophets, rulings, the hereafter)
plus conceptual search that finds ayahs by meaning, not just literal words.
Reuse the FTS5 index in `quran_local.db`.

## STAGE 7 — Security & guest mode  (T19)
Confirm no credentials in the client (`AppConfig` is currently secret-free —
keep it). Google sign-in optional with full guest mode: every offline feature
must work without an account. When signed in, show the account name with
sign-out / switch-account.

## STAGE 8 — Release  (T20)
`flutter clean` → `pub get` → `analyze` → `build apk --release --split-per-abi`.
Confirm `.gitignore` still covers `.env`, keystores, `google-services.json`,
`serviceAccountKey.json`. Push.

---

## Open items carried from earlier (do not lose these)

- **Rotate the Cloudflare R2 API token.** The old secret was pasted into a chat
  transcript and must be treated as public. Owner action.
- **Mushaf pages are served from GitHub raw**, pinned — fine for development,
  **not a CDN**. Before release, mirror `scripts/mushaf_build/<edition>/svg` to
  the project bucket and build with
  `--dart-define=RAFEEQ_MUSHAF_BASE=https://<bucket>/mushafs`.
- **`.git/_stale_locks/`** holds lock files a sandbox could not delete. Safe to
  delete the folder.
