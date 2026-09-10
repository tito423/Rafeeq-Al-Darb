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
   device-verification run, a full rebuild of a DB). If what is left will not
   cover the stage, say so *first* and pick a smaller stage instead.
3. **Size the plan to the budget you actually have.** Split a big brief into
   stages that each end at a committed, working state. Never begin a stage
   whose only useful output arrives at the end.
4. **Checkpoint before you get close to the edge**, not when you notice it —
   see §2.1. A dying session must die on a clean tree.
5. **Tell the owner where the budget went** when a session ends or is handed
   over: what was spent on what, and what is left. He is paying for it.

Never answer "how much quota is left" from memory or from an earlier reading in
the same session. It is a live number; read it live.

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

- One release at a time. The owner wants the repo clean: «كل حاجة تبقى على
  نضافة». Delete the previous release **and its tag** before publishing the new
  one, unless told otherwise.
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

Do not rediscover these.

1. **Android's SQLite has no FTS5.** `CREATE VIRTUAL TABLE ... USING fts5`
   throws `no such module: fts5`, and because it runs inside `onCreate`, the
   throw kills `openDatabase` and every call that touches that database. This
   has bitten three times (`HadithRepository`, `QuranRepository`,
   `LibraryApiService`). **Never reach for FTS5.** Use the established pattern:
   store a column normalised with `normalizeArabic`, match in Dart with
   `normalizeArabic` + `normalizeArabicLoose` + a word-boundary test, read rows
   in small pages.

2. **Plain SQL `LIKE` does not work for Arabic here.** Stored text is fully
   diacritised, so an undiacritised query never matches. Confirmed against the
   real `hadith.db`: `LIKE '%عمر%'` returned 0 rows on a hadith containing
   `عُمَرَ بْنَ الْخَطَّابِ`.

3. **A word boundary is any non-letter, not just a space.** Book text quotes
   hadith inside guillemets, so «انما الاعمال بالنيات» matched nothing under a
   space-only test.

4. **Never load a whole corpus in one query.** `_db.query('hadiths')` over ~41k
   rows tried a single ~83 MB allocation and threw `OutOfMemoryError` on a real
   device. Page it.

5. **Soft-404s.** `android.quran.com` returns its 6318-byte HTML homepage with
   HTTP **200** for missing folders. Always check `Content-Type` and the byte
   size, never just the status code.

6. **Hosted books are gzip without a `Content-Encoding` header.** That is the
   standing policy (`scripts/gzip_and_reupload_all_books.py`) — 207 of 215 are
   stored compressed, and the client sniffs the two magic bytes `1f 8b`. Any new
   code that fetches a book must sniff, exactly as `BookText.fromFile` and
   `LibraryApiService.downloadBook` do.

7. **`Icons.chevron_left` auto-mirrors in RTL.** For a disclosure chevron that
   should point the same way in Arabic, use `chevron_right`. Ten of them pointed
   the wrong way.

8. **A missing translation key renders as the raw key** on screen. Add or remove
   a key in **all 7** locale files or `translation_parity_test` fails — which is
   the point of that test.

9. **`archive.org` is worth searching before giving up.** Two sessions recorded
   the Shamarly mushaf as unsourceable after checking one GitHub repo. archive.org
   had a complete 521-page set the whole time. Its `advancedsearch.php` needs
   **ASCII** queries; Arabic queries error out. `https://archive.org/metadata/<id>`
   lists every file, and `https://archive.org/download/<id>/page/n0_w800.jpg`
   returns page 0 of a scanned book — which for a mushaf is its printed cover.

10. **Windows console is cp1256 and cannot print Arabic.** Write reports to a
    UTF-8 file and `cat` it, or the run dies on `UnicodeEncodeError`.

11. **Heredocs mangle `\n` and quotes.** For any script that writes Dart or
    JSON, use the `Write` tool or build the string with `chr(39)`/`chr(92)`.
    This has broken generated files repeatedly.

12. **`py -3` has `boto3` and `PIL`; the msys `python` does not**, and msys
    Python has no CA bundle (TLS verification fails). Use `py -3` for anything
    touching R2 or images, and `curl` for HTTPS downloads.

13. **Avast intercepts TLS on this machine, and it breaks every `boto3`
    upload.** R2 fails with `CERTIFICATE_VERIFY_FAILED: unable to get local
    issuer certificate` while `curl` to the same endpoint is fine. Two causes
    stack: Avast's Web Shield re-signs the certificate with its own root, which
    lives in the **Windows** store and will never be in `certifi`; and R2 sends
    only the leaf certificate, which curl chases via AIA and Python does not.
    Fixed once, in **`scripts/r2_common.py`** — use `r2_client()` from there
    for every R2 script. **Never `verify=False`:** those requests carry the
    bucket's access key and secret.

14. **`ffmpeg` is already on this machine**, bundled with ShareX at
    `C:\Program Files\ShareX\ffmpeg.exe`. Nothing needs downloading to
    transcode audio the owner supplies.

15. **A translucent highlight over a dark ground composites dark**, however
    bright the highlight colour looks on its own. Three mushaf themes shipped
    dark ink on that composite and measured 2.3–2.6 : 1 against a 4.5 : 1
    floor. **Compute the composite and its contrast ratio; do not judge a
    colour pairing by eye.**

16. **A number next to a Latin unit reverses in an Arabic paragraph.**
    `60.5 MB` rendered as `MB 60.5` on every size label in the app, because a
    numeral is bidi-weak and takes its direction from what surrounds it. Wrap
    such fragments in a left-to-right isolate — `ltr()` and `formatBytes()` in
    `lib/core/utils/byte_formatter.dart` do it. There were five copies of that
    formatter, all with the same bug; there is one now.

17. **Shamela's own search searches *inside* books, not their titles.** Asking
    it for «الرحيق المختوم» returns a *commentary on* al-Raheeq above
    al-Raheeq itself — which is exactly how a session ends up cataloguing the
    wrong book id. Use the local index instead:
    `py -3 scripts/shamela_index.py find "<title>"` (8,598 books, built once
    from the 40 category pages by `shamela_index.py build`).

18. **A free scan is not automatically free to rehost. Read its back matter.**
    The Taj Company 16-line mushaf on archive.org is a clean, complete,
    legible 559-page scan with no licence stated — and its own last page
    prints «جملہ حقوق محفوظ» plus a copyright warning naming Taj Company Ltd.
    The Qur'an text is nobody's property; a publisher's typesetting and scan
    can be. **Render the first and last few pages of any scan and read them
    before building an edition from it.** مصحف قطر was used instead precisely
    because its archive.org item states CC BY-NC-SA 3.0.

19. **R2's public endpoint answers a bare `urllib` request with HTTP 403.**
    It wants a `User-Agent`. `curl` sends one by default, which is why a URL
    can work in the shell and 403 from Python in the same minute. Every
    script that reads the bucket over HTTP sets one — see
    `scripts/fit_mushaf_polygon_transform.py`.

20. **`py -3` already has PyMuPDF (`import fitz`)**, so a scanned mushaf PDF
    can be rasterised without installing anything. There is no `pdftoppm`,
    `mutool`, `gs` or `magick` on this machine, and `pdf2image` is not
    installed — do not reach for them.

21. **Two printings "looking the same" is not evidence they set the same
    page.** The Tajweed mushaf really does set the Madinah 15-line grid, and
    that was established by clustering line positions on 30 scans and on the
    Hafs polygons and finding *exactly 15 clusters on both sides with matching
    counts* — not by looking at a page. `madinah_gold` looks like the Madinah
    mushaf too and sets 6 lines where it sets 15. Measure the grid, then
    render the mapped polygons over the real pages and **look at the
    pictures** — the residuals are not the evidence.

22. **A scanned edition's pages are not all the same size.** All 604 Tajweed
    pages were read from their JPEG headers: two groups, 602 at 861×1317 and
    the two illuminated openings at 901×1476. مصحف قطر varies page to page
    (1720–1779 × 2294–2399) because each leaf was cropped separately. Census
    the real dimensions before assuming one aspect ratio, and never lay a
    coordinate overlay on a `BoxFit.contain` box — the drawn rectangle depends
    on the surrounding box, so put the page in an `AspectRatio` of its own
    measured shape.

23. **In generated Dart, a backslash before a `$` is an ESCAPE, not an
    interpolation.** `scripts/add_seerah_catalog_entries.py` wrote
    `'\${AppConfig.contentBaseUrl}/books/text/x.json'` into `book_catalog.dart`
    — a perfectly valid Dart string literal that evaluates to that text
    *verbatim*. Every book it generated failed on the device with «Invalid
    argument(s): No host specified in URI». Eleven books; **eight of them
    shipped in v3.6.0.**

    Three things made it survive:
    * `flutter analyze` sees a valid string and says nothing.
    * The other 215 books use the plain form and always worked, so the
      catalogue looked fine.
    * The session that added them verified the *upload* — a range request
      against R2 — and never opened the library in the app. **The bytes being
      on the bucket is not the feature working** (§1.3).

    `test/book_catalog_urls_test.dart` now parses all 226 URLs and asserts each
    has a real host. When you write a test for a bug like this, **prove it
    fails on the broken code** before trusting it — that one was proven by
    reintroducing the escape into `la_tahzan` and watching the test reproduce
    the device's exact complaint.

24. **A `flutter build apk --release` kills a running emulator on this
    machine.** It happened twice in one session — the emulator disappears from
    `adb devices` mid-build and the app has to be reinstalled after a fresh
    boot. Build first, *then* start the emulator; don't leave a device-
    verification run half-finished across a build. A fresh boot also throws
    a «System UI isn't responding» dialog for the first ~30 seconds — tap Wait
    and give it time rather than reading the screenshot as a crash.

25. **Fetchable is not legible.** All 604 pages of مصحف قطر answered a range
    request, and four of them were still unreadable — a flat green block, a
    pink wash, a grey wash, a torn orange band, all in the source scan's own
    embedded JPEGs. **Run `scripts/check_mushaf_pages.py <edition>` on every
    rendered page set before uploading**; it scans for a large flat coloured
    area and reports each sample page's printed header beside the surah the
    Hafs layer expects.

    When a page is damaged, look for a second copy of the *same* scan set
    rather than a different printing, and prove it is the same set before
    lifting anything: 598 of the 604 embedded images were byte-identical
    between the two archive.org copies, and every page that differed had the
    same byte length in both — the signature of corruption, not of a different
    scan. Watch for a watermark drawn as page TEXT in the second copy; redact
    it before rendering (`fitz` `add_redact_annot` + `apply_redactions(
    images=PDF_REDACT_IMAGE_NONE)`) or the repaired pages ship defaced while
    their neighbours are clean.

26. **A page may honestly have NO ayah fit.** Kuwait's two illuminated
    openings defeated every panel measurement, so they carry no entry at all
    and the reader gets no highlight on them — one line out on al-Fatiha is
    worse than nothing. This is why a per-page printing carries no `default`
    in `editions.json`: a page with no entry must fall through to nothing, not
    to an affine measured on a differently-set page.

27. **A downloaded zip unpacks under the ZIP's name, not the entry's.**
    `DownloadManager._unzipToDatabases` writes
    `basename(zipPath) + '.db'`, ignoring what the archive entry is called.
    `hadith.zip` has always worked only because those two names are the same
    word. The HadeethEnc packs were saved as `ar.zip`, unpacked to `ar.db`,
    and the repository opened `hadeethenc_ar.db` — so the download reported
    success, the unzip reported success, `flutter analyze` was clean, 66 tests
    passed, every pack had been range-checked on the bucket, **and the tab sat
    on its download button for ever.** Name a pack's local file after the
    database it becomes, and derive one from the other so they cannot drift.
    This is §1.3 in one sentence: **the bytes being on the bucket is not the
    feature working, and neither is a green test run.**

28. **`adb shell date` cannot set the clock on a Google Play emulator image**
    — no root, `Operation not permitted`. **`adb shell cmd alarm set-time
    <epoch-millis>` can**, and it is how a scheduled notification was made to
    fire within two minutes instead of waiting for Fajr. `settings put global
    auto_time 0` first. Jumping the clock *past* pending alarms fires them all
    at once, so jump to just before the one you want to watch.

29. **A notification's text is frozen when the alarm is ARMED, not when it
    fires.** `.tr()` runs at schedule time and the resulting strings sit
    inside AlarmManager until they are shown. Changing the app's language did
    nothing to the fifteen already-armed prayer reminders, so tomorrow's Fajr
    reminder stayed in yesterday's language until the next times fetch.
    Anything that changes wording has to re-arm — `RafeeqApp` does it on every
    locale change.

30. **`Localization` and `Translations` are not exported by
    `easy_localization`.** A test that wants the real `plural()` has to import
    them from `package:easy_localization/src/…` and **must** pass
    `ignorePluralRules: false`, exactly as `main.dart` and `adhan_entry.dart`
    do — otherwise the package's fallback collapses Arabic's six CLDR cases
    into zero/one/two/other and `few` becomes unreachable, which is the
    difference between «١٠ دقائق» and «١٠ دقيقة».

31. **One tap handler owns every notification in the app.**
    `FlutterLocalNotificationsPlugin()` is a singleton and `initialize`
    installs exactly one `onDidReceiveNotificationResponse`. Five services
    were each calling it and two passed `(_) {}`;
    `PrayerStatusNotification`'s empty one is installed lazily from
    `AppShell`'s first frame — *after* `main()` — so it won, and **every**
    notification tap in the app was thrown away. The سنن السور reminder had
    been dead that way for as long as it existed, invisibly, because a tap
    that opens the app on the screen it was already on looks like it worked.
    `NotificationRouter` is the only caller now and
    `test/notification_router_test.dart` fails the build on a second one.

32. **`inexactAllowWhileIdle` is not an interval.** A quote slot armed for
    02:35 had still not fired at 02:43 — Doze batches inexact alarms. When
    the owner picks «كل ١٥ دقيقة», use `exactAllowWhileIdle`; the app already
    holds the permission for the adhan. And keep the count down: exact alarms
    are a real ask.

33. **Android drops a package's notifications past 25 posted.** Twenty-four
    undismissed quote notifications spent the whole budget and the app could
    no longer post anything else. Anything that posts repeatedly needs
    `timeoutAfter` so it clears itself.

34. **A Shamela edition puts the EDITOR's footnotes in the body stream, and
    its isnads are fully diacritised.** «صيد الخاطر» interleaves «١ التحقيق:
    أي تفصيل المسائل…» with Ibn al-Jawzi's own text and welds superscript
    markers to words as Arabic-Indic digits; «روضة العقلاء» writes
    «حَدَّثَنَا», which `"حدثنا" in t` does not match — trap #2 again, in a
    new place. Read real pages before writing the filter, and compare on a
    diacritic-stripped copy while keeping the original verbatim.

35. **Ayahs and hadith are marked typographically, not by wording.** These
    editions set an ayah in plain `{ }` — not `﴿ ﴾` — and a hadith in doubled
    parentheses `(( ))`. A filter that only looked for `﴿` shipped four
    floating ayahs and a hadith of Muslim's with no grading, which is exactly
    what §1.2 forbids.

36. **A catalogue nobody opened is a catalogue of claims.** Six of the ten
    adhan background clips were not the scene the app named them — a flag of
    Pakistan was «رحاب مسجد», gold calligraphy was «الكعبة المشرّفة عن قرب», a
    cartoon was «ساحات الحرم المكي», a Turkish city was «رحاب المسجد النبوي».
    ffmpeg reads four frames from across a clip in seconds
    (`contact_sheet_adhan_videos.py`); the resolution was checked first and
    was the *smaller* problem. **Look at the frames of anything you catalogue,
    and record what you saw** — `adhan_video_content.json` is that record and
    a test checks the catalogue against it.

37. **`BoxFit.cover` on a portrait screen is a magnifying glass.** A 640×360
    landscape clip drawn full-screen on a 1080×2400 phone is scaled 6.7× and
    most of its frame is cropped away. Whatever is first in a catalogue is
    usually the default; make the default the one that fits.

38. **Wikimedia refuses a User-Agent with no contact in it.**
    `upload.wikimedia.org` answers **429 to every request** from
    `SomeApp/1.0 (personal)` and 200 to
    `RafeeqAlDarb/3.10 (https://github.com/... ) curl/8`. Its API throttles
    bursts as well, and a helper that swallows the failure and returns `{}`
    turns "you are being rate-limited" into "there is nothing there" — the
    Commons search reported «0 of 105 are public domain» for exactly that
    reason. Same family as trap #19.

39. **A Windows filename cannot contain `?`, and curl will not tell you.**
    Commons' API appends `?utm_source=…` to every file URL; naming the
    download after the URL gave curl a path it could not create and it
    reported **`code=200 size=0`** for all 37 files. A 200 that writes nothing
    is the most misleading success there is — name a download after your own
    slug, and check the size.

40. **Read the response you are going to parse, not its cousin.** The
    HadeethEnc record for a translation carries `words_meanings_ar`; the
    **Arabic** record carries `words_meanings`, with no suffix, exactly as it
    carries `hadeeth` and `grade` unsuffixed. A crawl written from the English
    response fetched all 3,574 Arabic records and stored 3,574 empty
    glossaries before anyone noticed. §1.4, applied to the specific call you
    are making.

41. **The release APK is signed OUTSIDE Gradle, and Gradle still says debug.**
    `build.gradle.kts` deliberately keeps `signingConfig =
    signingConfigs.getByName("debug")`; `scripts/sign_release.py` re-signs the
    built APK with the real key afterwards. **Never publish `flutter build
    apk` output directly** — it is debug-signed, which is how every release up
    to and including the first upload of v3.12.0 shipped.

    The reason it is done this way: switching keys normally forces an
    uninstall, and this app holds hundreds of MB of downloaded mushaf pages
    that an uninstall destroys. APK Signature Scheme v3 allows a
    **SigningCertificateLineage** — a signed proof that the new key inherited
    from the old — and Gradle's DSL has no field for one.

    Two things that cost time here:
    * `apksigner sign --lineage` **refuses** unless the *oldest* signer is
      passed too (`--ks <debug> --next-signer --ks <release>`). The v1/v2
      blocks stay signed by the old key so a device that cannot read v3 still
      sees an update rather than a signature mismatch.
    * It defaults to `--rotation-min-sdk-version 33`, which silently leaves
      Android 9–12 on the old key. Pass `28`.

    And verify it the way it is actually consumed — one `apksigner verify`
    hides half the answer, because the certificate presented **differs by
    Android version**. The script runs it twice (`--min-sdk-version 28`, then
    `24`–`27`) and refuses to finish unless the new key covers 9+ *and* the
    old one still covers below it. Proven on the emulator: the signed APK
    installed over the debug-signed 3.11.1 with `adb install -r` → `Success`,
    and all 358.5 MB of downloaded content survived.

    **The keystore lives in `../Rafeeq-Keys/`, outside this repository, and is
    the owner's to back up.** If it is lost, no further update can ever be
    installed over the app without an uninstall.

42. **A chapter number is not always an integer, and one row that isn't took a
    whole collection down.** Sunan an-Nasa'i's «كتاب المزارعة» is numbered
    **35.2** — a real sub-book between 35 and 36, carrying 83 hadiths, stored
    by SQLite as a REAL. `HadithChapter.fromRow` read it with
    `r['chapter_no'] as int`, which throws `type 'double' is not a subtype of
    type 'int'`; and because the cast runs while mapping the result set, the
    throw lost **all 52** of that collection's books, not just the odd one.

    Two lessons, both cheap:

    * **`X as int` on a database row is a claim about the data.** Check it.
      `py -3 scripts/db_type_audit.py` finds every non-nullable `as int` in
      `lib/core/db/` and asks the bundled databases whether that column really
      holds integers everywhere. Run it after any DB rebuild. As of this
      writing it clears every other column across all three databases — 67k
      hadiths, 42k tafsir rows, 83k word meanings — so those two were the
      only mines.
    * **Do not "clean" the data to fit the code.** Rounding 35.2 to 35 merges
      two books, renumbering it to 36 pushes every later book out of step with
      the printed edition, and deleting it drops 83 hadiths. The column was
      widened to `num` and the label prints «35.2» as the source writes it.

    And the reason it was findable at all: the screen used to render the throw
    as a **spinner** (`if (!snapshot.hasData)` — see `FutureView`), so for
    however long it had been broken it looked like a slow load. An error that
    is invisible is an error nobody can report properly.

---

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

---

## 6. When the owner says «جهّز الدنيا» / asks for a handover

This is a standing, mandatory routine. Do all of it:

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

Never hand over a state you have not just verified.

---

## 7. The next-session prompt — a standing instruction

> «لما تكتب برومبت للسيشن الجاية يكمل من عند ما انت وقفت، ولو وقفت في حاجة
> خليه يرجع يعملها تاني، ودايما تصدّر البرومبت في ملف .md جاهز للنسخ.»

Every time you write a prompt for the next session — asked for it or not, at a
handover or when the quota is closing — all three of these hold:

1. **It resumes exactly where you stopped.** Not a summary of the project: the
   next instruction, in order, starting from the thing your hands were on. Name
   the file, the command, the screen.

2. **Anything you left half-done is named as half-done, and the next session is
   told to redo it — not to trust it.** This is the whole point of the rule.
   "Applied but never run", "committed but never opened on a device", "the crawl
   was at 2,900 of 25,000", "the emulator was on the wrong screen" — each of
   those is a *first* item for the next session, not a footnote. If you cannot
   say whether something works, say that, and say to do it again.

3. **It is written to `NEXT_PROMPT.md` in the repo root, ready to copy whole.**
   A prompt buried in a chat reply is lost when the session is. `NEXT_PROMPT.md`
   is the thing the owner pastes; it is rewritten every time, and it is
   committed with everything else.

`NEXT_PROMPT.md` is the paste-ready message. `NEXT_SESSION_PROMPT.md` remains
the long brief it points at — the two are not the same file and neither
replaces the other.
