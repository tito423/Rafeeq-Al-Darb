# Rafiq Al-Darb — next session brief

**Last written:** 2026-09-09, at the end of the sixth session, at **75 % quota**
on a clean tree with `flutter analyze lib test` clean and `flutter test` 44/44.
**Nothing is released.** Everything below and everything from the fifth session
is committed on `master` and not in any APK the owner has.

You are picking up **رفيق الدرب / Rafeeq Al-Darb**, a personal **sideloaded**
Android Islamic app in Flutter, on the owner's own repo (`tito423/Rafeeq-Al-Darb`)
— not a store app, not commercial. He writes in Egyptian Arabic; **reply in
Arabic**, keep code and commits in English.

## Read these, in this order, before touching anything

1. **`CLAUDE.md`** — the mandatory working method. **§2.0 first: check the
   quota before you plan, and say the number.** In a non-interactive session
   (the desktop app's Code tab) `/usage` does not run — say so in your first
   reply and ask the owner to read it off his screen. He answers.
2. **`HANDOVER.md`** — the state block at the top.
3. This file.

---

## 0. THE LOCALISATION JOB IS DONE. THE MEASUREMENT SAYS 0.

```bash
py -3 scripts/i18n_audit.py
```

```
UNTRANSLATED USER-VISIBLE STRINGS: 0 in 0 files
   chrome  (UI text that must go through .tr()): 0
   native  (Arabic that ANDROID renders, not Dart): 0
   content (Arabic the app authors, needs translating): 0
   allowlisted (deliberate, with a reason in this script): 789
```

It was **1,497 across 39 files** when the sixth session started. Do not treat
that as a finished feature and move on — **treat the 789 as the thing to argue
with.** Every one of them is a decision with a written reason in
`scripts/i18n_audit.py`; if you disagree with one, say so to the owner rather
than changing it quietly. The classes are:

* **recitation and scripture** — the words of the adhan, the guide's ten
  `phraseAr` phrases (the shahada, «سُبْحَانَ رَبِّيَ الْعَظِيمِ», the
  tashahhud), the mushaf font samples. Arabic because that is the thing on
  screen, not a label for it (CLAUDE.md §1.2).
* **proper names** — 226 book titles and authors, 7 channel names, 5 reciters,
  the dawah channels and sites. Never translated; written in the reader's own
  script by `properName()` (`lib/core/i18n/proper_name.dart`), which asks
  `common.script` — `arabic` in ar/ur, `latin` in the other five.
* **citations** — the printed-edition lines on the Sources screen and each
  book's `sourceLabel`. Translating a citation stops it being one.
* **Arabic-Indic digit tables** — the mushaf page number, the Arabic-numeral
  clock face. The owner's decision.
* the owner's own name; `NativeStrings.kt`'s Arabic fallback map.

### What the sixth session actually changed, and the three bugs nobody had listed

1. **Most of the original 89 `chrome` findings were false positives.** The
   audit's literal scanner was a regex reading quotes pairwise, so
   `'${_hits.length} ${'library.text_search_results'.tr()}'` — translated all
   along — was split into fragments that looked like hardcoded text. It is a
   state machine now that judges the RESIDUE left after interpolations are
   removed, and it was proven not to have gone blind: four probes injected into
   a real screen were all four reported.
2. **`adhan_entry.dart` listed SIX locales.** The full-screen Adhan alert boots
   as its own miniature Flutter app with its own `supportedLocales`, and Urdu
   was missing, so an Urdu user's alert fell back to Arabic. Both lists now read
   `kSupportedLocales`; `test/supported_locales_test.dart` pins it to the files
   on disk and was proven to fail on the bug.
3. **Fifteen Arabic strings lived in Kotlin** — three notification channels and
   their descriptions, the adhan alert's title/body/two buttons, the download
   service's notification — and a Dart-only audit could never see them. They
   come from Dart now via `NativeStrings` (SharedPreferences, readable from a
   receiver with no engine alive; Android's own `values-<lang>/` cannot do this
   because the app's language is its own setting, not the device's). The audit
   grew a `native` bucket that measures them.
4. **The «Lu aujourd'hui» the owner photographed** is the khatma undo
   `SnackBar`, shown through the root `ScaffoldMessenger` — which is what makes
   it survive a push to another screen, and what made it survive a language
   change. `MaterialApp` has a `scaffoldMessengerKey` now and the locale-change
   callback clears it. **His screenshots are from v3.8.0** — the clipped
   «Bibliothèq/ue» in them is the label bug the fifth session already fixed and
   never released; the mixed-language tabs were checked on the current build and
   are gone.

### Counting the shapes is what made this affordable

Three times, what looked like hundreds of strings was a handful:
* 226 author death lines → **three** templates (`توفي N هـ`, `توفي نحو N هـ`,
  one note) plus an int field.
* 226 book blurbs → **one** generated sentence covering 197 of them, whose
  three slots (author, page count, category) were already solved, plus 29
  written paragraphs.
* 443 book titles and authors → **no translation at all**: both forms were
  already in the catalogue and no screen looked at the Latin one.

Count before translating.

### Verified on emulator-5554, not in anyone's head

French: the fired test adhan read «Adhan — prière du Dhuhr / Allahou Akbar —
c'est l'heure de la prière» with «Arrêter» and «Muet», and `dumpsys` showed the
three channels renamed in place on an upgrade install. English: the Library's
Hadith tab end to end, with the imam biographies in English. Spanish: the New
Muslim Guide, headings and bodies translated with the shahada still Arabic in
its own box.

**NOT swept on the device: Portuguese, Russian, Urdu and Arabic.** The owner
asked for exactly that — «كل اللي انت عملته مع الفرنساوي اعمله بالتفصيل مع باقي
اللغات لغه لغه». Do it, and screenshot each.

---

## 1. HADITH TRANSLATIONS — the owner's stated top priority, half done

> «اهم حاجة ترجمات المواد العلمية خاصة الحديث من مصادرها الموثوقة»

**HadeethEnc is measured and the crawler is written and was running at
handover.** Read `hadeethenc_survey.txt` — it prints one whole record in all
seven languages, so the field names were read, not guessed.

```
languages served: 72 — ar, en, es, fr, pt, ru, ur ALL present
categories: 493, of which 7 top-level
4,273 category entries -> 3,574 DISTINCT hadiths
  (a hadith sits in more than one category; the old 4,273 double-counted)
```

Every record carries `hadeeth`, `attribution` (تخريج) **and** `grade` (درجة) in
the target language, plus the Arabic originals as `*_ar`, plus an explanation
and word meanings. That is what makes it usable at all — CLAUDE.md §1.2 forbids
a grading without a named source.

```bash
py -3 scripts/hadeethenc_crawl.py            # resume; skips what it has
py -3 scripts/hadeethenc_crawl.py --status   # writes hadeethenc_status.txt
```

**At handover: 750 of roughly 25,000 (id, language) rows.** The crawl is slow
and polite (0.25 s between requests) and fully resumable — every row is
committed as it arrives. `hadeethenc.db` is gitignored.

**Honest gap already visible:** in the sampled record Urdu returned
`attribution` and `grade` still in Arabic. Where a field is not translated it is
stored as it came — never filled in from another language. Measure how often
that happens before deciding how the card should read.

### What is NOT done

* Nothing is wired into the app. The plan that fits: a **separate, fully
  documented collection beside the nine books**, hosted on R2 as per-language
  packs and downloaded on demand exactly like the 45 Quran translations, and
  credited on the Sources screen. Do **not** try to translate the nine books'
  67,153 hadiths — nothing translates that corpus.
* No R2 upload, no `AppConfig` version bump, no UI.

---

## 2. Two things still waiting on the OWNER's decision

He has been told about both and has not answered:

* **The `""` and stray `.` in the hadith text** (Sunan Abi Dawud 1417 — he
  photographed it again this session). Not corrupt data: the source wraps
  speech in ASCII quotes surrounded by invisible RLM marks, and 51,460 hadiths
  contain them. Stripping the invisible *control characters* at render time
  changes no letter and no punctuation — but CLAUDE.md §1.2 forbids editing
  hadith text, so it is his call.
* **Whether to ship the unattributed fr/ur/ru hadith sets** if HadeethEnc turns
  out not to cover something he wants.

---

## 3. Still open, in the order worth doing

1. **Finish the HadeethEnc crawl**, then design the collection and ship it. §1.
2. **Sweep the remaining four languages on the device.** §0.
3. **Release.** Nothing since v3.8.0 has been built into an APK. Bump
   `pubspec.yaml` (still `3.8.0+4`), one release at a time, delete the old
   release *and* its tag, tag from `master`, verify the tag's SHA equals
   `git rev-parse HEAD`.
4. **The tenth mushaf** — the Turkish Diyanet scan;
   `scripts/mushaf_pdf_build/turkish.pdf` (12.7 MB) is already on disk. Pages 1
   and 2 are a single spread and index 0 is a library bookplate, so the spread
   must be split and the folio offset pinned by reading printed page numbers.
   Every other candidate was examined and rejected with a stated reason — do
   not re-examine them.
5. **The full-screen adhan video** — still never fired on real hardware. Needs
   the owner's phone.

---

## 4. Things that will bite you

- **This shell eats backslashes in a heredoc.** `\b` became 0x08 and `\n`
  became a real newline inside a `<<'PY'` block, twice. Write a script with the
  Write tool and run it; do not pipe Python or Dart through a heredoc
  (CLAUDE.md trap #11, confirmed again).
- **Python's `\d` matches Arabic-Indic digits.** `re.sub(r"توفي (\d+) هـ", …)`
  cheerfully produced `deathYearAh: ٧٥١,` — valid-looking, invalid Dart.
  `flutter analyze` caught it as "Illegal character '1637'".
- **A `.tr()` inside a `const` constructor is a compile error** — drop the
  `const`.
- **`.tr()` does not register a `BuildContext` dependency.** Anything already
  built keeps the old language until something above it rebuilds. That is the
  whole reason the snackbar went stale.
- `easy_localization` re-exports `package:intl`, whose `TextDirection` collides
  with `dart:ui`'s. `import … hide TextDirection;` where you need `dart:ui`'s.
- **`ArabicText` forces RTL, and that is now sometimes wrong.** It exists for
  Arabic content in a Latin UI. Where a string became Latin (`properName`, the
  translated blurb, the death line) it must be a plain `Text`, or the bug just
  points the other way.
- Windows console is cp1256: write reports to a UTF-8 file and `cat` it.
- **A `flutter build apk --release` kills a running emulator** (#24). A
  `--debug` build did not, three times this session.
- **Never FTS5** (#1). **Soft-404s** (#5). **Books are gzip without a header**
  (#6). **A backslash before `$` in generated Dart is an escape** (#23).

## 5. The scripts you will want

| | |
|---|---|
| `i18n_audit.py` | the measurement; `chrome` / `native` / `content` / allowlisted |
| `hadeethenc_survey.py`, `hadeethenc_crawl.py` | §1 |
| `add_i18n_keys_*.py`, `patch_book_desc.py` | the pattern for a batch of keys |
| `build_mushaf_from_pdf.py` | scan PDF → `mushaf/<id>/NNN.jpg` on R2 |
| `check_mushaf_pages.py` | defect scan before uploading |
| `fit_mushaf_polygon_per_page.py` | one ayah affine per page; **look at the proofs** |
| `verify_hosted_content.py` | range-request every hosted path |
| `shamela_index.py find "<title>"` | search 8,598 book titles locally |
