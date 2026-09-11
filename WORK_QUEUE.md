# Work queue — the owner's third batch, 2026-09-11

Sent while testing v3.15.0 on his own phone, with 30 screenshots — including
**screenshots of two other apps** as references for how a highlight and a dark
page should look. He also pasted an AI-written architecture brief («اعمل
OpenCV pipeline…») and asked what I thought of it before anything was built.

Marked **DONE (seen)** only after it has been run on a device and looked at
(§1.3). Everything below is measured against the real asset, not recalled.

---

## B0 · The pasted brief: what was right, and what was already there

The brief asked for an OpenCV morphology pipeline to extract word boxes from
each of the mushaf scans, per-mushaf kernel settings, conversion to relative
percentages, and an HTML page that fakes a rotation.

**Its central idea — "one rectangle per line, not one box per ayah" — is
correct and is now implemented (B1).** The rest does not fit this app:

* **The coordinates are already relative.** `AyahRegion.rings` are normalized
  0..1 of the page box and have been since they were built; the widget puts
  the page in an `AspectRatio` of its own measured shape and multiplies at
  paint time. That is the brief's "CRITICAL" item, already shipped.
* **Contour detection would be a downgrade.** The polygons come from the
  publisher's own hit layer (quranpedia/quran-svg, CC0) and are verified
  6,236 / 6,236 against `quran_local.db`. Morphology on a *decorated colour
  scan* — Indo-Pak red/blue tajweed, Kuwait's illuminated openings, Qatar's
  cropped leaves — finds frames, rosettes, ayah medallions and footnotes, and
  has no way to know which blob is which ayah. It would replace measured data
  with guessed data, which §1.1 forbids.
* **The three printings that have no highlight are not a detection problem.**
  Shamarly (521 pages), Indo-Pak (564) and Nastaleeq (611) paginate their own
  way, so no layer measured on the 604-page Madinah grid maps onto them. A
  better kernel does not fix a different page break; only a per-page fit for
  those printings would, and that is a separate, honest piece of work.
* **An HTML rotation harness proves nothing here.** This is Flutter; the
  layout under test is `AspectRatio` + `LayoutBuilder`, not CSS. The real
  check is the emulator, rotated (§1.3).

---

## B1 · The highlight covered half the page

His photographs: al-Baqarah 2:32 on page 6, ar-Ra'd 13:38 on page 254 — a
solid block across several lines. His reference screenshot of another app
shows what it should be: a tight mark per line with paper visible between.

**Measured in `hafs_kfqc_polygons.json`, 604 pages, 11,386 rings:**

* every ring is already a 4-point rectangle — the brief's "multi-rect" exists;
* a one-line ring is 0.86–0.99 of the line pitch, so it **touches both
  neighbours** and two marked lines composite into one slab;
* **1,054 rings (9.3%) are ONE rectangle spanning several lines** — the worst
  8.59 lines, page 353, an-Nur 31.

That layer is a **tap** layer; forgiving boxes are right for a tap and wrong
for a mark. `ayah_highlight_rects.dart` recovers each page's line grid from
the rectangles' own edges, cuts every rectangle at those lines, and insets each
band by 9% of the pitch. Median pitch over all 604 pages is 0.06705 — the
Madinah 15-line grid, measured rather than assumed — and is the fallback for a
page with too few edges to derive its own.

STATUS: **DONE (seen)** — al-Baqarah 2:17 on page 4, emulator-5554: two
separate rounded marks with paper between them. 7 tests, the first two of
which re-measure the defect itself.

## B2 · Landscape draws the page the size of a stamp

Two screenshots: page 4 and page 417 in landscape, each about 130 logical
pixels wide in the middle of an empty screen.

Cause, and it is arithmetic: the page was laid out with `Center(AspectRatio)`,
so it fits the *height*. A phone on its side leaves roughly 200 logical pixels
under the toolbar; 200 × 0.63 is that stamp.

Landscape now lays the page out at the **full width** and scrolls it
vertically. Stated cost: pinch-zoom is off in landscape, because a vertical
scroll and an `InteractiveViewer` cannot both own the drag, and full width is
already the largest the page can be drawn — and about three lines of the page
are on screen at a time, which is the trade for legible text.

STATUS: **DONE (seen)** — rotated on emulator-5554: the page spans the full
2400 pixels.

## B3 · «الانتقال إلى» sat under the number pad — and had the wrong range

The dialog's buttons were behind the keyboard in landscape (his screenshot),
and separately it accepted any page **1–604, hard-coded**. Three of the nine
printings are not 604 pages: it refused page 607 of the 611-page Nastaleeq and
accepted page 600 of the 521-page Shamarly.

Both fixed; the range is now the current printing's and is printed under the
field. Proved on the old code — both new expectations fail there.

STATUS: **DONE (seen)** — both buttons clear the number pad in landscape. The
first fix still clipped the title, so a screen with under 420 logical pixels
left drops it; and the range read «604 – 1» (trap #16), so it is in an LTR
isolate. 3 tests, one of which asserts the plain string is NOT on screen.

## B4 · «إصلاح التحميلات» sits on top of the list

A floating button reserves no space, so the last rows of all three tabs were
underneath it (his screenshots of سورة النساء and العربية 20.2 MB). Every list
in that screen now keeps `kRepairButtonClearance` at its foot.

STATUS: FIXED — **not yet opened on a device**

## B5 · Landscape, text mode: the surah header sits on the text

His screenshot shows «سُورَةُ البَقَرَة» drawn over the first line, with two
lines of text visible. Not yet touched.

STATUS: open

## B6 · «زي نظام ختمة اللي باللون الأسود»

The reference is a reflowed **text** page filling the screen edge to edge. Our
dark raster page keeps black bands above and below because a 0.63-ratio scan
on a 0.46-ratio phone can only fit by width — the bands are the shape of the
paper, not a bug. What can honestly be gained is cropping the scan's own
margin in ملء الشاشة, which needs the highlight overlay cropped with it.

Needs one word from him: crop the paper, or make the **text** mode the dark
full-bleed one.

STATUS: open, waiting on him

---

## الدفعة الثانية — 2026-09-10

Sent while testing v3.13.0 on his own phone, with ten screenshots. He asked for
these to be split and started immediately: «قسم دول وحده وحده وابدا فيهم حالا».

Ordered by how broken each one is, not by the order he wrote them. Each item is
marked **DONE (seen)** only after it has been run on a device and looked at
(§1.3).

---

## A1 · Recitation: playing needs a download first, and it should not

> «لو فتحت التطبيق ورحت على تشغيل التلاوة مش بيشغل أي حاجة ويقولي تعذّر تشغيل
> التلاوة … خليه يديني اختيار تحميل التلاوة عادي من الـ API لحد ما يخلص
> التطبيق تحميل التلاوة»

What he wants, in order, and where each part stands:

1. Press play → **it plays**, streamed, immediately. DONE — the cause was a
   truncated cached file that passed the old 2 KB floor and that `just_audio`
   then refused, failing the whole surah. The floor is measured now, and a
   third load attempt streams every verse.
2. The download runs in the background at the same time. DONE.
3. «تم تحميل التلاوة بصوت الشيخ كذا» when it finishes. DONE — only on a real,
   complete finish.
4. **List the downloaded reciters.** DONE — `downloadedRecitersProvider` counts
   from the files themselves, so a reciter who is 112 of 114 surahs in says so
   rather than looking finished.
5. **Choose per play: downloaded, or the API.** DONE — `PlaybackSource` with
   three settings (automatic / online / downloaded only), honoured in one
   place so the single-ayah path and the continuous queue cannot disagree.

STATUS: FIXED, tests pass — **not yet opened on a device**

## A2 · «تعذّر تنزيل التلاوة — تعذّر إكمال بعض الآيات»

**Measured against the live hosts, 2026-09-10.** Both are reachable and both
serve 16 simultaneous requests without a refusal — but both are
*intermittently* bad: a burst of fifteen HEADs to `cdn.islamic.network`
returned 502 to every one, one ranged GET returned 403, `everyayah.com` stalled
21.5 seconds on a single file, and a minute later everything answered 200/206.

A correction to my own first reading: I nearly concluded «the CDN rejects Range
requests», and re-testing with six different User-Agents showed 206 for all of
them. It is not Range and not the User-Agent — it is a host that fails under
bursts.

Against a host like that, `retries: 2` is what turns a blip into «تعذّر إكمال
بعض الآيات» permanently, because nothing ever comes back for that ayah. Now 4.

**The repair button.** It was not doing nothing, but it had two silent holes:

* it only ever repaired the **currently selected reciter**, so a surah left
  half-finished under a reciter he had switched away from was invisible to it;
* a download job whose tracking was lost (process killed, an update that never
  arrived) stays in the in-memory map for ever, `isDownloading` then reports
  true, and the loop skipped that surah **in silence**. A job that has heard
  nothing for three minutes is now treated as abandoned, because repair is an
  explicit request to start again.

STATUS: FIXED, tests pass — **not yet opened on a device**

## A3 · Downloads stall when several run at once

> «التنزيلات بتقف خالص لما أجي أنزل حاجات كتيرة … أنا عايزه حرفيًا لو بحمل كل
> اللي في التطبيق من تلاوات ومصاحف وكتب وكل حاجة في وقت واحد ميهنجش لحظة»

His shade shows four mushafs downloading at once (445/604, 375/604, …) plus a
recitation.

**They were not stopping — they were queued.** Every file the app fetches that
is not an ayah goes through one `MemoryTaskQueue`, and it was **two wide in
total**: mushaf pages, books, the hadith database and adhan clips all share it.
Four mushafs is 4 × 604 = 2,416 page tasks through two slots, so the third and
fourth genuinely do not move until the first two finish. From the outside that
is indistinguishable from stalled.

Now 8 wide with 4 per host (the per-host cap is what keeps it polite, and 16
simultaneous was measured as fine on both audio hosts). Recitations go 6 → 12,
still 6 per host.

STATUS: FIXED, tests pass — **not yet opened on a device**, and the honest test
is his own phone with four mushafs at once, not the emulator.

## A4 · Thematic search returns almost nothing

> «اتأكد إن البحث الموضوعي فعلاً بيبحث في المصحف كله — بحثت في الرحمة طلعلي ٣
> آيات بس وده مش ممكن طبعًا»

He is right that it is not possible. Measured over the real corpus with the
app's own normalisation:

    query        space-only   + proclitics   + article stripped
    الرحمة            6            6                72
    رحمة             34           72                72
    العلم            91           91               250

Two losses, both ordinary Arabic: a space-only word boundary cannot see
«وَرَحْمَةٌ» or «بِرَحْمَةٍ», and a query carrying «ال» only matched the article
form. Both fixed, plus the 50-result cap raised to 200 («العلم» has 250).

STATUS: FIXED, tests pass — **not yet opened on a device**

## A5 · Khatma

Four separate things, from his screenshots:

* **It cut the ayah off mid-word.** `maxLines: 2` + `TextOverflow.ellipsis`
  lets the text engine break wherever the line runs out, and the card's label
  says «من قوله تعالى» — an opening is right, a damaged one is not.
  `ayahOpening` cuts on a whole word and adds «…» only when something was
  actually left, and never rewrites the text it keeps (§1.2).
* **The two steps are one sheet now**, so «ختمة جديدة» is not a separate
  screen with a lone button at the bottom.
* **«من أي سورة» is in the same list** as «بداية المصحف» and the thirty juz —
  one dropdown, three kinds of choice, 145 entries.
* Changing the starting point now recomputes the daily amount, which it did
  not do before: the plan is derived from how much is left to read.

Found while doing it, and worth its own line: the generator wrote
`value: 'j\$j'` into the dropdown — **trap #23**, a backslash before `$` is an
escape, so all thirty juz would have carried the same value and the dropdown
would have thrown. `flutter analyze` said nothing, exactly as the trap says.
`no_escaped_dollar_test.dart` now fails the build on it anywhere in `lib/`.

STATUS: FIXED, tests pass — **not yet opened on a device**

## A6 · Search inside the Surahs and Juz sheets

The recitation downloads screen already has «ابحث عن سورة…». The reader's own
Surahs sheet (114 rows) and Juz sheet do not.

Both have one now. It matches the **normalised** name, because the stored
names are vocalised and «الفاتحة» typed plainly cannot reach «ٱلْفَاتِحَة» with a
`contains` (trap #2); it matches a fragment from the middle, because in a list
this short that is what someone expects from «قرة» → «البقرة»; and it matches
the number, so «36» finds Ya-Sin.

STATUS: FIXED, tests pass — **not yet opened on a device**

## A7 · The Encyclopaedia and the شروح, downloaded for him

> «حمّل الموسوعة الحديثية دي جوّه التطبيق أوتوماتيك بعد أول مرة تشغيل … وخلي
> كارت الحديث يعرض بس الأحاديث منها على أساس إنها مشروحة»

And: Shamela carries commentaries (شروح) on the hadith collections the library
already has; download the ones that match our books, and let the card work from
those too. Both should download automatically or ship with the app, **and**
appear as separate, explained choices in the downloads screen — because someone
short of storage should be able to decline and still get the card, without a
شرح.

Needs a real source check before anything is catalogued (§1.1): which شروح
exist on Shamela for our nine collections, and whether they are usable.

STATUS: open
