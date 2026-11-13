# TASK_FOLLOWUP — the live step log (read right after CLAUDE.md)

Keep this file SHORT (under 60 lines): every session loads it whole. Newest
log line on top; past ~10 lines move the oldest to
`docs/history/TASK_FOLLOWUP_archive_2026-10-13_to_2026-11-12.md`. Times Dubai.

## Current task — no repeats: Home / Quran page / Prayer page (unreleased)

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
LEFT: the tour PHOTOS (assets/tour/<lang>/*.webp) still show the old Home
and Prayer page -> retake with scripts/capture_tour.py (release capture
build, kills a running emulator: trap 24).

## Windows GPU (windows-gpu session)

 load: mostly done (commit 4 in Windows app)

`Rafiq-Al-Darb-Windows/app` (windows-desktop), measured 2026-11-12/13,
Get-Counter 3D mean: hidden 91.1% -> 2.7-5.5%; visible 94.7% -> ~45%
(frames 52/s -> ~19/s). Fixes: TickerMode on hidden window + hidden
IndexedStack tabs, RGB backdrop timer 5/s, clock timer, focus-ring ticker.
Remaining visible load = PrayerCountdown seconds roll (owner-designed) at
~20 ms raster per full-window frame.

## Next step (exact)

Retake the tour photos: build the capture APK (capture_tour.py header),
sign, boot Rafeeq_Audit_API24, install, start the quick tour, run the
script; check continue_reading/khatma/sunan_card/adhan_settings/
prayer_adjustments pictures in ar+en; analyze/test; checkpoint. No release
without the owner's word.

## Standing owner orders (still open)

- NO release without the owner's word. Last published: v4.7.0
  (2026-11-14, versionCode 126).
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
