# TASK_FOLLOWUP — the live step log (read right after CLAUDE.md)

Keep this file SHORT (under 60 lines): every session loads it whole. Newest
log line on top; past ~10 lines move the oldest to
`docs/history/TASK_FOLLOWUP_archive_2026-10-13_to_2026-11-12.md`. Times Dubai.

## Current task — no repeats: Home / Quran page / Prayer page (RELEASED v4.8.0)

Owner 2026-11-14 ~03:00: «ختمة متكررة … مواقيت الصلاة وكمان موقع الصلاة
متكرر … الرئيسية يبقى فيها مقولة اليوم وحديث اليوم والوصول السريع وكارت
الصلوات والترحيب … وكمّل اللي ناقص وانتبه للتدوير والأورينتيشن».
Done + seen API 24 portrait/landscape: Home = greeting, prayer card, quick
access, quote, hadith (continue reading, khatma, sunan, selected surahs
moved off — they are on the Quran page). Quran page: the second «ختمة»
action card removed (KhatmaCard stays), sciences pack joined
«الاستماع والتعلّم». Prayer page: today's times card (Home has it), the
location card (first row of «ضبط المواقيت»; hint now says so, 7 langs) and
the adhan-pictures card (inside adhan settings) removed. Tour: the three
moved stops now on AppTab.quran; `tutorialAnchorProvider` makes QuranTab
show its page for them (seen: stop 8 frames the khatma card there). Also
fixed: tour started from «المزيد ← الأدوات» ran hidden behind that page.
Unused keys prayer_hub.*, quran_hub.section_read/khatma_sub dropped.
Tour PHOTOS retaken 2026-11-14 ~04:50 (capture_tour.py --fresh, 7 langs x
42 = 294). The first run skipped sunan_card: the Quran page was a lazy
ListView, the last card unbuilt below the fold, so the tour (users too)
skipped that stop -> page is now SingleChildScrollView+Column; retaken.

## Windows GPU (windows-gpu session)

 load: mostly done (commit 4 in Windows app)

`Rafiq-Al-Darb-Windows/app` (windows-desktop), measured 2026-11-12/13,
Get-Counter 3D mean: hidden 91.1% -> 2.7-5.5%; visible 94.7% -> ~45%
(frames 52/s -> ~19/s). Fixes: TickerMode on hidden window + hidden
IndexedStack tabs, RGB backdrop timer 5/s, clock timer, focus-ring ticker.
Remaining visible load = PrayerCountdown seconds roll (owner-designed) at
~20 ms raster per full-window frame.

## Next step (exact)

Nothing pending. v4.8.0 published 2026-11-14 (tag 9aebff14). Wait for the
owner's next order.

## Standing owner orders (still open)

- NO release without the owner's word. Last published: v4.8.0
  (2026-11-14, versionCode 127).
- `scripts/own_irab/SPECIALIST_SAMPLE.csv`: 300 words for a human grammarian;
  the app may not call the i'rab «معتمد» before that result.
- Hourly autorun `own-irab-autorun` stays DISABLED.

## Half-done / unverified

- v4.3.0 on a real phone: Android 10+ «السماح طوال الوقت» screen, the card
  following a real trip, the city name from the phone's Geocoder (emulator
  gave none).
- Khatma (d5ef5d8a): rub' tap on the PRINTED page, share with
  translation/tafsir, non-Arabic UI, landscape, reminder firing unseen.
- Rafeeq voice assistant background fix; Google book voice (v3.99.0): not on
  a device.
- Adhan retry fix: API 36 only. Per-ABI APKs: ARM phone pending.
- «إشعار منبثق فقط» heads-up not seen on Android 8+.
- Emulator Rafeeq_Audit_API24 left in ARABIC UI, LIGHT theme («نهاري»), portrait, card mode «elapsed».

## Log (newest first)

- 2026-11-14 ~06:50 owner asked for a better tasmee model: Abdou/quran-asr-small (MIT, int8 36 MB, sherpa zipformer-CTC) measured vs current NVIDIA FastConformer on 4 reciters held out of its training: 99.4% vs 94.7-95.1% words, phone band 99.4 vs 94.9; scripts/asr_quran_small_2026-11-14.txt. Not switched yet (needs owner's go).
- 2026-11-14 ~06:10 RELEASED v4.8.0 (tag 9aebff14, versionCode 127) on the owner's «طلع اصدار»; v4.7.0 release+tag deleted; release APK seen on API 24 (4.8.0, Quran page, «ادعم التطبيق»); asset 318,236,555 B, range request 206.
- 2026-11-14 ~04:55 tour photos retaken in 7 langs (294 pictures); Quran page built whole so the tour no longer skips the sunan card; looked at continue_reading/khatma/sunan_card/adhan_settings/prayer_adjustments ar+en; analyze clean, 1476 tests; NOT released.
- 2026-11-14 ~03:40 repeats removed (Home/Quran/Prayer pages), tour stops moved + hidden-tour fix; seen API 24 portrait/landscape; analyze clean, 1476 tests; tour photos pending; NOT released.
- 2026-11-14 ~01:20 tested dark theme + quick tour on API 24, then RELEASED v4.7.0 (tag 28bbb8aa) on the owner's «جرب وبعدين ابني. انشر».
- 2026-11-14 ~00:50 Quran hub + Prayer page on mosque backdrops, bars-restore fix for API 24; seen API 24 (ar/en, portrait/landscape, all jumps); 1476 tests; not released.
- 2026-11-14 ~00:20 v4.6.0 misses fixed: plate auto again, cards plate (tap + auto; painter clamp crash); seen API 24 all layouts; not released. Next: Quran + Prayer hubs.
- 2026-11-13 ~23:35 RELEASED v4.6.0 (tag 05f58765) on the owner's «طلع اصدار».
- 2026-11-13 ~23:00 medallion heart filled with paper; reading-layout ayah separators = scalloped ring, number centred; line-start medallion fixed; seen API 24; 1476 tests; not released.
- 2026-11-13 ~22:50 11-item batch done: tasbeeh reset, adhkar row scrolls, library strips collapse on phones, sideways prayer card hugs content, sunan names, More groups as pages, inline medallion per text layout + plate on tap; seen API 24; 1476 tests; not released.
- 2026-11-13 ~21:50 owner sent 11-item UI batch (shots in docs/owner_shots/2026-11-13_batch); recorded; handed to a fresh session (context 180k).
- 2026-11-13 ~20:50 reading-layout juz/page badges fade while text scrolls (`scroll_quiet_overlay.dart`); seen API 24 portrait+landscape; analyze clean, 1474 tests; NOT released.
- 2026-11-13 ~17:30 RELEASED v4.5.2 (tag 58c7f888): the owner's medallions on the text mushaf.
