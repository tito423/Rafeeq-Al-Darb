# TASK_FOLLOWUP — the live step log (read right after CLAUDE.md)

Keep this file SHORT (under 60 lines): every session loads it whole. Newest
log line on top; past ~10 lines move the oldest to
`docs/history/TASK_FOLLOWUP_archive_2026-10-13_to_2026-11-12.md`. Times Dubai.

## Current task — owner batch (a)-(f) + release: DONE, RELEASED v4.5.0

v4.5.0 (versionCode 122) published 2026-11-13 on the owner's word «انشر»; tag
17acb716 = master. Seen on emulator-5554 API 24 before release: landscape
reading layout, dark plate/home/sunan/share, English Display row + share
sheet; fixed + seen: share «آية ٥٥» (was clock-like «٥:٥٥»), «Juz ٦» pill.
Details: HANDOVER row «RELEASED v4.5.0».

## Windows GPU (windows-gpu session)

 load: mostly done (commit 4 in Windows app)

`Rafiq-Al-Darb-Windows/app` (windows-desktop), measured 2026-11-12/13,
Get-Counter 3D mean: hidden 91.1% -> 2.7-5.5%; visible 94.7% -> ~45%
(frames 52/s -> ~19/s). Fixes: TickerMode on hidden window + hidden
IndexedStack tabs, RGB backdrop timer 5/s, clock timer, focus-ring ticker.
Remaining visible load = PrayerCountdown seconds roll (owner-designed) at
~20 ms raster per full-window frame.

## Next step (exact)

No open owner request. Unverified: fr/es/pt/ru/ur, real phone, printed
plate in landscape. Possible polish (not asked): reading layout badges
float over scrolling text. NO release until the owner says so.
Emulator rotation: set BOTH `accelerometer_rotation 0` and `user_rotation`.
Emulator lags: a screenshot can be stale, so a tap can land on a moved
button (two khatma wirds got marked this way, test data 14->16).

## Standing owner orders (still open)

- NO release without the owner's word. Last published: v4.5.0
  (2026-11-13, versionCode 122).
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
- Emulator Rafeeq_Audit_API24 left in ENGLISH UI, DARK theme, card mode «elapsed».

## Log (newest first)

- 2026-11-13 ~14:10 (a)-(f) seen on API 24 incl. tablet; committed, no release.
- 2026-11-13 ~13:40 (d)(e)(f) coded, partly seen (see Next step); checkpoint, no release.
- 2026-11-13 ~12:00 rub' strip removed; printed-style plate centred over the page 3 s when the page is on screen (printed + text, seen API 24); analyze/test clean; NOT released (owner's word needed).
- 2026-11-13 ~01:45 v4.4.0 released: printed rub' strip moved into the left margin; English tasbeeh/adhkar seen; emulator back to Arabic + light theme.
- 2026-11-13 ~00:45 six-item Android batch done + seen (see Current task); analyze clean; commit pending release word.
- 2026-11-12 ~23:30 token trim: .gitignore for scratch (git status 82 -> 0 lines), this file cut 126 -> 45 lines, cheap agents in `.claude/agents/`.
- 2026-11-12 ~23:20 v4.3.0 released (card forever + LocationFollow + background-location permission).
- 2026-11-12 ~21:15 6a8627eb card rebuilds itself daily (PrayerCardJob), seen +35 days.
- 2026-11-12 ~20:10 i'rab group B closed (parts 5-7 seen on API-24).
