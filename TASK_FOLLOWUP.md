# TASK_FOLLOWUP — the live step log (read right after CLAUDE.md)

Updated after EVERY step, committed and pushed, so a session that dies mid-task
(quota, a dropped remote connection) loses nothing: the next session — this
account, the other one, or another agent — reads this and continues from
**Next step**. Newest entries at the top of the log. Log times are the PC clock, which IS Dubai time (checked against the owner: 14:23 real, 2026-09-24).

## Current task
**PLAN.md Stage 1 — «التحميلات المبدئية»** (owner's order 2026-09-24).

## Next step (exact)
0. DONE in code (analyze 0, 568 tests): More colours (gold / info /
   primarySoft / error / info / gold); Hifz swipe fix (owner's video: a
   thumb arc flipped 2:255 <-> 256 - REPRODUCED on the emulator at
   font_scale 1.3 with an `input motionevent` arc; fixed with 3x slop + a
   |dx| >= 2|dy| path check); Hifz app-bar jump button + sheet + its keys
   removed (the navigator covers it). Version 3.61.0+63. Release build
   started ~16:05 (log %TEMP%/claude/build_log2.txt).
1. When the build is done: start the emulator, `adb uninstall
   com.tito.rafeeq_aldarb`, install fresh, and check on the device: new
   title/blurb; every row (ayah reciter probe + picker, whole recitation,
   tasmee, voice, total line); screenrecord the علوم القرآن download for
   the jump fix; the More colours; the Hifz swipe fix (font_scale 1.3,
   Baqarah 255, the same motionevent arc must SCROLL, not change the ayah;
   a real sideways swipe must still turn it). Reset font_scale to 1.0.
2. Release: delete v3.60.0 + its tag (keep v3.51.0 and content-*), publish
   v3.61.0 with --target master, verify the tag SHA == HEAD.

## Owner's orders queued (15:25) — all go into ONE release
- «حطّه»: the enhanced book-reader voice (OpenVoice, 260.7 MB) IS a row.
- Finish every requested edit, then PUBLISH on GitHub (bump pubspec +
  About, build_github_release.bat, delete v3.60.0 release+tag, keep v3.51.0
  and content-* prereleases).
- «المزيد» screen: each MAIN card a different colour from the one under it,
  same style; every SUB-card of a section takes its main card's colour.
  Change ONLY the colours — card design stays exactly as it is.
- Tasmee: tiny model goes in the row now (done). whisper-base-ar-quran
  (R2, 160.6 MB, unused): owner asked «ادمجه ولا ايه رايك» — answer given:
  not before PLAN 4a is MEASURED (word accuracy on real recitations +
  latency); do 4a after this release, integrate only if it wins by numbers.

- NEW (16:12): «ملخص العمرة» + «ملخص الحج» — a quick step-by-step card at
  the BOTTOM of each section in the Hajj/Umrah screen: from arrival, stage
  by stage, the adhkar said along the way, the wajibat and the sunan.
  Religious content: every step/dhikr from a NAMED source (CLAUDE.md 1.2);
  first read what hajj data the app already has (HajjScreen, its sources).
  Do AFTER the v3.61.0 release.

## Half-done / unverified (redo, do not trust)
- Stage 1 rows: ALL written (`offline_pack_tiles.dart`), analyze clean,
  NOT seen on device. Sizes:
  `ayah_recitation_sizes.json`, `offline_pack_sizes.json` (mushaf 74.3 MB,
  basit 449.0, maher 709.1 — R2 listing). hadeethenc + UI-locale
  translations are bundled → no rows.
- Stage 1 items 1+2: title/blurb (7 locales) + ContentPackTile fixed-width
  slot/cancel — analyze+test pass, NOT seen on device.
- D1 sign-out scope: committed, not device-tested (needs a Google sign-in).
- B1 /sync caps: deployed (Worker 48b3fa3a), caps not exercised live (needs a
  real Google ID token).

## Settled facts
- C1 backgrounds come from R2: after `pm clear`, opening Adhkar + new-Muslim
  made 6 connections, all to 104.18.50.34/104.18.54.45 (= the r2.dev
  bucket), zero to Unsplash (151.101.x / 146.75.x) or GitHub; images drawn.
  Method: emulator `-http-proxy` + logging proxy (TRAPS #53).

## Log
- 2026-09-24 15:56 - Owner order logged: Umrah/Hajj quick summaries after the release
- 2026-09-24 15:53 - TASK_FOLLOWUP next steps rewritten (build running)
- 2026-09-24 15:53 - TASK_FOLLOWUP next steps rewritten (build running)
- 2026-09-24 15:52 - Bump 3.61.0; release build started
- 2026-09-24 15:51 - Hifz: vertical thumb arc no longer flips the ayah (reproduced 255->256 on emulator; fix: 3x slop + clearly-sideways path check); jump button/sheet removed; More main-card colours alternate
- 2026-09-24 15:39 - Stage 1 rows: ayah reciter (host probe, smallest recommended), whole recitation, tasmee, voice, measured total; 7 locales; analyze clean, not yet on device
- 2026-09-24 15:36 - Stage 1: shared OfflinePackRow + R2-measured mushaf/whole-recitation sizes; owner's queued orders logged
- 2026-09-24 15:17 - C1 proven served from R2 via logging proxy; new rules 1.7b (certainty) and no-lazy-shortcuts; trap 53
- 2026-09-24 14:50 - Stage 1 item 3: per-ayah reciter sizes measured (35 reciters, everyayah listings) and bundled as a catalogue
- 2026-09-24 14:46 - Stage 1 item 1: title/blurb in 7 locales; C1 backgrounds seen on emulator (adhkar + new-Muslim render)
- 2026-09-24 14:38 - Stage 1 item 2: ContentPackTile fixed-width trailing slot + tabular digits + cancel (unverified)
- 2026-09-24 14:09 - checkpoint.ps1 regex rebuilt with chr(92) (trap 11); log line verified
- 2026-09-24 ~15:30 — Working rules settled (d56ee71f); TRAPS.md split out;
  AGENTS.md made a pointer to CLAUDE.md; this file created. v3.60.0 is the
  latest release; master has D1/B1/B5/C1 unreleased.
