# Hourly auto-continue prompt for the own i'rab (scheduled task)

Paste this whole text as the prompt of a scheduled task in the Claude desktop
app (Code tab -> Scheduled -> New task), schedule "every hour", working folder
`E:\My Projects\Rafiq-Al-Darb`. Each run is a NEW session, so its context
starts cheap; a run already in progress blocks the next one, and a lock file
guards that as well.

---

You are an automatic hourly run that continues the "own i'rab" of the Qur'an in the repo E:\My Projects\Rafiq-Al-Darb (owner's Flutter app Rafeeq Al-Darb, branch master). The owner is at work and set this up so that every run starts with a FRESH, cheap context. Nobody is watching; do not ask questions, do not wait for answers.

STEP 0 - guards (in this order; end the run quietly if any says stop):
1. Lock: the file %LOCALAPPDATA%\rafeeq_autorun.lock. If it exists and is less than 70 minutes old, another run is working: end now. Otherwise write the current time into it. Delete it as the very last action of the run.
2. Quota: call mcp__ccd_session_mgmt__get_usage (load with ToolSearch "select:mcp__ccd_session_mgmt__get_usage" if deferred). If weekly >= 95% or 5-hour >= 90%, delete the lock and end (the next hourly run retries after the reset). Owner's rule: stop at 95% of the weekly quota.
3. Tree: `git status --short`. Untracked scratch files are normal. If a tracked file under scripts/own_irab/ or TASK_FOLLOWUP.md is modified (a previous run died mid-block): run `py -3 scripts/own_irab/fill_NNN.py` (PYTHONIOENCODING=utf-8); if it loads and reports WIP, commit it as a checkpoint; if it fails to import, `git checkout -- <file>`.

STEP 0b - OWNER BACKLOG FIRST (owner, 2026-11-02: «ضيف وابدا بيهم»). Read the section "Owner backlog (2026-11-02 01:01 Dubai)" in TASK_FOLLOWUP.md. While any item there is still "- [ ]", this run works ONE such item (the first open one) instead of the i'rab, under these rules (they replace the i'rab-only limits of STEP 2 for this item):
- Read CLAUDE.md first; investigate the real thing (code, data, the live page or endpoint) before changing code (CLAUDE.md 1.3/1.4). For the Dorar search item, look at docs/owner_reports/2026-11-02_dorar_search_cannot_read.jpg and fetch the real result page.
- Edit what the fix needs (rafeeq_app/lib, assets/translations, tests). Every user-visible string in all 7 locales (ar, en, fr, es, pt, ru, ur). `flutter analyze lib test` and `flutter test` must pass (select the SDK with `. .\scriptslutter_env.ps1`, CLAUDE.md 1.8).
- Verify on the emulator per CLAUDE.md 1.3 with a DEBUG build (never a release build, never publish, never `build_github_release.bat`): install, open the screen, take a screenshot and look at it. If the emulator cannot be brought up, say so in the item's line and leave it "- [ ] (code done, device check pending)".
- Commit + push after each meaningful step; when the item is verified, change its "- [ ]" to "- [x]" with the commit and what was seen, and add a "## Log" line.
- Stop rules of STEP 3 apply (context 45%, 5-hour 90%, weekly 95%). The next run takes the next open item. When all five are "- [x]", runs go back to the i'rab below.

STEP 1 - read in full: CLAUDE.md (mandatory), TASK_FOLLOWUP.md "Current task" (the own i'rab sentence near its end names the WIP surah and the exact next command, e.g. `py -3 scripts/own_irab/sheet.py 16 1 4`), scripts/own_irab/README.md, scripts/own_irab/phrasebook_sheet.txt (all codes), and the header plus last ~60 entries of the WIP fill file and of the previous finished one (e.g. fill_017.py) to copy the style exactly.

STEP 2 - the method (unchanged):
- Work backwards surah by surah, chunks of 3-6 ayahs. Read the sheet WITHOUT its al-Da'as lines plus the al-Da'as lines from --full (the default cut drops al-Da'as text when a section spans several ayahs): `py -3 scripts/own_irab/sheet.py S A B | grep -v "^   DAAS"` and `py -3 scripts/own_irab/sheet.py S A B --full | grep "^   DAAS"` (PYTHONIOENCODING=utf-8; redirect to a scratch file and Read it).
- Every word in short codes from phrasebook_sheet.txt (irab_dsl.py); literal Arabic clauses mix in; `W:x code` gives «و«x»» + clause. Codes must exist. `Ais:X`/`is:X` are mansub (inna-type only); for kana-type names write «اسم «كان» مرفوع ...» literally. `IDHA` is a Python constant usable as IDHA + ',...'.
- Every word against al-Da'as; doubts read in al-Jadwal (J) and Darwish (D). Two books against al-Da'as -> ours follows them, al-Da'as as alt. One book against -> ours = al-Da'as, that book as alt. Obvious al-Da'as slips -> ours correct, al-Da'as as alt. alt books: daas, jadwal, darwish only; alt text is the book's own words copied from the sheet. Syntax: alt('codes', ('daas', 'text')).
- Where our al-Da'as copy truly has no text for a word (confirm with --full): write it from al-Jadwal + Darwish as ('codes', 'fuller') and add it to the "check vs print" list in TASK_FOLLOWUP.
- Never change the mushaf word; never rewrite Qur'an text.
- Block file in the scratchpad, then `py -3 scripts/own_irab/append.py S <block>`; its "last" token must be the last word of the chunk, else fix the block. Review the printed hand-typed entries.
- After EVERY block: update the WIP sentence in TASK_FOLLOWUP.md ("NNN <name> WIP in scripts/own_irab/fill_NNN.py: ayahs 1-X written (N of T tokens). Next: py -3 scripts/own_irab/sheet.py S A B"), add a "## Log" line with the previous commit, `git add` the fill file and TASK_FOLLOWUP.md, commit "WIP own i'rab: surah S up to ayah X" ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`, `git push -q origin master`.
- End of a surah: validate every entry with irab_dsl.x; `py -3 fill_NNN.py`; `check.py S`; `ayah_counts.py S` (no mismatch); `export_app.py`; commit fill_NNN.py, NNN.json, rafeeq_app/assets/data/own_irab.json, TASK_FOLLOWUP.md (done sentence with agree/alt/fuller counts and export totals, then a WIP sentence for the next surah); create the next fill file from the finished one's header/footer; push.
- Do NOT build the app or touch the emulator (owner: one build after the last surah). Edit nothing outside scripts/own_irab/, TASK_FOLLOWUP.md, rafeeq_app/assets/data/own_irab.json.

STEP 3 - size of one run: block after block; after each committed block check get_usage. Stop at a committed block when this session's context >= 45%, weekly >= 95%, 5-hour >= 90%, or all surahs through 002 are done. Delete the lock and end with a two-line Arabic summary (what was written, last commit, quota numbers).

When 002 is done: start nothing else; write in TASK_FOLLOWUP.md that the own i'rab is complete and the single build + emulator check waits for the owner's OK; commit, push, delete the lock, end.
