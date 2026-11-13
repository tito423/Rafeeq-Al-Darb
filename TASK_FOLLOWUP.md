# TASK_FOLLOWUP — the live step log (read right after CLAUDE.md)

Keep this file SHORT (under 60 lines): every session loads it whole. Newest
log line on top; past ~10 lines move the oldest to
`docs/history/TASK_FOLLOWUP_archive_2026-10-13_to_2026-11-12.md`. Times Dubai.

## Current task — landscape check + release: DONE, RELEASED v4.5.1

v4.5.1 (versionCode 123) published 2026-11-13 on the owner's word; tag
1e754c59 = master. In it: landscape mushaf without the tab bar over the
page; landscape home labels (sunrise slide, quick-access grid) no longer
cut/split. Seen on API 24 in fr/es/pt/ru/ur. Details: HANDOVER row
«RELEASED v4.5.1».

## Windows GPU (windows-gpu session)

 load: mostly done (commit 4 in Windows app)

`Rafiq-Al-Darb-Windows/app` (windows-desktop), measured 2026-11-12/13,
Get-Counter 3D mean: hidden 91.1% -> 2.7-5.5%; visible 94.7% -> ~45%
(frames 52/s -> ~19/s). Fixes: TickerMode on hidden window + hidden
IndexedStack tabs, RGB backdrop timer 5/s, clock timer, focus-ring ticker.
Remaining visible load = PrayerCountdown seconds roll (owner-designed) at
~20 ms raster per full-window frame.

## Next step (exact)

No open owner request. Unverified: real phone. Possible polish (not asked):
reading layout badges float over scrolling text. NO release until the owner
says so. Emulator rotation: `adb emu rotate` (user_rotation does nothing on
API 24). Emulator lags: a screenshot can be stale.

## Standing owner orders (still open)

- NO release without the owner's word. Last published: v4.5.1
  (2026-11-13, versionCode 123).
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

- 2026-11-13 ~15:55 checked printed mushaf landscape + fr/es/pt/ru/ur (plate, Display row) on API 24: all right; fixed + seen landscape home labels (sunrise cut, quick-access mid-word split); RELEASED v4.5.1 (tag 1e754c59).
- 2026-11-13 ~14:50 checked v4.5.0 myself on API 24: plate in English+dark (½ Hizb 12, illuminated, slides, leaves), landscape text mode fine; FIXED landscape full-screen mushaf: bottom tab bar floated over the page with the chrome (5 of 15 lines left) - now hidden when wide (`app_shell.dart`), seen. Unreleased. Still unseen: printed mode landscape, fr/es/pt/ru/ur, real phone. Emulator rotate: `adb emu rotate` (settings user_rotation did nothing on API 24).
- 2026-11-13 ~12:00 rub' strip removed; printed-style plate centred over the page 3 s when the page is on screen (printed + text, seen API 24); analyze/test clean; NOT released (owner's word needed).
- 2026-11-13 ~01:45 v4.4.0 released: printed rub' strip moved into the left margin; English tasbeeh/adhkar seen; emulator back to Arabic + light theme.
- 2026-11-13 ~00:45 six-item Android batch done + seen (see Current task); analyze clean; commit pending release word.
- 2026-11-12 ~23:30 token trim: .gitignore for scratch (git status 82 -> 0 lines), this file cut 126 -> 45 lines, cheap agents in `.claude/agents/`.
- 2026-11-12 ~23:20 v4.3.0 released (card forever + LocationFollow + background-location permission).
- 2026-11-12 ~21:15 6a8627eb card rebuilds itself daily (PrayerCardJob), seen +35 days.
- 2026-11-12 ~20:10 i'rab group B closed (parts 5-7 seen on API-24).
