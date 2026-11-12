# TASK_FOLLOWUP — the live step log (read right after CLAUDE.md)

Keep this file SHORT (under 60 lines): every session loads it whole. Newest
log line on top; past ~10 lines move the oldest to
`docs/history/TASK_FOLLOWUP_archive_2026-10-13_to_2026-11-12.md`. Times Dubai.

## Current task — Windows GPU load: hidden case DONE; visible case open

Hidden/minimised GPU fixed in `Rafiq-Al-Darb-Windows/app` (windows-desktop,
TickerMode + runner visibility message): 91.1% -> 2.7% hidden, 0% minimised
(measured 2026-11-12, 5 s means, Get-Counter). Window VISIBLE still ~95% GPU
3D on the first screen: find which animation (analog clock ticker,
rgb_backdrop, focus ring, splash video) and cap it.

## Next step (exact)

Profile the visible-window 95% (disable suspects one at a time in a build),
then rebuild `dist` zip only if the owner asks for a Windows release.

## Standing owner orders (still open)

- NO release without the owner's word. Last published: v4.3.0
  (2026-11-12 ~23:20, tag 7630abac, versionCode 120).
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
- Emulator Rafeeq_Audit_API24 left in ENGLISH UI, card mode «elapsed».

## Log (newest first)

- 2026-11-12 ~23:30 token trim: .gitignore for scratch (git status 82 -> 0 lines), this file cut 126 -> 45 lines, cheap agents in `.claude/agents/`.
- 2026-11-12 ~23:20 v4.3.0 released (card forever + LocationFollow + background-location permission).
- 2026-11-12 ~21:15 6a8627eb card rebuilds itself daily (PrayerCardJob), seen +35 days.
- 2026-11-12 ~20:10 i'rab group B closed (parts 5-7 seen on API-24).
