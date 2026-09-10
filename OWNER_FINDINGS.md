# Owner's findings — 2026-09-10, from real use on his own phone

Reported with screenshots after installing v3.12.0. This file is the working
list; each item is struck through only when it has been fixed **and seen
working on a device** (§1.3), not when the code compiles.

Ordered by severity, not by the order he wrote them.

## A. Broken, and content-integrity issues

1. **The adhan audio is not the muezzin the entry names.** His words: «كل
   الأذانات ماعدا الأول والتاني والتالت أسماء بس، لكن الأذان الفعلي مش بتاعهم
   وهما أصوات تانية خالص غير أصواتـ أسماءها الفعليين». This is §1.1 and §1.2:
   an attribution nobody verified. Trap #36 is the same mistake in the video
   catalogue. Either every clip's attribution is verified against a named
   source, or the name comes off the entry.
   STATUS: open

2. **The default adhan is stuck on al-Banna and cannot be changed**, and
   **selecting an adhan does not register** — «ظاهرته مش بتنوّر إنه تم
   اختياره».
   STATUS: FIXED (the picker was a stale pushed route) — not yet re-seen on a device

3. **The adhan preview button does not play; it opens Settings.**
   STATUS: open

4. **The before/after prayer reminders do not fire** on his phone. They were
   verified on the emulator by `dumpsys alarm`, so the gap is between "the
   alarm is armed" and "the notification appears on a real phone" — most
   likely OEM battery management. Needs measuring on the real device, not the
   emulator.
   STATUS: open

5. **Raw translation keys ship in a notification.** Not reported by him — read
   off two of his screenshots: the download notification shows
   `notif.dl_recit_running_title` / `notif.dl_recit_running_body` literally.
   Trap #8.
   STATUS: FIXED

6. **Landscape breaks the text mushaf** — «في الأورينتيشن المصاحف النصية مش
   بتشتغل»; the image mushafs need checking too. His landscape screenshot shows
   the toolbar over an empty page.
   STATUS: FIXED, seen on emulator-5554: the Qur'an text renders in landscape now

7. **A quote notification does not open the quote.** Tapping it cold-starts the
   app instead. He wants the tap to open the quote screen directly, skipping
   the splash, even when the app was closed.
   STATUS: FIXED — not yet re-seen on a device

8. **The calculation method is labelled «دبي».** The real name is «وزارة
   الأوقاف والشؤون الإسلامية بالإمارات».
   STATUS: FIXED

9. **Islamic channels / sites are duplicated** between the Library tab and
   More.
   STATUS: FIXED

10. **A hadith book screen came up blank** (سنن النسائي, portrait, only a
    spinner). Possibly the same root cause as (6), possibly its own. Reproduce
    before assuming.
    STATUS: open

## B. Missing, asked for

11. **Swipe navigation on the hadith card** — both the card on Home and the
    one on its own screen. «خليه فيه إمكانية تنقل».
12. **A hadith explanation (شرح)** if a real source can be found. HadeethEnc
    carries explanations; it is already in the app, so this may be free.
13. **Ruqyah has no media player** — no icons, no control. «مافيش ميديا بلاير
    بأيقونات يخليني أتحكم فيها».
14. **Some adhkar screens have no background** (e.g. أذكار السفر). He wants
    backgrounds **drawn in code, not downloaded** — «اعملها برمجيًا زي آخر
    خلفية في آخر صورة بعتهالك» (the أذكار الاستيقاظ من النوم screen).
15. **The mushaf toolbar at the top of the text reader** should be animated and
    better looking, with nicer icons.


---

## Added 2026-09-10, after he sent more screenshots

16. **The running header named the wrong surah.** «الصورة بتاعة سورة
    يوسف مطلعه سورة هود وفوق على اليمين كاتب سورة يوسف». Page 235 holds the end
    of Hud and the start of Yusuf; the header named only Yusuf. FIXED —
    `page_surahs.dart`, six tests. **Not yet seen on a device.**

17. **Picking a surah could land on a different one.** Three of the nine
    printings paginate their own way (Shamarly 521, Indo-Pak 564, Nastaliq
    611) while the surah→page table is the Madinah 604. FIXED by withholding
    the surah and juz indexes on those three, matching how the running header
    was already handled. **Not yet seen on a device.**

## Still open

* 1 · the adhan attribution, and the 16 kb/s encodings
* 3 · the adhan test button opening Settings
* 4 · before/after prayer reminders not firing on HIS phone
* 10 · the blank سنن النسائي screen
* 11 · swiping the hadith card BACK
* 12 · a hadith explanation
* 15 · the toolbar's looks (its landscape shape is done; the styling is not)
