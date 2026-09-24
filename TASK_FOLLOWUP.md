# TASK_FOLLOWUP — the live step log (read right after CLAUDE.md)

Updated after EVERY step, committed and pushed, so a session that dies mid-task
(quota, a dropped remote connection) loses nothing: the next session — this
account, the other one, or another agent — reads this and continues from
**Next step**. Newest entries at the top of the log. Log times are the PC clock (shows AST, UTC+3 — one hour behind Dubai).

## Current task
None in progress. The next task is **PLAN.md Stage 1 — «التحميلات المبدئية»**
(owner's order 2026-09-24).

## Next step (exact)
1. Read CLAUDE.md, then PLAN.md Stage 1.
2. First, see on emulator-5554 what was committed but never seen: the adhkar
   and new-Muslim background photos (audit C1, commit ff2fab92). Build with
   `build_github_release.bat` BEFORE starting the emulator (trap #24).
3. Then start Stage 1 at item 1 (title + blurb), writing each step here.

## Half-done / unverified (redo, do not trust)
- C1 backgrounds: committed, not seen on a device.
- D1 sign-out scope: committed, not device-tested (needs a Google sign-in).
- B1 /sync caps: deployed (Worker 48b3fa3a), caps not exercised live (needs a
  real Google ID token).

## Log
- 2026-09-24 14:09 - checkpoint.ps1 regex rebuilt with chr(92) (trap 11); log line verified
- 2026-09-24 ~15:30 — Working rules settled (d56ee71f); TRAPS.md split out;
  AGENTS.md made a pointer to CLAUDE.md; this file created. v3.60.0 is the
  latest release; master has D1/B1/B5/C1 unreleased.
