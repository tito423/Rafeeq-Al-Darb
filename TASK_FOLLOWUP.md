# TASK_FOLLOWUP — the live step log (read right after CLAUDE.md)

Updated after EVERY step, committed and pushed. Newest log entry on top.
Times are Dubai (UTC+4). Keep this file SHORT and in plain sentences with
spaces: the next session has to read it whole. Long history goes to
`docs/history/` — the log up to 2026-10-13 17:25 (871 KB, written by Codex
in compressed run-together words) is archived unchanged in
`docs/history/TASK_FOLLOWUP_archive_to_2026-10-13.md`.

## Current task

The full audit (owner brief 2026-10-09, report `docs/audits/AUDIT_2026-10-09.md`)
was carried out by Codex from 2026-10-09 to 2026-10-13 and then stopped by the
owner. Claude reviewed it on 2026-10-13 (see log). 47 of 48 findings are fixed
in code; v3.88.0 is published. What is left needs the OWNER, not code.

## Next step (exact)

Nothing to code until the owner answers these. Ask him, do not guess:

1. **A-01 (Critical) — rotate the R2 keys.** Two R2 credential values sit in
   the PUBLIC git history (commit `3747f715`, `scripts/upload_quranflash_coords.dart`
   lines 7-8, since deleted from the tree). Deleting the file did not remove
   them. Only the owner can rotate them in the Cloudflare dashboard (R2 →
   Manage API tokens → create a new token, then delete the old one), then put
   the new pair in `scripts/.env` on the laptop. Never paste the keys in chat.
2. **Worker + review site (A-03).** The new Worker code requires a verified
   Google sign-in AND a grant in the `REVIEWERS` secret for every reviewer.
   The secret is EMPTY on the live account (Codex checked read-only). Deploying
   now would lock every reviewer out. Needed from the owner: each reviewer's
   Google e-mail (or sub), the name to show, and role (reviewer/admin). Then:
   set the secret, deploy the Worker, publish the paired review-client
   (local-only commit `8dee5e0` in the sibling rafeeq-review Pages repo on the
   laptop), and check the Google OAuth client allows the origin
   `https://tito423.github.io`. Codex wrote that the owner authorized the
   deployment; that approval was in Codex's chat and is not visible here —
   confirm with the owner before deploying. Dry run log:
   `.local-audit/phase2/worker-deploy-dryrun.log`; current live version for
   rollback: `.local-audit/phase2/worker-predeploy-version.json`.
3. **Phone-only checks** Codex could not do on an emulator: adhan on the lock
   screen of a real phone with a PIN after a reboot (A-12), ARM build on a real
   phone, real microphone for tasmee, Google sign-in sync between two devices.

## Half-done / unverified

- The emulator `emulator-5554` now has a DEBUG build (uninstalled the signed
  3.88 to run the native suites). Reinstall the signed release before any
  release-upgrade check.
- The adhan retry fix (log 2026-10-13 18:05) is verified on API 36 only, not
  on the API 24 emulator (`Rafeeq_Audit_API24`, port 5556) and not on a phone.
- Codex's `.local-audit/` (1,828 files, gitignored) holds its raw evidence.

## Log

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
