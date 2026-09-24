# TASK_FOLLOWUP — the live step log (read right after CLAUDE.md)

Updated after EVERY step, committed and pushed, so a session that dies mid-task
(quota, a dropped remote connection) loses nothing: the next session — this
account, the other one, or another agent — reads this and continues from
**Next step**. Newest entries at the top of the log. Log times are the PC clock, which IS Dubai time (checked against the owner: 14:23 real, 2026-09-24).

## Current task
Post-3.61 fixes, all in code AND verified on emulator-5554 (build of 17:05),
NOT released yet — ask the owner whether to release 3.62.0.

## Next step (exact)
1. Ask the owner: release 3.62.0 now? (bump pubspec + about_screen, build,
   delete v3.61.0 + tag, keep v3.51.0 + content-*, notes in Arabic, verify
   tag SHA == HEAD, `git status --short` clean of source first — trap 55).
2. Then PLAN 4a (owner asked to be reminded): measure whisper-base-ar-quran
   (R2, 160.6 MB) vs the tiny model — word accuracy on real recitations +
   latency — integrate only if it wins by numbers.

Done since v3.61.0 (each verified):
- Hifz scroll stall: page built once (SingleChildScrollView). Root cause
  from the owner's video (7 same-direction stalls while scrolling up, each
  followed by a catch-up jump). Emulator does not stall at all, so the
  final proof is the owner's phone.
- Umrah/Hajj summary cards: seen on emulator; 2 tests prove every piece
  verbatim from the book; ayah 2:198-199 from the mushaf.
- Location stuck after first-run permission: reproduced, fixed, re-run of
  the same fresh-install path shows Dubai + times at once.
- Prayer methods: 2400 times vs AlAdhan live, worst 2 min; Dubai added.

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
- 2026-09-24 17:02 - Location fix verified on fresh install (Dubai + times at once); 570 tests pass; post-3.61 fixes ready, release pending owner
- 2026-09-24 16:53 - Location stuck after first-run permission: reproduced + fix (invalidate prayer controller at onboarding end); building to verify
- 2026-09-24 16:48 - Hajj summary: pillars and obligations under separate headings; summary seen on emulator (Umrah + Hajj, ayah 2:198-199 from mushaf)
- 2026-09-24 16:43 - Prayer times re-verified LIVE vs AlAdhan: 2400 times, 20 methods x 5 cities (Dubai added) x 2 dates x 2 schools, worst 2 min
- 2026-09-24 16:36 - Umrah/Hajj summary card (verbatim excerpts, ayah from mushaf, 7 locales); 570 tests pass; building
- 2026-09-24 16:33 - checkpoint.ps1 warns about untracked source files; trap 55
- 2026-09-24 16:32 - Add measurement scripts and hajj summary files to git
- 2026-09-24 16:32 - Scroll stall root-caused from owner video (7 same-direction stalls while scrolling up); emulator numbers corrected; measurement scripts kept
- 2026-09-24 16:28 - Hajj/Umrah summary data + verbatim test (2/2 pass); trap 54 (flutter test during a build breaks it)
- 2026-09-24 16:24 - Hifz scroll stall: page built once (SingleChildScrollView) instead of lazy ListView; before = 2 stalls 911/1019 ms (emulator), owner video 7 x ~200 ms; after-measurement pending
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
