# Rafiq Al-Darb — next session brief

**Last written:** 2026-09-11, at the end of the **tenth** session, on a clean
tree with `flutter analyze lib test` clean, `flutter test` **147 passed**, and
**15** hosted content paths range-requested with **0** failures.

**`v3.15.0` is released**, at `eb210cf`. The tag is on `master`, its SHA equals
`git rev-parse HEAD`, and it is the only release in the repo. The published APK
was downloaded back from GitHub and its certificate checked:
`CN=Rafeeq Al-Darb, OU=Personal, O=tito423, L=Cairo, C=EG` on Android 9+.

## What changed about how this project works

Two things are new since the last brief and both change the first hour of a
session:

1. **The owner now tests every release on his own phone and sends findings.**
   They live in `OWNER_FINDINGS.md` (the first batch) and `WORK_QUEUE.md`
   (the second, A1–A7), each item marked with whether it was seen on a device.
   Those two files, not this one, are where the work comes from.

2. **The app signs itself with a real key.** Gradle still signs debug *on
   purpose*; `py -3 scripts/sign_release.py` re-signs the built APK with the
   release key and a SigningCertificateLineage, so an update installs over the
   old debug-signed copy without an uninstall. **Never publish
   `flutter build apk` output directly** — trap #41. The keystore is in
   `../Rafeeq-Keys/`, outside this repository, and backing it up is his job.

Three scripts were added that answer questions this project keeps asking:

* `scripts/verify_hosted_content.py` — range-requests every hosted path, and
  checks the content type and the magic bytes, because a soft-404 answers 200
  (trap #5).
* `scripts/db_type_audit.py` — every non-nullable `as int` in `lib/core/db/`,
  checked against the real databases. One row in 1,482 was fractional and it
  took a whole hadith collection down.
* `scripts/sign_release.py` — the signing path above, which refuses to finish
  unless the result really carries the release certificate.

You are picking up **رفيق الدرب / Rafeeq Al-Darb**, a personal **sideloaded**
Android Islamic app in Flutter, on the owner's own repo
(`tito423/Rafeeq-Al-Darb`) — not a store app, not commercial. He writes in
Egyptian Arabic; **reply in Arabic**, keep code and commits in English.

`NEXT_PROMPT.md` is the paste-ready message. This file is the long brief it
points at.

## Read these, in this order, before touching anything

1. **`CLAUDE.md`** — the mandatory working method. **§2.0 first: check the
   quota before you plan, and say the number.** In the desktop app's Code tab
   `/usage` does not run — say so in your first reply and ask the owner.
2. **`HANDOVER.md`** — the state block at the top is this session's.
3. This file.

---

## 0. NOTHING IS SHIPPED-BUT-UNSEEN

Every change this session was opened on `emulator-5554` and looked at:

* the before-Fajr reminder **firing on screen**, read twice — once with the
  wording that was wrong, once with the wording that is right;
* the iqama reminder firing **in English** after a language switch, which is
  what proves the re-arm-on-locale-change works;
* the whole Encyclopedia tab in Arabic and in English — download, the seven
  sections with their counts, a hadith with its takhrij and grading, search.

Three things are **deliberately absent** and are named as such in §4 of
`HANDOVER.md`: `words_meanings_ar`, Urdu digits, and
`QuranTranslationInfo.sizeLabel`. They are work, not breakage.

---

## 1. WHAT THE EIGHTH SESSION DID

### 1.1 The prayer reminder, watched rather than assumed

`dumpsys alarm` had proved the fifteen reminders armed. It had never proved one
appeared. Moving the emulator's clock to 06:01 with the before-Fajr alarm at
06:03 did — and what appeared was wrong in three ways at once (feminine verb on
a masculine noun, singular counted noun after 10, Latin digits beside the app's
own Arabic-Indic ones). All three are fixed, with a test that was proved to
fail on the old strings first.

The clock trick matters and is not obvious: `adb shell date` is refused on a
Google Play emulator image (no root), but **`adb shell cmd alarm set-time
<millis>`** works.

### 1.2 موسوعة الأحاديث النبوية, in the app

The owner's stated top priority. A fifth Library tab, one downloadable SQLite
pack per language, every record carrying a takhrij and a grading in the
reader's own language. The publisher's redistribution terms were read before
anything was uploaded and are met and documented.

Scripts, in the order they run:

| | |
|---|---|
| `hadeethenc_crawl.py` | the corpus (already complete: `hadeethenc.db`, 60.5 MB, gitignored) |
| `hadeethenc_categories.py` | the seven section titles in all seven languages |
| `build_hadeethenc_packs.py` | `dist/hadeethenc/<lang>.zip` + `hadeethenc_packs.json` |
| `r2_upload_hadeethenc.py` | upload, read back off the public endpoint, then write the bundled catalogue |
| `verify_hosted_content.py` | range-checks all seven packs with everything else |

---

## 2. WHAT IS NEXT, IN ORDER

### 2.1 Islamic-quote notifications

A notification every N minutes (the owner chooses). Tapping it opens a **card
inside the app** that covers what is behind it, on an **Islamic background that
changes at random each time**, well designed, with a dismiss button in the
interface language.

Both sources are settled by the owner:

* **The quotes come from the app's own library.** «لا تحزن» and «صيد الخاطر»
  are already among the 227 books in `book_catalog.dart`. «حلية الأولياء» and
  «روضة العقلاء ونزهة الفضلاء» are not, and their Shamela ids are **6944** and
  **10495** so nobody has to hunt (trap #17: Shamela's own search searches
  *inside* books, not their titles — use `shamela_index.py find`).
  **Every quote carries the book it came from** (§1.1, §1.2).
* **The backgrounds come from the internet**, in quantity and at high quality,
  some carrying ornaments like the adhkar cards (`IslamicPatternPainter` /
  `_CardBackground` in `azkar_section_screen.dart`). **Trap #18 applies**:
  read each source's licence, record it, drop anything whose licence is not
  stated. This session did exactly that for hadeethenc.com and it turned out
  to permit redistribution on conditions — so reading the terms is not a
  formality that ends in "no".

### 2.2 The adhan video's quality

> «الفيديو بتاع الأذان لما بيشتغل بتبقى جودته سيئة جدًا — حل المشكلة دي»

Nobody has looked. Start by **measuring**: the source file's resolution and
bitrate, what is actually rendered, and how it is played
(`adhan_video_catalog.dart`, `AdhanActivity`). `ffmpeg` is already on the
machine at `C:\Program Files\ShareX\ffmpeg.exe` (trap #14).

### 2.3 The three named gaps

`words_meanings_ar` in the HadeethEnc packs (needs a re-crawl and a
`hadeethEncVersion` bump to `v2`), Urdu's digits, and the sixth copy of the
byte formatter. Each is written up in `HANDOVER.md` §4.

---

## 3. SETTLED — do not reopen

* Nothing of unknown provenance ships. The `fawazahmed0` French/Urdu/Russian
  hadith sets name no translator → out.
* Moonsighting, Jafari and Tehran are deliberately absent, with the reasons in
  `prayer_calculation_methods.dart`.
* The quotes/full-stop bug was a rendering bug in two halves — strip the
  source's bidi marks **and** lay the paragraph out RTL. Both are needed.
* The hero cards follow the theme, reversing P3‑4, at the owner's request.
* **A HadeethEnc grading is never attributed to a named scholar.** The
  encyclopedia names none per hadith; the app says «تصنيف موسوعة الأحاديث
  النبوية» and shows the encyclopedia's own reference list. Do not "improve"
  this by guessing a grader.

---

## 4. Traps that bit in THIS session

* **A zip unpacks under the ZIP's name, not the entry's.**
  `DownloadManager._unzipToDatabases` uses `basename(zipPath) + '.db'`, so
  `ar.zip` became `ar.db` while the repository opened `hadeethenc_ar.db`. The
  download succeeded, the unzip succeeded, `flutter analyze` was clean and 66
  tests passed — and the feature was dead. **§1.3 in one sentence: bytes on
  the bucket are not the feature working.**
* **`adb shell date` cannot set the clock on a Play-image emulator**, but
  `adb shell cmd alarm set-time <millis>` can.
* **`Localization` and `Translations` are not exported by
  `easy_localization`.** A test that wants the real `plural()` imports them
  from `src/` and **must** pass `ignorePluralRules: false`, or Arabic's six
  cases collapse into four.
* **Windows' console is cp1256** (trap #10) — bit twice. Write reports to a
  UTF-8 file and `cat` them.
* **A notification's text is frozen when the alarm is armed**, not when it
  fires. Anything that changes wording — a language switch above all — has to
  re-arm.

---

## 5. The scripts you will want

| | |
|---|---|
| `i18n_audit.py` | the measurement; `chrome` / `native` / `content` / allowlisted |
| `verify_hosted_content.py` | range-request every hosted path, packs included |
| `build_hadeethenc_packs.py`, `r2_upload_hadeethenc.py` | §1.2 |
| `shamela_index.py find "<title>"` | search 8,598 book titles locally |
| `build_prayer_method_fixtures.py` | AlAdhan's method table + the 320-row grid |
| `check_hero_contrast.py` | every hero tone against its composited ground |
| `build_mushaf_from_pdf.py`, `check_mushaf_pages.py` | mushaf pipeline |
