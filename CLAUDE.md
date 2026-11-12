# CLAUDE.md — how work is done on Rafiq Al-Darb (short form)

Mandatory for every agent. The full text, with every quote, example and the
history behind each rule, is `docs/CLAUDE_full.md`: read the section you need
when a rule below is unclear or you work in its area. If something here seems
to need an exception, stop and ask the owner. Kept short on purpose (owner,
2026-11-12: a session should start under ~20k tokens).

## 0. Project
رفيق الدرب: the owner's personal sideloaded Android Islamic app (Flutter),
repo `tito423/Rafeeq-Al-Darb`, APK on GitHub Releases. **Reply in Arabic**
(the owner writes Egyptian Arabic); code, comments, commits in English. Work is on `master`
(the default branch `main` is only the initial commit).

## 1. Rules
1. **Nothing fake.** No placeholders, mock data, guessed URLs or sizes. Never
   add a catalogue entry before its first real file answers on the public
   endpoint (HEAD / 1 KB range).
2. **Religious content.** A hadith grade needs a named grader in a named
   edition; ungraded is a valid answer. Never alter Qur'an or hadith text.
   Qur'an words quoted inside a book: fix only after looking at the Madinah
   page (`madinah_qc`), the book's print, an evidence image, and an entry in
   the correction file; tell the owner. No leniency in Qur'an matters: chase
   every copy and named work before a doubt goes to the owner. Credit every
   source on the Sources screen.
3. **Verify on a device** (`emulator-5554` or a phone): analyze/tests are
   not proof. Screenshot and look. `adb shell input text` cannot type Arabic.
4. **Read the real source before writing its parser**, then check the parser
   against pages read by hand.
5. **Report honestly**: say what is unverified; correct wrong claims plainly;
   numbers are measured, with where from.
6. **Secrets**: R2 keys in `scripts/.env` (gitignored) — never print/commit.
7. **Facts are checked live** (web, package source, endpoint), with source
   and date; no «ممكن/أظن/معرفش» — go and find out, or say exactly what
   blocks the check.
8. **Seven languages** (ar, en, fr, es, pt, ru, ur) for every UI string and
   displayed content; only scripture-type text stays Arabic.
9. **Toolchain**: Flutter 3.47.7 / Dart 3.13.5 at `E:\DevEnv\flutter-3.47.7`
   — run `. .\scripts\flutter_env.ps1` first (the machine default 3.38.7 is
   wrong). Gradle 8.14, AGP 8.11.1, Kotlin 2.2.20 pinned; newest stable that
   works; record held-back packages (permission_handler 12.0.3: 13 needs AGP 9).
   An upgrade is done only after a signed `build_github_release.bat` installs
   and the feature is seen working.

## 2. Workflow
- **Quota**: read it at the start (`mcp__ccd_session_mgmt__get_usage`
  locally; `get_session` in the cloud) and report it in the first reply;
  re-read before every long stage. Stop at 85% of the 5-hour window. Context
  near 200k (owner, 2026-11-12): checkpoint, update `TASK_FOLLOWUP.md`, tell the owner.
- **Per task**: a short table piece / who / why / estimated weekly points.
  Python first (free); Haiku for bulk classification, Sonnet for judging
  against rules, Opus for religious-content decisions, reviews, design. Cap 5
  weekly points unless told otherwise.
- **Cheap agents** (`.claude/agents/`): `bulk-haiku` for sweeps, counts and
  bulk classification; `judge-sonnet` for checks against written rules and
  small specified edits. The main model only decides, reviews religious
  content and designs. Agents answer in summaries, never file dumps.
- **Tokens**: read files by section (offset/limit, grep), never whole big
  files; long builds/tests run in the background, their logs read with
  `tail`/`grep`; past ~200k context hand off to a new session.
- **Sessions** start from the phone (cloud) or locally; never check or report
  Remote Control. A cloud session reaches the laptop through the runner repo
  `tito423/rafeeq-control` (`gh workflow run run.yml -R tito423/rafeeq-control
  -f command="..."`); R2 uploads, Gemini voices, builds, emulator, signing run
  there only, and only as the session's prompt allows.
- **`TASK_FOLLOWUP.md`** is the live log: after every step update the current
  task, **Next step (exact)**, half-done items, one log line; then checkpoint.
  Without a prompt, the job is its Next step.
- **Checkpoint**: cloud — `git add <files> && git commit && git fetch origin
  master && git rebase origin/master && git push origin HEAD:master`; PC —
  `.\cp.bat "..."`. `git add` every new file.
- **Done** = `flutter analyze lib test` clean, `flutter test` passes, seen on
  the emulator, `HANDOVER.md` updated, committed and pushed.
- **Releases only when the owner asks.** One release at a time (delete the old
  release and tag), except `v3.87.0` and the `content-mirror`,
  `content-mushaf`, `content-surah` prereleases — never delete those. Build
  with `build_github_release.bat` only; support link is «دعم التطبيق», never
  «تبرع». Bump `pubspec.yaml` version; `--target master`; Arabic notes; verify
  the tag SHA equals HEAD; give the release page and APK link.
- **Commits**: English, why + evidence, end with the Co-Authored-By line.

## 3. Traps
Read the matching entry in `TRAPS.md` before working in its area (78 so far:
no FTS5 on Android, gzip books, RTL chevrons, cp1256 console, Avast TLS,
emulator headless launch, signing outside Gradle, …). Add new ones there.

## 4. Where things live
App `rafeeq_app/`; pipelines `scripts/` (`py -3`); content on R2
`https://pub-39dbef68a1a845d5ba669b43a59516b9.r2.dev` (bucket
`rafeeq-content`); state `HANDOVER.md`; history `docs/history/`. Content is
hosted, not bundled, except `hadith.db` (bundled AND `hadith/hadith.zip` on
R2: keep in sync, bump `AppConfig.hadithDbVersion`).

## 5. Style
Be compact; finish the task in hand first; decide yourself and say why
(«امشي برايك»); use supplied assets exactly; ask only when two readings lead
to different work; no risky shortcuts, but look for the smarter safe road.

## 6–7. Handover and next prompt — only when the owner says «جهّز الدنيا»
Then: verify (analyze, test, range requests on hosted content), measure,
update `HANDOVER.md`, rewrite `NEXT_SESSION_PROMPT.md` and `NEXT_PROMPT.md`
(resume exactly where you stopped; half-done work named and redone), commit,
push, and print the prompt in a fenced md block. Never write a next-session
prompt unasked. Details: `docs/CLAUDE_full.md` §6–7.
