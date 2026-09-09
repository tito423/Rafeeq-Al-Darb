# Rafiq Al-Darb — next session brief

**Last written:** 2026-09-09, at the end of the session that shipped **v3.8.0**.

You are picking up **رفيق الدرب / Rafeeq Al-Darb**, a personal **sideloaded**
Android Islamic app in Flutter. The owner's own app on his own repo
(`tito423/Rafeeq-Al-Darb`) — not a store app, not commercial. He writes in
Egyptian Arabic; **reply in Arabic**, keep code and commits in English.

## Read these, in this order, before touching anything

1. **`CLAUDE.md`** — the mandatory working method. **Start with §2.0: check the
   quota before you plan.**
2. **`HANDOVER.md`** — the state block at the top, then §5.-1 and §5.0.
3. This file.

## Where things stand

| | |
|---|---|
| Version | `3.8.0+4` |
| Checks | `flutter analyze lib test` clean · `flutter test` **37/37** |
| Locales | 7 · **665** leaf keys, parity enforced |
| Mushaf editions | **9** (see the table below) |
| Ayah layer | **4 of 9** printings highlight ayahs and open the sciences sheet |
| Library | **226** books |
| Quran translations | 45 languages (6 bundled); catalogue and bucket match exactly |
| Adhans | 14 · Ruqyah 6 · Channels 7 |
| Hadith | 67,153 in 9 books · `hadith.db` 109.7 MB |
| R2 bucket | **1.81 GB**, 5,012 objects — measured at handover, after the riwayah deletion (−270 MB, 1,208 objects) and the four new page sets (+542 MB) |

### The nine printings

| id | pages | Madinah page? | ayah layer | source |
|---|---|---|---|---|
| `hafs_kfqc` | 604 | yes | its own polygons | quranpedia/quran-svg (vector) |
| `tajweed_color` | 604 | yes | **yes** — one affine per page group | archive.org |
| `qatar` | 604 | yes | **yes** — one affine per page | `QuranMushafQatar` |
| `kuwait` | 604 | yes | **yes** — per page, except pages 1-2 | `HQ23…DolatUlKuwait…` |
| `madinah_night` | 604 | yes | **yes** — one affine per page | `QuranMadina…hNight` |
| `madinah_gold` | 604 | yes | no — see §3 below | `smartmushaf` |
| `shamarly` | 521 | no | no | `QURANShamarly` |
| `indopak_tajweed` | 564 | no | no | `TajweediColor-coded…` |
| `madinah_nastaleeq` | 611 | no | no | `mushaf-al-madinah_nastaleeq` |

---

## UNFINISHED — in the order worth doing

### 1. The tenth printing — every candidate examined was rejected, with reasons

He asked for ten. Nine ship. **Do not pad the list to reach ten** — that is the
opposite of what he asked for. What was examined this session:

| candidate | why not |
|---|---|
| `AlQuran16LinesTaj` (Taj Company, 16-line, 559 pp) | **Its own back page prints «جملہ حقوق محفوظ» and a copyright warning naming Taj Company Ltd.** The Qur'an text is nobody's property; a publisher's typesetting and scan can be. Not ours to rehost. |
| `06MushafAlMadinahOld549` | The title says 549 but its folios say otherwise: index 6 prints ٥ and index 602 prints ٦٠١, so it is the ordinary **604-page Madinah mushaf** — the same typesetting the app already ships as `hafs_kfqc`. Adding it would be padding. |
| `Kuran-Kerim-ArapaMushaf-erif-Diyanet-` (Turkish Diyanet) | Genuinely distinct and attractive, but its PDF holds **pages 1 and 2 as a single spread image**, and index 0 is a school library bookplate. **This is the best remaining lead** — if you can split that spread and pin the folio offset by reading printed page numbers, it is a real tenth. |
| the Madinah colour variants (green/brown/blue/pink/red) | The same printing in different cover stock. Padding. |
| Warsh, Qalun, Shu'bah editions | Riwayat, not printings. The owner had these deleted. |

**Before building any printing:** read its front AND back matter for a rights
notice (CLAUDE.md #18), measure its folio offset by reading printed page
numbers (never assume), and run
`py -3 scripts/check_mushaf_pages.py <edition>` on the rendered pages before
uploading (CLAUDE.md #25). `scripts/build_mushaf_from_pdf.py` does render /
upload / verify; add an entry to its `EDITIONS` dict.

### 2. Kuwait's two illuminated openings have no ayah highlight

Deliberate, not an oversight — see `HANDOVER.md` §5.0. Its warm cream ground
and brown ink defeated every attempt to separate the seven Fatiha lines; the
best found six. To close it, measure the panel by eye off
`scripts/mushaf_pdf_build/kuwait/001.jpg`, add it to `special` in
`scripts/fit_mushaf_polygon_per_page.py`, then render the proof overlay and
**look at it**. Six of seven lines would put the highlight one line out on
al-Fatiha, which is exactly why it is off.

### 3. `madinah_gold` may well be fittable, and has not been re-checked

It is the only 604-page printing on the Madinah page division without an ayah
layer. The claim that it "sets 6 lines on its page 2" came from an earlier
session and predates the line-detection tooling that now exists. Run the
per-page fitter over it before believing it.

### 4. Still never verified on real hardware

The full-screen adhan video render (notification tap / lock-screen
full-screen-intent) has still never fired under ADB on this emulator. **It
needs the owner's actual phone.** This is the one item that cannot be closed
from here.

### 5. More books, if he wants volume

226 in the app against 8,598 in the Shamela index, so there is plenty. Note
that the brief two sessions ago promised "12 books by أبو إسحاق الحويني, 5 by
محمد حسان, 3 by مصطفى العدوي, 3 more by عائض القرني" — searched again against
the whole index, what exists is **four** actual books by those authors plus
five transcribed lecture series, which are a different kind of thing. Do not
repeat that promise to him.

---

## Things that will bite you

- **Fetchable is not legible.** Four Qatar pages answered a range request and
  were still unreadable — a green block, a pink wash, a grey wash, a torn
  orange band, all in the source's own embedded JPEGs. CLAUDE.md #25.
- **A page may honestly have no ayah fit**, and a per-page printing therefore
  carries **no `default`** in `editions.json`, so a page with no entry falls
  through to no highlight rather than a borrowed one. CLAUDE.md #26.
- **A release build kills the running emulator** on this machine — twice this
  session. Build first, start the emulator after. CLAUDE.md #24.
- **In generated Dart a backslash before `$` is an escape**, not
  interpolation — eleven book URLs shipped as literal text because of it.
  CLAUDE.md #23.
- **Never FTS5.** Android's SQLite has no such module.
- **One release at a time**, previous release *and tag* deleted, tagged from
  `master`, `pubspec.yaml` bumped to match.
- **Checkpoint with `.\cp.bat "…"` constantly.**

## The scripts you will want

| | |
|---|---|
| `build_mushaf_from_pdf.py` | scan PDF → `mushaf/<id>/NNN.jpg` on R2; `--render --upload --verify` |
| `check_mushaf_pages.py` | defect scan + printed-header check for a rendered page set |
| `fit_mushaf_polygon_transform.py` | one ayah affine per page group (uniform crops) |
| `fit_mushaf_polygon_per_page.py` | one ayah affine per page (individually cropped leaves) |
| `build_mushaf_covers.py` | each edition's real printed cover, from a URL, a local render or a PDF page |
| `verify_hosted_content.py` | range-request every hosted path the app uses |
| `r2_delete_riwayah_mushafs.py` | the audit + deletion that removed Warsh/Qalun |
| `shamela_index.py find "<title>"` | search 8,598 book titles locally — Shamela's own search searches *inside* books |
