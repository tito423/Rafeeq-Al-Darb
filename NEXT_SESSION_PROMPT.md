# Rafiq Al-Darb — next session brief

**Last written:** 2026-09-09, at the end of the **seventh** session, at **89 %
quota**, on a clean tree with `flutter analyze lib test` clean, `flutter test`
62/62, `i18n_audit` 0, `check_hero_contrast` all ≥ 4.5:1, and 23 hosted content
paths range-requested with 0 failures.

**Nothing is released.** Seven sessions of work sit on `master` and are in no
APK the owner has.

You are picking up **رفيق الدرب / Rafeeq Al-Darb**, a personal **sideloaded**
Android Islamic app in Flutter, on the owner's own repo
(`tito423/Rafeeq-Al-Darb`) — not a store app, not commercial. He writes in
Egyptian Arabic; **reply in Arabic**, keep code and commits in English.

`NEXT_PROMPT.md` is the paste-ready message. This file is the long brief it
points at.

## Read these, in this order, before touching anything

1. **`CLAUDE.md`** — the mandatory working method. **§2.0 first: check the
   quota before you plan, and say the number.** In the desktop app's Code tab
   `/usage` does not run — say so in your first reply and ask the owner. He
   answers.
2. **`HANDOVER.md`** — the state block at the top is this session's.
3. This file.

---

## 0. NOTHING IS SHIPPED-BUT-UNSEEN, WITH ONE EXCEPTION

Every change last session was opened on `emulator-5554` and looked at. The
one thing that was **proved scheduled but never watched fire**:

**The three prayer reminders.** `dumpsys alarm` showed ten
`ScheduledNotificationReceiver` alarms at exactly −10 and +5 around all five
prayers — 06:03 and 06:18 around a 06:13 Fajr, 13:42/13:57 around 13:52, and
so on — with the adhan's own alarm untouched at 06:13. That is proof they are
**armed**, not proof one has ever appeared on screen.

**First job:** set «قبل الأذان» to a value that makes one fire within a few
minutes (or move the emulator's clock to just before Fajr), wait, and **look at
the notification**: its title, its body, and that `{prayer}` and `{minutes}`
resolved in the app's language. If it does not appear, say so rather than
carrying the claim forward.

---

## 1. THE HADITH COLLECTION — the owner's stated top priority, and now unblocked

> «اهم حاجة ترجمات المواد العلمية خاصة الحديث من مصادرها الموثوقة»

**The HadeethEnc crawl is finished.** `hadeethenc.db` (gitignored, 60.5 MB):

```
3,574 hadiths · 15,498 (id, language) rows · 100 % fetched
every row carries BOTH a takhrij and a grading, in its own language
ar 3574 · en 2328 · ru 2249 · ur 2220 · es 1955 · fr 1790 · pt 1382
```

The old "of 25,018" was a wrong denominator — not every hadith has all seven
languages, and the crawler only asks for the ones a hadith declares.

**A measurement that changes the design.** `py -3
scripts/hadeethenc_gap_report.py`:

```
en · es · fr · pt · ru   0.0 % of takhrij and grade left in Arabic
ur                      29.1 % / 29.9 %
```

and Urdu's 29 % reads «متفق عليه» and «صحيح» — Arabic-script hadith
terminology an Urdu reader reads as Urdu, not a gap. **The card needs no "not
translated" state at all.**

### What is NOT done

Nothing is wired into the app. The plan that fits: a **separate, fully
documented collection beside the nine books**, hosted on R2 as per-language
packs, downloaded on demand exactly like the 45 Quran translations, and
credited on the Sources screen. No R2 upload, no `AppConfig` version bump, no
UI yet.

Do **not** try to translate the nine books' 67,153 hadiths — nothing
translates that corpus.

---

## 2. THE RELEASE

Seven sessions are not in the owner's hands. `pubspec.yaml` is still
`3.8.0+4`. Bump it, **one release at a time**, delete the previous release
**and its tag**, tag from `master`, and verify the tag's SHA equals
`git rev-parse HEAD`. Release notes in Arabic, structured, honest.

Worth putting in them: the hadith punctuation fix, 20 calculation methods with
the Asr madhab and the high-latitude rule, the plural-rules fix in all seven
languages, the themed cards and the live countdown, and the three prayer
reminders.

---

## 3. THE OWNER'S NEW REQUESTS — after 0, 1 and 2

### 3.1 Islamic-quote notifications

A notification every N minutes (he chooses — half an hour, more, less). Tapping
it opens a **card inside the app** that covers what is behind it, on an
**Islamic background that changes at random each time**, well designed, with a
dismiss button in the interface language.

**He settled both sources:**

* **The quotes come from the app's own library.** He named: **«لا تحزن»** and
  **«صيد الخاطر»** (both already among the 217 books in `book_catalog.dart`),
  plus **«حلية الأولياء»** and **«روضة العقلاء ونزهة الفضلاء»** by Ibn Hibban
  al-Busti — neither of which is in the catalogue yet.
  **Their Shamela ids were already looked up so nobody has to hunt:**

  | book | Shamela id |
  |---|---|
  | روضة العقلاء ونزهة الفضلاء | **6944** |
  | حلية الأولياء وطبقات الأصفياء — ط السعادة | **10495** |

  `py -3 scripts/shamela_index.py find "<title>"` for anything else. Trap #17:
  Shamela's own search searches *inside* books, not their titles — use the
  local index.

  **Every quote carries the book it came from.** §1.1 and §1.2: nothing
  attributed to a scholar without a source.

* **The backgrounds come from the internet, in quantity and at high quality**,
  and some should carry ornaments like the adhkar cards do
  (`IslamicPatternPainter` and `_CardBackground` in
  `azkar_section_screen.dart`). **Trap #18 applies squarely: a free scan or
  image is not automatically free to rehost.** Read each source's licence,
  record it, and drop anything whose licence is not stated.

### 3.2 The adhan video's quality

> «الفيديو بتاع الأذان لما بيشتغل بتبقى جودته سيئة جدًا — حل المشكلة دي»

Nobody has looked at it. Start by **measuring**: the source file's resolution
and bitrate, what is actually rendered, and how it is played
(`adhan_video_catalog.dart`, `AdhanActivity`). `ffmpeg` is already on the
machine at `C:\Program Files\ShareX\ffmpeg.exe` (trap #14) — nothing needs
downloading to re-encode.

---

## 4. SETTLED — do not reopen

* **Nothing of unknown provenance ships.** The `fawazahmed0` French/Urdu/
  Russian hadith sets name no translator → out. "Other apps do it" is the
  opposite of the owner's standard.
* **Three calculation methods are deliberately absent** and the reasons are in
  `prayer_calculation_methods.dart`'s doc comment: Moonsighting (the `adhan`
  package's implementation differs from the committee's by up to 9 minutes,
  with no constant offset to correct), Jafari and Tehran (Maghrib from a
  4°/4.5° sun angle is a Shia fiqh position, and this is a Sunni app).
  Everything else in the owner's reference screenshots is in no published
  source with angles.
* **The quotes/full-stop bug was a rendering bug in two halves** — strip the
  source's bidi marks **and** lay the paragraph out RTL. Both are needed.
* **The hero cards follow the theme now.** That reverses P3‑4's «RGB في جميع
  الثيمات», at the owner's explicit request.

---

## 5. Traps that bit in THIS session

* **`urllib` took 43 seconds per request against `api.aladhan.com`** while
  `curl` took 0.5 s, measured three times. Trap #12 with a new host — use
  `curl` for any HTTPS, and write progress incrementally so a stall costs only
  the rows it had not reached.
* **A `--debug` build killed the emulator.** Trap #24 says release builds do
  that; it happened on debug. After the reboot the app is still installed but
  the location permission and `adb emu geo fix` have to be redone, and the
  prayer card sits on a spinner until a fix arrives.
* **This shell eats `==` and backticks inside `python -c`.** Use the Write
  tool for any script (trap #11, again).
* **`easy_localization` disables CLDR plural rules by default.** If you add a
  plural key, check `ignorePluralRules: false` is still passed in *both*
  `main.dart` and `adhan_entry.dart`.
* **A character budget cannot judge text width across scripts.** Cyrillic at
  the same character count is wider than Latin;
  `test/nav_label_width_test.dart` is per-script now.

## 6. The scripts you will want

| | |
|---|---|
| `i18n_audit.py` | the measurement; `chrome` / `native` / `content` / allowlisted |
| `check_hero_contrast.py` | every hero tone against its composited ground |
| `build_prayer_method_fixtures.py` | AlAdhan's method table + the 320-row timings grid |
| `hadeethenc_crawl.py`, `hadeethenc_gap_report.py` | §1 |
| `shamela_index.py find "<title>"` | search 8,598 book titles locally |
| `verify_hosted_content.py` | range-request every hosted path |
| `add_i18n_keys_*.py` | the pattern for a batch of keys across all seven |
| `build_mushaf_from_pdf.py`, `check_mushaf_pages.py` | mushaf pipeline |
