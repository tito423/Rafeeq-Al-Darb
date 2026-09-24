# TASK_FOLLOWUP — the live step log (read right after CLAUDE.md)

Updated after EVERY step, committed and pushed, so a session that dies mid-task
(quota, a dropped remote connection) loses nothing: the next session — this
account, the other one, or another agent — reads this and continues from
**Next step**. Newest entries at the top of the log. Log times are the PC clock, which IS Dubai time (checked against the owner: 14:23 real, 2026-09-24).

## Current task
**«ملخص العمرة» + «ملخص الحج»** (owner's order 2026-09-24 16:12).
PLAN.md Stage 1 is DONE and RELEASED: v3.61.0 published 2026-09-24 16:09
(tag SHA d84abe8a == HEAD at release; APK 265,181,991 bytes; v3.60.0 +
tag deleted; v3.51.0 and content-* kept). Verified on emulator — see
Settled facts.

## Next step (exact)
1. Read what the Hajj/Umrah screen already has (HajjScreen and its data /
   sources) before writing anything.
2. Write a quick stage-by-stage summary card at the BOTTOM of the Umrah
   section and of the Hajj section: from arrival, what to do at each stage,
   the adhkar said along the way, the wajibat and the sunan. Every step and
   dhikr from a NAMED source (CLAUDE.md 1.2); credit on the Sources screen.
3. Then PLAN 4a: measure whisper-base vs tiny (owner asked about integrating
   the better model; answer was: only if it wins by numbers).

- CORRECTION (16:30): the owner's Hifz video was NOT about the ayah flipping
  (he swiped on purpose to test). His bug: scrolling up/down on a long ayah
  (2:255) STALLS ~1 s mid-way. 3.61's arc fix is real but not his bug.
  Now measuring with dumpsys gfxinfo on emulator (font 1.3, 2:255).
  Umrah/Hajj summary PAUSED: material read (book pp.136-149, 180-188),
  plan = verbatim excerpts + a test that every fragment is in the book.

- Scroll-stall evidence so far (3.61, emulator, font 1.3, 2:255): screenrecord
  frame timeline — first swipe had a 180 ms gap with no frame mid-motion
  (0.59->0.77 s), later swipes smooth. gfxinfo counts 0 frames (Flutter
  surface) — useless here. Candidate (NOT proven): hifz_session_screen
  ListView disposes off-screen children; TasmeePanel is rebuilt on every
  scroll-in (new recorder, TasmeeMics.find platform call, isInstalled) and
  on scroll-out dispose() calls restoreAudioRoute(). Owner is sending a
  second video — read it before fixing.

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
- VERIFIED on emulator (3.61.0 fresh install, 16:00-16:04): onboarding title/blurb + all 6 rows with measured sizes, smallest recommended (Banna 383.6, Basit 449.0), total 1.3 GB (= 1278.5 MB summed); علوم القرآن download screenrecorded 0->90%: row never re-wraps or moves; More colours gold/blue/teal/red/blue/gold, Reminders sub-cards red; Hifz: jump button gone; a fine-sampled thumb arc on 2:255 at font 1.3 SCROLLS the page and keeps 255; a sideways swipe still turns to 256.
- FOUND + FIXED after the build: «شرح التطبيق» (TutorialEntryCard) stayed gold under Tools — now reads MoreGroupAccent. Needs the rebuild, then release.

- C1 backgrounds come from R2: after `pm clear`, opening Adhkar + new-Muslim
  made 6 connections, all to 104.18.50.34/104.18.54.45 (= the r2.dev
  bucket), zero to Unsplash (151.101.x / 146.75.x) or GitHub; images drawn.
  Method: emulator `-http-proxy` + logging proxy (TRAPS #53).

## Log
- 2026-09-24 16:20 - Scroll-stall evidence + candidate logged; waiting for owner's second video
- 2026-09-24 16:16 - Correction logged: hifz bug is a scroll stall, not ayah flip; measuring
- 2026-09-24 16:10 - v3.61.0 released and verified (tag == HEAD); next: Umrah/Hajj summaries
- 2026-09-24 16:08 - 3.61.0 final build verified (tutorial card teal under Tools); releasing
- 2026-09-24 16:04 - 3.61.0 verified on emulator (onboarding rows, jump fix, More colours, Hifz arc); tutorial card follows group colour
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
