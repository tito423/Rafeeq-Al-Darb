# Rafiq Al-Darb — next session brief

**Last written:** 2026-09-09, at the end of the session that shipped **v3.7.0**.

You are picking up **رفيق الدرب / Rafeeq Al-Darb**, a personal **sideloaded**
Android Islamic app in Flutter. The owner's own app on his own repo
(`tito423/Rafeeq-Al-Darb`) — not a store app, not commercial. He writes in
Egyptian Arabic; **reply in Arabic**, keep code and commits in English.

## Read these, in this order, before touching anything

1. **`CLAUDE.md`** — the mandatory working method. **Start with §2.0: check the
   quota before you plan.**
2. **`HANDOVER.md`** — the state block at the top.
3. This file.

## Where things stand

| | |
|---|---|
| Version | `3.7.0+3` |
| Checks | `flutter analyze lib test` clean · `flutter test` **30/30** |
| Locales | 7 · **665** leaf keys, parity enforced |
| Mushaf editions | **6** — `hafs_kfqc`, `tajweed_color`, `shamarly`, `madinah_gold`, `indopak_tajweed`, **`qatar`** (new) |
| Ayah layer | **2 of 6** — `hafs_kfqc` (own polygons) and `tajweed_color` (Hafs polygons under a fitted affine) |
| Text-mushaf themes | 10 + 10 frames + 11 frame colours |
| Library | **226** books (the 3 that were mid-crawl at v3.6.0 are in) |
| Adhans | 14 · Ruqyah 6 · Channels 7 |
| Hadith | 67,153 in 9 books · `hadith.db` 109.7 MB |
| R2 bucket | 1.54 GB before this session, **+154 MB** for the Qatar pages |

## What this session finished

1. **The three books that were still crawling at v3.6.0.**
   `as_seerah_ibn_kathir`, `rijal_hawl_ar_rasul`, `la_tahzan` — uploaded,
   range-verified on the public endpoint, catalogued. 226 books.
2. **Ayah highlighting + tap-to-sciences on the Tajweed mushaf** — the first
   raster printing to have them. Details below and in `HANDOVER.md` §5.
3. **مصحف قطر** as the sixth printing — 604 pages, verified page by page.

---

## UNFINISHED — in the order worth doing

### 1. Give مصحف قطر its ayah layer (the mechanism already exists)

The Qatar printing **does** follow the Madinah page and line division — checked
on 11 pages spread across the mushaf, each carrying the same surah and juz as
the Madinah page of that number, and page 50 setting the same 13 lines with the
same words on each. So the Hafs polygons can be mapped onto it exactly as they
now are onto the Tajweed printing.

**What blocks it:** its scans are cropped slightly differently page to page —
the embedded images run 1720–1779 × 2294–2399, about 2% of variation, which is
a third of a line height. One affine for the whole edition would drift.

**What to do:** fit **per page**. `MushafEdition.polygonFitPages` already takes
per-page overrides (it is what the Tajweed printing's two illuminated opening
pages use), and `scripts/fit_mushaf_polygon_transform.py` already contains the
line-detection and fitting machinery — `scan_body_lines()` returns the printed
lines of any page. Generalise it to emit 604 entries instead of one, then
render the proof overlays and **look at them** before believing it.

Rough size: 604 × 5 floats ≈ 50 KB of JSON in `editions.json`, which is a
bundled asset — fine.

### 2. Four more printings (the owner wants ten)

Six ship. **Do not add one before a range request on a real page answers 206
with a real `Content-Type` and a real byte size** — eight editions once shipped
whose pages all 404'd. `scripts/build_mushaf_from_pdf.py` does the whole
pipeline now (render / upload / verify); add an entry to its `EDITIONS` dict.

Candidates found on archive.org this session, with what is known about each:

| Item | What it is | Verdict |
|---|---|---|
| `QuranMushafQatar` | مصحف قطر, 254 MB PDF, CC BY-NC-SA 3.0 | **shipped this session** |
| `AlQuran16LinesTaj` | Taj Company 16-line Indo-Pak, 559 pp, clean scan | **REJECTED — do not use.** Its own back page prints «جملہ حقوق محفوظ» and a copyright warning naming Taj Company Ltd. Not ours to rehost. |
| `HQ23AlQuranAlKareemMushafDolatUlKuwaitWww.Quranpdf.blogspot.in` | مصحف دولة الكويت, 94 MB PDF | not yet inspected; no licence stated |
| `QuranMadina35685363568hNight` | مصحف المدينة، الطبعة الليلية, 307 MB | not yet inspected; no licence stated. Same typesetting as `hafs_kfqc`, so it would likely take a single affine and get highlighting cheaply |
| `holy-quran-in-high-quality-qatar-interpret-network-15-lines` | Qatar 15-line, 250 MB | not yet inspected |
| `AlQuranAlKAreemKuwaitLineMohamedSaadIbrahimHaddad...` | Kuwait, Muhammad Sa'd Ibrahim's hand | not yet inspected |

**Check each one's own back matter for a copyright notice before building it.**
The Taj rejection is the reason this row exists.

### 3. The Warsh and Qalun page sets are still sitting on R2 — ask him

The owner said «احذف مصاحف الروايات» and a previous session removed the two
editions from `editions.json`. **Their page images were never removed from the
bucket**: `mushaf/warsh` (604 objects, 173.2 MB) and `mushaf/qaloon` (604
objects, 97.2 MB) — 270 MB, 17% of the bucket, referenced by nothing.

Deleting 1,208 objects is irreversible and re-uploading them would cost hours,
so this session did **not** delete them. **Ask him.** If he says yes it is one
`delete_objects` loop with `r2_client()`.

### 4. The old brief overstated what more books are available — corrected here

The previous brief said "12 books by أبو إسحاق الحويني, 5 by محمد حسان, 3 by
مصطفى العدوي, 3 more by عائض القرني — all confirmed present in the Shamela
index with ids." **That is not what the index contains.** Searched again this
session against all 8,598 books
(`py -3 scripts/shamela_index.py find "..."`), the whole of what exists is:

| id | title | note |
|---|---|---|
| 627 | المنتقى — ابن الجارود، ت الحويني | al-Huwaini **edited** it; he did not write it |
| 313 | فضائل بيت المقدس — ابن الجوزي، ت الحويني | same |
| 19482 | الأحاديث القدسية الأربعينية، ت الحويني | same |
| 312 | الترياق بأحاديث قواها الألباني وضعفها الحويني | his own |
| 7693 | دروس للشيخ أبي إسحاق الحويني | transcribed lecture series, not a book |
| 905 | الدار الآخرة — محمد حسان | his own |
| 7703 | دروس للشيخ محمد حسان | lecture series |
| 7695 | سلسلة التفسير لمصطفى العدوي | lecture series |
| 10631 | المنتخب من مسند عبد بن حميد، ت مصطفى العدوي | he edited it |
| 7694 | دروس للشيخ مصطفى العدوي | lecture series |
| 7708 | دروس الشيخ عائض القرني | lecture series |

So: **four** actual books by these authors, plus five lecture-series
compilations that are a different kind of thing. Tell the owner that before
promising him 23 titles. The classical catalogue is far from exhausted if he
wants more volume — there are 8,598 books in the index and 226 in the app.

### 5. Still never verified on real hardware

The full-screen adhan video render (notification tap / lock-screen
full-screen-intent) has still never fired under ADB on this emulator. **It
needs the owner's actual phone.** This is the one item that cannot be closed
from here.

---

## How the Tajweed ayah layer works — read before touching it

It has **no polygon layer of its own.** It borrows the Hafs one through an
affine, because the two printings set the same 15-line Madinah page.

That claim was established by measurement, not by eye: line positions on 30
Tajweed scans and on the Hafs polygons **both collapse to exactly 15 clusters**,
with matching per-cluster counts. Then:

* `x' = 0.980009·x + 0.013937`, `y' = 0.974249·y + 0.017192` for the 602 body
  pages, and separate fits for pages 1 and 2, which are illuminated openings
  with their own frame, their own text block and their own pixel size.
* Every one of the 604 pages' real dimensions was read from its JPEG header:
  exactly two groups, 602 at 861×1317 and pages 1–2 at 901×1476, no exceptions.
* Checked two ways: **841 real polygon rings across 86 pages** land a median
  3.9 px from their printed line on an 84 px pitch (95th percentile 11.9 px),
  and the mapped polygons were **rendered over the real scans and looked at**.
* Then verified on `emulator-5554`: a tap opened the sciences sheet on exactly
  2:3, and the recitation highlight painted 2:2 across its two-line wrap on the
  opening page and 3:2 on body page 50, marker to marker.

`scripts/fit_mushaf_polygon_transform.py` reproduces all of it and writes the
proof overlays. **The numbers are not the evidence; the pictures are.**

`AyahCoordsRepository` is keyed by **asset path**, not edition id, so both
editions share one parse of the 0.7 MB layer. A raster page that has a fit is
laid out inside an `AspectRatio` of its own measured shape — with
`BoxFit.contain` alone the drawn rectangle depends on the surrounding box and
the highlight would float free of the text.

`test/mushaf_polygon_fit_test.dart` pins the fit to **measured pixel positions
on the printed pages**, so an edit to `editions.json` that drifts the highlight
off the text fails there instead of shipping.

---

## Reminders that repeatedly matter

- **Verify on the emulator and look at the screenshot.** Everything real found
  on this project was found by looking.
- **Never FTS5.** Android's SQLite has no such module.
- **Never catalogue content before a range request on the public endpoint
  answers 206** with a real content type and a real byte size.
- **Check a scan's own back matter for a copyright notice** before rehosting it.
- **One release at a time**, previous release *and tag* deleted, tagged from
  `master`, `pubspec.yaml` bumped to match.
- **Checkpoint with `.\cp.bat "…"` constantly.**
