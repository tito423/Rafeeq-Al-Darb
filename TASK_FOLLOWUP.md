# TASK_FOLLOWUP — the live step log (read right after CLAUDE.md)

Updated after EVERY step, committed and pushed. Newest log entry on top.
Times are Dubai (UTC+4). Keep this file SHORT and in plain sentences with
spaces: the next session has to read it whole. Long history goes to
`docs/history/` — the log up to 2026-10-13 17:25 (871 KB, written by Codex
in compressed run-together words) is archived unchanged in
`docs/history/TASK_FOLLOWUP_archive_to_2026-10-13.md`.

## Current task

2026-10-20: own i'rab continues backwards (057 al-Hadid 574 words, 056
al-Waqi'a 379 words, 055 al-Rahman 351 words, 054 al-Qamar 342 words, 053 al-Najm 360 words, 052 al-Tur
312 words, all seen in the app's i'rab tab on Rafeeq_Audit_API24). 051 al-Dhariyat 360 words and 050 Qaf 373 words (both written, check.py OK, seen in the app 51:38 and 50:39). 049 al-Hujurat 347 words and 048 al-Fath 560 words written, check.py OK, seen in the app 49:13 and 48:29. Owner:
«كمل كل السور اوتو» - continue backwards without asking. 047 Muhammad 539 words written, check.py OK, NOT yet seen in the app. Next: device-check 47, then surah 046 with show.py, books.py, fill_046.py, check.py, export_app.py. Release 3.91.1 is
ON HOLD (owner said «استنى»): do not publish until he asks.

Older context:
Codex's full audit (2026-10-09..13, report `docs/audits/AUDIT_2026-10-09.md`)
was reviewed by Claude on 2026-10-13. v3.88.1 is published with the adhan
re-arm fix. The review site was reworked to the owner's model: NO reviewer
list, no Google sign-in — he sends the link, a reviewer writes his name.

## Next step (exact)

1. Owner phone checks: install 3.90.0 over the existing app, press Listen
   on a few adhkar (and the sleep dhikr «الم تنزيل … وتبارك»: ~15.5 min),
   test adhan before the first PIN after reboot, real microphone/tasmee,
   recitation Home -> launcher icon -> Back, and Google sync on two devices.
2. Per-ABI APKs: ARM64/ARMv7 phone checks are still pending. Existing split
   experiments predate the final 3.88.1 adhan retry; refresh/sign/validate
   the current-version splits before giving them to the owner. Keep the
   universal APK primary and build_github_release.bat unchanged until all
   the original ABI gates pass. Emulators stay off at the owner's request.
3. The adhan retry native suite is still unverified on API24. Do not claim
   that check passed or silently substitute the API36 result.

Completed: review Worker fb98ec8c-2c2f-4961-9db7-66d588d7030d and Pages
cff08c1 are live and verified. No Google/list is needed for reviews; a name
is bound to its browser key and does not verify real-world identity. The
two owned QA registrations and technical note were removed. Screenshot
capture was unavailable; actual browser state and server rows were checked.

A-01 is now verified: after the owner rotated/revoked the credential,
Codex's read-only ListObjectsV2 MaxKeys=1 using the public historical pair
from 3747f715 returned 401 Unauthorized with TLS verification. No values
were printed, the new scripts/.env key was not read, no objects were
written, and git history was not modified. Raw proof is outside git.

Remote cleanup was completed by the owner/other session: main and master
remain; release-v1.2.0 and v3.51.0 are in the verified backup bundle
E:/My Projects/Rafeeq-Backups/release-v1.2.0-and-v3.51.0.bundle.
Keep v3.87.0 and the three content mirror releases.

Other repos (Claude, 2026-10-13 22:10, owner's explicit order): deleted
`tito423/rafeeq-api` (old content host, 1.6 GB, unused since the R2 move;
mirror backup E:/My Projects/Rafeeq-Backups/rafeeq-api.git) and the
untouched fork `tito423/Quran-PNG`; deleted branch
claude/intelligent-franklin-lu4lnd from rafeeq-control (mirror backup
E:/My Projects/Rafeeq-Backups/rafeeq-control.git). Remaining repos:
Rafeeq-Al-Darb, rafeeq-review, rafeeq-recitations, rafeeq-control,
tito-kids-tube-webos (separate project, untouched).

The stored review page equals live Pages commit 71ea463 again (c3ad0ff6
had set it back to cff08c1, dropping the "name taken" message that is live).

The owner also requested a caravan game assessment and ideas after the
audit, before any game implementation. Do not begin game edits from this
heartbeat or mistake that future proposal for an approved redesign.

## Half-done / unverified

- The adhan retry fix is verified on API 36 only (native suite + upgrade
  install), not on API 24 or a real phone.
- The review rework is now deployed and verified on the live Worker and
  Pages. Backend 82 tests, live API controls, and actual browser name/note
  flow passed. Screenshot capture was unavailable; no image proof claimed.
  All owned QA notes and registrations were removed after verification.
- emulator-5554 has the signed 3.88.1 installed (upgraded over 3.88.0).

## Log

- 2026-10-20 21:40 — Own i'rab 047 Muhammad: 539 words, check.py OK,
  exported (69 surahs, 1,698 ayahs, 12,113 words). Not yet device-checked.
- 2026-10-20 21:15 — WIP fill_047.py: Muhammad 1-19 written (token counts
  match), 20-38 not yet; file has no write() call yet, 047.json not built.
- 2026-10-20 20:55 — Device check: 49:13 and 48:29 i'rab tabs seen on
  Rafeeq_Audit_API24 (fresh debug build 11:48 emulator time); named views
  under «عند» (al-Da'as, Darwish) and «من أثر» (al-Da'as) render.
- 2026-10-20 20:40 — Own i'rab 048 al-Fath: 560 words, check.py OK,
  exported (68 surahs, 1,660 ayahs, 11,574 words). Not yet device-checked.
- 2026-10-20 19:30 — Own i'rab 049 al-Hujurat: 347 words, check.py OK,
  exported (67 surahs, 1,631 ayahs, 11,014 words). Not yet device-checked.
- 2026-10-20 18:45 — Device check: 51:38 and 50:39 i'rab tabs seen on
  Rafeeq_Audit_API24 (al-Jadwal's view named under «وفي»; Qaf's «ما» alt).
- 2026-10-20 18:30 — Own i'rab: Qaf (050) written, 373 words, check.py OK,
  exported (66 surahs / 10,667 words). Not yet seen in the app (with 051).
- 2026-10-20 17:50 — Own i'rab: al-Dhariyat (051) written, 360 words, check.py
  OK, exported. Not yet seen in the app (device check batched with the next
  surahs). 51:56 «ليعبدون» lam = التعليل (both books), al-Da'as «العاقبة» named.
- 2026-10-20 17:05 — Own i'rab: al-Tur (052) written, 312 words, check.py
  OK, exported (64 surahs / 9,934 words), 52:35 seen in the app. Alignment
  review caught 52:35 «خلقوا» written as مضارع; fixed to ماض مبني للمجهول.
- 2026-10-20 16:20 — Own i'rab: al-Najm (053) written, 360 words, check.py
  OK, exported (63 surahs / 9,622 words), 53:58 seen in the app with al-Da'as
  named. 53:20 «الأخرى»: al-Da'as «صفة العزى», both books صفة ثانية لمناة.
- 2026-10-20 15:30 — Own i'rab: al-Qamar (054) written, 342 words, check.py
  OK, exported (62 surahs / 9,262 words), 54:51 seen in the app. One al-Da'as
  slip not copied: 54:20 «منقعر صفة أعجاز» (the word is genitive -> صفة لنخل).
- 2026-10-20 14:40 — Own i'rab: al-Rahman (055) written, 351 words, check.py
  OK, exported (61 surahs / 8,920 words), 55:73 seen in the app. One al-Da'as
  slip not copied: 55:72 «والجملة استئنافية» on an ayah with no clause.
- 2026-10-20 13:55 — Own i'rab: al-Waqi'a (056) written, 379 words, check.py
  OK, exported (60 surahs / 8,569 words), 56:81 seen in the app with Darwish's
  two views named. One al-Da'as slip not followed: 56:39 «الجملة صفة
  أصحاب» (a sentence after a definite noun); ours = al-Jadwal, al-Da'as shown.
- 2026-10-20 11:15 — Own i'rab: al-Hadid (057) written, 574 words,
  check.py OK, exported (59 surahs / 8,190 words), seen word-for-word in the
  i'rab tab on the emulator (57:4). Fixed: the full-screen card drew its
  tab row under the status bar (a modal sheet's MediaQuery drops the top
  inset; now read from the View). analyze clean, 1448 tests pass.
- 2026-10-20 03:50 — Owner asks (1) bookmarks for ayah/page, (2) one place
  for all notes, (3) tafsir/translation/i'rab expandable to the full screen,
  (4) resume the i'rab work. Done 1-3, SEEN on API-24: «علامة على الآية» in
  the card menu (button turns gold), «علّم الصفحة» + both lists in a new
  «العلامات والملاحظات» tab of «الانتقال إلى» (tap -> page), full-screen
  button beside the card tabs (header and ayah hidden). Bookmarks are
  device-only (quran_bookmarks_v1): syncing needs the Worker key list
  changed and deployed - owner's call. 7 languages. 1448 tests.
  NEXT: i'rab - own i'rab stopped at 58 (done: 1 + 58-114, 5,247 / 77,430
  words); next surah 57 al-Hadid via show.py/books.py/fill_057.py.

- 2026-10-20 02:55 — Paper mushaf now fills the band between the bars
  (owner's phone screenshot: page at ~69% width with empty margins).
  ChromeFit fitted the whole box, margins included; given the drawn
  page's aspect (MushafPageView.pageAspectFor) it now scales only the
  page into the band and centres it. Seen on the API-24 emulator: page
  from under the top bar to above the page badge. Text mode unchanged.
  1445 tests. Not released (v3.91.0 has the previous fit).

- 2026-10-20 02:25 — RELEASED v3.91.0 on the owner's order («الاتنين»):
  https://github.com/tito423/Rafeeq-Al-Darb/releases/tag/v3.91.0 , tag
  18a8b306 = master, APK 313,520,342 B, sha256 9d37d77d...fdb679 equal to
  GitHub's digest, range 206, versionCode 106. v3.90.0 and its tag deleted;
  v3.87.0 + content mirrors kept. Next: owner's ear on the new voice and its
  speed on his phone; the ~300 azkar mp3s missing on content-mirror.

- 2026-10-20 02:20 — «رفيق» no longer crash-loops on 1 GB phones (TRAPS
  76). MemTotal from /proc/meminfo; below 1.6 GB (rafeeq_memory.dart, test
  pinned to the measured 1,019,240 / 2,049,872 kB) the wake listener never
  starts the service or the ear, RafeeqEar refuses to load, the settings
  switch is off with «يحتاج «رفيق» إلى ذاكرة … {} … {}» (7 languages, sizes
  via formatBytes), the 368 MB download is disabled, diagnostics says why.
  API-24 emulator: 1 GB -> app stayed alive, no service, message shown;
  2 GB -> Rafeeq service runs as before. 1445 tests pass.

- 2026-10-20 01:15 — `onnxruntime` pub package removed (unused since the
  voice moved to sherpa). pubspec/lock, the A48 integration test's OrtEnv
  lines, build.gradle.kts (pickFirsts, copySherpaOrt, the MS AAR note) and
  check_apk_native.py's description. build_github_release.bat SUCCEEDED
  (after trap 75: CRLF + chcp 65001 + ErrorActionPreference Continue):
  check_apk_native passed for arm64/armv7/x86_64 (sherpa ORT 1.28.2), signed
  with the lineage. APK 313,520,342 B vs v3.90.0's 313,766,102 B: no native
  library changed (pickFirsts had already kept 1.15.1 out), the -245,760 B
  is all libapp.so (Dart, includes this session's other changes). The signed
  APK installed over the app with `adb install -r` on the API-24 emulator,
  data kept (voice pack still installed); the book voice read Al-Adab
  al-Mufrad in the RELEASE build (sid 6, 8 steps). «رفيق» on: at the AVD's
  default 1 GB the low-memory killer crash-loops the app (TRAPS 76, not a
  regression); at 3 GB the service runs with the recogniser loaded (528 MB
  PSS). flutter analyze lib test integration_test clean; 1440 tests pass.
  OPEN: «رفيق» on 1 GB phones (needs a RAM check before loading the model,
  or a smaller model) - not started.

- 2026-10-20 00:45 — Book voice replaced: Supertonic-3 int8 (voice 6, male,
  8 steps) through the app's own sherpa_onnx 1.13.8, in a worker isolate;
  OpenVoice keeps its API. 30 matns: UTMOS 3.27 vs 2.69 for FastPitch, CER
  5.4% vs 5.3% (worst 13.6% vs 30%); jalala heavy 1262/1209 Hz, light 1421
  after kasra (same pattern as before, so the «يفخّم لفظ الجلالة» text stays
  true). Pack 145,295,768 B on R2 `tts/supertonic3_ar_v1/` (8 objects incl.
  OpenRAIL-M LICENSE.txt, all 206) and on content-mirror (8 assets, 206).
  API-24 emulator: downloaded in-app, read Al-Adab al-Mufrad aloud, pulled
  the rendered WAVs and FastConformer read the book's isnad back; RTF 0.31
  there (x86). The old open_ar_v1 pack is deleted from devices (seen).
  7 languages: the voice is disclosed as machine-generated (OpenRAIL-M);
  Sources: one Supertonic entry replaces ASC + nipponjo. Phonetiser and its
  test deleted. 1440 tests pass.
  NOT DONE / UNVERIFIED: speed on a real ARM phone (if a chunk renders
  slower than 85% of its length the voice drops to 6 steps by itself);
  owner has not yet said how the new voice sounds to him (samples sent).
  The `onnxruntime` pub package is now unused by lib/ but still in pubspec
  (build.gradle pickFirsts + check_apk_native.py depend on it) - removing
  it needs build_github_release.bat + a signed install. github_content_mirror
  found ~300 azkar voice mp3s missing on content-mirror; I stopped that bulk
  upload (TRAPS 60) - run it in a quiet window, not before a release.

- 2026-10-19 23:00 — Two owner reports fixed and seen on emulators. (1)
  «الرجوع للآية المقروءة: إيقاف» still pulled the reader back: the page
  FOLLOW on every new verse did it, not the timer (at once when recitation
  started on the page in view - `_followedPage` was unset). Now a reader
  who turned away by hand stays; only the timer returns him. API-24
  emulator, Baqarah/Minshawi: Off -> stayed on page 4 for 40 s while the
  recitation crossed to page 3; 5 s -> back on page 3 within 8 s. (2)
  Tasbih «الأذكار الطويلة» gone: on the owner's phone size (1224x2700 @
  520 dpi, font 1.3) the «أذكار مأثورة» card sat under the capped controls,
  hidden in a scroll. It is pinned now, rounds+reset share one row, the
  circle reserve is 150, and the scroll shows a thumb. Normal phones look
  unchanged. Emulator downloads unblocked (TRAPS 61 addendum). 1441 tests.
  Next: the owner wants a much better TTS voice ("النموذج اللي بيقرا").
- 2026-10-19 23:40 — TTS evaluation (NOT committed: the shell tools died
  mid-run, every command exited 107/66). Harness `E:\DevEnv\tts_eval\eval.py`
  + `sweep.py`, models in that folder, wavs in `out/`. Same 5 diacritised
  Bukhari sentences, ASR = NVIDIA Arabic FastConformer, CER on the
  undiacritised text, RTF on this laptop (4 threads):
  supertonic-3 int8 (sherpa 1.13.8, MIT code + OpenRAIL-M weights, 44.1
  kHz, 10 voices; sid 5-9 MALE by measured F0 86-125 Hz, 0-4 female) CER
  2.2% @8 steps RTF 0.32; @5 steps: sid7 1.8%, sid8 1.9% (RTF 0.20).
  Current FastPitch+Vocos44 3.4% (RTF 0.03). Piper miro_V2 6.3%, dii 7.4%,
  miro 27%; Nabra-82M (Kokoro, Apache, female) 7.1%. Supertonic's indexer
  gives every haraka its own id (fatha 324 ... sukun 328), so it reads them.
  Next (exact): finish `py -3 sweep.py steps 7` (steps 3/5/8/12), measure
  RTF on a real ARM device or the emulator, make 3 samples (current, st
  sid7, st sid8) on one passage for the owner, then integrate via the
  sherpa_onnx package already in the app (OfflineTtsSupertonicModelConfig,
  GenerationConfig.extra = {'lang': 'ar'}), host the pack on R2 + mirror,
  credit + license on the Sources screen, label the audio as machine voice.

- 2026-10-19 21:45 — Full-screen mushaf: the page shrank to ~70% width when
  the controls came up («بتصغر بحجم صغير جدا»). Made both bars smaller: the
  floating panel's header is tighter and its action strip is held to 44 px
  (buttons at 80%), the tab bar is 52 px instead of 68 while it lies over
  the page, and the badge gap went from 10 to 4. On emulator-5554 (Medium
  Phone API 36.1) the page is now ~79% wide. Auto-hide checked: still 5 s,
  and now any touch on the panel restarts the count (before, it could hide
  under the finger). analyze clean, 1441 tests pass. Not released; not yet
  seen on the owner's phone. Emulator shut down again after the check.

- 2026-10-13 23:00 — Published v3.90.0 (tag 94c100ae, APK 313,766,102 B,
  SHA256 2f13dc71...96f7, GitHub digest equal, range 206) and deleted v3.88.1
  on the owner's order; releases now: v3.90.0, v3.87.0 (restore point), the
  3 content mirrors. 3.90.0 voices all 302 adhkar (R2
  azkar/rafeeq_voice/items/v1/, every file read back publicly, sha1 equal);
  dhikr 138 = As-Sajdah + Al-Mulk complete (Alafasy). Installed over 3.88.1
  on API 36; Listen button shown; in-emulator playback blocked by Avast TLS
  (trap 61), so playback of the new voices is NOT seen on a device - first
  phone check for the owner. Emulator stopped afterwards.

- 2026-10-13 22:25 — Codex fully stopped (app ChatGPT.exe of the Codex
  package and all codex/node children killed; ~/.codex/automations empty).
  Found finished jobs still scheduled: recitation mirror done 17:25 (35 ayah
  + 284 surah sets verified), azkar voices done (302/302; item 138 stopped on
  purpose - its Qur'an piece «تَنْزِيل ...» has no ayah match) yet
  RafeeqAzkarVoice re-ran daily for nothing. Disabled RafeeqMirrorWatchdog,
  RafeeqR7Page, RafeeqAzkarVoice, RafeeqLibraryPhase3, LaunchEmuTask; killed
  the dashboard; Startup rafeeq-r7-dashboard.vbs renamed .disabled.

- 2026-10-13 21:58 — A01 old credential rejection verified after the
  owner's rotation: one read-only request, 401 Unauthorized, TLS checked,
  no secret output/new-key read/writes/history edits. Audit now records all
  48 local findings resolved, with phone/ABI and API24 retry gates still
  explicit. Restore release 3.87 freshly checked; asset digest unchanged.

- 2026-10-13 21:48 — Worker and review page activation finished. Final
  validation: 08:38 +1440 ~4: All tests passed!; analyzer clean; backend 82 passed,
  TypeScript clean. Account namespace/D1/rollback were checked before
  deployment. Live unauthorized, duplicate, own-write and attribution
  controls passed; guarded QA cleanup verified. Template aligned with the
  actual Pages commit. No app release, R2 key, or religious text changed.

- 2026-10-13 21:38 — Live review workflow verified, with all owned QA data
  removed. Final backend/TypeScript and Flutter checks run for the aligned
  durable page template. Earlier console-encoding description corrected.

- 2026-10-13 21:23 — Worker and paired Pages published under existing
  approval. API smoke checks passed; browser name registration seen.
  Owned QA registration cleanup and final UI note proof remain. No APK,
  R2 keys, scripture, or user sync records changed.

- 2026-10-13 21:18 — Deployment preflight refreshed by Codex. Tests 82/82,
  tsc and dry run passed; actual account namespace and D1 checked read-only.
  Existing OAuth session refreshed through Windows trusted CAs. No live
  publication yet; no overlapping builds or tests, original untracked files
  untouched. Owner approval remains in force.

- 2026-10-13 18:55 — Published v3.88.1 (tag `3286a0a4`, APK 313,762,006 B,
  SHA256 `209199219fa0…`, GitHub digest equal, range download 206). Upgrade
  over the published 3.88.0 on API 36 kept the install; Arabic home and the
  support button seen. Owner then: keep 3.87, delete 3.51, clean up. Deleted
  releases+tags v3.88.0 and v3.51.0, and tags rollback-v3.87.0,
  backup-2026-09-20/21/21b/21c/21d, v3.81.0..v3.86.0. Remaining: v3.87.0,
  v3.88.1, the three content mirrors. RESTORE.md and CLAUDE.md §2.3 now name
  v3.87.0. Review rework committed (`ac979837` + page fix); deploy blocked by
  the classifier, see Next step 1. Mirror watchdog disabled during the
  release and re-enabled after.

- 2026-10-13 18:05 — Claude reviewed Codex's audit work. Verified live:
  v3.88.0 tag = `78811509`, asset 313,762,006 B, SHA256 `47fc2b2c…` as
  claimed; v3.87.0 and v3.51.0 and the three content mirrors kept; CI green;
  Worker NOT deployed (dry run only). `flutter analyze lib test` clean,
  `flutter test` 1440 passed / 4 skipped (Flutter 3.47.7).
  Found and fixed one real defect in Codex's A-11 change: after an adhan
  fires, the next day's alarm is recalculated by a headless Flutter engine;
  if that failed (8 s timeout, engine start) the prayer had NO alarm until
  the daily job, up to ~24 h later. Now a one-shot retry job runs within
  1-15 min with exponential backoff. New native suite `adhan-retry`:
  RED on the old code («No retry job after failure»), PASS after; existing
  `adhan` (18 cases), `preview`, `back` suites PASS on API 36. App launched
  and onboarding seen. Also: archived this 871 KB log; shut down both emulators (owner asked),
  which ended ~40 leftover adb logcat processes; killed a stale
  flutter_tester from the old 3.38.7 SDK.
