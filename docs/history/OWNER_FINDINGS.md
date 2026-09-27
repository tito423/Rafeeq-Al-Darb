# Owner's findings — 2026-09-10

Reported with screenshots after installing v3.12.0, from real use on his own
phone. Nothing here is marked done on the strength of a clean analyze:
**seen** means opened on `emulator-5554` and looked at (§1.3).

---

## Verified on the device this session

| # | What he reported | Evidence |
|---|---|---|
| 16 | The header named the wrong surah — «الصورة بتاعة سورة يوسف مطلعه سورة هود وفوق على اليمين كاتب سورة يوسف» | Went to Surah Yusuf (page 235, from the app's own index). The header reads **«سُورَةُ هُودٍ · سُورَةُ يُوسُفَ»** — both surahs that are actually on the page. |
| 17 | Picking a surah could land on a different one | On the Shamarly printing (521 pages) the toolbar now offers **no «Surahs» and no «Juz»** — only Full screen, Thematic Search, Jump to, Mushafs, Text mode. |
| 2 | «الأذان الافتراضي ثابت على البنا» / «ظاهرته مش بتنوّر إنه تم اختياره» | Tapped عبد الباسط عبد الصمد: the tick **moved to it immediately**, the row went gold, the preview played. Left the screen and came back — still selected. |
| 6 | Landscape broke the text mushaf | The Qur'an text renders in landscape. It did not before. |
| 13 | Ruqyah had no player | The transport plays and seeks, and read **00:03 / 25:11** with ±10 s and stop. |
| 14 | Adhkar lists had no background | The drawn ground (category colour + geometric tile) is on screen. |
| 11 | Swipe / navigate the hadith card | Next loads a new hadith and enables ‹; ‹ returns to the previous one and greys out again at the start of the history. |
| 3 | «الأذان فعليا مش شغال في زر التجربة» | **Could not reproduce.** Preview Adhan opens the real player with the synced «الله أكبر». The per-prayer **Test** fired the real alarm ~8 s later → `AdhanActivity` plus a heads-up with Stop/Mute. See "still open" below. |
| 5 | (not reported — read off his screenshots) raw keys `notif.dl_recit_running_title` in the shade | Resolved off the translation asset now; a test fails the build if it goes back to `.tr()`. |

## Fixed, analyze- and test-clean, **not yet opened on a device**

* **7** — a quote notification tapped with the app closed skips the splash and
  opens the quote. Needs a real notification to exercise; not done here.
* **8** — «دبي» is now «الهيئة العامة للشئون الإسلامية والأوقاف — الإمارات».
* **9** — the duplicate Islamic-channels entry point is gone from More.
* **10** — a failed query no longer renders as an endless spinner («سنن النسائي
  بتحمل على الفاضي»). The `FutureView` path is in, but the failure that
  triggered it was never reproduced — see below.
* **12** — the hadith detail screen offers to find its explanation in the
  Hadeeth Encyclopaedia, as candidates the reader judges rather than a match
  the app asserts.
* **15** — the Qur'an toolbar's icons are rounded and non-directional, and the
  bar fades in.
* **1** — five adhans replaced with much better takes of the same muezzin
  (16 → 128/192 kb/s) and all fourteen levelled to one loudness target.

## Still open, and honest about why

1. **Who the muezzins are.** The files are byte-identical to their archive.org
   sources, so the app is not mis-mapping them — but the *names* rest on the
   source's filenames and nothing else, and he says his ear disagrees. His ear
   is better evidence than a filename. **Listen to the five new takes**; if they
   still sound wrong, the names come off the entries (§1.1, §1.2).

2. **The ANR.** Twice on a debug build: `Waited 5007ms for MotionEvent`, the app
   frozen on Home. **Not reproduced on the profile build** — this session's
   whole verification pass ran ANR-free. Two measured rebuild loops on Home were
   removed (a one-second whole-tree `setState`, and a clock rebuilding ~25×/s to
   show whole seconds), which is real waste but is **not claimed as the cause**.
   Next session: `flutter run --profile` and read the DevTools timeline for the
   first ten seconds.

3. **Before/after prayer reminders on HIS phone.** Verified armed on the
   emulator by `dumpsys alarm`; the gap is between "armed" and "shown on a real
   phone", almost certainly the manufacturer's battery management. Needs
   measuring on his device, not this one.

4. **The Test button opening Settings.** Not reproducible here. The likely cause
   is a missing permission on his phone: the adhan settings screen shows a card
   for the exact-alarm grant and another for the full-screen-intent grant, and
   those cards' buttons *do* open Settings. **He should check that both cards
   are absent from that screen on his phone**, and take the battery-optimisation
   exemption the same screen offers.

5. **The blank سنن النسائي screen.** The endless-spinner path is fixed, but the
   underlying failure was never seen: the bundled DB has 52 chapters and 5,768
   hadiths for that collection, the on-device copy is the same size to the byte,
   and the app opens it fine. If it recurs it will now show a message and a
   retry instead of spinning — the message is the next clue.
