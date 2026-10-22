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
«كمل كل السور اوتو» - continue backwards without asking. 047 Muhammad 539 words written, check.py OK, seen in the app 47:35. 046 al-Ahqaf 643 words written, check.py OK, seen in the app 46:32. 045 al-Jathiya 488 words written, check.py OK, seen in the app 45:14. 044 al-Dukhan 346 words written, check.py OK, seen in the app 44:28. 043 al-Zukhruf 830 words written, check.py OK, seen in the app 43:84. 042 al-Shura 860 words written, check.py OK, seen in the app 42:37. 041 Fussilat 794 words written, check.py OK, seen in the app 41:50. 040 Ghafir 1219 words written, check.py OK, seen in the app 40:82. 039 al-Zumar 1172 words written, check.py OK, seen in the app 39:75; 39:64 has no al-Da'as text in our copy (written from al-Jadwal + Darwish, to check against the print). 038 Sad 733 words written, check.py OK, exported; seen on emulator 38:72 (i'rab tab, al-Da'as alt shown). 037 al-Saffat 861 words written (738 agree / 113 alt / 10 fuller), check.py OK, exported (79 surahs, 2,455 ayahs, 20,059 words); seen on emulator 37:162 ( 37:98 has no al-Da'as text, written fuller from al-Jadwal + Darwish, check vs print). 036 Ya-Sin 724 words written (626 agree / 91 alt / 7 fuller), check.py OK, exported (80 surahs, 2,538 ayahs, 20,783 words); seen in the app 36:62. 035 Fatir 775 words written (687 agree / 84 alt / 4 fuller), check.py OK, exported (81 surahs, 2,583 ayahs, 21,558 words); seen in the app 35:35. 034 Saba 883 words written (794 agree / 83 alt / 6 fuller), check.py OK, exported (82 surahs, 2,637 ayahs, 22,441 words); seen in the app 34:42. 033 al-Ahzab 1287 words written (1156 agree / 128 alt / 3 fuller), check.py OK, exported (83 surahs, 2,710 ayahs, 23,728 words); seen in the app 33:48. 032 al-Sajda 372 words written (325 agree / 47 alt), check.py OK, exported (84 surahs, 2,740 ayahs, 24,100 words); seen in the app 32:14. 031 Luqman 546 words written (491 agree / 51 alt / 4 fuller), check.py OK, exported (85 surahs, 2,774 ayahs, 24,646 words); seen in the app 31:21. 030 al-Rum 817 words written (723 agree / 94 alt), check.py OK, exported (86 surahs, 2,834 ayahs, 25,463 words); device check pending. 2026-10-22: SHORT CODES (irab_dsl.py, codes in scripts/own_irab/phrasebook_sheet.txt) - write entries as codes, write_surah expands them; see README. 029 al-Ankabut 976 words written in codes (882 agree / 86 alt / 8 fuller), check.py OK, exported (87 surahs, 2,903 ayahs, 26,439 words); device check deferred: owner 2026-10-22 «مش تبني التطبيق الا لما تخلص خالص كل السور» - build and check ONCE after the last surah (not yet seen: 030, 029). 028 al-Qasas 1430 words written in codes (1291 agree / 130 alt / 9 fuller), check.py OK, exported (88 surahs, 2,991 ayahs, 27,869 words); device check deferred to after the last surah (not yet seen: 030, 029, 028). 2026-10-22 fixes: irab_dsl.x literal entries now get «، » and a final stop (029 regenerated, 67 words, punctuation only); ayah_counts.py handles helper lists/splats; a scan of every surah found 10 words whose pronoun ha had the wrong vowel (e.g. «عنهُ» written «مبني على الكسر») in 030-059 - fixed in the JSON (and in 8 fill files). 027 al-Naml in progress in fill_027.py (codes), ayahs 1-45 done (574 of 1150 words). tafsir.app also serves al-Samin «الدر المصون» as src=aldur-almasoon (and Makki as src=makki) - used for the 27:9 doubt. Owner 2026-10-22: keep going but STOP at 95% of the weekly quota (leave some for other work). Next: 027 from ayah 46 (books_range.py 27 46 60, show.py 27 46 60), wip_check.py 27; check with wip_check.py 28. (Debug APK: build OFFLINE with an init script E:/DevEnv/gradle/init.d/rafeeq_offline_tmp.gradle = offline + force androidx.test:runner:1.2.0 and espresso-core:3.2.0 (written WITHOUT a BOM), delete it after; sign with scripts/sign_release.py --apk; adb install -r.) with show.py, books_range.py, fill_041.py, ayah_counts.py, check.py, export_app.py (helpers: books_range.py S A B prints both books for a chunk; ayah_counts.py S checks entries per ayah). v3.92.0 PUBLISHED 2026-10-21 14:44 Dubai on the owner's order (v3.91.2 deleted).

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

- 2026-10-22 06:00 Dubai — Own i'rab 029 al-Ankabut: 976 words, first surah fully in short codes, check.py OK, exported. Cost measured: ~110 words per 1% of the 5-hour window; weekly 81%.
- 2026-10-22 05:30 Dubai — i'rab short codes: irab_dsl.py + frozen phrasebook.json (229 clauses mined from 030-114, 81% of clauses); round-trip of 16,342 old words byte-identical (22a165b6). 029 ayahs 1-13 written in codes (cd9ae7d9). Weekly quota 80%.
- 2026-10-21 19:20 Dubai — Device check: i'rab tab seen full-screen on emulator for 36:62, 35:35, 34:42, 33:48, 32:14, 31:21 (debug APK built offline, signed, installed -r over 3.92.0). Tried an auto-draft script for the i'rab: on 30:10-15 it drafted 7 of 49 words and one of them wrong (لهم as «خبر مرفوع»), so it was dropped; method unchanged.

- 2026-10-21 05:54 — Own i'rab 038 Sad: 733 words (621 agree, 100 alt, 12 fuller),
  per-ayah counts match, check.py OK, exported (78 surahs, 2,273 ayahs,
  19,198 words). Not yet device-checked.

- 2026-10-21 05:42 — Device check: 39:75 i'rab tab seen full-screen on emulator
  (page 467). Sad 1-11 written (WIP).

- 2026-10-21 05:39 — Own i'rab 039 al-Zumar: 1,172 words (1,006 agree, 140 alt,
  26 fuller), per-ayah counts match, check.py OK, exported (77 surahs,
  2,185 ayahs, 18,465 words). 39:64: al-Da'as section «60-64» ends at 63 in
  our copy - 64 written from al-Jadwal + Darwish, still to check against the
  printed al-Da'as. Not yet device-checked.

- 2026-10-21 05:26 — Device check: 40:82 i'rab tab seen full-screen on emulator
  (page 476), al-Da'as alternative shown; debug APK signed with
  sign_release.py --apk, installed -r over 3.91.2. Al-Zumar 1-15 written (WIP).

- 2026-10-21 05:17 — Own i'rab 040 Ghafir: 1,219 words (1,028 agree, 168 alt,
  23 fuller), per-ayah counts match, check.py OK, exported (76 surahs,
  2,110 ayahs, 17,293 words). Not yet device-checked.

- 2026-10-21 05:05 — RELEASED v3.91.2 (owner: «لينك النشر بآخر الإصلاحات»):
  https://github.com/tito423/Rafeeq-Al-Darb/releases/tag/v3.91.2 , tag = master
  fb30fd76, asset digest = local sha256, range 206; v3.91.1 deleted. Ghafir 1-40
  written (WIP). Owner: never stop; check quota, wait for reset, resume.

- 2026-10-20 22:45 — Device check: 41:50 i'rab tab seen full-screen on
  emulator (page 482), al-Da'as and al-Jadwal alternatives shown. The
  background build's `adb install` hung ~3 h with no output; stopped it
  and installed the same APK (own_irab.json 3,184,524 B inside) directly.
  Ghafir 1-20 written (WIP).

- 2026-10-20 19:50 — Own i'rab 041 Fussilat: 794 words (673 agree, 110 alt,
  11 fuller), per-ayah counts match, check.py OK, exported (75 surahs,
  2,025 ayahs, 16,074 words). Not yet device-checked.

- 2026-10-20 19:09 — Device check: 42:37 i'rab tab seen full-screen on
  emulator (page 487). 041 Fussilat ayahs 1-8 written (WIP, counts match).

- 2026-10-20 19:05 — Own i'rab 042 al-Shura: 860 words (749 agree, 99 alt,
  12 fuller), per-ayah token counts match, check.py OK, exported (74
  surahs, 1,971 ayahs, 15,280 words). Not yet device-checked.

- 2026-10-20 18:54 — Device check: 43:84 i'rab tab seen full-screen on
  Rafeeq_Audit_API24; al-Da'as's view under «في السماء» renders.
  WIP fill_042.py al-Shura 1-43 (659/860).

- 2026-10-20 18:50 — Own i'rab 043 al-Zukhruf: 830 words (698 agree, 120 alt,
  12 fuller), per-ayah token counts match, check.py OK, exported (73
  surahs, 1,918 ayahs, 14,420 words). Not yet device-checked.

- 2026-10-20 18:38 — Device check: 45:14 and 44:28 i'rab tabs seen full-screen
  on Rafeeq_Audit_API24 (x64 debug build); al-Da'as's view under «للذين»
  and «كذلك» renders.

- 2026-10-20 18:33 — Own i'rab 044 al-Dukhan: 346 words (302 agree, 39 alt,
  5 fuller), per-ayah token counts match, check.py OK, exported (72
  surahs, 1,829 ayahs, 13,590 words). 45 and 44 not yet device-checked.

- 2026-10-20 18:27 — Own i'rab 045 al-Jathiya: 488 words (419 agree, 58 alt,
  11 fuller), per-ayah token counts match, check.py OK, exported (71
  surahs, 1,770 ayahs, 13,244 words). Not yet device-checked.

- 2026-10-20 18:20 — Device check: 46:32 i'rab tab seen full-screen on
  Rafeeq_Audit_API24 (x64 debug build 17:17 emulator time); al-Da'as's view
  under «ومن» renders. WIP fill_045.py: al-Jathiya 1-20 (240/488 tokens), 21-37 not yet.

- 2026-10-20 18:15 — Own i'rab 046 al-Ahqaf: 643 words (557 agree, 74 alt,
  12 fuller), check.py OK, exported (70 surahs, 1,733 ayahs, 12,756 words).
  Not yet device-checked.

- 2026-10-20 18:05 — RELEASED v3.91.1: https://github.com/tito423/Rafeeq-Al-Darb/releases/tag/v3.91.1 ,
  tag f3159aba = master, APK 313,692,374 B, sha256 14d67fbe...d907a3 equal to
  GitHub's digest, range 206, versionCode 107; installed over 3.91.0 on API-24
  and launched. v3.91.0 + tag deleted. fill_046.py: 1-20 written (366/643), 21-35 not yet.

- 2026-10-20 17:50 — Owner: «انشرلي التطبيق الاول وكمل الاعراب». 3.91.1+107
  bumped (5ce8a3ef), analyze clean, 1448 tests pass; signed build running.
  WIP fill_046.py: al-Ahqaf 1-8 written (117 of 643 tokens aligned), 9-35 not yet.

- 2026-10-20 21:55 — Device check: 47:35 i'rab tab seen full-screen on
  Rafeeq_Audit_API24 (fresh debug build); Darwish's view under «أعمالكم»
  renders. Stopped here: 5-hour quota at 90% (get_usage: resets 11:40 UTC =
  15:40 Dubai); next is 046 al-Ahqaf.
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
- 2026-10-21 05:59 Dubai: device check Sad (38): signed x64 debug over 3.91.2, page 457, 38:72 i'rab full-screen shows entries + al-Da'as alt. OK.
- 2026-10-21 06:17 Dubai: own i'rab al-Saffat (37) complete, 861 words (738/113/10), check OK, exported 20,059 words. Notes: 37:98 no al-Da'as text (fuller); 37:130 al-Jadwal singular view.
- 2026-10-21 06:25 Dubai: device check al-Saffat 37:162 i'rab OK. FOUND BUG (not fixed here): tafsir ranges in quran_sciences.db mis-assigned - build_sciences_db.py treats a group's verse_key as LAST ayah but api.quran.com keys it by FIRST (live check 37:162 -> verses 161-163). Wrong/missing passage: muyassar 897 ayahs, tantawi 119, sadi 56, tabari 40, ibn_kathir 31, qurtubi 1. Proposed as its own session (task_8c729d31) - needs rebuild + R2 upload + sciencesDbVersion bump.
- 2026-10-21 12:45 Dubai: TAFSIR RANGE FIX (owner: «Do this task here»). quran_sciences.db tafseer_texts rewritten (scripts/fix_tafsir_ranges.py, rule in scripts/tafsir_ranges.py; backup build/quran_sciences.v2.backup.db sha1 704e34ff). Zip build/quran_sciences.zip 32,168,511 B ready. UPLOADED 13:10 via VPN (see log). Was: R2 S3 endpoint did not answer TLS from this laptop (any *.r2.cloudflarestorage.com, curl 35; public r2.dev OK). Background retry every 5 min x30 uploads to sciences/v3/. NEXT EXACT: when uploaded -> AppConfig sciencesDbUrl v3 + sciencesDbBytes (head_object) + sciencesDbVersion 'v3'; mirror asset sciences__v3__quran_sciences.zip to content-mirror (gh release upload, verify size+206); flutter analyze/test; signed x64 debug build; on emulator download the pack, see 37:162 Muyassar = 161-163 passage, a tail (53:62) and Ibn Kathir 53:15. Then i'rab surah 035 (Fatir).
- 2026-10-21 12:49 Dubai: fixed DB pushed into the emulator's downloaded copy: 37:162 al-Muyassar now shows the 161-163 passage (seen). Ya-Sin 30-40 written.
- 2026-10-21 12:56 Dubai: own i'rab Ya-Sin (36) complete, 724 words (626/91/7), check OK, exported 20,783 words.
- 2026-10-21 14:32 Dubai: TAFSIR FIX DONE + DEVICE-VERIFIED. Avast SecureLine VPN connected (owner's order, laptop in Saudi Arabia: R2 S3 endpoint blocked there) -> sciences/v3/quran_sciences.zip uploaded (32,168,511 B, PK, no CE, public 206) + content-mirror asset sciences__v3__quran_sciences.zip (byte-identical, 206). AppConfig v3 (url/bytes/version), analyze clean, flutter test 1448 pass. Emulator: after the VPN came up it lost DNS -> relaunched with -dns-server 1.1.1.1,8.8.8.8; app offered the 32.2 MB pack, downloaded it from R2 (stamp v3), 37:162 shows al-Muyassar 161-163 passage; every table in the device DB identical to the local one (only android_metadata added). NOT RELEASED: 3.91.2 users keep the v2 pack until the next release (ask the owner).
- 2026-10-21 14:44 Dubai: RELEASED v3.92.0 (owner: «انشر الجديد»): tag 37d9223c = HEAD, APK 313,880,790 B sha256 f4d526d3... = GitHub digest, 206; v3.91.2 deleted. Emulator was relaunched with -dns-server 1.1.1.1,8.8.8.8 (VPN on). Next: Fatir (35) from ayah 13.
- 2026-10-21 15:52 Dubai: own i'rab Fatir (35) complete, 775 words (687/84/4), check OK, exported 21,558 words. Device check pending (not in 3.92.0).
