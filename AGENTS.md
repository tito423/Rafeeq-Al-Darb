# AGENTS.md — Codex and any other agent start here

**This file is mandatory.** Codex loads it automatically.

The working method for this project lives in ONE file: **`CLAUDE.md`**. It
used to be copied here in full; the copy fell behind (last synced
2026-09-20, missing §1.7, §1.8, TRAPS.md and more), so it is a pointer now.
Whatever agent you are, the rules are the same.

## Before anything else, read in this order
1. **`CLAUDE.md`** — the whole file. Binding. Reply to the owner in Arabic.
2. **`TASK_FOLLOWUP.md`** — the task in progress, step by step: what is
   done (with commits), what is half-done, and the **exact next step**.
   Continue from there. Do not restart the task and do not trust a step
   marked unverified.
3. `TRAPS.md` — the entry for any area you are about to touch.
4. `HANDOVER.md` (state table + WIP), `PLAN.md` (stages), `docs/AUDIT_*.md`.

## While you work
Update `TASK_FOLLOWUP.md` after EVERY step and commit + push it (`.\cp.bat
"what you did"` does the commit). The session can end at any moment — the
owner's quota runs out while he is at work and he moves to another session
or another agent that must continue from the exact point you reached.
