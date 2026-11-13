# TASK_FOLLOWUP — the live step log (read right after CLAUDE.md)

Keep this file SHORT (under 60 lines): every session loads it whole. Newest
log line on top; past ~10 lines move the oldest to
`docs/history/TASK_FOLLOWUP_archive_2026-10-13_to_2026-11-12.md`. Times Dubai.

## Current task — Quran hub + Prayer hub pages: DONE, RELEASED v4.7.0

Owner: «عايزك تعمل صفحة جديدة للقرآن يكون فيها كل حاجة تخصه أقدر أروح منها
للختمة وأي حاجة تخصه بشكل جميل وروعة بصفتك خبير، وكمان عايزك تحطلي للصفحة
دي خلفية مسجد إسلامي هادية جميلة، وكذلك قسم الصلاة».
Plan (decided): the Quran tab opens a HUB (calm mosque photo backdrop, like
`core/widgets/mosque_backdrop.dart`): a big «متابعة القراءة / افتح المصحف»
card on top, then grouped cards for everything Quran: khatma, bookmarks,
topic search, recitation player (quran_audio), continuous recitation,
tajweed, hifz, selected surahs, sunan of the surahs, translations/tafsir,
mushaf editions/display. Jumps from elsewhere (`quranJumpProvider`,
tab requests) must still land IN the mushaf. Same for the Prayer tab: a hub
on a mosque backdrop (times card, adhan settings, timings adjust, qibla,
fasting, tasbih reminder...). 7 languages for every new string; check
portrait + landscape + tour anchors (TourAnchor) still resolve.
First fixed (unreleased): the medallion misses - see HANDOVER top row.

## Windows GPU (windows-gpu session)

 load: mostly done (commit 4 in Windows app)

`Rafiq-Al-Darb-Windows/app` (windows-desktop), measured 2026-11-12/13,
Get-Counter 3D mean: hidden 91.1% -> 2.7-5.5%; visible 94.7% -> ~45%
(frames 52/s -> ~19/s). Fixes: TickerMode on hidden window + hidden
IndexedStack tabs, RGB backdrop timer 5/s, clock timer, focus-ring ticker.
Remaining visible load = PrayerCountdown seconds roll (owner-designed) at
~20 ms raster per full-window frame.

## Next step (exact)

No open owner request. v4.7.0 out (HANDOVER top row). Waiting for the
owner's look on his phone. Unseen: real phone, the detailed tour walked
through. Emulator left Arabic, light, portrait, layout «reading».

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

- 2026-11-14 ~01:20 tested dark theme + quick tour on API 24, then RELEASED v4.7.0 (tag 28bbb8aa) on the owner's «جرب وبعدين ابني. انشر».
- 2026-11-14 ~00:50 Quran hub + Prayer page on mosque backdrops, bars-restore fix for API 24; seen API 24 (ar/en, portrait/landscape, all jumps); 1476 tests; not released.
- 2026-11-14 ~00:20 v4.6.0 misses fixed: plate auto again, cards plate (tap + auto; painter clamp crash); seen API 24 all layouts; not released. Next: Quran + Prayer hubs.
- 2026-11-13 ~23:35 RELEASED v4.6.0 (tag 05f58765) on the owner's «طلع اصدار».
- 2026-11-13 ~23:00 medallion heart filled with paper; reading-layout ayah separators = scalloped ring, number centred; line-start medallion fixed; seen API 24; 1476 tests; not released.
- 2026-11-13 ~22:50 11-item batch done: tasbeeh reset, adhkar row scrolls, library strips collapse on phones, sideways prayer card hugs content, sunan names, More groups as pages, inline medallion per text layout + plate on tap; seen API 24; 1476 tests; not released.
- 2026-11-13 ~21:50 owner sent 11-item UI batch (shots in docs/owner_shots/2026-11-13_batch); recorded; handed to a fresh session (context 180k).
- 2026-11-13 ~20:50 reading-layout juz/page badges fade while text scrolls (`scroll_quiet_overlay.dart`); seen API 24 portrait+landscape; analyze clean, 1474 tests; NOT released.
- 2026-11-13 ~17:30 RELEASED v4.5.2 (tag 58c7f888): the owner's medallions on the text mushaf.
- 2026-11-13 ~17:00 owner's medallions on the text mushaf: cut (Python), wired, seen on API 24; not released.
- 2026-11-13 ~15:55 checked printed mushaf landscape + fr/es/pt/ru/ur (plate, Display row) on API 24: all right; fixed + seen landscape home labels (sunrise cut, quick-access mid-word split); RELEASED v4.5.1 (tag 1e754c59).
- 2026-11-13 ~14:50 checked v4.5.0 myself on API 24: plate in English+dark (½ Hizb 12, illuminated, slides, leaves), landscape text mode fine; FIXED landscape full-screen mushaf: bottom tab bar floated over the page with the chrome (5 of 15 lines left) - now hidden when wide (`app_shell.dart`), seen. Unreleased. Still unseen: printed mode landscape, fr/es/pt/ru/ur, real phone. Emulator rotate: `adb emu rotate` (settings user_rotation did nothing on API 24).
- 2026-11-13 ~12:00 rub' strip removed; printed-style plate centred over the page 3 s when the page is on screen (printed + text, seen API 24); analyze/test clean; NOT released (owner's word needed).
- 2026-11-13 ~01:45 v4.4.0 released: printed rub' strip moved into the left margin; English tasbeeh/adhkar seen; emulator back to Arabic + light theme.
- 2026-11-13 ~00:45 six-item Android batch done + seen (see Current task); analyze clean; commit pending release word.
- 2026-11-12 ~23:30 token trim: .gitignore for scratch (git status 82 -> 0 lines), this file cut 126 -> 45 lines, cheap agents in `.claude/agents/`.
- 2026-11-12 ~23:20 v4.3.0 released (card forever + LocationFollow + background-location permission).
- 2026-11-12 ~21:15 6a8627eb card rebuilds itself daily (PrayerCardJob), seen +35 days.
- 2026-11-12 ~20:10 i'rab group B closed (parts 5-7 seen on API-24).
