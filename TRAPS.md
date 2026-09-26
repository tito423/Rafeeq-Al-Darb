# TRAPS — what this project has already paid for

Moved out of CLAUDE.md on 2026-09-24 so CLAUDE.md stays small enough to load every session. **Read the entry before touching its area.** CLAUDE.md §3 keeps a one-line index.


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

   **And the header must stay OFF.** On 2026-09-18 four books were found
   carrying `Content-Encoding: gzip` on R2. Dio unpacks those transparently,
   so the device stores the *decompressed* file, `isBookDownloaded`'s size
   check fails, and the book downloads, indexes 2,010 pages, and still shows
   «تنزيل» for ever. Never upload a book with `ContentEncoding`;
   `py -3 scripts/fix_book_content_encoding.py` strips it in place and
   checks all books on the public endpoint.

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

    **And it reaches the EMULATOR, where it looks exactly like an app bug.**
    Every hosted download inside the app fails on `emulator-5554` with
    `HandshakeException … CERTIFICATE_VERIFY_FAILED: unable to get local
    issuer certificate`, and the screen shows «يلزم تنزيل نصّ الدروس» as
    though the feature were broken. Proven, not assumed: a handshake to
    `pub-…r2.dev` from this machine is answered with a leaf whose
    **`Issuer: CN=Avast Web/Mail Shield Root`** — Avast re-signs it, and that
    root is in the Windows store, never in the emulator's. Dart does not read
    the Windows store.

    Two things follow. **Prove it is the environment before touching code**:
    open a feature that already works on the owner's phone (the level-two
    tajweed course) and watch it fail identically — that took one minute and
    settled it. **Then see the screen anyway**, by putting the real hosted
    file where a successful download would have put it, which needs a
    `--debug` build because `run-as` refuses a release one:

        adb -s emulator-5554 shell "cat /data/local/tmp/x.b64 |           run-as com.tito.rafeeq_aldarb sh -c 'base64 -d > app_flutter/books/text/<id>.json'"

    Push the bytes the bucket serves **verbatim** — they are gzip and the app
    sniffs the magic itself (trap #6) — and remember `isBookDownloaded` wants
    a `book_meta` row too, so pull `databases/library_books.db` out with
    `run-as … base64`, insert the row with `py -3`, and push it back. Base64
    both ways; a raw binary through `adb shell` is not safe. And `adb root`
    is refused on this AVD, which is why all of it goes through `run-as`.

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
    ffmpeg reads four frames from across a clip in seconds; the resolution
    was checked first and was the *smaller* problem. **Look at the frames of
    anything you catalogue, and record what you saw.**

    The clips themselves are gone — the owner said «احذف الكليبات» once
    `AdhanScene` existed, so the catalogue, the settings toggle, the
    `video_player` pipeline in the adhan screen, the four pipeline scripts and
    the `adhan_video_content.json` record all went with them (the eleven
    objects still sit under `adhan/video/` on R2, ~74 MB, untouched). The
    lesson stays, because it is about catalogues, not about video: **a
    catalogue nobody opened is a catalogue of claims.**

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

43. **`SystemChrome.setEnabledSystemUIMode` is PROCESS-WIDE, and a kept-alive
    tab is never disposed.** `QuranScreen` hid the system bars for its
    full-screen mushaf and restored them in `dispose` — but it lives in
    `AppShell`'s `IndexedStack`, so it is built on the app's first frame and
    disposed never. One stored «ملء الشاشة» of true put the **whole app** into
    `immersiveSticky` for the life of the process, and that mode peeks the
    bars back on any interaction before hiding them again — so every keyboard
    open resized the window twice. That was the owner's «الشاشة بتعمل فليكر …
    في أي حتة في التطبيق», reported for months as a keyboard bug.

    Anything global — system UI mode, orientation lock, audio focus, a
    wakelock — set from a tab must follow `activeTabProvider`, the seam the
    Qibla compass already uses to park its sensor. `test/immersive_mode_
    scope_test.dart` holds it.

    **How it was found is the point.** `flutter analyze` and 196 tests had no
    opinion. `adb shell screenrecord`, 15 fps, ffmpeg to a contact sheet
    showed the keyboard bouncing up/part-down/up with the status bar flashing;
    `adb shell dumpsys window | grep statusBars` on a library search screen —
    which asks for nothing of the kind — said `visible=false`. And
    `dumpsys gfxinfo <pkg> reset` before the action and again after **counts
    the frames the action cost**: 43 frames / 101 ms median before, 10 frames
    / 32 ms after. Reset, act, read — and check the action really happened
    (the first attempt measured «0 frames» because `keyevent 111` had not
    closed the keyboard at all; `keyevent 4` does. Compare a screenshot's
    bottom third before and after, or the number is fiction).

44. **`Navigator.maybePop()` inside a `PopScope(canPop: false)` is a loop.**
    `maybePop` consults the route's `PopScope` first, so it hands the request
    straight back to `onPopInvokedWithResult`, which is usually the very
    handler that called it. The tutorial's «تخطّي» button looked right, was
    wired right, analyzed clean, and **did nothing at all** — the tour could
    only be left by finishing it. A screen that sets `canPop: false` so the
    back gesture routes through its own exit must call `pop()`, not
    `maybePop()`, and wants a re-entrancy guard because three paths reach it.

45. **`background_downloader`'s `registerCallbacks` diverts the updates
    stream — but only for status and progress.** Its doc comment says "tasks
    belonging to a group that has registered callbacks will not emit updates
    to the `updates` stream", which reads as fatal here: `DownloadEngine` and
    `DownloadManager` both live on that stream, so every progress bar and
    completion registry in the app would go silently dead. Read the package's
    own source before believing or dismissing it — in 9.5.9's
    `base_downloader.dart`, `_emitStatusUpdate` checks `groupStatusCallbacks`
    and `_emitProgressUpdate` checks `groupProgressCallbacks`, while
    `groupNotificationTapCallbacks` is read in `processNotificationTap` and
    nowhere else. So `taskNotificationTapCallback` **alone** is safe, and
    `test/download_notification_routing_test.dart` pins "alone".

46. **Git Bash rewrites an absolute path into a Windows one before `adb` sees
    it.** `adb pull /sdcard/kb.mp4 .` fails with
    «failed to stat remote object 'C:/Program Files/Git/sdcard/kb.mp4'». Set
    `MSYS_NO_PATHCONV=1` for that command, or double the leading slash
    (`//sdcard/...`). Same for `adb shell` arguments that start with `/`.

47. **Dart's `\w` is `[A-Za-z0-9_]`, and `unicode: true` does NOT widen it.**
    `RegExp(r'[^\w\s]', unicode: true)` was written in two places to mean
    "drop the punctuation". It matches **every Arabic letter**, so the two
    heading normalisers — `jazariyyahBare` and `tamhidBare` — returned the
    empty string for every Arabic input they were ever given.

    What that cost: both level screens drop the leading paragraphs that equal
    the lesson's own title, so a card does not print its heading twice. With
    every comparison `'' == ''`, that loop ate **the entire lesson**. Levels
    two and three opened onto a single «إتمام الدرس» button with no text above
    it, on every lesson, in a build where `flutter analyze` was clean and 271
    tests passed.

    And the tests could not have caught it, because **they were the same
    comparison**: `expect(bare(first.text), bare(lesson.title))` passes
    perfectly when both sides are `''`. A test that compares two normalised
    strings must first assert the normaliser returns something —
    `test/lesson_heading_bare_test.dart` does exactly that, with real headings
    from each book, and it is what stands behind the two course tests now.

    Use an explicit class that names what to keep:
    `[^ء-ي٠-٩a-zA-Z0-9\s]`. And when a screen's job is
    to *hide* something, open it and check something is still there: this was
    found in one tap on the emulator, and by nothing else.

48. **Impeller drops the words of a Qur'an page drawn too large.** On
    2026-09-19 the owner photographed page 316 in landscape on his Honor
    with «قالوا يموسى إما أن» simply not drawn. On emulator-5554 the same
    thing reproduced only when the page was zoomed two-fold: every word
    vanished and the small ayah markers stayed. The page SVG was drawn as
    live vector paths (`SvgPicture`, `RenderingStrategy.picture`, the
    default), re-tessellated at whatever size a zoom or a wide landscape
    screen asks for, and the big word paths are what gets dropped.

    `mushaf_page_view.dart` now uses `RenderingStrategy.raster`: the page
    is drawn once into an image at its own size and that image is scaled.
    Zoomed text is a little softer; it is never missing. Removing the
    colour-filter and backdrop-blur layers (`inkedSvg`) came first and was
    not enough on its own. **Never draw a mushaf page as live vector paths
    at an unbounded scale**, and when checking a Qur'an screen, zoom in —
    that is what makes this failure visible on an emulator.

49. **"It plays" is not "it is heard" — and a phone can mute ONE app.**
    On 2026-09-23 the recitation was silent on the owner's Honor for every
    reciter, over the speaker and over Bluetooth, while the adhan played.
    The highlight moved, no error showed, media volume was at maximum. The
    cause was not in the app: Honor (and Xiaomi, and others) keep a
    **per-app volume slider** — press a volume key, open the full panel —
    and «Rafeeq Al-Darb» was at zero. Nothing the app can call reads it.

    Two lessons, one about the phone and one about method:
    * **Ask about the per-app slider first** when sound is missing but the
      position moves. The in-app «لا تسمع التلاوة؟» tips say so.
    * **An AudioTrack line in logcat and a moving highlight prove the
      decoder runs, not that anything is audible.** The emulator had been
      "verified" that way all day. The honest check is
      `adb shell dumpsys media.audio_flinger` WHILE it plays: the app's
      track row must be `Active yes`, `Usg 1` (media), `G db 0`, `PortMuted
      false`. And read the pid/session before believing a mute: a `muted
      source:clientVolume` event seen first here was the SPLASH video,
      muted by setting — not the recitation.

---

50. **just_audio 0.10 reports a failed source on `errorStream`, as a value.**
    `playbackEventStream` carries no stream error for it (just_audio.dart
    0.10.6, `_errorSubject`). A listener on `playbackEventStream(onError:)`
    was deaf: with the network cut, continuous recitation sat idle for good.
    `maxSkipsOnError` defaults to 0 and must stay 0 — above 0 the library
    SKIPS failed sources, which the owner forbids (never skip an ayah).

51. **R2 objects stored with `Content-Encoding: gzip` come back INFLATED to a
    client that does not send `Accept-Encoding: gzip`.** Copying the 45
    translations to the GitHub mirror, the byte count no longer matched the
    object and the size check (rightly) refused all 45. Send
    `Accept-Encoding: gzip` when you want the stored bytes.

52. **`permission_handler` 13 → `permission_handler_android` 14.1.0 needs
    AGP 9** (`kotlin { compilerOptions {} }` at top level) and fails the
    release build on this project's AGP 8.11 — while a debug build and
    `flutter analyze` passed. Stay on 12.0.3 until the project moves to AGP 9.
    Proof of an upgrade is `build_github_release.bat`, not a debug run (§1.8).

53. **The emulator's `-tcpdump` captures nothing here; `-http-proxy` does.**
    To prove which host served a file (2026-09-24, C1 backgrounds), a
    `-tcpdump` capture came back 14 KB with not even a DNS query in it. Start
    the emulator with `-http-proxy http://127.0.0.1:8899` behind a tiny
    logging CONNECT proxy instead: every TCP connection from the guest goes
    through it (checked with `nc example.com 80` from `adb shell`). It logs
    IPs, not names - map them with `Resolve-DnsName` / `adb shell ping`.
    Also: `pm trim-caches` does NOT evict `CachedNetworkImage`'s files -
    only `pm clear` forced a refetch; grant runtime permissions with
    `adb shell pm grant` so system dialogs do not sit on the screen.

54. **Never run `flutter test` (or any flutter command) while a release build
    is running.** 2026-09-24: `flutter test` regenerated
    `GeneratedPluginRegistrant.java` with the dev-only `integration_test`
    plugin halfway through `build_github_release.bat`, and
    `:app:compileReleaseJavaWithJavac` failed with `package
    dev.flutter.plugins.integration_test does not exist`. Nothing was wrong
    with the code; rebuilding alone passed. Likewise do not edit `lib/`
    during a build - an APK built at 14:40 turned out NOT to contain an edit
    made while it compiled (seen on the device: the old title).

55. **`cp.bat` commits TRACKED files only - a new file stays out until you
    `git add` it.** 2026-09-24: the four new files of the initial-downloads
    screen were never committed; v3.61.0's APK (built from disk) was fine, but
    a checkout of the tag did not compile (fixed in 6b679984).
    `scripts/checkpoint.ps1` now prints `UNTRACKED SOURCE - git add these:`
    as its LAST line when lib/, test/, catalogs or scripts/*.py hold an
    untracked file. Before a release, also run `git status --short`.

56. **Restarting this emulator (`adb emu kill`, then `-no-snapshot-save`)
    resumes an OLD quickboot snapshot - the installed APK and every app
    setting go back with it.** 2026-09-25: a manual place set on build 11
    was «gone» after the restart; `dumpsys package` showed
    `lastUpdateTime=01:56:56` - build 9's install time, not build 12's -
    and airplane mode was back off. Not an app bug. After EVERY emulator
    restart (and trap 24 forces one per release build): `adb install -r`
    the APK again, check `lastUpdateTime`, and redo any setting the test
    depends on.

57. **Since the Windows restart of 2026-09-26 18:37 the emulator WINDOW hangs
    the whole emulator; `-no-window` boots fine.** Every AVD (phone, Google
    TV), with both the E: and the original C: emulator binary, with
    `-gpu host`, `-gpu swiftshader_indirect`, `-accel off` and `-no-audio`,
    logged `detected a hanging thread 'QEMU2 CPU0 thread'` within 5 s,
    qemu CPU time froze at ~2 s and adb never saw a device. The same AVD
    with `-no-window -no-audio -no-snapshot` booted in 85 s (0 hang lines)
    and the release APK installed and ran. So it is not the move to
    E:\DevEnv and not WHPX. Launch headless:
    `E:\DevEnv\Android\Sdk\emulator\emulator.exe -avd Medium_Phone_API_36.1 -no-window -no-audio`
    and take screenshots with `adb exec-out screencap -p`. Delete stale
    `*.lock` files in the .avd folder after killing a hung emulator.
    Update (2026-09-26 23:52): headless with the default host GPU then
    CRASHED twice (`qemu-system-x86_64-headless.exe` 0xc0000005, right after
    `ERROR | bad color buffer handle` lines), once 19 s after an `adb
    install`, leaving the package half-registered (`pm list packages` did
    not list it, `am start` said the activity does not exist) until it was
    installed again. `-gpu swiftshader_indirect` has run without a crash
    since. Launch: `emulator -avd Medium_Phone_API_36.1 -no-window -no-audio
    -gpu swiftshader_indirect`.
