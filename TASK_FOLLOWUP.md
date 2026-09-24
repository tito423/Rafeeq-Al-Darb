# TASK_FOLLOWUP — the live step log (read right after CLAUDE.md)

Updated after EVERY step, committed and pushed, so a session that dies mid-task
(quota, a dropped remote connection) loses nothing: the next session — this
account, the other one, or another agent — reads this and continues from
**Next step**. Newest entries at the top of the log. Log times are the PC clock, which IS Dubai time (checked against the owner: 14:23 real, 2026-09-24).

## Current task
**PLAN.md Stage 1 — «التحميلات المبدئية»** (owner's order 2026-09-24).

## Next step (exact)
1. Stage 1 item 3 rows. DONE: per-ayah sizes measured —
   `scripts/measure_recitation_sizes.py` → `assets/data/catalogs/
   ayah_recitation_sizes.json`, 35 reciters, all 6236/6236 (smallest:
   mahmoud_ali_al_banna_32kbps 383.6 MB, Ibrahim_Akhdar_32kbps 485.9 MB;
   Maher 1204.3 matches R2). NEXT: whole-surah (التلاوة الكاملة) sizes for
   the R2 mirrors (`Mp3QuranApi.r2Mirrors`), then build the rows on
   `onboarding_screen.dart` reusing `AyahRecitationLibrary.downloadReciter`
   and the host-speed probe (range request per host at screen open).
2. Ask the owner about his note on «صوت قارئ الكتب المحسّن» (PLAN item 3).
3. Items 1+2 are in code (analyze 0, 568 tests pass) but NOT seen on device:
   verify both on a FRESH install (adb uninstall) with screenrecord during
   the علوم القرآن download.

## Half-done / unverified (redo, do not trust)
- Stage 1 items 1+2: title/blurb (7 locales) + ContentPackTile fixed-width
  slot/cancel — analyze+test pass, NOT seen on device.
- D1 sign-out scope: committed, not device-tested (needs a Google sign-in).
- B1 /sync caps: deployed (Worker 48b3fa3a), caps not exercised live (needs a
  real Google ID token).

## Log
- 2026-09-24 14:50 - Stage 1 item 3: per-ayah reciter sizes measured (35 reciters, everyayah listings) and bundled as a catalogue
- 2026-09-24 14:46 - Stage 1 item 1: title/blurb in 7 locales; C1 backgrounds seen on emulator (adhkar + new-Muslim render)
- 2026-09-24 14:38 - Stage 1 item 2: ContentPackTile fixed-width trailing slot + tabular digits + cancel (unverified)
- 2026-09-24 14:09 - checkpoint.ps1 regex rebuilt with chr(92) (trap 11); log line verified
- 2026-09-24 ~15:30 — Working rules settled (d56ee71f); TRAPS.md split out;
  AGENTS.md made a pointer to CLAUDE.md; this file created. v3.60.0 is the
  latest release; master has D1/B1/B5/C1 unreleased.
