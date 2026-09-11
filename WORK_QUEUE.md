# Work queue — the owner's sixth batch, 2026-09-11 (night) → v3.17.1

Everything below was run on emulator-5554 with the signed release build.

## E1 · A running recitation must move fast

The surah being read is now loaded whole, so moving within it is a `seek`
(no playlist rebuilt, no host round trip); the surah/juz/page index moves a
running recitation with it.

STATUS: **DONE (seen)** — an-Nisa' picked from the index while 3:23 was
playing: `PLAYING` from 4:1 in 1.26 s (adb-polled, so an upper bound). Back
from 4:3 to 4:1 inside the surah: item id 2 → 0 with no new
`ExoPlayerImpl: Init` in the log, i.e. no reload.

## E2 · Choose the reciter from the small recitation bar

STATUS: **DONE (seen)** — the bar shows the reciter's name and a picker (fast
everyayah sources first, marked ⚡). Switching to Maher al-Muaiqly was
`PLAYING` again at the same ayah in 1.3 s.

## E3 · Image mushaf: recitation and highlight — or text only

> «لو فيه مشكلة … خلّي التلاوة التلقائية آية بآية محصورة بس في المصحف النصي»

There was a problem: the Tajweed printing's page 77 highlighted 4:3 about a
line low (from «ما طاب لكم» into the start of 4:4). The Madinah vector image
was right on the same verse. Continuous recitation is now text-only; from an
image page the button opens the same page as text and starts there, and a
recitation is stopped if the reader switches to an image page.

STATUS: **DONE (seen)** — pressed on image page 53: text page 53, reciting
3:23, verse tinted.

## E4 · «مشغّل تلاوة القرآن»

STATUS: **DONE (seen)** — the section's title on the device.

## E5 · A cover instead of the letter «أ»

The player's artwork is typeset from the surah name (Qur'an face), reciter and
recitation on a lattice whose ground is chosen from the reciter's name. The
list avatars — every one of which read «أ», because most names begin «أحمد» /
«محمد» — now show the family name's letter on the reciter's own ground.

STATUS: **DONE (seen)**. NOT fixed: the avatar letter sits a little below
centre (the AmiriQuran face's ascent).

## E6 · Downloads screen updates itself; notifications

The overview re-reads its totals while anything downloads (at most every 2 s)
and the downloaded-items list reloads on every download event. Recitations
storage no longer counts `library.json` (an empty library read «2 B»).

STATUS: code — the live refresh was not watched during a running download in
this round.

## E7 · The prayer card must come back when dismissed

Posted natively (`PrayerCard.kt`) with a delete intent that posts it again,
plus a native rollover alarm and a BOOT_COMPLETED / MY_PACKAGE_REPLACED
receiver.

STATUS: **DONE (seen)** — swiped away: event log `notification_canceled`
reason 2 at 14:28:37.698, `notification_enqueue` again at 14:28:37.744.
«Clear all» left it in place. NOT seen: rollover at the prayer's time, and
restore after a reboot.

## E8 · Repair must never hang

Each step has a 12 s deadline, and a whole-surah transfer that has reported
nothing for 2 minutes is cancelled and re-queued.

STATUS: returned in under a second with «لا توجد تحميلات غير مكتملة» — but
**a genuinely wedged download was not produced to press it on**.

## Also found and fixed

* Adhkar cards: the photo's `errorWidget` was a `Positioned.fill` inside the
  image widget and threw «ParentData is not a subtype of StackParentData» in
  the release log at every launch. Pre-existing. After the fix: 0 Flutter
  errors in the log across launch, Qur'an, player and downloads.

---

# Work queue — the owner's fifth batch, 2026-09-11 (night) → v3.17.0

One long message, then a second one mid-work: «الكوته ١٥ … عايز البلاير يبقى
روعة بصريًا واحترافي وفكّنا من تحميل تلاوات آية بآية على الجهاز».

## D1 · The running header named a surah that is not on the page

> «فيه سورة كاتب فيها في الهيدر سورة الرعد سورة يوسف وهي الرعد بس وكمان
> متكرر كلمة سورة الرعد ٣ مرات»

Two causes. The rule from v3.13 assumed a surah always ends on the page where
the next begins; measured against `quran_local.db` that holds at **58 of 113**
boundaries, and at the other 55 the header named the previous surah too
(Yusuf ends on 248, al-Ra'd opens 249). Now read from MIN and MAX page per
surah. And the text mode showed the name three times — corner badge, pinned
header, banner — so the corner badge is image-mode only and the pinned header
is blank on a page that opens with a banner.

STATUS: **DONE (seen)** — page 249 on emulator-5554: image mode names «سورة الرعد» alone, text mode shows it once (banner only).

## D2 · The Hadeeth Encyclopaedia, out of the box

> «نزّل الموسوعة الحديثية وادمجها مع التطبيق out of box. خلّي كارت الحديث
> بشروحه مرتبط بالموسوعة بس … ايه حزمة العربية دي»

All seven packs bundled (`assets/data/hadeethenc/`, 15.9 MB), each checked
byte-for-byte against the catalogue and row-for-row against its hadith count.
The pack for the app's language unpacks on first open. The download gate,
the auto-fetch and the «العربية» row under «العناصر المنزَّلة» are gone (the
registry entry is dropped without deleting the database). The Home card draws
only from the encyclopaedia. Source: HadeethEnc.com — read off its own page.

STATUS: **DONE (seen)** — the Home card showed a Muslim hadith with «الشرح» under it on first launch; «الحديث» in «التنزيلات» no longer lists «العربية».

## D3 · The Tajweed notification stuck for ever; repair said «لا يوجد»; the tiles did not move

* The mushaf download posted an `ongoing` flutter_local_notifications progress
  notification. When Android killed the process it stayed, unswipeable.
  Progress now lives in the foreground service's own notification, which dies
  with the service; leftovers are cancelled at launch.
* Repair looked only at the page cache: an edition with 0 pages was "not
  started", a paused or stuck loop was "running". Downloads asked for are now
  remembered (`mushaf.wanted_downloads_v1`), resumed at launch, and repair
  resumes paused ones and restarts one with no page for 90 s. Each loop owns a
  generation number, so a restart cannot run beside the loop it replaced.
* `MushafDownloadTile` only listened to a download it had started itself. It
  now always listens.

STATUS: **DONE (seen)** — Qatar download started, `am force-stop`: 0 notifications left from the package; relaunched: 30 s later the download had resumed by itself and the service notification read «مصحف قطر 30 / 604». NOT seen: the repair button pressed on a stuck download, and the tile re-attaching after a relaunch.

## D4 · Per-ayah recitation downloads removed — the reader streams

> «شيل خيار تحميل التلاوات على الجهاز ده خالص وخليه دايما من الـ API آية
> بآية … واحذف خيار تلقائي ومحمّل ومن النت»

The Recitations tab of «التنزيلات», the playback-source setting, the
onboarding recitation download and all of `AyahAudioService`'s download code
are gone. A recitation that fails to load retries on a new player, then on the
reciter's other host. Files earlier builds downloaded under
`documents/recitations/` and their platform tasks are purged once at launch.

STATUS: **DONE (seen)** — single ayah and continuous recitation both reached `PLAYING` with `error=null` from the network; the recitations bucket fell from 280.2 MB to 628.5 KB after launch.

## D5 · «تحميل تلاوات القرآن» — a new section in المزيد

mp3quran.net API v3 (measured: 241 reciters, 287 recitations, unique ids,
all https, surah lists consistent, files `206 audio/mpeg`). Whole-surah
downloads on their own platform queue (3 at a time, 2 per host). The library
is folders: reciter → recitation → surahs, indexed in
`quran_audio/library.json` and re-read from disk. Device audio files can be
added and played. The player: seek with elapsed/remaining, ±10 s, previous /
next, shuffle, repeat list / one surah, speed 0.5–2×, sleep timer (minutes or
end of surah), queue, mini player, lock-screen controls.

STATUS: **DONE (seen)** — reciter list loaded, al-Fatiha (al-Hudhaifi) downloaded with live progress to «منزّلة على الجهاز», played from disk, mini player and full player drawn, next track streamed. NOT seen: a whole-recitation download to the end, pause/resume, sleep timer firing, device-file import.

## D6 · His questions

* **Do competing apps offer recitation downloads?** Answered in the reply,
  with the recommendation he then chose himself.
* **«وضع المصحف مش بيشغّل أول مصحف مصوّر»** — NOT reproduced: picking مصحف التجويد الملوّن on emulator-5554 opened page 249 as an image. Asked him for a screenshot.
* **What is «حزمة العربية»?** The encyclopaedia's Arabic language pack, which
  was downloaded separately. It is inside the app now (D2).

---

# Work queue — the owner's fourth batch, 2026-09-11 (late)

Five decisions in one message, after reading the third batch's answers.

## C1 · Any imaged mushaf without ayah coordinates leaves the app

> «حل جذري لتظليل المصاحف … اي مصحف مصورة مش محدد اجزاء الايات عشان التظليل
> شيله من التطبيق كله وريح نفسك وريحني»

Removed: **shamarly** (521 pages), **indopak_tajweed** (564),
**madinah_nastaleeq** (611). Nine editions → six, and the test asserting a
good layer is now an invariant over the whole catalogue instead of a
hand-kept list of ids.

The consequence that would have bitten silently: `storageSummaryProvider`
walks the catalogue, so those printings' downloaded pages would have sat on
the device for ever with no button left that could free them.
`purgeUnknownEditions` deletes a page directory whose edition is gone, and can
only ever do that for an id the live catalogue does not contain.

STATUS: **DONE (seen)** — the mushaf list on emulator-5554 now shows six,
with الشمرلي and the Indo-Pak one gone.

## C2 · The recitation stalls while other downloads run

> «بس حل موضوع التلاوة بتقف تنزيل لما بحمل حاجات كتير في نفس الوقت»

**NOT FIXED. A hypothesis was tested on the device and rejected, and the
change that went with it was reverted rather than shipped with a story
attached to it.**

The hypothesis, and why it looked right: `background_downloader` runs every
transfer as a WorkManager Worker, and WorkManager's default executor — read
out of `work-runtime-2.11.0.aar`, `ConfigurationKt.createDefaultExecutor` —
compiles to

```
Executors.newFixedThreadPool(max(2, min(availableProcessors - 1, 4)))
```

**four threads at most on any device**, against `DownloadEngine`'s 20 tasks in
flight. That reads exactly like sixteen tasks waiting for a thread.

The measurement that killed it, on emulator-5554 — two mushafs and
al-Baqarah's 286 ayahs downloading together, counting established TCP
connections out of `/proc/net/tcp`:

| WorkManager pool | connections | al-Baqarah |
|---|---|---|
| 20 threads | 11 | 10 / 286, climbing |
| **2 threads** | 10 | 53 / 286, climbing |

No difference at all. The reason is in the plugin's own source: `TaskWorker`
is a **`CoroutineWorker`**, so `doWork` runs on the coroutine context and the
transfer sits inside `withContext(Dispatchers.IO)` — it never occupies a
WorkManager executor thread in the first place.

**What is now known:**

* Two mushafs + a full surah download together on this emulator, at ~10
  simultaneous connections, and every one of them keeps advancing. **The stall
  did not reproduce here.**
* The two queues are separate objects with separate per-host counters, so a
  mushaf download cannot consume a recitation slot.
* The mushaf pages come from R2 and the ayahs from the audio CDNs, so the
  per-host caps cannot collide either.

**What would identify it — needs him:** when the recitation stopped, what else
was downloading at that moment, did it start again on its own after the others
finished, and did «إصلاح التحميلات» bring it back? Those three answers
separate a queue problem from a host refusing a burst (already measured as
intermittent, see the second batch's A2) from a task the app lost track of.

STATUS: **FIXED in v3.16.0** — see the entry below; the cause turned out to
be a leaked queue slot, not the thread pool. The hypothesis and its rejection
are kept here because the rejection is the useful part.

## C2b · The jam, found

`MemoryTaskQueue.advanceQueue` counts a task active the moment it hands it
to the platform, and on a refused enqueue it logs and **never removes it or
decrements the counters** — only `taskFinished` does, and a task that never
started never produces the update that would call it. Every refusal burns a
slot for the life of the process: **eight kill the file queue, twelve kill the
recitation queue** («بتهنج تماما»), and repair adds to that dead queue
(«ولا بيعمل اي حاجة نهائي»).

Fixed on both sides: the plugin publishes `enqueueErrors` and nobody was
listening — the slot is returned and the task retried up to three times with a
growing delay; and repair calls `unjamQueues` first, freeing every slot held
by a task the platform has never heard of, while a live task keeps its slot.

STATUS: **FIXED, 5 tests against the real `MemoryTaskQueue`** — the repair
button was seen reporting «تم استئناف 2 تحميل غير مكتمل» on emulator-5554,
but **the jammed state itself was never reproduced on a device.**

## C3 · A third text layout, exactly like the one he reads in

> «انت تضيف وضع نصي زي بتاع ختمة بالظبط يبقى المجموع نصي ٣»

`QuranTextLayout.reading` — the page layout with the ornament taken out:

| | page | reading |
|---|---|---|
| surah banner | illuminated frame | plain centred name |
| ayah marker | open rosette, gold number | filled disc, number in paper colour |
| leading | 2.1 | 1.85 |
| side margins | 18 | 8 |

The toolbar control cycles instead of flipping, and is labelled with the
layout it will give you.

STATUS: **DONE (seen)** — cycled to it on the device: tighter lines, filled
gold discs, edge to edge, and more of the surah on one screen. The number
inside the disc measures **6.7 : 1** against the gold.

## C4 · The reciting ayah must be fully visible

> «لما تيجي الاية عليه وفيه جزء منها مش باين في الصفحة خليها تقزح لفوق عشان
> تبان كلها»

Centring a card is right only while the card fits. Al-Baqarah 282 is a card
several screens tall, so centring it lost its beginning AND its end. A card
taller than the viewport is now shown from the top. The flowing layouts put
the verse's start a third of the way down rather than centred — they know
where a verse begins but not how tall it is, so leaving twice as much room
below it is the best available guess.

STATUS: FIXED — **not yet opened on a device.** The card case needs a verse
taller than the screen (al-Baqarah 282) with the recitation running, and that
was not reached.

## C5 · Rotation belongs to the text mode, and opens the page

> «خلي الاورينتيشن بس على النص لو ده افضل واول ماعمل اورينتيشن الصفحة تكبر
> بملئ الشاشة اوتوماتيك زي ختمة»

The image mode is locked to portrait; the text mode rotates. The lock is
released when the screen goes away, so nothing else in the app inherits it.

Turning sideways enables full-screen by itself and restores what he had when
he turns back. Deliberately **not persisted** — it is how the phone is being
held, not a preference, and persisting it would leave a reader who rotated
once permanently immersed in portrait.

STATUS: **DONE (seen)** — rotated on emulator-5554: the text mode went to
full screen by itself and came back to exactly the toolbar it had; the image
mode refused to rotate at all.

---

## الدفعة الثالثة — 2026-09-11

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

He picked the second reading: the **text** mode should be the black full-bleed
one. Measured on emulator-5554 before changing anything:

| | ختمة | رفيق الدرب (قبل) |
|---|---|---|
| الطول اللي بياخده النص | ~80% | **51%** |
| نفس الشيء في «ملء الشاشة» | — | **82%** |
| تباين علامة الآية على الأسود | — | **8.0 : 1** |

So the layout he asked for already existed, at 82%, and is remembered between
runs — it survived a full reinstall during this session. Two things hid it:

* **«ملء الشاشة» is one of twelve actions in a three-row toolbar**, and those
  three rows are the whole 51% → 82% difference.
* **The black paper lived in Settings**, in another tab, five themes down. Its
  marker measures 8.0:1 on the charcoal ground, so this was never legibility —
  it was that he could not find it. That is why the app looked to him like it
  had no black page while shipping five.

Changed, and **seen on emulator-5554**:

1. **ثيمات المصحف النصي is an action on the Quran toolbar** — one tap from the
   page whose colour it changes, the way the reference app puts it behind a
   gear on the reading screen.
2. **The toolbar hides itself while you read forward and comes back when you
   pull up.** Nothing moved behind a preference; the default reading state is
   now the full-bleed one.

STATUS: **DONE (seen)** — toolbar hidden on a forward drag and restored on the
pull back, theme picker opened from the toolbar with فحمي selected, and the
full-screen page came back black after a reinstall.
