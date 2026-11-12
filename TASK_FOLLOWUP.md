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
2. Classify b052-b063 with Haiku (8 at a time, REVIEW_PROMPT.md).
3. `py -3 mkjudge_b.py 48 63 22 30`, Sonnet judges (two-book rule).
4. Opus reads the CHANGE list (`pending_digest.py`, `quote_check.py`,
   `pending_plan.py`), groupb table, apply, check, audit_vowels, export.
5. Build (signed, `build_github_release.bat`) + look on Rafeeq_Audit_API24:
   36:13 must show the al-Da'as line «أَصْحابَ» مفعول به أول and no badal.
6. Still unchecked: the «حتى إذا» family outside the flagged ayahs; 14:29, 3:143.

Cost of 2-4 ≈ 5 weekly points. Stop at 85% of the 5-hour window; at ~150k
context checkpoint and tell the owner (he may order a new session).

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

- 2026-11-12 ~15:00 group B part 5: 24 neighbour fixes (NEIGHBOURS_FINDINGS), table B kept (al-Mujtaba = second book).
- 2026-11-12 ~13:40 TASK_FOLLOWUP trimmed (601 lines/36k tokens -> this); full file archived unchanged.
- 2026-11-12 ~13:30 5b3b6962 neighbour coherence: 94 read, findings file, nothing applied.
- 2026-11-12 00229577 revert 36:13 أصحاب badal (seen on device).
- 2026-11-12 b8180af0 group B state at 5-hour stop, b048-b051 classified.
- 2026-11-12 b70035d4 8 al-Da'as alts made verbatim.
- 2026-11-12 3e112254 group B part 3: 92 fixes applied after Opus read 94.
