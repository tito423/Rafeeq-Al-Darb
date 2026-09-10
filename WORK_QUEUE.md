# Work queue — the owner's second batch, 2026-09-10 (evening)

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

What he wants, in order:

1. Press play → **it plays**, streamed from the API, immediately.
2. The download runs in the background at the same time.
3. When it finishes: «تم تحميل التلاوة بصوت الشيخ كذا».
4. If more than one reciter is downloaded, list them and let him pick.
5. He chooses per-play: from the downloaded copy, or from the API.

STATUS: open

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
