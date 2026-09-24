# CLAUDE.md — how work is done on Rafiq Al-Darb

**This file is mandatory.** Claude Code loads it automatically every session.
Any agent working on this project — Claude Code, Antigravity, Cline, Gemini,
anything — follows it. The owner made this a hard requirement so that a new
session, or a different agent entirely, works the same way the last one did.

If you are about to do something this file forbids, stop and tell the owner
why you think it should be an exception. Do not just do it.

---

## 0. What this project is

**رفيق الدرب / Rafeeq Al-Darb** — a personal, **sideloaded** Android Islamic
app in Flutter. The owner's own app, on his own repo (`tito423/Rafeeq-Al-Darb`),
distributed as an APK on GitHub Releases. Not a Play Store app, not commercial.

Arabic is the primary language and the owner writes in Egyptian Arabic. **Reply
in Arabic.** Code, comments and commit messages stay in English.

---

## 1. The rules that matter most

### 1.1 Nothing fake. Ever.

> «ممنوع استخدام أكواد وهمية (Placeholders)» — the owner, in the original spec.

No mock data, no placeholder URLs, no sample text, no invented API responses,
no "TODO: real source later". If a real source cannot be found and verified,
**say so and stop**. Shipping a feature backed by nothing is worse than not
shipping it.

This has been violated before and cost real time:

- Eight mushaf editions were added whose page images were never uploaded.
  Every page 404'd and selecting one opened a blank reader. All eight were
  deleted later.
- Every library book card claimed `الحجم: 1.0 MB`, because the widget had
  `final sizeMb = '1.0';` written into it. Real sizes ranged 3 KB – 883 KB.
- Ten adhan clips were attributed to named muezzins nobody had verified.

**Never add an entry to a catalogue before its content resolves on the public
endpoint.** A `HEAD` (or a 1 KB range request) on the first real file, every
time.

### 1.2 Religious content is held to a higher standard

> «لازم كل الاحاديث يبقى لها تخريج حقيقي. ده علم الحديث مفيش فيه هزار.»

- A hadith grading must come from a **named scholar in a named edition**, and
  the app must show whose it is. `grade` without `grader` is not acceptable.
- **Ungraded is a valid, honest answer.** Muwatta Malik ships with no grading
  because al-A'zami's critical edition gives takhrij but no per-hadith verdict —
  the Muwatta simply is not graded hadith-by-hadith the way the Sunan are.
  Bukhari and Muslim ship ungraded by design; the app shows «من الصحيحين».
  Do not "fill the gap" with a guess to make a column look complete.
- Never rewrite, normalise or "fix" the text of a Qur'an ayah or a hadith. If a
  source has an obvious typo (`إسناده صحح`), it stays — it is the source's text,
  and silently correcting scripture-adjacent text is not yours to do.
- Every content source gets credited on the Sources screen with a link.

### 1.3 Verify on a real device, not in your head

**Nothing is "done" until it has been run on `emulator-5554` (or a real phone)
and seen.** `flutter analyze` passing means the code compiles, not that the
feature works.

Every serious bug on this project was found by running it, and would have been
missed by reading:

| Bug | What reading it suggested | What running it showed |
|---|---|---|
| `no such module: fts5` | clean code, clean analyze | Android's SQLite has no FTS5 → the entire library DB failed to open → downloads, opening, deleting and search all dead |
| Gzipped books | `jsonDecode(res.data!)` looks fine | 207 of 215 books are gzip bytes → `FormatException` on byte 1 |
| Reader path `'sqlite'` | "just a marker" | `File('sqlite')` resolves to nothing → no book ever opened |
| Transparent glyph masks | PNGs downloaded fine | black letterforms on a transparent ground → invisible on the dark reader |

Take screenshots. Read them. `adb exec-out screencap -p > x.png` then look at it.

**`adb shell input text` cannot type Arabic** (`NullPointerException` in
`InputShellCommand.sendText`). To get an Arabic query into a field: long-press
text inside the app, copy it, then long-press the field and paste. There is no
`cmd clipboard` on this emulator.

### 1.4 Read the real thing before writing the code that parses it

Before writing a parser, fetch a few real pages and **look at them**. The
Musnad Ahmad crawl needed four separate discoveries that no amount of reasoning
would have produced: an editorial mark before the hadith number (`* ٥١٨ -`,
`° ٥١٩ -`, `• ٢٦٧ -`), a line starting `=` opening the footnote area, footnotes
that are manuscript variants rather than rulings, and numbered lists in the
editor's introduction that look exactly like hadith lines.

Then **verify the parser against pages you read by hand.** Eight hadiths were
checked against their printed footnotes; all eight matched before the result
was trusted.

### 1.5 Report honestly

- If something is unverified, say exactly what is unverified and why.
- If you claimed something that turned out to be wrong, correct it plainly —
  in the reply and in the commit message. This has happened (a claim that the
  app showed «الدرجة: غير مذكورة» when those keys were dead) and correcting it
  was the right call.
- Never describe work as verified in `HANDOVER.md` unless you ran it.
- Numbers in reports are measured, not estimated. Say where the number came
  from.

### 1.6 Secrets

R2 credentials live in `scripts/.env`, which is gitignored. Never commit them,
never print them, never paste them into a message.

---

### 1.7 Every fact is checked at the moment it is given

> «اي معلومة تقولها لازم تكون بتاريخ اللحظة اللي بسالك فيها مش من دماغك
> باخر تحديثات عشان مش نلبس في حيطة» (2026-09-24)

Prices, store rules, package versions, API behaviour, another app's features,
a host's limits: **look them up now** (web, the package's own source, the
live endpoint) and say where from and when. Anything you could not check is
labelled as unchecked, never stated as fact. Training memory is a starting
point for where to look, not an answer.

### 1.7b Certainty, not "maybe" — go and check

> «مفيش حاجة اسمها ممكن تكون او معرفش او اظن لازم تتاكد يقينا دايما وابدا
> عشان لما تبني قرار تاخده صح بناء على ارضية ثابته» (2026-09-24)

"Maybe", "I think", "probably", "I don't know" are not answers on this
project. When one is about to leave your mouth, stop and **find out** — run
it, fetch it, read the source, measure it — then state the fact and how it
was established. Labelling something "unverified" (§1.5) is not the end of
the job; it is the list of things still to check. A decision is built only on
facts checked this way. If a check is genuinely impossible from here (needs
the owner's phone, his Google sign-in, money), say exactly what blocks it and
what would unblock it — never leave a guess standing in its place.

This was set after a report said the backgrounds «ممكن تكون جاية من المصدر
الاحتياطي» instead of checking which host served them.

### 1.8 Libraries and toolchain: current, stable, and proven compatible

> «كل مكتبات التطبيق والبيئة اللي بنطور بيها لازم تكون محدثة ومتوافقه
> بالاصدارات المستقرة اللي مش تسبب اي مشاكل او كراشات» (2026-09-24)

- Keep Flutter, Dart, Gradle/AGP/Kotlin and every package on the newest
  **stable** release that actually works together — checked live
  (`flutter pub outdated`, the changelog, the package source), not assumed.
- "Newest" loses to "works": `permission_handler` 13 needed AGP 9 and broke
  the release build, so 12.0.3 stayed (2026-09-24). Record every held-back
  package and why, and re-check it when the toolchain moves.
- An upgrade is done only when `build_github_release.bat` succeeds, the
  signed APK installs over the previous one, and the features that use the
  package are seen working on the emulator (§1.3). `flutter analyze` and a
  debug build are not proof — the AGP-9 break passed both.

## 2. Workflow

### 2.0 Know how much quota is left — before you plan, and while you work

**This is mandatory.** Sessions on this project have died mid-task from quota
exhaustion more than once, and each time the loss was not the tokens — it was
the uncommitted tree and the unwritten note. The owner's instruction:

> «دايما يتحقق في الوقت الفعلي من الكوته عشان مش نلبس في حيطة ونضيع وقت كل مرة»

So:

1. **Check the remaining budget at the start of the session**, before promising
   anything. In Claude Code that is `/usage` (or `/status`) in an interactive
   terminal; the running total is also printed in the context/usage indicator.
   If the interface you are in cannot show it, **say so to the owner in your
   first reply and ask him to read it off his screen** — do not silently guess.
2. **Re-check before starting any long stage** (a crawl, a bulk upload, a
   device-verification run, a full rebuild of a DB) and **report the number**.
   The owner watches the quota himself: the reading informs him, it does not
   stop the work — keep going unless he says stop. (The quota tool in this
   app is `mcp__ccd_session_mgmt__get_usage`; it also shows how full the
   CONTEXT is — when that nears ~90 %, say so and offer a clean handover.)
3. **Size the plan to the budget you actually have.** Split a big brief into
   stages that each end at a committed, working state. Never begin a stage
   whose only useful output arrives at the end.
4. **Checkpoint before you get close to the edge**, not when you notice it —
   see §2.1. A dying session must die on a clean tree.
5. **Tell the owner where the budget went** when a session ends or is handed
   over: what was spent on what, and what is left. He is paying for it.

Never answer "how much quota is left" from memory or from an earlier reading in
the same session. It is a live number; read it live.

### 2.0b Remote Control — check it in the first reply

The owner steers sessions from his phone, so **in the same first reply as the
quota question**, check whether Remote Control is on and say so.

`ListAgents` is the check: with Remote Control connected it lists the account's
other sessions, including Remote Control ones on other machines. None listed
means it is not connected.

**It is switched on when the session STARTS, and only then.**

    claude rc            # or: claude --remote-control [name]

That is `claude remote-control`, «Control local sessions from claude.ai/code or
the Claude mobile app», and it **starts a new interactive session** with Remote
Control enabled — it cannot be added to a session that is already running.
So an agent inside a running session cannot turn it on for that session, and
running `claude rc` from a tool call only spawns a process the owner is not
sitting in front of. (Checked: `claude rc --help` prints exactly that usage,
and a bare `claude rc` blocks waiting for a terminal.)

So the useful thing to do is tell him **early**, while restarting is still
cheap: if it is off and the session is going to be long, say so in that first
reply and let him decide whether to restart with `claude rc`. Never claim to
have opened it, and never say it is on unless a `ListAgents` result showed it.

### 2.0c `TASK_FOLLOWUP.md` — the live step log (mandatory)

The owner works from his phone 12:00–24:00 Dubai time, drives the PC through
TeamViewer/RustDesk, and when a subscription's quota stops he opens another
session (the other account, or another agent) and pastes `NEXT_PROMPT.md`.
That prompt is now a **stable pointer** — it always says «read CLAUDE.md, then
TASK_FOLLOWUP.md, continue from Next step» — so it never needs rewriting.

Therefore, after **every** step (not every stage): update `TASK_FOLLOWUP.md`
— current task, **Next step (exact)**, half-done/unverified items, one log
line with the commit — then `.\cp.bat "…"` (which commits it and pushes).
A session may die between any two tool calls; the file must always be true.

### 2.1 Checkpoint constantly

Sessions here die from quota exhaustion, usually mid-task. Do not save the
write-up for the end.

```bash
.\cp.bat "what you just did"
```

updates the WIP note in `HANDOVER.md`, stamps the date, and commits — one step.
A session that dies right after a checkpoint loses nothing.

### 2.2 The definition of done

A change is done when **all** of these hold:

1. `flutter analyze lib test` → **No issues found**
2. `flutter test` → **all pass** (25 as of 2026-09-09; the translation-parity
   test enforces identical key sets and no empty values across all 7 locales)
3. It has been **run on the emulator and seen working**
4. `HANDOVER.md` reflects it
5. It is committed and pushed

### 2.3 Releases

- **A release is published only when the owner asks.** If a session is
  ending with finished, verified work unreleased, ASK him — do not publish on
  your own and do not stay silent about it.
- One release at a time. The owner wants the repo clean: «كل حاجة تبقى على
  نضافة». Delete the previous release **and its tag** before publishing the new
  one, unless told otherwise. **Two standing exceptions, never deleted:**
  `v3.51.0` (the restore point, RESTORE.md) and the `content-mirror`,
  `content-mushaf`, `content-surah` prereleases — the GitHub copy of the R2
  content that the app falls back to (`ContentMirrors`); deleting them breaks
  every fallback download.
- **Build the GitHub APK with `build_github_release.bat`**, never a bare
  `flutter build apk`. It passes
  `--dart-define=RAFEEQ_SUPPORT_URL=https://paypal.me/Tito320` and then
  signs. The owner wants the PayPal link **only** in the GitHub build
  (2026-09-19); `AppConfig.supportUrl` is empty in the source, so a build
  without the define simply has no support button. Check the Support
  screen shows «ادعم التطبيق» on the published APK. **Never call it
  «تبرع» / donation** anywhere the owner or a user reads it - it is «دعم
  التطبيق», and the amount is the reader's to choose (no preset sum).
- `pubspec.yaml`'s `version:` is what the About card shows. **Bump it** — a
  release tagged `v3.2.0` while the About card said `3.0.0` shipped once.
- Tag from `master`. `gh release create ... --target master`. A previous session
  used `--target main` while all work was on `master`, and every tag pointed at
  the initial commit.
- Release notes in Arabic, structured, honest about what was broken.
- Verify after publishing: `gh release view <tag> --json tagName,targetCommitish,assets`
  and confirm the tag's SHA equals `git rev-parse HEAD`.

### 2.4 Commit messages

English, explaining **why** and what was actually observed — not a changelog of
file names. Include the evidence: what was measured, what was verified live,
what stayed unverified. End with:

```
Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
```

---

## 3. Traps this project has already paid for

The full entries — what happened, the evidence, the fix — are in **`TRAPS.md`**. Read the relevant one before working in its area; add a new entry there (and a line here) when you pay for a new one.

1. Android's SQLite has no FTS5.
2. Plain SQL `LIKE` does not work for Arabic here.
3. A word boundary is any non-letter, not just a space.
4. Never load a whole corpus in one query.
5. Soft-404s.
6. Hosted books are gzip without a `Content-Encoding` header.
7. `Icons.chevron_left` auto-mirrors in RTL.
8. A missing translation key renders as the raw key
9. `archive.org` is worth searching before giving up.
10. Windows console is cp1256 and cannot print Arabic.
11. Heredocs mangle `\n` and quotes.
12. `py -3` has `boto3` and `PIL`; the msys `python` does not
13. Avast intercepts TLS on this machine, and it breaks every `boto3` upload.
14. `ffmpeg` is already on this machine
15. A translucent highlight over a dark ground composites dark
16. A number next to a Latin unit reverses in an Arabic paragraph.
17. Shamela's own search searches *inside* books, not their titles.
18. A free scan is not automatically free to rehost. Read its back matter.
19. R2's public endpoint answers a bare `urllib` request with HTTP 403.
20. `py -3` already has PyMuPDF (`import fitz`)
21. Two printings "looking the same" is not evidence they set the same page.
22. A scanned edition's pages are not all the same size.
23. In generated Dart, a backslash before a `$` is an ESCAPE, not an interpolation.
24. A `flutter build apk --release` kills a running emulator on this machine.
25. Fetchable is not legible.
26. A page may honestly have NO ayah fit.
27. A downloaded zip unpacks under the ZIP's name, not the entry's.
28. `adb shell date` cannot set the clock on a Google Play emulator image
29. A notification's text is frozen when the alarm is ARMED, not when it fires.
30. `Localization` and `Translations` are not exported by `easy_localization`.
31. One tap handler owns every notification in the app.
32. `inexactAllowWhileIdle` is not an interval.
33. Android drops a package's notifications past 25 posted.
34. A Shamela edition puts the EDITOR's footnotes in the body stream, and its isnads are fully diacritised.
35. Ayahs and hadith are marked typographically, not by wording.
36. A catalogue nobody opened is a catalogue of claims.
37. `BoxFit.cover` on a portrait screen is a magnifying glass.
38. Wikimedia refuses a User-Agent with no contact in it.
39. A Windows filename cannot contain `?`, and curl will not tell you.
40. Read the response you are going to parse, not its cousin.
41. The release APK is signed OUTSIDE Gradle, and Gradle still says debug.
42. A chapter number is not always an integer, and one row that isn't took a whole collection down.
43. `SystemChrome.setEnabledSystemUIMode` is PROCESS-WIDE, and a kept-alive tab is never disposed.
44. `Navigator.maybePop()` inside a `PopScope(canPop: false)` is a loop.
45. `background_downloader`'s `registerCallbacks` diverts the updates stream — but only for status and progress.
46. Git Bash rewrites an absolute path into a Windows one before `adb` sees it.
47. Dart's `\w` is `[A-Za-z0-9_]`, and `unicode: true` does NOT widen it.
48. Impeller drops the words of a Qur'an page drawn too large.
49. "It plays" is not "it is heard" — and a phone can mute ONE app.
50. just_audio 0.10 reports a failed source on `errorStream`, as a value.
51. R2 objects stored with `Content-Encoding: gzip` come back INFLATED to a client that does not send `Accept-Encoding: gzip`.
52. `permission_handler` 13 → `permission_handler_android` 14.1.0 needs AGP 9
53. The emulator's `-tcpdump` captures nothing here; `-http-proxy` + a logging proxy does.
54. Never run `flutter test` or edit `lib/` while a release build is running.

## 4. Where things live

| | |
|---|---|
| Flutter app | `rafeeq_app/` |
| Pipeline scripts | `scripts/` (Python, run with `py -3`) |
| R2 credentials | `scripts/.env` — **gitignored** |
| Hosted content | `https://pub-39dbef68a1a845d5ba669b43a59516b9.r2.dev` (bucket `rafeeq-content`) |
| Bundled databases | `rafeeq_app/assets/data/*.db` — gitignored, regenerable |
| Mushaf covers | `rafeeq_app/assets/mushaf_covers/*.jpg` — built by `scripts/build_mushaf_covers.py` |
| Long-form history | `HANDOVER.md` (state), `PHASE2.md` / `PHASE3.md` (build logs) |
| Next-session brief | `NEXT_SESSION_PROMPT.md` |

**Content is hosted, not bundled — except where the owner asked otherwise.**
`hadith.db` is bundled (he asked for the hadith library built in) *and* mirrored
on R2 as `hadith/hadith.zip`; keep the two in sync and bump
`AppConfig.hadithDbVersion` whenever the DB changes, or devices holding the old
download will open a stale file.

---

## 5. Working style the owner has asked for

- **«دايما تضغط الحاجه عشان التوكنز»** — be compact. Don't narrate options you
  are not going to take; decide and move.
- **«خلص الاول اللي انت بتعمله انا مش عوازك تهلوس في حاجة»** — finish the task
  in hand before opening a new front.
- **«امشي برايك»** — he delegates judgement. Use it, and report what you decided
  and why.
- When he supplies an asset (an icon, an image), **use it exactly as given**:
  «ياصاحبي استخدمها هيا بالظبط من غير تعديل».
- Ask only when two readings would lead to materially different work.
- **No lazy shortcuts; look for the better road.** «اوعاك تستسهل في حاجة
  ممكن تضيع تعبنا ... اوعاك الشورت كت اللي يودي في داهية ... دايما حلول
  ابداعية وابتكارية» (2026-09-24). A shortcut that risks the work — skipping
  a check, a guessed number, a hack that "should be fine" — is forbidden.
  But a faster, more efficient AND more reliable method is exactly what he
  wants: before grinding through a slow or fragile path, ask whether there
  is a smarter one (one listing instead of 6,236 HEADs; `adb pm grant`
  instead of tapping through dialogs; a logging proxy instead of guessing
  which host answered) and take it.

---

## 6. When the owner says «جهّز الدنيا» / asks for a handover

This is a standing, mandatory routine — and it is the **only** thing that
starts it. Until he says it, finish the work and report it; do not write the
next-session prompt (§7). Do all of it:

1. **Verify.** `flutter analyze lib test`, `flutter test`, and a range request
   against every hosted content path (`hadith/hadith.zip`, a book, one page of
   each mushaf edition, a translation). Record the actual results.
2. **Measure.** Locale count and key count, mushaf editions, library book count,
   `hadith.db` size / rows / graded, APK size, app version. Facts, not memory.
3. **Update `HANDOVER.md`** — the state block at the top must describe today,
   not a previous phase.
4. **Rewrite `NEXT_SESSION_PROMPT.md`** — what is done, what is next, what is
   blocked and on whom.
5. **Back up** — commit everything, push `master`, confirm the release and tag
   point at `HEAD`.
6. **Report** what you verified and anything that did not check out.
7. **Hand him the next prompt in the reply itself**, as the last thing you do.
   «اول ما تخلص وتحفظ كل حاجة تجهز برومبت يكمل بالظبط من عند ما حنا وقفنا
   وتديهوني مباشر في بلوك md قابل للنسخ». Writing it to `NEXT_PROMPT.md` is
   not enough on its own: the owner starts the next session by pasting, and a
   file he has to go and open first is one step he should not have to take.
   So after everything is committed and pushed, print the prompt **in the
   chat, inside a fenced markdown block, whole and ready to copy**. It is the
   same text as `NEXT_PROMPT.md` — the file is the record, the block is the
   thing he actually uses — and §7 governs what is in it.

Never hand over a state you have not just verified.

---

## 7. The next-session prompt — a standing instruction

> «لما تكتب برومبت للسيشن الجاية يكمل من عند ما انت وقفت، ولو وقفت في حاجة
> خليه يرجع يعملها تاني، ودايما تصدّر البرومبت في ملف .md جاهز للنسخ.»

**Write one only when he asks.** «مش تعمل البرومبت الا لما اقولك جهز الدنيا»
(2026-09-16). Ending a reply with an unasked-for next-session prompt reads as
"I am finishing now" while he is still handing out work, and it costs tokens he
is paying for. So: no `NEXT_PROMPT.md`, no printed block, until he says
«جهّز الدنيا» or asks for a handover. Then §6 runs in full.

When you do write one — at a handover, or because he asked — all three of these
hold:

1. **It resumes exactly where you stopped.** Not a summary of the project: the
   next instruction, in order, starting from the thing your hands were on. Name
   the file, the command, the screen.

2. **Anything you left half-done is named as half-done, and the next session is
   told to redo it — not to trust it.** This is the whole point of the rule.
   "Applied but never run", "committed but never opened on a device", "the crawl
   was at 2,900 of 25,000", "the emulator was on the wrong screen" — each of
   those is a *first* item for the next session, not a footnote. If you cannot
   say whether something works, say that, and say to do it again.

3. **It is written to `NEXT_PROMPT.md` in the repo root, ready to copy whole,
   and printed in the reply in a fenced markdown block.** Both, every time —
   see §6.7. The file survives the session; the block is what he pastes.
   A prompt buried in a chat reply is lost when the session is. `NEXT_PROMPT.md`
   is the thing the owner pastes; it is rewritten every time, and it is
   committed with everything else.

`NEXT_PROMPT.md` is the paste-ready message. `NEXT_SESSION_PROMPT.md` remains
the long brief it points at — the two are not the same file and neither
replaces the other.
