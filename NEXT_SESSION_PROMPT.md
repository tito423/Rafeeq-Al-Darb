# Rafiq Al-Darb — next session brief

**Last written:** 2026-09-09, at the end of the fifth session. The session
ended on a **clean tree with `analyze` clean and 43/43 tests passing**, but
with **nothing released** — everything below is committed on `master` and not
yet in an APK.

You are picking up **رفيق الدرب / Rafeeq Al-Darb**, a personal **sideloaded**
Android Islamic app in Flutter. The owner's own app on his own repo
(`tito423/Rafeeq-Al-Darb`) — not a store app, not commercial. He writes in
Egyptian Arabic; **reply in Arabic**, keep code and commits in English.

## Read these, in this order, before touching anything

1. **`CLAUDE.md`** — the mandatory working method. **Start with §2.0: check the
   quota before you plan.** The last session ran out at 98% mid-task.
2. **`HANDOVER.md`** — the state block at the top.
3. This file.

---

## 0. THE ONE THING THE OWNER CARES ABOUT RIGHT NOW

> «مش عايز حاجة اسمها اللغة تبقى مثلا فرنساوي والاقي شاشة وحدة مش مترجمة، كل
> شاشة وكل كارت منفصلا ومنفردا يجب انه يكون مترجما ترجمة صحيحة كاملة للغة
> المختارة بكل سطر كود في التطبيق.»

Every screen, every card, fully translated. This is measured, not guessed:

```bash
py -3 scripts/i18n_audit.py     # writes i18n_audit.txt
```

**It printed `1497 total, 89 chrome, 1408 content` at the end of the session**
(it was 167 chrome when the session started). Drive `chrome` to zero, then
start on `content`.

* **chrome** — UI text hardcoded in a widget or a service. Mechanical: give it
  a key, translate the key into all seven locales, done. The pattern is
  established — see `scripts/add_i18n_keys_notifications.py` and
  `scripts/add_i18n_keys_dawah.py`; write one of those per batch rather than
  hand-editing seven JSON files.
* **content** — Arabic the app itself authors. 1,217 of the 1,408 are the
  library book catalogue (226 books × title/author/blurb), 130 are the
  New Muslim Guide, then imam bios (19), channels (14), adhan text (8),
  ruqyah (7). Plus, NOT counted by the audit because it only scans Dart:
  **134 azkar section titles and 298 azkar item bodies** in
  `quran_sciences.db`, and 114 surah names in `quran_local.db`.

**A hard line to keep:** the azkar item bodies are duas and Qur'an/hadith text.
Those need a *sourced* translation (see §2), never one you write yourself.
Book blurbs, imam bios and channel descriptions are the app's own prose and
are yours to translate.

### What was already done to the chrome, and the exact pattern to copy

| done | how |
|---|---|
| every notification (azkar, khatma, sunan, downloads, prayer card) | keys under `notif.*`; the `const` on `AndroidNotificationChannel` / `NotificationDetails` has to be dropped when a `.tr()` goes inside it |
| the twelve Hijri months | were hardcoded **twice**, ar+en only. Now `core/i18n/hijri_months.dart` → `hijri.m1..m12` + `hijri.suffix` |
| prayer names in the persistent notification | had a hand-rolled ar/en/es/ru/pt table with **no French and no Urdu**; now `prayer.<key>`.tr() |
| 10 dawah channels + 5 Islamic sites | `dawah.*` description keys; the **names stay Arabic** — they are the real names of Arabic-language channels — and render through `ArabicText` |

**`core/widgets/arabic_text.dart`** is the other half of this: Arabic content
inside a Latin UI inherits a left-to-right paragraph and comes out with its
separators and sentence-final punctuation at the wrong end. Use `ArabicText`
for whole-Arabic content, and `rtl()` / `ltr()` from
`core/utils/byte_formatter.dart` for a fragment inside a mixed line.

### The immediate next step (this is where the session stopped)

The dawah/site work is **complete and compiling** — a background shell showing
"Stopped" for it was superseded by the same edit applied by hand; `analyze` is
clean and 43/43 pass. Nothing is half-applied.

Next: work down `i18n_audit.txt`'s remaining 89 chrome findings. The real ones
left are, roughly:

* `features/library/presentation/screens/library_screen.dart` — a few labels
* `features/settings/presentation/screens/sources_screen.dart` — 3 source names
* `ayah_share_card.dart`, `ayah_audio_service.dart` — «رفيق الدرب» should be
  `app.name`.tr()
* `quran_screen.dart` / `mushaf_nav_sheets.dart` — «الجزء» hardcoded
* `adhan_entry.dart` — the fallback prayer label «الصلاة»

**Deliberate, not findings** (add them to an allowlist in the audit script
with the reason, rather than "fixing" them):

* the basmalah previews in `mushaf_theme_picker.dart` and
  `non_arabic_reading_card.dart` — they are font samples, and the sample is
  the point;
* the Arabic-Indic digit tables in `quran_screen.dart`,
  `mushaf_nav_sheets.dart`, `analog_clock_faces.dart`,
  `digital_clock_faces.dart` — a mushaf's page number is set in Arabic-Indic
  digits on purpose, and one clock face is an Arabic-numeral face;
* `"Tito Abo Malak"` in `about_screen.dart` — the owner's name.

---

## 1. HADITH TRANSLATION — the correction that matters

An earlier reply in that session told the owner that **no Spanish or
Portuguese translation of the hadith collections exists in any redistributable
source**. **That was wrong, and he was right to push back.** Measured:

```
https://hadeethenc.com/api/v1/languages
  → ar, en, ur, es, ru, fr, pt  (+53 more)
```

**HadeethEnc** (موسوعة الأحاديث النبوية) returns, for every hadith:
`hadeeth_ar`, `attribution_ar` («متفق عليه»), `grade_ar` («صحيح»),
`explanation_ar`, `hints_ar` — **and the same fields translated**, with their
own attribution and grade, in the requested language. Measured size:
**≈ 4,273 hadiths** across the 7 top-level categories (493 categories in all;
summing every category double-counts to 15,222).

```
/api/v1/categories/list/?language=ar
/api/v1/hadeeths/list/?language=es&category_id=5&page=1&per_page=100   → ids + titles only
/api/v1/hadeeths/one/?language=es&id=3086                              → the full record
```

One `one` call per hadith per language; the Arabic comes free with every call.
≈ 4,300 × 6 non-Arabic languages ≈ **26,000 requests** — budget for it.

**Architecture that fits this app:** do NOT try to translate the nine books'
67,153 hadiths — nothing translates that corpus. Add HadeethEnc as its own
fully-documented, multilingual collection beside them, hosted on R2 as
per-language packs and downloaded on demand exactly like the 45 Quran
translations. Credit it on the Sources screen.

What ships today, and why: `hadith.db` carries an English rendering for
**36,148 of 67,153** hadiths from sunnah.com's published translations (named
translators). Musnad Ahmad's 27,584 and al-Darimi's 3,406 have none in any
language. The `fawazahmed0/hadith-api` fr/ur/ru sets are public domain but
**name no translator**, and the French Bukhari sampled reads as a translation
of the English rather than of the Arabic — so they were not shipped, and the
owner was told rather than it being decided for him. `HadithTranslation`
(`features/library/presentation/widgets/hadith_translation.dart`) always
labels what language the text is and where it came from, and says so plainly
when a collection has no translation at all.

---

## 2. Where things stand

| | |
|---|---|
| Version | `pubspec.yaml` still `3.8.0+4` — **bump it before releasing** |
| Released | v3.8.0 (before this session). **Everything since is unreleased.** |
| Checks | `flutter analyze lib test` clean · `flutter test` **43/43** |
| Locales | 7 · parity enforced by `test/translation_parity_test.dart` |
| Mushaf editions | **9**, and **5 of them highlight ayahs** (was 4) |
| Library | 226 books · Hadith 67,153 in 9 books |
| R2 bucket | 1.81 GB / 5,012 objects — **measured last session, NOT re-verified this one** |

### What this session shipped (all committed, none released)

1. **The continuous-recitation bug the owner reported.** `quran_screen.dart`
   passed `startContinuous` a **mushaf** id where a **reciter** id belongs
   (both `String`, so analyze saw nothing) → every verse resolved to
   `cdn.islamic.network/quran/audio/128/hafs_kfqc/<n>.mp3` → 404 → the catch
   arm called `stopContinuous()`. Picking a verse **stopped** the recitation.
   `test/recitation_edition_test.dart` was proven to fail on the old code.
2. **The sciences sheet's play button** read the shared player, so
   mid-recitation it rendered as STOP and killed the run. It is now
   «اقرأ من هنا» and jumps the recitation to that verse.
3. **The background hang** («التلاوة بتهنج ... مفيش حاجة بتحصل»): the player
   is rebuilt on failure (`just_audio_background` accepts a new player after a
   disposed one — read in the pub cache, then proven on the device), the state
   gains `stalled`, and a genuine failure is now *reported* instead of ending
   in silence. **The trigger itself could not be reproduced on the emulator** —
   see HANDOVER §"honest gaps".
4. **Splash / theme / permissions**: day theme by default on a fresh install;
   a splash-video sound switch; and the POST_NOTIFICATIONS dialog no longer
   lands on top of the splash video — the culprit was
   `DownloadEngine.ensureInitialized()`, called from `main()` via
   `resumeFromBackground()`, firing at 4.8s into an ~8s video (found in
   logcat, not by reading).
5. **The gilded mushaf highlights ayahs** — all 604 pages fitted directly. The
   claim that kept it out for three sessions («6 lines on page 2») was a
   measurement of the wrong thing: page 2 of *any* Madinah printing is
   al-Baqarah's illuminated opening and sets six lines.
6. **Kuwait's two illuminated openings are fitted.** Darkness was the wrong
   test — the illumination is coloured and the ink is neutral, so a
   **saturation** mask separates them.
7. **Language switching now re-renders every tab** (it did not, which is why
   the owner saw French chrome under an English UI), the bottom-nav label
   clipping is fixed and guarded by a test, and Arabic content inside a Latin
   UI is laid out RTL.

---

## 3. Still open, in the order worth doing

1. **Finish the i18n job** — §0. This is what he asked for last.
2. **HadeethEnc integration** — §1.
3. **The tenth mushaf.** Best remaining lead is the Turkish Diyanet scan;
   `scripts/mushaf_pdf_build/turkish.pdf` (12.7 MB) is **already on disk**. Its
   PDF holds pages 1 and 2 as a single spread and index 0 is a library
   bookplate, so the spread must be split and the folio offset pinned by
   reading printed page numbers. Every other candidate was examined and
   rejected with a stated reason — do not re-examine them.
4. **The full-screen adhan video** — still never fired on real hardware. Needs
   the owner's phone; it cannot be closed from here.
5. **Release.** Nothing since v3.8.0 has been built into an APK. Bump
   `pubspec.yaml`, one release at a time, delete the old release *and its tag*,
   tag from `master`.

### Two things the owner has flagged that need HIS decision

* **The `""` and stray `.` in the hadith text** (Sunan Abi Dawud 1417 in his
  screenshot). It is **not corrupt data**: the source itself wraps speech in
  ASCII quotes surrounded by `‏` RLM marks, and 51,460 hadiths contain
  them. Stripping the invisible *control characters* at render time changes no
  letter and no punctuation — but CLAUDE.md §1.2 forbids editing hadith text,
  so it is his call, and he has not answered yet.
* **Whether to ship the unattributed fr/ur/ru hadith sets** if HadeethEnc
  turns out not to cover something he wants. He was told the trade-off.

---

## 4. Things that will bite you

- **Check the quota first (§2.0).** The last session died at 98% mid-edit.
- A `.tr()` inside a `const` constructor is a compile error — drop the `const`.
- `easy_localization` re-exports `package:intl`, whose `TextDirection` collides
  with `dart:ui`'s. `import ... hide TextDirection;` in any file that needs
  `TextDirection.rtl`.
- **`.tr()` does not register a `BuildContext` dependency** — it reads a
  global. A widget that only calls `.tr()` will not rebuild on a locale change
  unless something above it does. That is the whole reason tabs froze.
- **Fetchable is not legible** (CLAUDE.md #25), **a release build kills the
  emulator** (#24), **a backslash before `$` in generated Dart is an escape**
  (#23), **never FTS5**.
- Windows console is cp1256: write reports to a UTF-8 file and `cat` it.
- `.\cp.bat "…"` chokes on very long notes with quotes; call
  `scripts/checkpoint.ps1 -Note $note` directly, reading the note from a file.

## 5. The scripts you will want

| | |
|---|---|
| `i18n_audit.py` | **the measurement for §0** — untranslated strings, split into chrome / content |
| `add_i18n_keys_notifications.py`, `add_i18n_keys_dawah.py` | the pattern for adding a batch of keys to all 7 locales at once |
| `build_mushaf_from_pdf.py` | scan PDF → `mushaf/<id>/NNN.jpg` on R2 |
| `check_mushaf_pages.py` | defect scan + printed-header check before uploading |
| `fit_mushaf_polygon_per_page.py` | one ayah affine per page; `--fit` then `--proof` and **look at the pictures** |
| `verify_hosted_content.py` | range-request every hosted path the app uses |
| `shamela_index.py find "<title>"` | search 8,598 book titles locally |
