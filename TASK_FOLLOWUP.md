# TASK_FOLLOWUP — the live step log (read right after CLAUDE.md)

Updated after EVERY step, committed and pushed. Newest log entry on top.
Times are Dubai (UTC+4). Keep this file SHORT and in plain sentences with
spaces: the next session has to read it whole. Long history goes to
`docs/history/` — the log up to 2026-10-13 17:25 (871 KB, written by Codex
in compressed run-together words) is archived unchanged in
`docs/history/TASK_FOLLOWUP_archive_to_2026-10-13.md`.

## Current task

Codex's full audit (2026-10-09..13, report `docs/audits/AUDIT_2026-10-09.md`)
was reviewed by Claude on 2026-10-13. v3.88.1 is published with the adhan
re-arm fix. The review site was reworked to the owner's model: NO reviewer
list, no Google sign-in — he sends the link, a reviewer writes his name.

## Next step (exact)

1. Finish final validation and commit the aligned review template.
   Worker fb98ec8c-2c2f-4961-9db7-66d588d7030d and Pages/cff08c1 are live.
   The live API passed 15 checks. Browser registration, note input, saved
   status, and the reviewers list (one technical note, zero reviewed ticks)
   were observed; the exact note was also read from the server. Both owned
   QA registrations and the technical note are now removed, verified by
   remote D1 count=0 and the public review list. Only those exact names,
   note ID/text, hashes, and creation times were used for cleanup.
   Browser screenshot capture failed in hidden and visible tabs; no image
   proof is claimed. Test tabs closed and visibility restored. Emulators
   remain off at the owner's request.
   Main review-client/index.html now matches the deployed sibling page.
   Correction: the earlier claim of a garbled error was caused by Python
   console encoding; the actual difference was a valid Arabic legacy-name
   warning absent from the already tested/published sibling page. Religious
   text and all other page content are unchanged.
   Backend final session 13833 and Flutter analyze/test session 41397 must
   finish green before saving this one owned template change and final docs.
   No additional Worker/APK deployment is needed for this artifact alignment.
2. **A-01 (Critical) — rotate the R2 keys.** Two R2 credential values are in
   the PUBLIC git history (commit `3747f715`). Only the owner can rotate them
   in the Cloudflare dashboard, then update `scripts/.env` on the laptop.
3. **Remote branches** not deleted (classifier blocked): ccr-2f2431dd-qhco4b,
   ccr-5abc3286-e7dj17, claude/intelligent-franklin-lu4lnd,
   claude/tajweed-simplify-49x14b, claude/zen-sagan-fvcgye,
   kids-stories-pipeline, known-good/v3.48.0 .. v3.53.0, master-353kkv,
   release-v1.2.0. All except release-v1.2.0 are fully contained in master;
   release-v1.2.0 and v3.51.0 are bundled in
   `E:\My Projects\Rafeeq-Backups\release-v1.2.0-and-v3.51.0.bundle`.
4. Phone-only checks: adhan on the lock screen after a PIN reboot, real
   microphone for tasmee, Google sync between two devices.

## Half-done / unverified

- The adhan retry fix is verified on API 36 only (native suite + upgrade
  install), not on API 24 or a real phone.
- The review rework is verified locally (82 backend tests; real page against
  `wrangler dev` with local D1: name claimed, note saved, a second claim of
  the same name refused with the message), NOT on the live Worker.
- emulator-5554 has the signed 3.88.1 installed (upgraded over 3.88.0).

## Log

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
