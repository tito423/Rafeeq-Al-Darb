# WORK QUEUE — Rafiq Al-Darb

**Companion to `HANDOVER.md`. Read that first — especially §3 (hard rules) and
§5 (decisions you must not undo).**

This file is the ordered backlog. It exists because every previous agent that
tried to do the whole roadmap in one pass produced screens that looked finished
and were wired to nothing. Work **one stage at a time**.

---

## Rules of engagement

1. **One stage at a time.** Finish it, verify it against its acceptance
   criteria, commit it, update `HANDOVER.md` (stamp + relevant section) and
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

## STAGE 1 — Adhan system  (pipeline T10–T13)

The owner has raised this more times than anything else. Treat it as top
priority after Stage 0.

**What exists:** 10 verified adhan MP3s (real, no music, ID3-checked) were
downloaded in T3 and live under the repo's staging area; `adhans.json` catalog
is in `assets/data/catalogs/`. `adhan_alarm_service.dart` and
`prayer_times_service.dart` exist from earlier work.

**Build:**
1. **Adhan picker with working preview.** A dropdown listing the 10 muezzins;
   the play button must actually play the audio immediately. Bundle the audio
   as assets so preview works offline.
2. **Custom adhan from device.** File picker for an MP3 from the phone; once
   chosen it becomes selectable like any built-in adhan.
3. **Per-prayer notification mode.** For each of the 5 prayers independently:
   audio + full screen / audio only / vibrate only / silent. Persisted.
4. **Exact background alarms.** `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`,
   `POST_NOTIFICATIONS`, `FOREGROUND_SERVICE`, `WAKE_LOCK`,
   `RECEIVE_BOOT_COMPLETED`, `USE_FULL_SCREEN_INTENT` in the manifest, plus a
   battery-optimisation exemption prompt.
5. **Adhan notification** that is ongoing (not auto-dismissed) with working
   **Stop** and **Mute** actions.
6. **Full-screen adhan** with a calm Islamic animated background and the adhan
   text synced to the audio (karaoke style). Include
   "الصلاة خير من النوم" for Fajr.

**Acceptance:** set a prayer time 2 minutes ahead, **lock the phone**, and
confirm the adhan fires with sound and the full-screen UI; Stop and Mute work
from the notification; the choice per prayer is respected after an app restart.

---

## STAGE 2 — Library & Hadith  (T14, T15)

**What exists:** `hadith.db` with 9 collections / 36,461 hadiths (rebuilt clean
in T3). 17 books were downloaded to `rafeeq-api/downloads/books` in T1.
`hadith_screen.dart` is currently a stub.

**Build:** the Library as a main destination with three tabs —
*Available to download* / *My library* (downloaded, offline) / *Categories*.
Catalog driven by a `books_catalog.json`, never hardcoded. Download + delete per
book with real progress. Hadith hub: Book → Chapter → Hadith, with hadith
number, grading, and fast local search.

**Known bug to fix:** hadith ordering was previously broken (jumping 2 → 9 → 99).
Verify sequencing is correct before calling this done.

**⚠️ STOP AND ASK THE OWNER** before populating the books list. He has a
specific list (Riyad as-Salihin, Mukhtasar Minhaj al-Qasidin, Fiqh ala
al-Madhahib al-Arba'ah, Ibn al-Qayyim, Ibn al-Jawzi, Ibn Taymiyyah, Ibn Abi
al-Dunya, al-Tirmidhi al-Hakim, and zuhd/raqa'iq works). Confirm the list and
the sources before downloading anything.

---

## STAGE 3 — Azkar & Tasbeeh  (T16)

**What exists:** 134 sections / 298 items from Hisn al-Muslim in
`quran_sciences.db`, plus `azkar_screen.dart`.

**Build:** verify there are no duplicate azkar within a section; smart tasbeeh
counter that increments on the **first** tap (an old build only counted after
reset — check this), haptics toggle, auto-advance at target count, and the
fadl/source for each dhikr. Custom reminder times chosen by the user — no
hardcoded 05:00 / 16:30.

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
