# TASK_FOLLOWUP — the live step log (read right after CLAUDE.md)

Keep this file SHORT (target under 80 lines, ~5k tokens): every session loads
it whole. Newest log line on top; when the log passes ~15 lines, move the
oldest into `docs/history/`. Full history up to 2026-11-12 13:40 Dubai:
`docs/history/TASK_FOLLOWUP_archive_2026-10-13_to_2026-11-12.md` (and the
older `TASK_FOLLOWUP_archive_to_2026-10-13.md`). Times are Dubai (UTC+4).

## Current task — own i'rab, group B review (scripts/own_irab)

Group B = words where our i'rab follows al-Da'as and the wider jury
(al-Nahhas, Makki, al-Mujtaba, al-Bahr, al-Samin; `review2.py`) differs.
Done so far: parts 1-3 applied (16 + 25 + 92 fixes, tables in
`write_surah.py` GROUPB / `groupb3_fixes.json`), 8 al-Da'as alts made
verbatim (b70035d4), 36:13 «أصحاب» badal reverted (00229577).
Rule: two books against ours = change; ALT counts as one book; one book alone = KEEP.
Opus reads every proposed change before it is applied.

## Next step (exact)

1. DONE 2026-11-12: NEIGHBOURS_FINDINGS.md decided, 24 fixes in
   `groupb5_fixes.json` applied, check OK, audit_vowels 3 flags (old ones:
   2:245, 18:40, 20:93 - none touched), exported. Open from it: 36:51
   «في الصور» na'ib fa'il (al-Jadwal + al-Mujtaba vs ours).
2. DONE 2026-11-12: b052-b063 classified (Haiku): 339 words = 227 OURS_OK,
   86 UNCLEAR, 9 OURS_WRONG, 17 NO_SOURCE; ids match packets.
3. DONE 2026-11-12: mkjudge_b 48 63 22 30 -> j22-j27 (137 flags + 30 audit);
   Sonnet judged all 167: 78 CHANGE (75 flags + 3 audit), 89 KEEP. Rate is
   high (j22-j26 ~50%): Sonnet j25 itself named weak ones (58:10 rests on one
   book + memory; 52:42, 60:5 fasl-pronoun debatable). Read each strictly.
4. DONE 2026-11-12: Opus read all 78 CHANGE (packets + al-Jadwal/Darwish
   from books_cache): 63 accepted -> `groupb6_fixes.json` (87 edits incl.
   neighbour tails), 15 rejected -> `GROUPB6_REJECTED.md`. Applied, check
   OK, audit_vowels 3 old flags, exported. Open from it: «إنك أنت»/«إنا نحن»
   family (60:5 now tawkid, others fasl); 64:13 «فليتوكل» fa.
5. DONE 2026-11-12 ~19:10: signed build of 8d30812d (truststore, trap 61;
   log dist/build_irab_groupb6.log), installed on Rafeeq_Audit_API24, SEEN:
   36:13 «أصحاب» مفعول به أول, no badal (al-Jadwal's badal shown as the other
   book). Part 6 SEEN too: 39:24 «وقيل» الواو حالية + والجملة في محل نصب
   حال, with al-Da'as's old line (حرف عطف) and al-Jadwal (واو الحال) under
   it. Note: the reader's «Jump to» ignores adb taps; swipe pages instead
   (finger left-to-right = next page).
6. DONE 2026-11-12: last items closed (group B part 7, groupb7_fixes.json,
   14 edits; GROUPB7_REJECTED.md): 36:51, «حتى إذا» family, «إنك أنت»
   family, 14:29, 3:143, 64:13. check OK, audit 3 old flags, exported.
   Built + installed on API-24, SEEN: 36:51 «ونفخ» نائب الفاعل الجار
   والمجرور «في الصور» with al-Jadwal and al-Da'as lines. The i'rab review has no open item left except the
   human grammarian sample (SPECIALIST_SAMPLE.csv) and the owner's release.

Cost of 2-4 ≈ 5 weekly points. Stop at 85% of the 5-hour window; at ~150k
context checkpoint and tell the owner (he may order a new session).

## NEW TASK (owner 2026-11-12 ~20:50): prayer card must run forever, no app opening

Owner: the status card was sometimes blank (Honor screenshot 19:00: only
«فتح التطبيق» + «منذ الأذان»). Cause: the schedule held yesterday..tomorrow
and only the open app refreshes it. Owner then: «لازم التطبيق يشتغل اوتو
لاخر العمر … ديناميكية … ولا تحتاج ابدا ان التطبيق يتفتح» - follow the
country he is in, no user action.
DONE (uncommitted->committed, NOT built/seen/released, pubspec 4.3.0+120):
- `PrayerTimesService.timesOnDay` + stored `prayer_calc_inputs_v1`; the
  card gets 30 real calculated days (`daysAhead`), test added (10/10 pass).
- `PrayerCard.kt`: when nothing is ahead -> fallback text
  `notif.prayer_open_to_update` (7 languages), no stale «منذ الأذان».
DONE 2026-11-12 ~21:15 (steps 1-2, signed build dist/build_cardjob.log,
   installed on API-24, SEEN): Dart sends `refresh` args (inputs, locale,
   city, hijri offset, HJCoSA cache) with every `show`; `cardSchedule` in
   `adhan_recompute_entry.dart` rebuilds the month headless;
   `PrayerCardJob` (own job, daily + `runSoon` when <3 days left) calls
   `PrayerCard.refreshInBackground`. Seen: app closed, clock (adb root +
   `date`) jumped to 2026-12-17 10:00 -> job ran by itself at 10:00:05,
   schedule now 17 Dec..17 Jan (187 events), card «Thursday · 8 Rajab 1448».
   Full flutter test 1472 pass, analyze clean.
DONE 2026-11-12 ~23:00 (step 3): «الموقع طوال الوقت» row on the first-run
   permissions page (+ asked once at startup for older installs), 7 languages;
   ACCESS_BACKGROUND_LOCATION; `LocationFollow` in the card job (last fix, one
   network fix if >6 h old; >10 km moves card inputs + adhan calculation_v1,
   re-arms adhan; manual place never moved). SEEN API-24: GPS Dubai->Cairo,
   app closed, forced job: «moved 2427187 m», card + adhan at 30.04/31.24.
   Not seen: the Android 10+ «Allow all the time» screen (no stable API-36).
   Owner ordered release 4.3.0 (2026-11-12 ~22:30).

## Standing owner orders (still open)

- NO release without the owner's word. Last published: v4.2.0 (04:42
  2026-11-12, tag 0c42dac3). Everything in group B since is NOT released;
  pubspec still 4.2.0+119 — bump before any release.
- After the i'rab: review the Windows edition (`E:\My Projects\Rafiq-Al-Darb-Windows`,
  branch `windows-desktop`) and fix its GPU load (100% GPU 3D with no window,
  measured 2026-11-11).
- `scripts/own_irab/SPECIALIST_SAMPLE.csv`: 300 words for a human grammarian;
  the app may not call the i'rab «معتمد» before that result.
- Hourly autorun `own-irab-autorun` stays DISABLED; one manual session only.

## Half-done / unverified (carried from the archive)

- Khatma (d5ef5d8a): rub' mark tap on the PRINTED page unverified (emulator
  cannot download page images, trap 61); share with translation/tafsir,
  other colours, non-Arabic UI, landscape unseen; reminder notification
  firing unseen; rub' plate missing on printed-page mode; ask the owner about
  keeping the tap bubble.
- Rafeeq voice assistant background fix: never seen on a device; owner's
  Honor retest pending.
- Book reader Google voice (v3.99.0): not seen on a device.
- Adhan retry fix: verified on API 36 only, not API 24 or a real phone.
- Per-ABI APKs: ARM phone checks pending; universal APK stays primary.
- Prayer «إشعار منبثق فقط» heads-up not seen on Android 8+.
- Emulator Rafeeq_Audit_API24 last left in ENGLISH UI.

## Log (newest first)

- 2026-11-12 ~20:10 group B part 7 built and seen (36:51); i'rab review closed, not released.

- 2026-11-12 ~19:25 part 6 seen on API-24 (39:24 waw hal + alts).
- 2026-11-12 ~19:10 signed build installed on API-24, 36:13 seen OK; not released.
- 2026-11-12 ~17:30 group B part 6: 63 of 78 judge CHANGE applied (groupb6_fixes.json), 15 rejected; not released.

- 2026-11-12 ~16:40 j22-j27 judged (Sonnet): 78 CHANGE / 89 KEEP, nothing applied.
- 2026-11-12 ~16:20 b052-b063 classified (Haiku, 12 batches): 227 OK / 86 UNCLEAR / 9 WRONG / 17 NO_SOURCE.
- 2026-11-12 ~15:00 group B part 5: 24 neighbour fixes (NEIGHBOURS_FINDINGS), table B kept (al-Mujtaba = second book).
- 2026-11-12 ~13:40 TASK_FOLLOWUP trimmed (601 lines/36k tokens -> this); full file archived unchanged.
- 2026-11-12 ~13:30 5b3b6962 neighbour coherence: 94 read, findings file, nothing applied.
- 2026-11-12 00229577 revert 36:13 أصحاب badal (seen on device).
- 2026-11-12 b8180af0 group B state at 5-hour stop, b048-b051 classified.
- 2026-11-12 b70035d4 8 al-Da'as alts made verbatim.
- 2026-11-12 3e112254 group B part 3: 92 fixes applied after Opus read 94.
