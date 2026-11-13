# TASK_FOLLOWUP — the live step log (read right after CLAUDE.md)

Keep this file SHORT (under 60 lines): every session loads it whole. Newest
log line on top; past ~10 lines move the oldest to
`docs/history/TASK_FOLLOWUP_archive_2026-10-13_to_2026-11-12.md`. Times Dubai.

## Current task — owner's 11-item UI batch: DONE in code, seen on API 24, NOT released

Shots (owner's phone, mostly LANDSCAPE, dark theme): `docs/owner_shots/2026-11-13_batch/01..12.jpg`.
Owner's words are in the session log; items (his numbering):
1. Adhkar (01): the two «استمع لأذكار الصباح/المساء» bars are pinned - make them scroll with the page.
2. Home (03/04): the prayer card/strip is too big, eats the page; shrink it to its content, above all in landscape.
3. Home (03/04): surah-virtue titles (سورة البقرة…) too big, overlapping the text under them; fix.
5/6. Text mushaf (05/06): the rub'/hizb medallion plate has an ayah-number badge showing inside it and its label sits low; centre the label; marks must draw ON TOP of the text (z-order), any rule otherwise is to be changed.
7. Tasbeeh (07): remove the trash (delete) button; the button next to the vibration one (reset ↻) takes over its job.
8. Library (08): the top strips (الدرر السنية / المكتبة الشاملة + tabs) eat the screen: scroll with the page on small phones, may stay fixed on large tablets - decide what is right.
9. More (09): cards in landscape are terrible (narrow card, text wrapped word per line); redesign the layout for landscape, logical and beautiful.
10. Text mushaf portrait (10/11/12): the medallion overlapping the text looks very bad.
11. Owner: pick THREE of the four medallions (`assets/rub_medallions/` quarter/half/three_quarters/hizb) and put them IN PLACE OF the quarter marks in the TEXT mushaf - one medallion per text layout (page / cards / reading), each layout always uses its own one. Owner asked for confirmation he was understood: confirmed in chat with this reading (marks sit where the ۞/✻ quarter sign is, not floating over ayahs). This also answers 10.
(No item 4 in the owner's message.) All 7 languages for any new string; seen on emulator in portrait + landscape (+ a large/tablet AVD for 8/9).

## Windows GPU (windows-gpu session)

 load: mostly done (commit 4 in Windows app)

`Rafiq-Al-Darb-Windows/app` (windows-desktop), measured 2026-11-12/13,
Get-Counter 3D mean: hidden 91.1% -> 2.7-5.5%; visible 94.7% -> ~45%
(frames 52/s -> ~19/s). Fixes: TickerMode on hidden window + hidden
IndexedStack tabs, RGB backdrop timer 5/s, clock timer, focus-ring ticker.
Remaining visible load = PrayerCountdown seconds roll (owner-designed) at
~20 ms raster per full-window frame.

## Next step (exact)

Batch done (HANDOVER top row). Waiting for the owner: his look on a real
phone, and his word for a release. Unseen: real phone, dark theme for the
medallions, the Shamela/Dorar strip collapsing (debug build hides it), a
tablet AVD. Emulator: `adb emu rotate` to rotate; screenshots via Bash.

## Standing owner orders (still open)

- NO release without the owner's word. Last published: v4.5.2
  (2026-11-13, versionCode 124).
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
