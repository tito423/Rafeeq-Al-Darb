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

Screenshot of the shade shows that notification. Find the actual failure — a
surah is 286 separate ayah files and something is dropping some of them.

And: **«زر إصلاح التحميل ده حرفيًا مالوش لازمة خليه فعلاً فعّال»** — the "repair
downloads" button does nothing useful. Either it repairs (re-fetches exactly
the missing ayahs and reports what it did) or it comes off the screen.

STATUS: open

## A3 · Downloads stall when several run at once

> «التنزيلات بتقف خالص لما أجي أنزل حاجات كتيرة … أنا عايزه حرفيًا لو بحمل كل
> اللي في التطبيق من تلاوات ومصاحف وكتب وكل حاجة في وقت واحد ميهنجش لحظة»

His shade shows four mushafs downloading at once (445/604, 375/604, …) plus a
recitation. The requirement is not "faster", it is **never blocks the UI and
never stops**.

STATUS: open

## A4 · Thematic search returns almost nothing

> «اتأكد إن البحث الموضوعي فعلاً بيبحث في المصحف كله — بحثت في الرحمة طلعلي ٣
> آيات بس وده مش ممكن طبعًا»

He is right that it is not possible: «رحمة» and its forms occur far more often
than three times. Measure the real count against the corpus first, then find
where the rest are being lost.

STATUS: open

## A5 · Khatma

Four separate things, from his screenshots:

* **It cuts the ayah off mid-word** when it displays the day's portion.
* **«ختمة جديدة» sits at the bottom** of an otherwise empty screen — merge it
  with the "start from" sheet instead of being a separate step.
* **Add «من أي سورة»** alongside «بداية المصحف» and «من أي جزء».
* **Put the options in the middle of the screen**, not pinned low.

STATUS: open

## A6 · Search inside the Surahs and Juz sheets

The recitation downloads screen already has «ابحث عن سورة…». The reader's own
Surahs sheet (114 rows) and Juz sheet do not. Add the same box to both.

STATUS: open

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
