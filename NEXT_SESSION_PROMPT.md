# Rafiq Al-Darb — next session brief

**Last written:** 2026-09-09, at the end of the session that shipped v3.5.0.

You are picking up **رفيق الدرب / Rafeeq Al-Darb**, a personal **sideloaded**
Android Islamic app in Flutter. The owner's own app on his own repo
(`tito423/Rafeeq-Al-Darb`) — not a store app, not commercial. He writes in
Egyptian Arabic; **reply in Arabic**, keep code and commits in English.

## Read these, in this order, before touching anything

1. **`CLAUDE.md`** — the mandatory working method. It is not optional and it is
   not a summary of this file; it is the rules. The owner made following it a
   hard requirement so that any agent works the way the last one did.
2. **`HANDOVER.md`** — the state block at the top is current as of 2026-09-09.
3. This file — what is next.

## Where things stand

Everything the owner has asked for so far is **done, verified on the emulator,
committed, pushed, and released as v3.5.0** — the only release in the repo.

| | |
|---|---|
| Version | `3.5.0+1`, tag `v3.5.0` = `d2391a2` on `master` |
| Checks | `flutter analyze lib test` clean · `flutter test` 25/25 · every R2 content path answered a range request on 2026-09-09 |
| Locales | 7 (ar default/RTL, en, es, fr, pt, ru, ur), 584 keys, parity test enforces it |
| Mushaf | 7 printings, each with its real printed cover bundled |
| Library | 215 books, gzip on R2, indexed + chaptered + cross-book search |
| Hadith | 67,153 in 9 books, 45,219 graded (67%) |

**There is no outstanding bug the owner has reported.** The queue below is work
he has discussed but not yet green-lit, plus honest gaps.

---

## Next up — nothing here is started

### 1. The deferred big question: fetching any book from the internet

The owner asked (and it is still open):

> «هل من الممكن يكون فيه اليه ان التطبيق يقدر يدور على اي كتاب في الانترنت
> وينزله ويعمله فهرسة وابواب بشرط يبقى نص ولو لقاه pdf يحوله نص؟»

The recommendation already given to him, which he has not yet accepted or
rejected:

- **Not inside the app.** A command-line tool on a PC, one source at a time,
  with the output reviewed before it is uploaded to R2. The app keeps consuming
  only verified content.
- **PDF → text is the risky half.** Where the PDF has a text layer it is fine;
  most of the Islamic heritage is scanned images, and Arabic OCR mangles
  tashkeel and names — which is exactly the failure mode «علم الحديث مفيش فيه
  هزار» forbids. A book that is 2% wrong is worse than a book that is absent.
- **The realistic first step**, which he was offered: generalise what already
  exists — `scripts/fetch_shamela_pages.py` already crawls any Shamela book
  resumably — into a tool that pulls any Shamela title with its chapters and
  text. That widens the library to thousands of books from a source already
  trusted, with no OCR risk.

**Do not start this without his word on which shape he wants.**

### 2. Honest content gaps (no action without a real source)

| Gap | Status |
|---|---|
| Muwatta Malik ungraded (1,985) | **Correct as-is.** al-A'zami's edition gives takhrij, no per-hadith verdict. Do not fill it. |
| ~3,054 Musnad Ahmad hadiths ungraded | Arna'ut does not rule on them. Correct as-is. |
| 764 Darimi hadiths unmatched | Text drift between two printings; a prefix shared by two hadiths is dropped rather than guessed. Could be improved with a better matcher, not with a guess. |
| 63 of 27,647 Musnad Ahmad numbers missing | 99.8% recovered. The rest need individual page inspection. Low value. |

### 3. Offered but never confirmed

- **`scripts/health_check.py`** — the owner asked whether a script could exist
  that knows the app's structure well enough to diagnose faults. Never built.
  Given how the last three sessions went (four independent faults that only a
  device run exposed), a script that range-requests every catalogue entry,
  opens the bundled DBs, and asserts the locale key sets would have caught real
  bugs. Worth proposing again.
- **archive.org mirror of R2 content** with a `mirror_url` fallback in the
  client. He asked how much space archive.org gives; the answer was given, the
  mirror was never built.

### 4. Never verified on real hardware

The full-screen adhan video render (notification tap / lock-screen
full-screen-intent) has never fired under ADB on this emulator. It needs the
owner's actual phone. Do not mark it verified.

---

## What to do first, in this session

1. Read `CLAUDE.md`.
2. Run the verification set — `flutter analyze lib test`, `flutter test`, and a
   range request against `hadith/hadith.zip`, one book, and one page of each
   mushaf edition. Confirm the state above still holds before believing it.
3. Ask the owner what he wants next. Do not pick something off this list and
   start; §1 in particular is his decision.

## Reminders that repeatedly matter

- **Verify on the emulator and look at the screenshot.** Everything serious
  found here was found by running it.
- **`adb shell input text` cannot type Arabic.** Copy text from inside the app
  and paste it.
- **Never FTS5.** Android's SQLite has no such module and it takes the whole
  database down with it.
- **One release at a time**, previous release *and tag* deleted, tagged from
  `master`, `pubspec.yaml` version bumped to match.
- **Checkpoint with `.\cp.bat "…"` constantly.** Sessions die from quota
  exhaustion mid-task.
