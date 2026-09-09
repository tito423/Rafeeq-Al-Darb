# Rafiq Al-Darb — next session brief

**Last written:** 2026-09-09, at the end of the session that shipped **v3.6.0**.

You are picking up **رفيق الدرب / Rafeeq Al-Darb**, a personal **sideloaded**
Android Islamic app in Flutter. The owner's own app on his own repo
(`tito423/Rafeeq-Al-Darb`) — not a store app, not commercial. He writes in
Egyptian Arabic; **reply in Arabic**, keep code and commits in English.

## Read these, in this order, before touching anything

1. **`CLAUDE.md`** — the mandatory working method. **Start with §2.0: check the
   quota before you plan.** The previous session ran to 90% and had to wrap up
   in a hurry; that is exactly what §2.0 exists to prevent.
2. **`HANDOVER.md`** — the state block at the top.
3. This file.

## Where things stand

| | |
|---|---|
| Version | `3.6.0+2` |
| Checks | `flutter analyze lib test` clean · `flutter test` 25/25 |
| Locales | 7 · **665** leaf keys, parity enforced |
| Mushaf editions | **5** (the two riwayah editions were deleted at the owner's request) |
| Text-mushaf themes | **10** + 10 frames + 11 frame colours |
| Library | **223** books (8 Seerah titles added this session) |
| Adhans | **14** (3 supplied by the owner + أذان قناة الناس, all first in the list) |
| Ruqyah | 6 recordings on R2 + a composed reading screen |
| Channels | 7, every id/avatar verified against YouTube itself |
| Hadith | 67,153 in 9 books · `hadith.db` 109.7 MB |

## UNFINISHED — pick this up first

### 1. Three books are BUILT but not yet uploaded or catalogued

The crawl finished after v3.6.0 was already published, so these three are
sitting in `scripts/book_text_build/` and are **not** in the app yet:

- `as_seerah_ibn_kathir` (Shamela 930)
- `rijal_hawl_ar_rasul` (Shamela 9835) — **the owner asked for this by name**
- `la_tahzan` (Shamela 12729) — **asked for by name**

Their `META` entries are already in `scripts/add_seerah_catalog_entries.py`,
so the remaining job is three commands, then a rebuild and a re-release:

```bash
py -3 scripts/r2_upload_seerah_books.py as_seerah_ibn_kathir rijal_hawl_ar_rasul la_tahzan
py -3 scripts/add_seerah_catalog_entries.py
# then: bump pubspec to 3.6.1, flutter build apk --release,
# delete the v3.6.0 release + tag, publish v3.6.1 from master
```

**Do this first** — it is the cheapest win on the list and it closes out two
books the owner named personally.

`add_seerah_catalog_entries.py` skips anything already in the catalogue and
anything not yet uploaded, so it is safe to re-run. **Set
`PYTHONIOENCODING=utf-8`** or the build script dies printing Arabic (trap #10).

### 2. Ayah highlighting on the raster mushafs — measured, and mostly impossible

The owner asked for highlighting in **every** mushaf. The honest position,
established this session by overlaying the real polygons on real pages and
looking at the result (the images are in the conversation):

- **`hafs_kfqc`** (vector) — works today. Polygons, tap-to-select, sciences.
- **`tajweed_color`** — **the same Madinah line layout**, verified word-for-word
  on page 2; only the scale and offset differ because of its decorative
  border. This one is **solvable** with a per-edition affine fit (find the text
  block rectangle once, map the normalised polygons into it). Not started.
- **`madinah_gold`** — a *different typesetting*. Its page 2 sets 6 lines where
  the Madinah mushaf sets 15. No transform can fix that.
- **`shamarly`** (521 pages) and **`indopak_tajweed`** (564) — different
  paginations entirely. Same verdict.

Do not promise highlighting on the last three without building them a
coordinate layer from scratch.

### 3. Mushaf editions: 5, the owner wants 10

Five verified free printings are shipping. Five more need sourcing and
verifying (archive.org is the proven route — see trap #9). **Never add an
edition before a range request on a real page answers 206 with a real
`Content-Type` and a real byte size** — eight editions once shipped whose pages
all 404'd.

### 4. Books that are not on Shamela

Checked against a **local index of all 8,598 Shamela books**
(`scripts/shamela_index.json`, built by `scripts/shamela_index.py`; use
`find` on it rather than Shamela's own search, which searches *inside* books
and will hand you a commentary on a title instead of the title):

- **مفاتيح الفرج** — not there.
- **من فتاوى الرسول (عبد الله العفيفي)** — not there. Shamela has exactly one
  book by that author and it is a different one.
- **كتب د. مصطفى محمود** — he is not in Shamela's author list at all.
- **شريف شحاتة** — **no such author on Shamela.** The owner clarified he means
  a contemporary preacher. A web search finds a «الدكتور شريف شحاتة» who writes
  self-development books **sold commercially by a publisher**; there is no
  verified free source, so nothing was added. The owner's instruction was «مش
  نزلت خلاص انسى امرو» — treat this as closed unless he raises it again.

Also available and **not yet built**: 12 books by أبو إسحاق الحويني, 5 by
محمد حسان, 3 by مصطفى العدوي, 3 more by عائض القرني — all confirmed present in
the Shamela index with ids.

### 5. Never verified on real hardware

The full-screen adhan video render (notification tap / lock-screen
full-screen-intent) has still never fired under ADB on this emulator. It needs
the owner's actual phone.

## Traps this session added — read §3 of CLAUDE.md too

- **Avast intercepts TLS on this machine.** Every `boto3` upload to R2 fails
  with `CERTIFICATE_VERIFY_FAILED` because Avast re-signs the certificate with
  its own root, which is in the *Windows* store and never in `certifi`. R2 also
  sends only the leaf certificate, and Python does no AIA chasing. Fixed once
  in **`scripts/r2_common.py`**, which builds a bundle from certifi + the
  Windows root store. **Use `r2_client()` from there for every R2 script.**
  Never `verify=False` — those requests carry the bucket credentials.
- **`ffmpeg` is already on this machine** at `C:\Program Files\ShareX\ffmpeg.exe`.
  Nothing needs downloading to transcode audio.
- **A translucent highlight over a dark ground composites dark.** Three mushaf
  themes shipped dark ink on it and measured 2.3–2.6 : 1. Compute the composite
  and its contrast ratio before trusting any colour pairing.
- **Numbers mixed with Latin units reverse in Arabic.** `60.5 MB` rendered as
  `MB 60.5`. Everything now goes through `formatBytes()` in
  `lib/core/utils/byte_formatter.dart`, which wraps the fragment in a
  left-to-right isolate. There were five copies of that formatter; there is one
  now.

## Reminders that repeatedly matter

- **Verify on the emulator and look at the screenshot.** Four real bugs this
  session (a 0.8px slide overflow, a 6px reader-bar overflow, the AM/PM marker
  cut by the clock hands, the reversed size text) were all found by looking,
  not by reading.
- **Never FTS5.** Android's SQLite has no such module.
- **One release at a time**, previous release *and tag* deleted, tagged from
  `master`, `pubspec.yaml` bumped to match.
- **Checkpoint with `.\cp.bat "…"` constantly.**
