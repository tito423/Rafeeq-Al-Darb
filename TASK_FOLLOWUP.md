# TASK_FOLLOWUP — the live step log (read right after CLAUDE.md)

Keep this file SHORT (under 60 lines): every session loads it whole. Newest
log line on top; past ~10 lines move the oldest to
`docs/history/TASK_FOLLOWUP_archive_2026-10-13_to_2026-11-12.md`. Times Dubai.

## Current task — Android batch of six owner requests (2026-11-13): DONE, RELEASED v4.4.0

Seen on emulator-5554 (API 24, Arabic): (1) mushaf quarter plate = narrow
strip in the gap under the «۞» line at the page edge, text full width, fades
in on first view / out after 2 s, tap «۞» shows it again - text mode AND
printed madinah_qc (the page image has only the in-line ornament, no plate);
(2) tasbeeh reset-counter button + vibration tap (vibrate call NOT felt:
emulator has no vibrator); (3) adhkar last card centred (portrait; landscape
3x3 needs nothing); (4) heads-up adhan now SOUNDS (native MediaPlayer started,
alarm stream) - was silent by design; (5)+(6) khatma reminder pills + 12-hour
ص/م in pills, picker and menu subtitle. Not seen: non-Arabic languages, real
phone, printed plate on landscape. Printed strip fixed (upright in left margin) and released as v4.4.0 (owner's word 2026-11-13).

## Windows GPU (windows-gpu session)

 load: mostly done (commit 4 in Windows app)

`Rafiq-Al-Darb-Windows/app` (windows-desktop), measured 2026-11-12/13,
Get-Counter 3D mean: hidden 91.1% -> 2.7-5.5%; visible 94.7% -> ~45%
(frames 52/s -> ~19/s). Fixes: TickerMode on hidden window + hidden
IndexedStack tabs, RGB backdrop timer 5/s, clock timer, focus-ring ticker.
Remaining visible load = PrayerCountdown seconds roll (owner-designed) at
~20 ms raster per full-window frame.

## Next step (exact)

Owner batch 2026-11-13 noon, side session (uncommitted edits checkpointed
~13:40; analyze clean, 1474 tests passed before the last 3 small edits).
SEEN on API 24: (a) plate slides in from the edge and re-shows on return;
(b) sunan names 24 + outline, day text readable. (d) plate redrawn as an
illuminated medallion (gold ground, lapis rule + rays, rosette, finial,
paper panel, printed wording) - seen once: number spilled under the panel
and rays too heavy -> FIXED in code (body +0.34w, text centred in panel,
rays thinner), NOT yet rebuilt/seen. (e) 8 colours (swatches) + 5 frames
(stars/interlace/arches/braid/plain), `share_frame.dart`, 7 langs, test
`share_frame_painter_test` - NOT yet seen on device. (f) landscape: chrome
is ONE row (surah · actions · juz), ChromeFit no longer shrinks a scrolling
page (padding instead), bookmark caption fixed, badge margin 48 dp - text
and printed seen in landscape before the last 3 fixes; reading layout,
tablet (`wm size 1600x2560` + `wm density 320`) NOT seen.
DO: rebuild x64 (alone - TRAPS #54), install, see plate, share sheet
(i'rab card «…» in KFGQPCHafs = item c), landscape text/printed/reading,
tablet both ways; flutter test; HANDOVER line; `.\cp.bat`. No release.
Emulator rotation: set BOTH `accelerometer_rotation 0` and
`user_rotation`; something resets the first to 1.

## Standing owner orders (still open)

- NO release without the owner's word. Last published: v4.4.0
  (2026-11-13, versionCode 121).
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

- 2026-11-13 ~13:40 (d)(e)(f) coded, partly seen (see Next step); checkpoint, no release.
- 2026-11-13 ~12:00 rub' strip removed; printed-style plate centred over the page 3 s when the page is on screen (printed + text, seen API 24); analyze/test clean; NOT released (owner's word needed).
- 2026-11-13 ~01:45 v4.4.0 released: printed rub' strip moved into the left margin; English tasbeeh/adhkar seen; emulator back to Arabic + light theme.
- 2026-11-13 ~00:45 six-item Android batch done + seen (see Current task); analyze clean; commit pending release word.
- 2026-11-12 ~23:30 token trim: .gitignore for scratch (git status 82 -> 0 lines), this file cut 126 -> 45 lines, cheap agents in `.claude/agents/`.
- 2026-11-12 ~23:20 v4.3.0 released (card forever + LocationFollow + background-location permission).
- 2026-11-12 ~21:15 6a8627eb card rebuilds itself daily (PrayerCardJob), seen +35 days.
- 2026-11-12 ~20:10 i'rab group B closed (parts 5-7 seen on API-24).
