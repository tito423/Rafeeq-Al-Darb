# TASK_FOLLOWUP — the live step log (read right after CLAUDE.md)

Updated after EVERY step, committed and pushed, so a session that dies mid-task
(quota, a dropped remote connection) loses nothing: the next session — this
account, the other one, or another agent — reads this and continues from
**Next step**. Newest entries at the top of the log. Log times are the PC clock, which IS Dubai time (checked against the owner: 14:23 real, 2026-09-24).

## Current task
FULL-APP CONFLICT AUDIT before releasing 3.62.0 (owner: «مش تنشر الا لما
تتاكد مليون في المية»). Session stopped by the owner at 18:58 (quota).
pubspec is ALREADY 3.62.0+64; NOT released; v3.61.0 is still the release.

## Next step (exact)
1. DONE in code (594155e1+): download state app-wide. Tasmee model and the
   enhanced voice were the ONLY buttons holding their download in widget
   state; now TasmeeEngine.startDownload/downloadProgress/installed and
   OpenVoice.install/installProgress/installed own it. Every other button
   (books, hadith DB, sciences, translations, mushaf, reciters, ayah
   reciters, onboarding rows) already read DownloadManager / a service -
   checked by reading each file 2026-09-24. analyze clean, 570 tests pass.
   NOT seen on device.
2. ONE build (emulator OFF, trap 24; no flutter test during it, trap 54),
   then verify on emulator:
   - tasmee: start «نزّل النموذج», leave the Hifz screen, come back ->
     still «جارٍ التحميل n%», then installed; onboarding row mirrors it.
   - voice: start download from a book «استماع», press «متابعة في الخلفية»,
     press «استماع» again -> progress dialog, not the offer; Settings
     «قارئ الكتب» subtitle shows «جارٍ التحميل n%».
   - «استمع» disabled while tasmee records; changing ayah mid-recording
     cancels it (tasmee_panel.dart tasmeeRecordingProvider).
   - deleting a reciter / surah recitation that is playing stops it.
   - REST OF THE CONFLICT AUDIT (owner 19:30: finish ALL conflicts and
     compat issues app-wide before the release): notifications count
     (trap 33, >25 posted), focus mode vs adhan, location (qibla + prayer
     card at once). Signed 3.62.0 APK built 19:30 with the download-state
     fix (build/app/outputs/flutter-apk/app-release.apk, signed).
   TELL THE OWNER when done so he can put the laptop back from Turbo.
3. Only then: release 3.62.0 (notes in dist/release_notes_v3.62.0.md - add
   the tasmee/delete/download-state items), delete v3.61.0 + tag, keep
   v3.51.0 + content-*, git status clean of source (trap 55), tag == HEAD.

Verified on device this session (3.62.0 builds): auto-scroll no longer
cascades (p1 ~20 s, p2 ~25 s); recitation + auto-scroll in sync (highlight
2:17->2:20 on p4); adhan pauses recitation and it resumes at the same ayah;
book reader stops a playing recitation; tasmee start stops a playing ayah;
tasmee + «استمع» ran at once (FIXED in code, not yet seen). Location fix,
Umrah/Hajj summary, hifz scroll-stall fix, prayer methods (2400 vs AlAdhan,
worst 2 m), ASR tiny kept (base == accuracy, 3.2x slower) - all in the log.

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
- SEEN on emulator (3.62.0 signed, 19:32-19:39): voice download started in
  onboarding shows «Downloading 0%->2%» live in Settings > Book reader
  (was a plain download offer); onboarding rows show both downloads with %;
  tasmee: «Listen» greyed while recording and pressing it plays nothing
  (media_session NONE); moving to ayah 2 mid-recording cancelled it, Listen
  back, nothing marked.
- SEEN (19:40-19:44, fresh install, umts then full): tasmee download started
  in onboarding shows in the Hifz panel «Downloading 0%» + Cancel; left the
  panel 20 s, came back at 33% (old build cancelled it on leave); then 90%
  -> «Start reciting» on its own. Isha adhan fired 19:43 during it (full
  screen, USAGE_ALARM MediaPlayer), Stop -> nothing playing, panel intact.
- FOUND (not fixed yet): on the slow (umts) network the onboarding
  per-ayah recitation row says «No server answered right now» and its
  button is DISABLED - the servers answer, just slowly. Look at the probe
  timeout in offline_pack_tiles.dart (_Probe). The emulator's Quran tab opens full screen - Back
  returns Home (not a bug; Display sheet ate one Back).
- VERIFIED on emulator (3.61.0 fresh install, 16:00-16:04): onboarding title/blurb + all 6 rows with measured sizes, smallest recommended (Banna 383.6, Basit 449.0), total 1.3 GB (= 1278.5 MB summed); علوم القرآن download screenrecorded 0->90%: row never re-wraps or moves; More colours gold/blue/teal/red/blue/gold, Reminders sub-cards red; Hifz: jump button gone; a fine-sampled thumb arc on 2:255 at font 1.3 SCROLLS the page and keeps 255; a sideways swipe still turns to 256.
- FOUND + FIXED after the build: «شرح التطبيق» (TutorialEntryCard) stayed gold under Tools — now reads MoreGroupAccent. Needs the rebuild, then release.

- C1 backgrounds come from R2: after `pm clear`, opening Adhkar + new-Muslim
  made 6 connections, all to 104.18.50.34/104.18.54.45 (= the r2.dev
  bucket), zero to Unsplash (151.101.x / 146.75.x) or GitHub; images drawn.
  Method: emulator `-http-proxy` + logging proxy (TRAPS #53).

## Log
- 2026-09-24 19:44 - Seen on device: tasmee download survives leaving the panel, shared with onboarding; adhan during download OK; found slow-network probe disables ayah row
- 2026-09-24 19:40 - Seen on device: voice download state in Settings, tasmee listen-disabled + ayah-change cancel
- 2026-09-24 19:31 - 3.62.0 signed build done (download-state fix in); owner 19:30: finish whole-app conflict audit first - remaining pairs logged; emulator starting
- 2026-09-24 19:26 - Download state audit done: only tasmee + voice held widget state (fixed); 570 tests pass; building 3.62.0 for device verification
- 2026-09-24 19:24 - Download state app-wide (1/2): tasmee model and enhanced voice downloads owned by TasmeeEngine/OpenVoice, not widgets; panel, pack rows, voice settings and reader sheet show downloading %/installed; analyze clean, not on device
- 2026-09-24 18:50 - Session stopped by owner: TASK_FOLLOWUP next steps exact (download-state buttons, one build, verify, then release 3.62.0)
- 2026-09-24 18:49 - Queued: download buttons show downloading/done state app-wide
- 2026-09-24 18:49 - Conflict: deleting the recitation/surah being played now stops it first; audit notes
- 2026-09-24 18:45 - Conflict: tasmee recording vs listen (both ran at once, verified on device) - listen disabled while recording; ayah change mid-recording cancels it
- 2026-09-24 18:36 - Conflict audit: 4 pairs tested on device (auto-scroll, recitation sync, adhan, book reader); ui_find.py tool
- 2026-09-24 18:07 - Auto-scroll/page-turn conflict: dwell on pages that fit; _current from onPageChanged only (found on device with recitation)
- 2026-09-24 17:48 - 3.62.0: recitation/auto-scroll sync (note in own file, under ceiling), AudioExclusive (book reader vs recitation, tasmee silences all), 570 tests pass
- 2026-09-24 17:31 - PLAN 4a result recorded
- 2026-09-24 17:30 - PLAN 4a measured: base == tiny on accuracy (446/500 each), 3.2x slower, 1.9x size -> tiny stays; recitation/auto-scroll sync in code
- 2026-09-24 17:26 - Queued: sync continuous recitation with auto-scroll; ASR tiny-vs-base script added (running)
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
