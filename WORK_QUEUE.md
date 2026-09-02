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

**Hadith hub — done and now fully verified, including the download.** Book →
Chapter → Hadith (real 40,943 hadiths, 9 real collections), hadith number,
local keyword search. No per-hadith grading exists in the source data (only
Bukhari/Muslim are sahih by collection definition) — never invent one.
Downloaded on demand (~17 MB zipped), not bundled — see
`AppConfig.hadithDbUrl`. The download was blocked most of this session by a
host-machine TLS problem (see `HANDOVER.md` §7); once the owner disabled
Avast, the real download → unzip → open cycle was confirmed twice from a
clean install. That same testing chain then found four real bugs in
sequence, all fixed: (1) a `setState`/Future misuse crashing the search box,
(2) `sqflite` having no FTS5 module on this Android build at all, (3) the
LIKE-based fix for (2) still not matching real Arabic input because
`arabic`/`text_uthmani` are stored fully diacritized — fixed with
`lib/core/utils/arabic_normalize.dart`, covered by
`test/arabic_normalize_test.dart`, (4) a real `OutOfMemoryError` crash from
loading all ~41k hadiths into memory at once — fixed by paging the search
scan instead of caching the whole table. Search is confirmed working live
end-to-end after all four fixes (searching "Umar" returns real Bukhari
hadiths #23/45/82/92/93, and a deliberate no-match query completes a full
table scan with no crash). See `HANDOVER.md` §7 for the full account — bugs
(2) and (3) apply to Stage 6's Quran search too.

**Known bug (hadith ordering jumping 2 → 9 → 99) — fixed and regression-tested**
both in `scripts/build_hadith_db.py` (0 out-of-order chapters) and live in the
running app.

**Library "Books" tab — real sources researched, catalog not yet built.**
Owner said mid-session to use al-Maktaba al-Shamela or another free
Islamic-books source directly (no further STOP AND ASK on this). Real, freely
available editions were already found on archive.org for Riyad as-Salihin,
Mukhtasar Minhaj al-Qasidin, al-Fiqh ala al-Madhahib al-Arba'ah, and works of
Ibn al-Qayyim, Ibn Taymiyyah, Ibn al-Jawzi, and al-Hakim al-Tirmidhi. All of
these classical texts are public domain (authors died centuries ago);
al-Jaziri's *al-Fiqh* compilation (1941) needs its own licensing check, and a
specific tahqiq/edition still needs picking per title since a modern
scholar's critical edition can carry its own separate copyright even when
the underlying classical text doesn't. Ibn Abi al-Dunya is many short
treatises, not one book — still needs a title-by-title pass. The Library
screen's "الكتالوج" tab currently shows an honest "sources pending
confirmation" message rather than any invented entries — building the real
catalog + download flow is still open.

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

## STAGE 4 — Translation selector in the reader  (rest of T9) — ✅ done 2026-09-02

`lib/features/quran/data/translation_lang_provider.dart` (persisted,
SharedPreferences, same `StateNotifier` pattern as the existing reciter
selector) + a dropdown in the translation tab of `AyahSciencesSheet`, styled
like the existing reciter dropdown (`InputDecorator` + `DropdownButton`). The
card now shows exactly one translation at a time instead of en/fr/ur stacked.
**2026-09-02: emulator-verified** — opened ayah 1:1, the translation tab
showed a "الترجمة" dropdown defaulted to English with only the Saheeh
International text below it (not all three languages).

---

## STAGE 5 — New Muslim guide  (T17) — ✅ done 2026-09-02

Owner approved using known trusted Islamic sources directly (no further
gate). `lib/features/new_muslim/data/guide_content.dart` — pillars of Islam,
articles of faith, wudu, prayer steps, a Quran introduction, written by hand
from mainstream, uncontroversial Sunni teaching, bilingual (ar/en). Not
illustrated (text + the Arabic phrase/dua for each step, in the Quran font)
— an illustrated version is a possible future enhancement, not done here.
**2026-09-02: emulator-verified** — all 5 topics list with correct item
counts; Wudu's 8 steps render in order with the Shahada dua in a proper
phrase box. Also fixed a real pre-existing bug: Home's quick-access card
was silently opening the wrong screen (Library) since STAGE 2 repointed the
tab index it used to navigate by — now pushes the guide screen directly.

## STAGE 6 — Thematic Quran search  (T18) — done
Topic tree (aqeedah, akhlaq, stories of the prophets, rulings, the hereafter)
built from real, curated ayah ranges — 5 categories, real references, no
invented "AI meaning search": there is no offline embedding model in this
app, so a topic → curated ayah-range table is the honest substitute rather
than relabeling keyword search as "conceptual." A separate literal keyword
tab covers word search.

**FTS5 could not be reused as planned** — `quran_local.db`'s `ayahs_search`
FTS5 table exists in the file but this Android build's `sqflite`/system
SQLite has no FTS5 module at all (same finding as Stage 2's hadith search;
see `HANDOVER.md` §7). A plain `LIKE '%term%'` was tried next but doesn't
work either for Arabic: `text_uthmani` (and `hadith.db`'s `arabic` column)
are stored fully diacritized, so ordinary undiacritized user input never
matches — confirmed directly with sqlite3 against the real data. Fixed with
`lib/core/utils/arabic_normalize.dart` (strips harakat/tatweel, unifies alef
forms), covered by `test/arabic_normalize_test.dart`, used by both
`QuranRepository.search()` and `HadithRepository.search()`. Loading the
whole 41k-row hadith table into memory for this also caused a real
`OutOfMemoryError` crash at one point — fixed by paging the scan
(`LIMIT`/`OFFSET`) with no persistent cache rather than caching everything;
see `HadithRepository.search()`'s doc. Everything in this stage is now
**fully emulator-verified**: all 5 topic categories load real ayah ranges,
the keyword tab returns real matches, and tapping a result ayah correctly
jumps `QuranScreen` to its page (confirmed: tapping 2:153 landed on page
23/604 showing that exact ayah) — the earlier "not confirmed" note about
tap-to-jump was tap-precision uncertainty in testing, not a real bug.

## STAGE 7 — Security & guest mode  (T19) — verified, one piece blocked
Confirmed no credentials in the client: `AppConfig` is secret-free (checked
again — only public API/CDN base URLs). Grepped the whole `lib/` tree for
`signIn`/`login`/`auth`/`FirebaseAuth` and found **no authentication code of
any kind** — the app has zero account system, so "every offline feature
works without an account" is trivially and completely true: there is nothing
that could gate a feature behind sign-in. Guest mode isn't a partial mode
here, it's the only mode that exists.

**Found and fixed a real gap along the way:** `rafeeq_app/android/app/
google-services.json` — a real, live Firebase config (project
`rafeeq-aldarb`, real API key and OAuth client ID) — was committed to git
back in the very first T1-T3 commit and never gitignored, even though this
file's category was already named in this stage's own release checklist.
Untracked it (`git rm --cached`, the local file itself is untouched so
nothing breaks) and added `google-services.json`, `GoogleService-Info.plist`,
`*.env`/`.env`, `android/key.properties`, and `*.jks`/`*.keystore` to
`.gitignore`. Unlike the Cloudflare R2 secret key incident, a Firebase
Android API key is designed to ship inside client apps and isn't a secret in
the same sense (Google's own guidance says so) — real protection comes from
Google Cloud Console API-key restrictions (package name + SHA-1) and
Firebase Security Rules, not from hiding the key — but it should still not
be sitting in git per this project's own checklist, and it already is in
git history from the earlier commit, which the owner may want to know.

**Google sign-in itself is not built — real credentials exist but building
this needs the owner in the loop, not just a session with API access.** The
`rafeeq-aldarb` Firebase project already exists (per the config file above)
and `pubspec.yaml` has no `firebase_auth`/`google_sign_in` packages yet, so
wiring it up would mean: adding those packages, registering the app's
release SHA-1 fingerprint(s) in that Firebase project's console, and
building the actual sign-in/sign-out UI. The package additions and UI are
buildable by any session; the SHA-1 registration is a Firebase-console step
that needs whoever owns that Firebase project's login. Flagged rather than
half-built with a broken sign-in button, per this project's own rule against
shipping something unverified as if it worked.

## STAGE 8 — Release  (T20) — pipeline verified, real signing still blocked
Ran the full chain for real: `flutter clean` → `pub get` → `analyze` (clean)
→ `build apk --release --split-per-abi`. **Succeeds**: `app-armeabi-v7a-
release.apk` (35.8MB), `app-arm64-v8a-release.apk` (37.8MB),
`app-x86_64-release.apk` (39.2MB). Installed the x86_64 one fresh on the
emulator and it runs correctly — no crash, correct Arabic UI, an honest
"enable location" empty state where prayer times would go (location wasn't
granted this run) rather than any placeholder data.

While building this, found and hardened a real release-security gap:
`AndroidManifest.xml`'s `<application>` tag had
`android:usesCleartextTraffic="true"` **applying to every build type,
release included** — even though a grep of the whole `lib/` tree found zero
`http://` URLs anywhere (everything is `https://`). This flag was almost
certainly left over from debugging the Avast TLS-interception problem, but
it doesn't actually do what that needed (TLS interception is still HTTPS
with a different root CA — that's what the debug-only
`network_security_config` already handles correctly; cleartext is a
different, unrelated permission). Removed it from the main manifest, so
release (and every variant) now defaults to disallowing cleartext HTTP,
matching what the app actually needs. Re-built after the fix — still
succeeds, still runs correctly.

Also confirmed `.gitignore` now covers `.env`, keystores (`*.jks`/
`*.keystore`/`android/key.properties`), `google-services.json`,
`GoogleService-Info.plist`, and `serviceAccountKey.json` — see the STAGE 7
section above for the real `google-services.json` that had to be untracked
to make that true.

**Still blocked on the owner:** the release build is signed with the
**debug** keystore (`signingConfig = signingConfigs.getByName("debug")` in
`android/app/build.gradle.kts`, with a `// TODO: Add your own signing
config` comment already in place) — this produces a real, installable APK
for testing, but it is not what should ship to users or an app store. Real
release signing needs the owner's own keystore file, key alias, and
passwords — no agent session can generate those (a self-generated keystore
would mean nobody but this session could ever re-sign an update, which is
worse than not shipping). Not pushed anywhere per usual convention — the
owner should review the diff first.

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
