# HANDOVER — Rafiq Al-Darb (رفيق الدرب)

**For:** the next AI agent picking up this project (Claude Code, Antigravity,
Cline, or any other).
**Read `CLAUDE.md` first — it is the mandatory working method — then this file.**

| | |
|---|---|
| **Last updated** | 2026-09-12 |
| **Released** | **v3.19.0** — tag on `master`, one release in the repo — **published without a device run** (owner's call, quota at 93%) |
| **App version** | `pubspec.yaml` `3.19.0+18` |
| **Signing** | the published APK was downloaded back from GitHub and checked: `CN=Rafeeq Al-Darb, OU=Personal, O=tito423, L=Cairo, C=EG` on Android 9+, and the old debug certificate still below it, so every install path is an update. **Gradle signs debug on purpose — run `py -3 scripts/sign_release.py` after every release build (trap #41).** |
| **Verified today** | `flutter analyze lib test` clean · `flutter test` **186 passed** · on emulator-5554 (signed release 3.18.0): verse tap opens the card with media NONE; continuous recitation from the selected 3:25 (media PLAYING «3:25», page unmoved); a 110-surah recitation kept downloading with the app at HOME (8 done in 90 s, 10 on return, nothing restarted); device scan found a pushed mp3 under its folder and played it; favourites, ten themes, disc; sunan reminder on two days; splash-sound switch present; library tab «الموسوعة الحديثية». Rebuilt APK after the fixes: tasks released 1, 2, 3, 4, 5 in order; downloads overview shows 3 running + «في الانتظار · 97»; reciter jump and back-to-top; finished track shows play and replays; scan reports its count; selected verse stays marked in the flowing layout |

## STATE AS OF 2026-09-11 (night) — v3.19.0: the tenth batch, NOT yet seen on a device

Read `WORK_QUEUE.md` J1–J26. Verified: `flutter analyze lib test` clean, `flutter test` 197 passed, and the Qur'an search modes and topic patterns measured over `quran_local.db` (scratchpad scripts `measure_search.py`, `measure_topics2.py`, `extract_words.py`; the numbers are in WORK_QUEUE J11/J12). **Not verified: everything on screen.** In short: a tap anywhere on a mushaf page toggles full screen, a long press opens the verse card, landscape stays full screen; «الانتقال إلى» is a surah/page/juz sheet; the scrollbar is a new rail (`arrow_scrollbar.dart`); search has derivatives/partial/exact + diacritics (`quran_search_match.dart`, `QuranRepository.searchQuran/searchTopic`) and topics list every verse their measured patterns find; ruqyah plays in the Qur'an player with its own download group; adhans azan15/azan17 removed; high-latitude option removed; clock gallery, qibla card and faces take the hero surface's colours; RGB backdrop, toolbar and nav icons animated.

## STATE AS OF 2026-09-11 — v3.18.0: the eighth and ninth batches

Read `WORK_QUEUE.md` I1–I13 and G1–G9; each says what was seen. In one paragraph: whole-surah downloads run in background_downloader's **native holding queue** as foreground work (the Dart queue did not advance with the app in the background) — tasks carry a creation time spaced in surah order, because the native queue orders by priority then creation time and a batch built in one millisecond came out in arbitrary order. A tap on a verse selects it and opens its card; «تلاوة الآية» plays that verse; the continuous recitation starts from the selected verse. The player has favourites, ten themes, a turning disc, and a MediaStore scan of the device grouped by folder, album and artist. Every vertical scroll view has an arrow scrollbar (`ArrowScrollBehavior`, `lib/core/widgets/arrow_scrollbar.dart`). Sunan reminders take several days. Unseen: the adhan playlist switch and cross-fade, the adhan text timing against a real adhan, landscape continuous recitation, the reciter-screen jump and back-to-top taps, everything on his own phone.

## STATE AS OF 2026-09-11 (night, last) — v3.17.2

Continuous recitation is offered only in the text mushaf (the button is gone from image pages). Choosing the image mushaf — by the mode button or from «المصاحف» — opens it full screen, and a tap shows its options. Picking a printing from «المصاحف» always opens it as the mushaf view (picking the vector Hafs used to leave the reader in text mode). Reciter badges show their list number, centred. See `WORK_QUEUE.md` F1–F4.

## STATE AS OF 2026-09-11 (night, later) — v3.17.1: the sixth batch

Read `WORK_QUEUE.md` E1–E8. In one paragraph: continuous recitation is **text-mushaf only** (the Tajweed printing's page 77 highlighted 4:3 a line low); the surah being recited is loaded whole and moved within by seek; the recitation bar has a reciter picker; the section is «مشغّل تلاوة القرآن» with a typeset cover; the prayer card is posted natively by `PrayerCard.kt` with a delete intent that re-posts it; repair steps have deadlines and stalled whole-surah transfers are re-queued; an adhkar `errorWidget` that threw in the release log is fixed. APK 347,222,322 bytes.

## STATE AS OF 2026-09-11 (night) — v3.17.0: the fifth batch

Read **`WORK_QUEUE.md`** D1–D6 first; each item says what was seen and what was not.

* **Per-ayah recitation downloads are gone.** The reader streams (everyayah, then islamic.network). Old files under `documents/recitations/` and their platform tasks are purged once at launch — 280.2 MB on the emulator.
* **«تحميل تلاوات القرآن»** (More) — `lib/features/quran_audio/`: mp3quran API v3, whole-surah downloads on `DownloadEngine.quranAudioQueue` (3 wide, 2 per host), a library indexed as reciter → recitation folders in `documents/quran_audio/library.json`, device files, and a full player on the app's single `AudioPlayer` (`AyahAudioService.claimForMusic` / `musicOwnsPlayer`).
* **The Hadeeth Encyclopaedia is bundled** — 7 zips in `assets/data/hadeethenc/`, 15.9 MB, unpacked per language on first open. The Home card draws only from it.
* **Mushaf downloads are remembered** (`mushaf.wanted_downloads_v1`) and resumed at launch; progress lives in the foreground service's notification (`DownloadForegroundServiceBridge.update`), never in an `ongoing` one.
* **Header rule** reads first AND last page per surah (`page_surahs.dart`).

## MEASURED, 2026-09-11 (night) — v3.17.0

| | |
|---|---|
| release APK | 347,173,170 bytes (was 330,194,494; +15.9 MB of encyclopaedia packs) |
| tests | 176 |
| mp3quran catalogue | 241 reciters · 287 recitations (ar), measured live |
| history | 355 commits before the release commit |

## MEASURED, 2026-09-11 (not remembered)

| | |
|---|---|
| locales × keys | 7 × 1,032 |
| mushaf editions | **6** — three were removed for having no ayah coordinates |
| library books | 228 |
| `hadith.db` | 109,731,840 bytes · 9 books · 1,482 chapters · 67,153 hadiths · 45,219 graded (67%) |
| Hadeeth Encyclopaedia | 7 language packs · 3,574 hadiths in Arabic, **every one with an explanation** |
| adhans | 14 · nothing below 48 kb/s · loudness spread 6.5 dB |
| release APK | 330,194,494 bytes |
| code | `lib` 190 files / 50,056 lines · `test` 41 files / 3,394 lines |
| history | 351 commits |

## WHAT v3.16.0 FIXED, and the one thing it did not

**The download jam.** `MemoryTaskQueue.advanceQueue` counts a task as active
the moment it hands it to the platform, and on a refused enqueue it neither
removes it nor decrements the counters — so every refusal burns one slot for
the life of the process, eight kill the file queue and twelve kill the
recitation queue, and repair then adds to a queue with no slots left. The app
now listens to the plugin's `enqueueErrors` (nobody did), gives the slot back,
and retries up to three times; and repair unjams against the platform's live
task list before it does anything else. **The jammed state itself has never
been reproduced on a device — only the healthy path was seen.**

**A correction that cost a rebuild and was worth it.** The stall was first
blamed on WorkManager's four-thread default executor, read correctly out of
`work-runtime-2.11.0.aar`. A 20-thread pool was written, shipped into a
checkpoint, then **measured on the device and reverted**: 20 threads gave 11
established connections, a deliberately narrowed 2-thread pool gave 10.
`TaskWorker` is a `CoroutineWorker`, so the transfer never occupies a
WorkManager thread at all. Reading gives a hypothesis; the device decides.

## STATE AS OF 2026-09-11 — two rounds of his own findings, and the ANR explained

He installed each release, used it, and sent findings with screenshots. Two
batches, tracked in **`OWNER_FINDINGS.md`** (the first) and **`WORK_QUEUE.md`**
(the second, A1–A7). Read those before this file: they say, item by item, what
was seen on a device and what was not.

### The ANR, measured at last

Every normal tool failed on it — `dumpsys gfxinfo` reports zero frames for a
Flutter app, `SurfaceFlinger --latency` returned no rows on Android 16, and
`flutter run --trace-startup` produced no `start_up_info.json` on this machine.
The answer came out of the system log:

    ANR in com.tito.rafeeq_aldarb
    Reason: Process ... failed to complete startup

Not the input-dispatch kind. Android gives a process ten seconds to finish
binding; in the same log the runtime reported **65 slow class verifications
totalling 9,724 ms** — the whole budget — before app code ran. 45 of them were
`androidx.work`, dragging Room, SQLite and coroutines with it, because
`androidx.startup` initialised WorkManager in a ContentProvider on **every**
process start. Both ANRs were on a process woken by a scheduled-notification
broadcast that had no use for WorkManager at all.

`RafeeqApplication` implements `Configuration.Provider` and the manifest
removes only the `WorkManagerInitializer` meta-data. After: **0 slow
verifications, 0 ms, 0 ANRs**, and a book downloaded on the R8 release build to
prove on-demand initialisation did not silently break `background_downloader` —
which was the whole risk of the change.

**He has never seen this ANR.** The emulator is x86_64 with no AOT profile, so
it verifies every method at runtime; a real ARM phone verifies a fraction. Do
not tell him it fixed something he reported.

### What else this round changed, and what proved it

* **The running header named the wrong surah** — «سورة يوسف» over the close of
  Hud. A page is not a surah; every surah on the page is named now. Seen on
  page 235.
* **One fractional chapter number lost a whole collection.** an-Nasa'i's
  «كتاب المزارعة» is chapter **35.2** with 83 hadiths; `as int` threw and took
  all 52 books with it. `scripts/db_type_audit.py` now checks every
  non-nullable int cast against the real databases and clears the rest.
* **The Qur'an search could not see half the Qur'an.** «الرحمة» found 6 ayahs of
  72 — a space-only word boundary cannot see «وَرَحْمَةٌ», and a query carrying
  the article only matched the article form.
* **Downloads were not stalling, they were queued two at a time.**
* **Only the adhan may take the lock screen now.** `MainActivity` declared
  `showWhenLocked` in the manifest *and* in code, so every notification tap
  opened the whole app on a locked phone.
* **The adhan list is his**: three removed by name, Mishary's four in
  (two of them Fajr), everything levelled to one EBU R128 target.

---

## STATE AS OF 2026-09-10 — v3.13.0: his findings, from real use

He installed v3.12.0, used it, and sent fifteen findings with screenshots.
`OWNER_FINDINGS.md` is the working list and says, item by item, what was seen
on a device and what was not. Do not restate it here; read it.

The two that mattered most, both content-correctness on the Qur'an screen:

* **The running header named a surah the reader was not looking at.** The rule
  was "the last surah whose start page is at or before this page", which at a
  boundary page names the surah that *begins* rather than the one filling the
  screen. His page is 235: Hud's last verses, Yusuf beginning below. Now every
  surah on the page is named. `page_surahs.dart` + six tests on the real
  Madinah page numbers.
* **Picking a surah could land on a different one.** Three of the nine
  printings paginate their own way while the surah→page table is the Madinah
  604's. The two indexes that would navigate wrong are withheld on those three.

On the adhan: the bundled files are byte-identical to their archive.org
sources, so nothing is mis-mapped — but **six of ten were encoded at 16 kb/s**
and the fourteen ranged over **21 dB** of loudness. Five now use much better
takes of the same muezzin and all fourteen are levelled. Who the muezzins
actually are is still unverified and still his to judge by ear.

Also fixed and seen: landscape (the toolbar's fixed 116pt height left the
Qur'an ~80 logical pixels), the adhan picker's frozen tick (a pushed route
handed captured values), the ruqyah transport, the adhkar grounds, hadith card
navigation. Fixed and NOT yet seen: the cold-start quote notification, the
endless-spinner path, the explanation button.

**The ANR is open.** Twice on debug (`Waited 5007ms for MotionEvent`), not
reproduced on profile. Two rebuild loops on Home were removed — real waste,
not a claimed cause.

---

## STATE AS OF 2026-09-10 — v3.12.0: the audit, and the two things it found

The owner asked for a full pass — organisation, maintainability, usability,
security, ease of future maintenance — and specifically for the permission
prompts to stop landing on the splash. Findings, all measured:

### Permission timing (fixed, verified)

The dialog was never on the splash. Measured on a fresh install: splash ended
~12s, onboarding appeared ~13s, and the location dialog landed at ~15s **on
top of the onboarding screen**, over the mushaf picker.

`AlarmPermissionsService.requestStartupGrants()` is now called from
`AppShell`'s first frame (900 ms in), and the splash asks for nothing.
`PrayerStatusNotification` also used to call
`requestNotificationsPermission()` on init, which jumped ahead of location;
removed, so location comes first. Re-measured: nothing interrupts the splash
or the onboarding, and the dialog appears 2.1s after onboarding ends, on Home.

### Two orphaned download categories (fixed, verified)

`hadeethenc` and `ruqyah` were enqueued under `DownloadManager` category
strings no bucket in `DownloadCategoryX.managerCategories` claimed. The bytes
sat on disk while the storage hub said "Nothing downloaded" and its delete
button skipped them. On device, after downloading the English pack: the Hadith
row went from empty to `1 · 10.4 MB` with a working delete, total
348.1 → 358.5 MB.

While fixing it I made `mushafs` count twice — the header read 696.2 MB over a
single 348.1 MB row. Caught on the screenshot, not in review.
`StorageSummary`'s constructor now asserts one entry per category.
`test/downloads_categories_test.dart` reads the `category:` literals out of
`lib/` and fails on any that no bucket claims; proven to reproduce the original
complaint before it was trusted.

### Security — one real finding, awaiting the owner's decision

Measured, not assumed:

* No secrets tracked; no `.env`, keystore or key material in git.
* No `http://` anywhere in `lib/`; no WebView.
* 3 exported Android components, all necessary.
* R8 minify + proguard rules on in release.
* **The debug signing key — FOUND, and FIXED without any data loss.**
  Every release up to the first upload of v3.12.0 was signed with the Android
  debug key (`C=US, O=Android, CN=Android Debug`) — a key that ships with the
  SDK and whose password is the word "android", so anyone could build an APK
  that Android accepts as an update to this one.

  The obvious fix costs an uninstall, because Android refuses an update signed
  by a different key, and that destroys the downloaded mushaf pages. It was
  avoided: APK Signature Scheme v3 takes a **SigningCertificateLineage**, a
  signed proof that the new key inherited from the old one, and an APK carrying
  it updates in place.

  Done and verified:
  * RSA-4096 keystore, 30-year validity, in `../Rafeeq-Keys/` — **outside this
    repository**, with its password beside it. The owner has been told to back
    it up; if it is lost, no update can ever be installed over the app again.
  * `scripts/sign_release.py` re-signs the built APK with the lineage and
    refuses to finish unless the result really carries the release certificate.
    Gradle still signs debug — see trap #41; **never publish `flutter build
    apk` output directly.**
  * Measured on the published asset, downloaded back from GitHub:
    Android 9+ → `CN=Rafeeq Al-Darb, OU=Personal, O=tito423, L=Cairo, C=EG`;
    Android 7–8 → the old debug cert, so those devices still see an update.
  * Proven on the device, which is the only thing that settles it:
    `adb install -r` of the signed APK over the debug-signed 3.11.1 returned
    **Success**, and the Downloads screen still read **358.5 MB** afterwards —
    nothing was lost.

### Performance and smoothness — what could and could not be measured

* Cold start: `TotalTime: 2676` ms (`am start -W`).
* Memory: TOTAL PSS 111,961 KB (`dumpsys meminfo`).
* **Frame-level jank could NOT be measured.** `dumpsys gfxinfo` reports 0
  frames for a Flutter app (it renders on its own thread), and
  `dumpsys SurfaceFlinger --latency` returned no rows on Android 16. So there
  is no jank number in this handover, and any claim of "smooth" here rests on
  watching it, not on a percentile. A `flutter run --profile` session with the
  DevTools frame chart is the way to get a real one.

### Code health (`py -3 scripts/code_health.py`)

178 files / 47,028 lines in `lib`, median 163. 23 test files / 2,155 lines
(5% of lib). 15% comment lines. **No dead code**: the one name the script
flagged (`DownloadCategoryX`) is used on five lines — Dart extension names
never appear at the call site, and that caveat is now written into the script.

One TODO left, `lib/core/config/app_config.dart:13`: the default mushaf SVG
base is GitHub raw. Measured today — pages 001/050/200/400/604 all answer 200
in 0.4–1.0s at 196–626 KB, so it works; the note stands as a scaling caution,
not a defect for a one-user sideloaded app.

Five files are over 1,000 lines (`book_catalog.dart` 4,063 is pure data;
`library_screen.dart` 1,582 and `ayah_sciences_sheet.dart` 1,548 are the two
worth splitting when someone next has reason to touch them).

---

## STATE AS OF 2026-09-10 — v3.11.1: the Urdu question, answered by measuring

The owner asked «شوف الصح في موضوع الأوردو باللاتيني» — is Latin right for
Urdu? It has a measurable answer, so CLDR was asked through the `intl`
package the app already ships (`numberFormatSymbols[locale]`):

    ur   ZERO_DIGIT = '0'   1,234,567
    fa   ZERO_DIGIT = '۰'   ۱٬۲۳۴٬۵۶۷
    ps   ZERO_DIGIT = '۰'   ۱٬۲۳۴٬۵۶۷
    ar   ZERO_DIGIT = '0'   1,234,567

Persian and Pashto default to the **extended** Arabic-Indic digits (U+06F0,
which are not the Arabic U+0660 set). **Urdu defaults to Latin** — and so, in
modern CLDR, does Arabic. So the app was already right, and the two cases are
different in kind rather than inconsistent:

* Urdu keeps Latin because that is the standard and nobody asked otherwise;
* Arabic gets Arabic-Indic because the owner wants it in the Arabic UI, which
  is a deliberate departure from CLDR.

`test/digits_test.dart` pins both, so neither gets "fixed" by someone reading
only half of it.

**And writing that test found something worse than the question.**
`core/utils/digits.dart` was created earlier this session with a doc comment
saying it existed to end a duplicate. There were in fact **five** copies of
the conversion in the app — `digital_clock_faces.dart`,
`prayer_countdown.dart` and `quran_screen.dart` each carried their own digit
table and their own loop, and I had not looked. The test greps for the table
itself, which is what found them. One implementation now; the clock, the
countdown and the mushaf page number were each re-checked on the device
afterwards.

## STATE AS OF 2026-09-10 — EIGHTH SESSION, THIRD HALF (after v3.10.0)

### 12. Measured for v3.11.0

7 locales × **1,000** keys · **9** mushaf editions · **228** library books ·
HadeethEnc **3,574** hadiths in 7 languages, **2,538** of them now carrying a
word glossary, packs **16,860,292** bytes on the bucket · **352** quotes from
3 books · **11** photographic backgrounds, worst contrast **9.07 : 1** ·
**5** adhan clips, all verified frame by frame · **93** tests · **36** hosted
paths, 0 failed · APK **325,971,517 bytes** (the adhan upgrade adds ~39 MB across both bundle copies).

**A correction to v3.10.0's notes:** they said 227 library books. The real
number was 228 — the count came from `src.count('LibraryBook(')`, which
includes one occurrence that is not a catalogue entry.

### 8. The adhan video complaint — and what measuring it actually found

> «الفيديو بتاع الأذان لما بيشتغل بتبقى جودته سيئة جدًا»

`scripts/probe_adhan_videos.py` read every hosted clip with ffmpeg. Three of
the ten were standard definition, and the **640×360 one was the default** —
`adhan_presentation_provider.dart` falls back to `adhanVideoCatalog.first`.
The adhan screen is portrait and draws the clip with `BoxFit.cover`, so on a
1080×2400 phone that clip was being scaled **6.7×**. The background he saw out
of the box was the worst file in the set.

**Then the frames were looked at, and the resolution turned out to be the
smaller problem.** `scripts/contact_sheet_adhan_videos.py` pulls four frames
from across each clip; six of the ten were **not the scene the app named**:

| id | the app said | it actually is |
|---|---|---|
| `mosque_view` | رحاب مسجد | the **flag of Pakistan** |
| `kaaba_close` | الكعبة المشرّفة عن قرب | gold «محمد» calligraphy |
| `kaaba_tawaf` | الحرم والكعبة | the same calligraphy |
| `kaaba` | الكعبة المشرفة | a **cartoon** 3-D animation |
| `haram_makkah2` | ساحات الحرم المكي | the same cartoon |
| `madina_haram` | رحاب المسجد النبوي | an Ottoman mosque over a **Turkish city** |

The only three that matched their labels were the three SD ones. This is
§1.1's failure mode exactly — a catalogue written from uploads nobody opened,
the same shape as the eight mushaf editions whose pages were never there. And
the first version of the fix had made `madina_haram` the **default**, i.e. a
Turkish city labelled «رحاب المسجد النبوي» as the first thing the owner sees.

Five clips are gone (two cartoons, the flag, two lower-quality duplicates).
The five that remain are labelled for what their frames show, and
`adhan_video_content.json` is the record `test/adhan_video_catalog_test.dart`
checks the catalogue against. **No HD Haram footage was sourced**: Pixabay and
Pexels answer 403 without an API key, Mixkit's licence is rendered by
JavaScript and could not be read, and archive.org's CC video for this subject
is hour-long broadcast footage.

### 9. Photographic quote backgrounds — eleven, licence-checked one at a time

The owner asked for «صور من النت، كمية كبيرة وجودة عالية». The source had to
be one whose licence can be **read per file**, so it is Wikimedia Commons:
190 candidates from curated Islamic-ornament **categories** (a free-text
search had returned Hindu temple carvings from Karnataka), 37 public domain or
CC0, 18 downloaded — and then somebody looked at them and threw out seven that
were paintings of people, a page of an illuminated **Qur'an manuscript**, and
a snapshot with a wall clock and plastic bags in it.

The eleven that ship were measured through the exact scrim the card draws:
brightest 60-pixel region, worst case **9.07 : 1** against a 4.5 floor (trap
#15 — the composite, not the swatch). Bundled, not downloaded, so a
notification that fires with no connection still opens on a picture. Commons
is credited on the Sources screen and every file's licence, author and Commons
page is in `assets/data/quote_backgrounds.json`.

### 10. Smaller things

* **The prayer notification said the prayer's name twice.** The owner read the
  shade: «اقترب موعد صلاة المغرب» beside «بقيت ١٠ دقائق على صلاة المغرب» —
  Android collapses a group into «title · body», so both landed on one line.
  The body carries the number and nothing else now, in all seven locales.
* **`QuranTranslationInfo.sizeLabel` was the sixth copy of the byte
  formatter**, hand-built and missing the LTR isolate. It uses
  `formatBytesBinary` now and `test/byte_formatter_is_the_only_one_test.dart`
  fails the build on a seventh.
* **Urdu keeps Latin digits, deliberately.** Not an oversight: Pakistani Urdu
  digital text overwhelmingly uses ASCII digits, and the rest of the Urdu
  build already does.

### 11. Two of my own claims that were wrong, and the corrections

* **«The سنن السور reminder fires and posts nothing.»** Wrong.
  `mLastNotificationUpdateTimeMs = 0` is not a post counter — the prayer
  channel reads 0 with nine posted — and the notification was missing because
  the test's own 41-hour clock jump fired 24 quote slots at once and **Android
  drops a package past 25 posted**. Re-run properly it posts, reschedules for
  the following Friday, and its tap opens سورة الملك's reader.
* **«0 of 105 Commons files are public domain.»** Also wrong, and for the same
  kind of reason: Commons answered **429** to a burst and `api()` swallowed
  the failure and returned `{}`, which reads exactly like "there is nothing
  there". With pacing it is 37 of 190. `upload.wikimedia.org` additionally
  refuses any User-Agent with no contact in it — trap #19's family.

## STATE AS OF 2026-09-10 — EIGHTH SESSION, SECOND HALF (after v3.9.0)

### 5. Islamic-quote notifications — the owner's fourth request, working

A notification every N minutes the owner picks (15 · 30 · 1h · 2h · 3h · 6h ·
12h, or off), each carrying a **different** saying, and tapping it opens a
card inside the app that covers what is behind it, on an Islamic background
that changes at random, with a dismiss button in the interface language.
Verified on `emulator-5554` end to end: a slot armed for 02:49:58 posted at
02:50:03, was tapped, and the card opened **on that saying** with its book and
its author.

**Where the sayings come from, and what was refused.** 352 quotes from three
of the four books the owner named. `scripts/build_quotes.py` takes the
author's own prose and throws away anything carrying an ayah, a hadith or an
isnad — because a floating ayah with no reference and a hadith with no grading
are both things §1.2 forbids, and there is no grading to attach here. Four of
its filters exist only because real pages were read (§1.4):

* ayahs are marked with plain `{ }` in these editions, not `﴿ ﴾`;
* hadith are marked with doubled parentheses `(( ))`;
* «صيد الخاطر»'s edition puts the **editor's footnotes** in the same body
  stream as Ibn al-Jawzi's text, with markers welded to words as Arabic-Indic
  digits;
* «روضة العقلاء» sets its isnads **fully diacritised**, so `"حدثنا" in t`
  matched none of them — trap #2 in a new place.

**حلية الأولياء is in the library but is NOT a quote source**, and the script
says so at length. A hand-read sample of its 1,032 candidates carried a hadith
qudsi fragment, a hadith in guillemets, half an isnad and an editorial note on
a chain. Tuning the filter until the sample looked clean would have been
guessing at the rest.

**Both new books were crawled, built, uploaded and catalogued**: روضة العقلاء
(Shamela 6944, 276 pages, 177,994 bytes) and حلية الأولياء (Shamela 10495,
3,891 pages, 10 volumes, 2,498,616 bytes). 227 books.

### 6. Two defects the feature uncovered, both fixed

**Every notification tap in the app was being thrown away.**
`FlutterLocalNotificationsPlugin` is a singleton and `initialize` installs one
tap handler for the whole app. Five services were calling it, and two of them
passed `onDidReceiveNotificationResponse: (_) {}`.
`PrayerStatusNotification`'s empty handler is installed lazily from
`AppShell`'s first frame — after `main()` — so it won. The quote card did not
open on a tap; **neither had the سنن السور reminder, silently, for as long as
that code has existed.** `NotificationRouter` is the only caller now and
`test/notification_router_test.dart` pins it.

**A 15-minute setting was not 15 minutes.** With
`inexactAllowWhileIdle`, a slot armed for 02:35 had still not fired at 02:43.
Doze batches inexact alarms, and an interval the owner chose is not something
to hand to Android's convenience. `exactAllowWhileIdle` now, with the window
cut from 48 slots to 24 so the app is not holding 48 exact alarms for a nudge.

**And one the test flood exposed:** Android caps a package at 25 posted
notifications and drops the rest. 24 undismissed quotes can spend the whole
budget. Each quote now clears itself when the next is due (`timeoutAfter`).

### 7. A claim I made and then disproved: the سنن السور reminder is fine

Mid-session this was written up as "fires and posts nothing, first job for the
next session". **That was wrong, and both pieces of evidence behind it were
misread.**

* `dumpsys`'s `mLastNotificationUpdateTimeMs = 0` on the channel is not "no
  notification has ever been posted here" — `rafeeq_prayer_reminder` reads 0
  too, and it had just posted nine.
* The notification really was missing after the test — because the test
  jumped the emulator's clock forward 41 hours, which fired 24 quote slots at
  once. **Android caps a package at 25 posted notifications and drops the
  rest**, and the dump showed exactly 25 quote records. The surah reminder was
  one of the ones dropped, by the app's own flood.

Re-run properly — clock moved to 19:59, one real minute waited, quotes off —
it posted, rescheduled itself for the following Friday, and **tapping it
opened سورة الملك's reader**. Which also proves the `NotificationRouter` fix:
before it, that tap went to `PrayerStatusNotification`'s `(_) {}`.

The pile-up that caused the false alarm is itself fixed (`timeoutAfter`).

## STATE AS OF 2026-09-10 — EIGHTH SESSION, FIRST HALF (released as v3.9.0)

### 1. A prayer reminder was watched firing, and the wording it fired with was wrong

The seventh session proved the fifteen reminders **armed** with `dumpsys alarm`
and stopped there. This session moved the emulator's clock to 06:01 with the
before-Fajr alarm at 06:03, waited, and read the shade. It said:

```
اقتربت الفجر
باقٍ 10 دقيقة على الفجر
```

Three defects in two lines, none of which `flutter analyze`, the 62 tests or a
key-parity check could see, because every string involved was present,
non-empty and grammatical *as a template*:

* **«اقتربت» is feminine and four of the five prayer names are masculine.**
  No single verb agrees with `{prayer}`. The sentence is built on «موعد صلاة»
  now — the owner's own wording, «اقترب موعد صلاة {prayer}» — which agrees for
  all five.
* **«10 دقيقة» is the wrong number agreement.** Arabic counts 3–10 with a
  plural and 11–99 with a singular accusative. `_minutes()` hardcoded one
  unit. It is `prayer.minutes_count`, a plural key, in all seven locales now;
  the other six abbreviate the unit and do not inflect.
* **Latin digits beside the app's own Arabic-Indic ones.** The ongoing prayer
  card one row below in the same shade read «الفجر · ٠٦:١٣». `localizeDigits`
  in `lib/core/utils/digits.dart` is the one conversion table now — it was
  about to be written a third time.

Re-verified live: «اقترب موعد صلاة الفجر» / «بقيت ١٠ دقائق على صلاة الفجر».

**And a fourth defect the fix exposed:** a reminder's title and body are baked
into AlarmManager when it is **armed**, so switching the app's language left
tomorrow's reminders in the old one until the next times fetch. `RafeeqApp`
re-arms from the cached times on every language change. Verified: switched to
English, jumped to 06:18, and the iqama fired as «Fajr iqama — It is time for
the Fajr iqama».

### 2. موسوعة الأحاديث النبوية — the owner's stated top priority, now in the app

> «اهم حاجة ترجمات المواد العلمية خاصة الحديث من مصادرها الموثوقة»

A fifth Library tab, **beside** the nine books and not inside them. 3,574
records, and **every single one carries both a takhrij and a grading in the
reader's own language** — measured across all 15,498 (hadith, language) rows
by `scripts/build_hadeethenc_packs.py`: **0 ungraded, 0 without takhrij**.

* **One pack per language**, `hadeethenc/<lang>.zip` on R2, 1.3–3.5 MB, built
  by `build_hadeethenc_packs.py` and uploaded by `r2_upload_hadeethenc.py` —
  which refuses to write the bundled catalogue unless every object answers
  `PK` with a matching `Content-Length` from the public endpoint.
* **Category titles were refetched in all seven languages**
  (`hadeethenc_categories.py`). The crawl walked the tree in Arabic only, so
  building from it alone would have put Arabic section headings over Spanish
  hadiths.
* **The grading is never shown bare.** §1.2: it is always «الدرجة: … —
  تصنيف موسوعة الأحاديث النبوية», with the encyclopedia's own reference list
  under it. HadeethEnc names no individual scholar per hadith; the verdict is
  the encyclopedia's, and the reader is told so.
* **The publisher permits this, conditionally, and the conditions were read
  before a byte was uploaded** (trap #18). Its «الشروط والسياسات» modal
  (hadeethenc.com/ar/home, read 2026‑09‑10) allows redistribution given: no
  modification, addition or deletion; clear credit to publisher and source;
  the version number; no unbefitting ads. The app modifies nothing, credits
  the source on the collection screen, on every hadith and on the Sources
  screen, and carries no advertising. **The version number does not exist to
  quote**: the API returns no version field, `hadeeths/list/`'s `meta` is only
  paging, and the PDFs answer `Last-Modified: Thu, 26 Mar 2000`. Each pack
  therefore records the retrieval dates instead, and says so.
* **No FTS5** (trap #1). Search is a pre-normalised `search` column matched in
  Dart, paged 400 rows at a time (trap #4).
* **A new boundary test.** `wordBoundaryContains` treats any non-letter as a
  boundary. The two existing tests could not serve a corpus in three scripts:
  `arabicWordBoundaryContains` counts only a space (trap #3), and
  `LibraryApiService._boundaryIndexOf` counts anything outside U+0621..U+064A,
  which would match «the» inside «other».

**The bug that only a device could find.** The download succeeded, the unzip
succeeded, `flutter analyze` was clean, 66 tests passed, and every pack had
been range-checked on the bucket — and the tab sat on its download button for
ever. `DownloadManager._unzipToDatabases` names the extracted database after
the **zip's** basename, not the entry's, so `ar.zip` became `ar.db` while the
repository opened `hadeethenc_ar.db`. `hadith.zip` has always worked only
because those two names are the same word. `HadeethEncPack.zipFileName` now
derives from `fileName`, and `test/hadeethenc_pack_test.dart` was proved to
reproduce the device's exact complaint before it was trusted.

Verified live in Arabic and in English: the download, the seven sections with
their measured counts (197 · 16 · 681 · 1690 · 727 · 79 · 184 in Arabic),
a hadith with its takhrij and whose grading it is, and search.

### 3. Measured for this release

7 locales × **965** keys · **9** mushaf editions · **227** library books ·
`hadith.db` **109,731,840 bytes**, 67,153 hadiths, **45,219 graded** ·
7 HadeethEnc packs, **15,202,244 bytes** on the bucket · APK
**281,598,575 bytes** · **71** tests · **30** hosted paths, 0 failed.

### 4. Not done, and named as not done

* **`words_meanings_ar` (معاني الكلمات) is not in the packs.** The API returns
  it and `hadeethenc_crawl.py` never stored it, along with `explanation_ar`
  and `hints_ar`. Adding them needs a re-crawl of ~3,574 Arabic records.
* **Urdu keeps Latin digits.** `localizeDigits` shapes Arabic only, because
  the rest of the Urdu build renders every number in Latin and shaping one
  screen would make Urdu inconsistent with itself. Urdu's own digits are
  U+06F0-U+06F9, *not* the Arabic ones.
* **`QuranTranslationInfo.sizeLabel` builds its own `'… MB'`** instead of
  using `formatBytes`, so it is a sixth copy of the formatter trap #16 exists
  for, without the isolate. Not touched this session.

## STATE AS OF 2026-09-09 — SEVENTH SESSION (superseded by the block above)

### 1. The «""» and the stray dot — the sixth session's fix was HALF the bug

`stripBidiControls()` was correct and is not the whole story. Opened Sunan Abi
Dawud 1417 on the device: the **detail screen** was right. Then opened the Home
daily card — Bukhari 4543 — and the full stop was still adrift, sitting after
«كِبْرَهُ}» instead of ending the sentence after «سَلُولَ».

The cause the sixth session could not see: **six of the seven locales lay the
app out left-to-right, and an Arabic paragraph in an LTR box throws its edge
punctuation to the wrong end.** Removing the source's RLMs does nothing about
that. It is invisible in Arabic and Urdu, which is why a sweep in Arabic would
never have found it.

Of the four patched render sites, exactly **one** forced RTL
(`hadith_detail_screen`). The other three did not, and the same defect was in
the adhkar screen, the khatma card, the New Muslim guide and Quran search — all
now `ArabicText`. `test/arabic_direction_test.dart` **measures** the defect
(the stop's x-position in an LTR paragraph) before it measures the fix.

The mirror of it bit Urdu: the prayer tiles read «AM 7:36». Same trap (#16) as
«MB 60.5»; `formatTime12h` isolates it now.

### 2. Prayer calculation — 20 methods, the Asr madhab, high latitudes

Was four methods, no Asr madhab (always Shafi'i), no high-latitude rule.

Angles come from **AlAdhan's published table**, refetched by
`scripts/build_prayer_method_fixtures.py`; `test/calculation_methods_test.dart`
asserts every angle against it and then asserts the app's own computed times
against **320 real answers** (20 methods × 4 cities × 2 dates × both Asr
schools) — **1,920 time comparisons, worst disagreement 2 minutes.**

That comparison found four real bugs that would have shipped:

* **Umm al-Qura's Isha is +30 minutes in Ramadan.** Without it every Umm
  al-Qura reader's Isha was half an hour early *for the whole of Ramadan*.
* **Turkey** needed sunrise −7, dhuhr +5, asr +4, maghrib +7.
* **Dubai, Morocco, Lisbon** needed measured per-prayer offsets.
* **High latitudes**: Fajr in London in June was **78–89 minutes** out for the
  four interval-Isha methods, because `twilight_angle` silently fell back.

**Three methods are deliberately absent, with reasons in the catalogue's doc
comment:** Moonsighting (the package's implementation differs from the
committee's by up to 9 minutes with no constant offset), Jafari and Tehran
(Maghrib from a 4°/4.5° sun angle is a Shia fiqh position). Everything else in
the owner's reference screenshots — the German, Canadian, Czech, Swiss,
Belgian, Austrian, Luxembourgish, Maldivian, Iraqi, Syrian, Omani and Libyan
entries — is in **no published source with angles**, so it is not shipped.

Verified on the device: switching Umm al-Qura → Egypt moved Isha 9:38 → 9:27 PM,
and the 11-minute gap matches AlAdhan for the same day and place exactly.

### 3. easy_localization's plural rules were OFF — in every locale, always

`ignorePluralRules` defaults to **true**, so `.plural()` only ever resolved
zero/one/two/other and **every `few` and `many` in all seven locale files was
dead text**. Russian showed «7277 хадиса» and «97 главы» (both need the
genitive plural); Arabic's «{} آيات» for 3–10 had never once been reached.
Both entry points pass `ignorePluralRules: false` now, pinned by
`test/supported_locales_test.dart`.

### 4. The Russian and Urdu sweeps, and Arabic

* Russian «Библиотека» (10 chars) **wrapped and clipped** in the bottom bar
  while `nav_label_width_test` passed it — the budget was one number and
  Cyrillic is wider than Latin. The budget is per script now (Latin 10,
  Cyrillic 8, Arabic 8) and was **proven to fail on the old label**.
* The Home header's three cells had no gap; in Russian the Hijri line and the
  greeting touched.
* Urdu and Arabic are otherwise clean.

### 5. The hero surfaces follow the theme, and the countdown is live

The owner reversed P3‑4's «RGB في جميع الثيمات»: the clock card, the prayer
carousel, the card screens and the four «المزيد» cards were a fixed dark
gradient in every theme. One `HeroSurface` decides all of them now — dark and
RGB unchanged, a new light member — and the twenty clock faces take their ink
from the card instead of painting white.

`scripts/check_hero_contrast.py` computes every tone against the composited
ground and found that **four prayer accents were never legible even on the
dark theme**: Fajr's violet measured **2.43 : 1**. Each is now the smallest
solved nudge that clears 4.6 : 1.

The «المتبقي» line is a real per-second countdown — hours : minutes : seconds,
each digit rolling through an `AnimatedSwitcher`, Arabic-Indic in Arabic,
coloured by the next prayer's measured accent.

### 6. Three reminders around each prayer

Before the adhan, after it, and the iqama — each 0–60 minutes, **zero means
off**, all off by default. They ride the same trigger as the adhan alarms (a
real times fetch) but go through `flutter_local_notifications`, not the native
alarm path: a reminder does not need to take over a locked screen.

Proved with `dumpsys alarm` on the device, not by reading the code: with the
pre-reminder at 10 and the iqama at 5, ten `ScheduledNotification` alarms stood
at **exactly −10 and +5 around all five prayers** (06:03/06:18 around a 06:13
Fajr, 13:42/13:57 around 13:52, and so on), with the adhan's own alarm
untouched at 06:13.

### 7. HadeethEnc is fully crawled

**3,574 hadiths, 15,498 (id, language) rows, 100 % fetched, 60.5 MB.** Every
single row carries both a takhrij and a grading. The earlier "of 25,018" was a
wrong denominator: not every hadith has all seven languages, and the crawler
only ever asks for the ones a hadith declares.

`scripts/hadeethenc_gap_report.py` settles the question the last brief asked:
**en/es/fr/pt/ru are 0 % untranslated**, and Urdu's 29 % is «متفق عليه» /
«صحيح» — Arabic-script hadith terminology an Urdu reader reads as Urdu. **The
card needs no "not translated" state.** Nothing is wired into the app yet.

### Measured today, not remembered

| | |
|---|---|
| locales · keys each | 7 · 941 |
| i18n audit | 0 untranslated · 809 allowlisted, each with a written reason |
| mushaf editions | 9 |
| library books | 217 |
| `hadith.db` | 104.6 MB · 67,153 hadiths · 45,219 graded |
| `hadeethenc.db` | 60.5 MB · 3,574 hadiths · 15,498 rows (gitignored) |
| calculation methods | 20 |
| tests | 62 |
| debug APK | 441 MB |

## STATE AS OF 2026-09-09 — SIXTH SESSION (superseded by the block above) (still unreleased, on top of v3.8.0)

**The tree is clean, `flutter analyze lib test` is clean, `flutter test` is
48/48, and `py -3 scripts/i18n_audit.py` reports 0.** The session ended at
**93 % quota** with everything committed and pushed. Nothing here is in any
APK the owner has.

### The localisation job the owner asked for is finished, and measured

> «مش عايز حاجة اسمها اللغة تبقى فرنساوي والاقي شاشة أو كارت مش مترجم.»

```
UNTRANSLATED USER-VISIBLE STRINGS: 0 in 0 files      (was 1,497 in 39 files)
   chrome 0 · native 0 · content 0
   allowlisted (deliberate, with a reason in the script): 789
```

The 789 are decisions, not gaps, and each carries its reason in
`scripts/i18n_audit.py`: recitation and scripture (the adhan's words, the
guide's ten phrases, the mushaf font samples), proper names (226 book titles
and authors, channels, reciters — written in the reader's own script by
`properName()`, never translated), printed-edition citations, the Arabic-Indic
digit tables, the owner's name.

### What that took, and the three bugs that were on nobody's list

1. **Most of the 89 `chrome` findings were false positives.** The audit's
   literal scanner was a regex reading quotes pairwise and split
   `'${_hits.length} ${'key'.tr()}'` — translated all along — into fragments
   that looked like hardcoded text. It is a state machine now, judging the
   residue left after interpolations are removed, and it was proven still to
   catch: four probes injected into a real screen, four reported.
2. **`adhan_entry.dart` listed six locales — Urdu was missing.** The
   full-screen Adhan alert boots as its own miniature Flutter app with its own
   `supportedLocales`, so an Urdu user's alert fell back to Arabic while every
   other screen was Urdu. One `kSupportedLocales` now, pinned by
   `test/supported_locales_test.dart`, which was proven to fail on the bug.
3. **Fifteen Arabic strings lived in Kotlin** and a Dart-only audit could never
   see them: three notification channels and their descriptions, the adhan
   alert's title, body and two buttons, the download service's notification.
   They come from Dart now through `NativeStrings`, and the audit grew a
   `native` bucket that measures them.
4. **«Lu aujourd'hui»** — the string the owner photographed sitting over English
   and Arabic screens — is the khatma undo `SnackBar` on the root
   `ScaffoldMessenger`. It is cleared when the locale changes now.

Counting the shapes is what made the rest affordable: 226 death lines were
**three** templates; 226 book blurbs were **one** generated sentence covering
197 of them plus 29 written paragraphs; 443 book titles and authors needed **no
translation at all**, because both forms were already in the catalogue and no
screen ever looked at the Latin one.

### Verified on emulator-5554 — four languages, not one

* **French** — fired a test adhan through the real alarm path: «Adhan — prière
  du Dhuhr / Allahou Akbar — c'est l'heure de la prière» with «Arrêter» and
  «Muet»; `dumpsys notification` showed the three channels renamed in place on
  an upgrade install.
* **English** — the Library's Hadith tab end to end, imam biographies included.
* **Spanish** — the New Muslim Guide: headings and bodies translated, the
  shahada still Arabic in its own box in the Quran font.
* **Portuguese** — the Library card: «Faleceu em 1420 AH ▪ 1 livro», the blurb
  in Portuguese, «Tamanho: 419.4 KB», «Transferir».

**Not swept: Russian, Urdu, Arabic.** The owner asked for every language, one by
one; three remain.

### HadeethEnc — measured, crawling, not yet in the app

The correction the owner was owed. An earlier session told him no Spanish or
Portuguese hadith translation existed in any redistributable source; measured
against the live API, all seven of the app's languages are served, and every
record carries `attribution` (تخريج) **and** `grade` (درجة) in the target
language — which is what CLAUDE.md §1.2 requires.

```
72 languages · 493 categories, 7 top-level
4,273 category entries -> 3,574 DISTINCT hadiths (the old 4,273 double-counted)
```

`scripts/hadeethenc_crawl.py` is resumable and was left running: **2,900 of
roughly 25,000 (id, language) rows** at handover. `hadeethenc.db` is gitignored.
Nothing is wired into the app and nothing is on R2 yet — see
`NEXT_SESSION_PROMPT.md` §1 for the shape that fits.

### The owner's two decisions, taken and recorded

> «انا عايز الافضل لتجربة المستخدم وللامانة العلمية والموثوقية … متحطش حاجة
> مجهولة المصدر إلا لو انت متأكد إن كل المطورين بيعملوا كده.»

* **Unattributed translations do not ship.** The `fawazahmed0` fr/ur/ru hadith
  sets name no translator; they stay out. HadeethEnc covers all seven languages
  with a per-language takhrij and grade, so nothing is lost.
* **The «""» and the orphaned «.» are a rendering bug, and are fixed as one.**
  Sunan Abi Dawud 1417 ends `… الْوِتْرَ ␣ U+200F " U+200F ␣ U+200F . U+200F`;
  those RIGHT-TO-LEFT MARKs force the quote and the stop to resolve RTL and be
  carried away from their words. 35,860 of 67,153 hadiths carry U+200F.
  `stripBidiControls()` removes only characters with **no glyph**, at the four
  places the Arabic is drawn; the database keeps the source's own bytes and the
  sequence of visible characters is identical before and after — so §1.2's ban
  on rewriting hadith text is not touched. Guarded by
  `test/bidi_controls_test.dart`.

### Everything verified this session, by hand

* `flutter analyze lib test` clean · `flutter test` **48/48**
* **every hosted content path range-requested: 23 checked, 0 failed** — all 206
  with the right content type and magic bytes (hadith.zip 22.2 MB `504b`, the
  first and last page of all nine mushaf printings, four books `1f8b`, a
  translation).
* 7 locales · **912 keys each, key sets identical** · 9 mushaf editions
  (already named in all seven languages) · 226 library books (29 with a written
  blurb, 197 on the generated sentence) · `hadith.db` 109.7 MB, 67,153 hadiths
  in 9 books, 45,219 graded · `pubspec.yaml` **3.8.0+4**

### Honest gaps from the sixth session

* **Three languages were never opened on the device** (ru, ur, ar).
* **`stripBidiControls` has never been seen on a device.** It is proven by
  a test on the real text and the APK builds, but no one has looked at a
  rendered hadith since it went in — the session ran out of quota with the
  emulator on the wrong screen. Look before trusting it.
* **The HadeethEnc crawl is ~3 % done.** Every number quoted about it is from
  the survey and the first 750 rows, not from a finished corpus.
* In the sampled record, **Urdu returned `attribution` and `grade` still in
  Arabic**. Where a field is not translated it is stored as it came; how often
  that happens has not been measured.
* **Still nothing released.** `pubspec.yaml` is `3.8.0+4` and every fix from the
  fifth and sixth sessions is only on `master`.

## STATE AS OF 2026-09-09 — FIFTH SESSION (unreleased work on top of v3.8.0)

**The tree is clean, `flutter analyze lib test` is clean and `flutter test` is
43/43 — but nothing below has been built into an APK or released.** The
session ended at 98% quota, mid-way through the i18n job. Read
`NEXT_SESSION_PROMPT.md` §0 first: it holds the measurement that says how much
of that job is left.

### What the fifth session did

1. **Continuous recitation** — three separate faults, all reported by the
   owner and all fixed and seen working on `emulator-5554`:
   * picking a verse **stopped** the recitation, because `quran_screen.dart`
     handed `startContinuous` a *mushaf* id where a *reciter* id belongs. Both
     are `String`, so `flutter analyze` saw nothing; every verse resolved to a
     404 and the catch arm called `stopContinuous()`.
     `test/recitation_edition_test.dart` was proven to fail on the old code
     before being trusted.
   * the sciences sheet's play/stop toggle read the **shared** player, so
     mid-recitation it rendered as STOP and killed the run. It is now
     «اقرأ من هنا» and moves the recitation to the tapped verse.
   * the hang after a long spell in the background: the player is rebuilt and
     the sources reloaded on failure, the run can be resumed rather than
     silently toggled off, and a real failure is now *reported*.
2. **Splash, theme, permissions** — day theme by default on a fresh install; a
   splash-video sound switch in Settings; and the POST_NOTIFICATIONS dialog no
   longer lands on top of the splash video.
3. **Two more mushaf printings highlight ayahs** — `madinah_gold` (all 604
   pages, fitted directly) and Kuwait's two illuminated openings. **Five of
   nine** printings now carry the ayah layer.
4. **Localisation** — the Quran translation follows the app language; mushaf
   and reciter names read in the app's language; the hadith translation is
   shown under the hadith on the card as well as in the book, always labelled
   with its language and source.
5. **The language-switch bug the owner photographed** — changing the language
   left already-built tabs in the old one. `AppShell` now depends on the
   locale and rebuilds every tab. Bottom-nav label clipping fixed and guarded
   by a test; Arabic content inside a Latin UI now laid out RTL.
6. **`scripts/i18n_audit.py`** — the measurement for "every screen fully
   translated": **1,497 untranslated user-visible strings, 89 chrome and
   1,408 content** at session end (chrome was 167 at the start).

### Honest gaps from the fifth session

* **The recitation background hang could not be reproduced on the emulator.**
  `am stopservice` on the AudioService did not release the player
  (audio_service restarted itself and playback kept advancing), and cutting
  the network did not stall it either because played ayahs are cached to disk.
  What *was* verified is the recovery half: with no network and an uncached
  surah the reader now says «تعذّر تشغيل التلاوة …» instead of falling silent,
  and playback then works again on the rebuilt player — which proves
  `just_audio_background` accepts a new player after a disposed one, the
  riskiest assumption in the fix. **The trigger still needs the owner's phone.**
* **Hosted content was NOT re-verified this session** — no range requests were
  run. The R2 figures in the table below are the previous session's.
* **A correction the owner is owed:** he was told that no Spanish or
  Portuguese hadith translation exists in any redistributable source. That was
  wrong. **HadeethEnc** serves ar/en/ur/es/ru/fr/pt with grading and takhrij —
  see `NEXT_SESSION_PROMPT.md` §1.

## STATE AS OF 2026-09-09 (v3.8.0)

Phases 1–3 are complete. Everything since is owner-driven. **Read
`NEXT_SESSION_PROMPT.md` for what is unfinished.**

### What v3.8.0 added (2026-09-09, fourth session)

1. **Nine mushaf printings, up from six**, and **four of them now
   highlight ayahs**. New: مصحف قطر, مصحف دولة الكويت, مصحف المدينة
   الطبعة الليلية, مصحف المدينة بالخط النستعليقي. See §5.0 for what had
   to be measured on each before it could ship, and
   `NEXT_SESSION_PROMPT.md` for why the tenth was **not** added.
2. **Six corrupt pages found in the Qatar source; four repaired** from a
   second copy proven to be the same scan set. A page being fetchable is
   not the same as a page being legible — see §5.0.
3. **The Warsh and Qalun page sets are gone from R2** — 1,208 objects,
   270 MB, completing «احذف مصاحف الروايات». The bucket is **1.81 GB /
   5,012 objects** at handover — the deletion gave 270 MB back and the four
   new page sets took 542 MB.

### What v3.7.0 added (2026-09-09, third session)

1. **The three books that were still crawling at v3.6.0 are in.**
   `as_seerah_ibn_kathir` (1,880,427 B), `rijal_hawl_ar_rasul` (293,158 B) and
   `la_tahzan` (344,210 B) — each uploaded, then range-requested on the public
   endpoint *before* being catalogued: 206, `application/json`, `1f 8b` magic,
   byte totals matching `head_object`. **226 books.**
2. **Ayah highlighting and tap-to-sciences on the Tajweed mushaf** — the first
   raster printing to have them. It has no polygon layer of its own; it borrows
   the Hafs one through a fitted affine. See §5 and
   `scripts/fit_mushaf_polygon_transform.py`.
3. **مصحف قطر — the sixth printing.** 604 pages, Hafs, from archive.org
   (`QuranMushafQatar`, CC BY-NC-SA 3.0). Its page division was verified
   against the bundled Hafs polygon layer on 11 pages spanning the mushaf, and
   all 604 uploaded pages were range-requested on the public endpoint before
   anything entered `editions.json`. Built by the new, reusable
   `scripts/build_mushaf_from_pdf.py`.
4. A dangling separator the new books exposed: al-Qarni is alive, so
   `la_tahzan`'s `authorDeathAr` is empty, and both render sites in
   `library_screen.dart` concatenated it unconditionally.

5. **Eleven dead book downloads fixed — eight of which shipped in v3.6.0.**
   `add_seerah_catalog_entries.py` generated
   `'\${AppConfig.contentBaseUrl}/books/text/x.json'`, and in Dart a
   backslash-dollar inside a string is an *escaped* dollar, so the URL was
   never interpolated and every one of those books failed on the device with
   «Invalid argument(s): No host specified in URI». `flutter analyze` cannot
   see it — the escaped form is a valid string literal. Found by tapping
   Download on the emulator. See CLAUDE.md trap #23; guarded now by
   `test/book_catalog_urls_test.dart`, which was proven to fail on the broken
   form before being trusted.
6. **A blank author name.** `sahih_as_seerah_albani` shipped with an empty
   `authorAr`, because Shamela's card for book 592 names al-Albani on a
   «لَخّصه … وعَلّق عليه:» line rather than a «المؤلف:» one. Taken from that
   line; the generator now refuses an empty author instead of writing it.

**Rejected on purpose:** the Taj Company 16-line Indo-Pak scan
(`AlQuran16LinesTaj`) is clean and complete, but its own back page prints
«جملہ حقوق محفوظ» and a copyright warning naming Taj Company Ltd. It is not
ours to rehost. Check a scan's back matter before building it.

### Measured facts (2026-09-09, measured this session, not from memory)

| | |
|---|---|
| Locales | **7** — ar (default, RTL), en, es, fr, pt, ru, ur · **665** leaf keys, parity enforced by `test/translation_parity_test.dart` |
| Tests | **34** — the four new `book_catalog_urls_test.dart` cases and the five `mushaf_polygon_fit_test.dart` ones both pin *measured* facts, not code shape |
| Ayah layer | **4 of 9** printings — `hafs_kfqc` (its own polygons), `tajweed_color` (one affine per page group) and `qatar` / `kuwait` / `madinah_night` (one affine per page). That is 5 of 9 counting Kuwait, whose two illuminated openings are deliberately unfitted. The rest paginate their own way and ship without one rather than with a wrong one; see §5.0. |
| Mushaf editions | **9** — `hafs_kfqc`, `tajweed_color`, `shamarly`, `madinah_gold`, `indopak_tajweed`, `qatar`, `kuwait`, `madinah_night`, `madinah_nastaleeq`. Warsh and Qalun were deleted from the app *and now from R2* on the owner's instruction («احذف مصاحف الروايات»). He wants 10; the candidates examined for a tenth were each rejected for a stated reason — see `NEXT_SESSION_PROMPT.md`. |
| Text-mushaf appearance | **10 themes × 10 frames × 11 frame colours**, one picker card, all painted |
| Text library | **226** books |
| Mushaf covers | 9 files, 662 KB — every edition ships its real printed cover |
| R2 bucket | **1.81 GB**, 5,012 objects — measured at handover, after the riwayah deletion (−270 MB, 1,208 objects) and the four new page sets (+542 MB) |
| Quran translations | **45** languages — 6 bundled, and all 45 mirrored on R2; the catalogue and the bucket match exactly, no entry without an object and no object without an entry (measured 2026-09-09; an earlier note said 47) |
| Adhans | **14** — the owner's own three plus أذان قناة الناس are the first four |
| Ruqyah | 6 recordings mirrored on R2 + a composed reading screen |
| Islamic channels | 7, each id/handle/avatar read off YouTube itself |
| Hadith | **67,153** in 9 books · **45,219 graded** · `hadith.db` **109.7 MB** bundled |

### What v3.6.0 added

1. **Cards open as animated card screens, not inline.** `lib/core/widgets/card_route.dart`
   (`CardRoute` + `CardScreen`) — the card grows out of the widget that was
   tapped, the page behind stays put and blurs, and the card is sized to its
   own content. The prayer editor and the clock gallery were converted; use it
   for any future card. The owner's complaint was that an inline expansion
   fights the page's scroll, which it did.
2. **Home**: the carousel bug is fixed (it opens on the next prayer); the
   expanded prayer editor writes through the same providers as the Adhan
   settings screen (verified: `+3` moved Fajr from 4:43 to 4:46 live); the
   weekday name renders; the clock gallery's 20 faces all run on real time.
3. **Ruqyah** (`lib/features/ruqyah/`) — verses read from `quran_local.db` and
   six duas addressed **by row id** in `azkar_items` so they carry their own
   takhrij. No scripture is duplicated into Dart. Three honestly-separated
   groups; see the doc comment in `ruqyah_catalog.dart` for why.
4. **المزيد** reordered to «المزيد» destinations then «الإعدادات».
   `SettingsScreen` was deleted (dead — nothing pushed it).
5. **10 text-mushaf themes + 10 painted Islamic frames + 11 frame colours**,
   all in one card. Every preview is drawn on the active theme's own paper.
6. **Sunan Suwar reader** rebuilt with the full text-mushaf option set, still
   locked to the surah (`wholeMushaf: false` keeps the recitation inside it).
7. **Islamic channels** section, grid/list, avatars mirrored to R2.
8. **Owner-supplied audio**: three adhans (his 24-bit 40 MB WAV transcoded to
   2.8 MB mono 160k, duration preserved exactly) and his own ruqyah recording.

### Bugs found by running it, not by reading it

| Bug | How it showed |
|---|---|
| Prayer slide overflowed by 0.8px | only once a manual correction added a `+3` line |
| Sunan reader bar overflowed by 6px | seven controls do not fit at default IconButton metrics |
| AM/PM marker unreadable | the clock hands crossed it; it now has a capsule |
| `60.5 MB` rendered as `MB 60.5` | bidi: a number next to a Latin unit reverses in an RTL paragraph. Five duplicate formatters replaced by one |
| 3 mushaf themes at 2.3–2.6 : 1 contrast | dark ink on a translucent wash over a dark ground. All ten now 6.0–12.3 : 1 |

### What was found broken (and fixed) in the last three sessions

Treat this as evidence about how much of the app is verified rather than
assumed.

1. **The whole text library was dead on a device.** Four independent faults,
   each sufficient on its own: `no such module: fts5` killed `openDatabase` and
   therefore downloads, opening, deleting and search together; 207 of 215 books
   are gzip and were never decoded; the reader was handed the literal string
   `'sqlite'` as a file path; and a failed download reported nothing at all
   because the error went to a `debugPrint` that release builds strip.
2. **Page indexing produced empty text for every page** — `_indexableBody` cast
   the page's paragraphs to `List<String>` when a paragraph is `{"t":…, "k":…}`.
3. **Every book card claimed `1.0 MB`** — hardcoded. Real: 3 KB – 883 KB.
4. **Mushaf covers were drawings**, one board recoloured per edition. Now each
   edition ships its real printed cover or title page (556 KB total for all 7).
5. **Release tags pointed at the initial commit** (`--target main` while work is
   on `master`), and the About card said 3.0.0 while releases were tagged 3.2.0.

### Home screen rebuild (2026-09-09, second session) — READ THIS

This is the newest work in the repo and it is **not fully verified on a
device**. Do not describe it as done until the checks at the end of this
section have actually been run and seen.

**What the owner asked for** (his message, condensed): make the prayer-time
slides on Home animated and professional; tapping one should grow it into a
card showing the adhan mode, the muezzin, the chosen video, an adhan preview
and a manual time correction, all reflected immediately; make moving between
slides animated; put the weekday name next to the Gregorian date; make the
clock tappable so it opens a bigger animated card offering **10 digital** and
**10 analogue** faces, all previewing the real live time; and make the default
recitation محمد صديق المنشاوي (المجود).

**What was built**

| File | What it is |
|---|---|
| `lib/features/home/data/clock_settings_provider.dart` | Extended: `DigitalClockFace` (10) + `AnalogClockFace` (10) enums beside the existing `ClockStyle`. The old enum value names are kept **exactly** (`analogRgb`), because those names are the SharedPreferences payload — renaming would have silently reset every existing user to the digital clock. |
| `lib/features/home/presentation/widgets/analog_clock_faces.dart` | The 10 analogue faces, each a `CustomPainter`: rgb, classicGold, minimalDark, neonRing, arabicNumerals, islamicStar, skeleton, sunMoon, halo, mosaic. The widget owns a `Ticker` (throttled to ~30 fps) so the seconds hand really sweeps instead of stepping, and the ticker dies with the widget. |
| `lib/features/home/presentation/widgets/digital_clock_faces.dart` | The 10 digital faces: minimal, neon, segment (a real 7-segment painter), flip (per-digit flip cards), gradient, arabic, ring, bars, glass, dots (a 5x7 dot-matrix painter). |
| `lib/features/home/presentation/widgets/clock_gallery_sheet.dart` | The picker. Every tile is the **real** face running on the real current time, not a thumbnail. Tapping one writes straight through `clockSettingsProvider`, which Home watches, so the card changes under the sheet. |
| `lib/features/home/presentation/widgets/prayer_slides.dart` | The carousel + the expanded per-prayer editor. |
| `lib/features/home/presentation/screens/home_screen.dart` | Weekday name added above the Gregorian date (`DateFormat.EEEE(locale)` — the locale's own calendar data, not a hand-written list). Clock is now a tap target opening the gallery. Chips row replaced by `PrayerSlides`. |
| `lib/features/settings/presentation/screens/settings_screen.dart` | The two old style chips replaced by one button into the same gallery, labelled with the currently-selected face. One picker, not two lists that can drift. |
| `lib/core/services/ayah_audio_service.dart` | `defaultEdition` is now `ar.minshawimujawwad`. |
| `assets/translations/*.json` (all 7) | +23 keys each (20 face names, `clock_gallery_title`, `clock_analog`, `prayer.sunrise_no_adhan`); `clock_analog_rgb` removed. 606 leaf keys per locale, parity test green. |
| **deleted** `rgb_analog_clock.dart` | Superseded by `analog_clock_faces.dart`'s `rgb` face, which is the same drawing. |

**The expanded prayer card** writes through the *same* providers the Adhan
settings screen uses (`adhanSettingsProvider`, `adhanPresentationProvider`,
`prayerAdjustmentsProvider`) and calls `rescheduleFromCache()` after each
change, so a change made on Home is the same change made there — it moves the
time on the card and re-schedules the alarm without leaving the tab. The adhan
preview goes through `AdhanNative.preview`, **not** a second `just_audio`
player, for the reason already recorded in `adhan_settings_screen.dart`:
`just_audio_background` throws for any player after the first, and the Quran
recitation player holds that slot.

Sunrise is handled honestly: it is a timing, not a prayer, so its card offers
only the manual correction and says so (`prayer.sunrise_no_adhan`) instead of
showing dead adhan controls.

**Verified**

- `flutter analyze lib test` → No issues found.
- `flutter test` → 25/25 (includes the 7-locale parity test over the new keys).
- Range request (206) on `hadith/hadith.zip`, one page of every one of the 7
  mushaf editions, one adhan video, and
  `everyayah.com/data/Minshawy_Mujawwad_192kbps/001001.mp3` — the new default
  reciter, so it is a resumable per-ayah source on day one and not only a CDN
  stream.
- **Seen on `emulator-5554`**: the weekday name renders («الأربعاء» above
  «٩ سبتمبر ٢٠٢٦»); the digital `minimal` face renders with Arabic-Indic
  digits in the correct order (cropped and read: `٠٢:٢٦:٣٧`, with «ص» on the
  RTL side); the carousel renders with the centred slide at full size/colour
  and its neighbours scaled down and dimmed.

**NOT verified, and one open bug**

1. **Open bug — the carousel opened on the wrong prayer.** On the device run
   the card's own pill correctly said «الصلاة القادمة: الفجر», but the
   carousel was centred on العصر. A `PageController` isolation test proved the
   controller honours `initialPage`, so the fault is on the caller side. Two
   changes were made in response and **neither has been seen running**:
   - `reverse:` was removed from the `PageView`. A horizontal `PageView`
     already resolves its scroll direction from the ambient `Directionality`,
     so passing `reverse: rtl` double-flipped it and laid the day out
     left-to-right. On the device run Fajr was at the left-hand end, which is
     wrong for Arabic.
   - A `didUpdateWidget` was added that animates to the next prayer when
     `nextKey` changes, guarded by a `_userDriven` flag so it never yanks the
     carousel out from under the reader's finger. The likeliest root cause is
     that the widget was born while the times were still resolving and never
     re-centred afterwards.
   **This must be checked on a device first thing next session.**
2. **The expanded prayer editor has never been opened on a device.** Not the
   mode pills, not the muezzin picker, not the video picker, not the adhan
   preview button, not the ± minute stepper.
3. **The clock gallery has never been opened on a device.** None of the 20
   faces has been seen rendering at Home size or at tile size. The `segment`
   and `dots` faces draw Latin digits by construction (a seven-segment display
   has no Arabic-Indic glyphs) — that is deliberate, but it should be looked
   at before it is called finished.

**Why it could not be verified.** The card only renders once real prayer times
exist, and the emulator would not produce a location fix on a fresh boot:
`dumpsys location` reported `last location=null` and `gps provider:
ProviderRequest[OFF]`, `adb emu geo fix` returned OK without ever populating a
provider, and `cmd location providers add-test-provider` was refused with
`SecurityException: android from uid 2000 not allowed to perform
MOCK_LOCATION`. The one successful device run earlier in the session worked
because that emulator instance still held a cached position (it resolved to
Dubai). **Next session: get a location fix first, or run on the owner's real
phone, before touching anything else here.**

### One honesty note carried forward

`madinah_gold` is **not a printing**. Its archive.org source (`smartmushaf`)
states in its own description that it took vector Qur'an pages already on the
internet and added colours and borders — the Madinah typesetting, illuminated
digitally. It was named «مصحف المدينة المذهّب», which implied a printed book that
does not exist; it is now «المصحف المذهّب (Smart Mushaf)» and shows its own page.
Licence CC BY-NC-ND (non-commercial — fine for this sideloaded app).

---

### PHASE 2 progress (2026-09-02) — details in `PHASE2.md`

| Stage | State |
|---|---|
| P2‑1 small-bug sweep | ✅ done, verified (6 bugs; launcher icon designed in-house, src in `rafeeq_app/assets/icon/src/`) |
| P2‑2 4 themes (system/light/dark/**RGB** animated) | ✅ done, verified — `lib/core/theme/theme_controller.dart` + `app_theme.rgb()` + `rgb_backdrop.dart`. §5.6. |
| P2‑3 es / ru / pt locales | ✅ done, verified — 5-locale parity (260 keys after P2‑4/4b), `test/translation_parity_test.dart`. Fixed `const AppShell` not re-translating on `setLocale`. |
| P2‑4 Library redesign | ✅ structural done, verified — Home المكتبة card → `LibraryScreen`; tabs [الكتب المتوفرة \| الحديث]; 3 sub-tabs (كل الكتب abc / التصنيفات / مكتبتي w/ فتح+حذف). `BookCategory` enum, `LibraryBook.category/sortKey`. **Fixed real bug:** `DownloadManager.remove()` didn't purge the SharedPreferences registry. Added `العبودية` (Ibn Taymiyyah) — 5 books / 3 categories now. |
| P2‑4b book **text editions** (Shamela) | ✅ done, emulator-verified — 5 Shamela text editions (`build_book_text.py` → `rafeeq-api/books/text/*.json`), `book_text_reader_screen.dart` (فهرس/search/font/bookmarks/provenance), `مصوّر\|نص` switch per card, one مكتبتي row per (book, edition). `printReliable` gates printed-page UI (false for Riyad/12014). §5.7. |
| P2‑5 pro download manager | ✅ done, emulator-verified — unified `DownloadsScreen` (نظرة عامة tab: storage total + per-category تفريغ + downloaded-items list), `downloads_controller.dart` aggregator, **live progress notification for every download kind** (`DownloadNotifications` generalized + wired into mushaf-prefetch & surah-audio, requests POST_NOTIFICATIONS), and **pause/resume** for mushaf + audio. Minor: 3 tabs not the 5 labelled sections; a few toasts not re-shot. |
| P2‑6 persistent prayer notification (next prayer + Hijri + countdown) | ✅ done, emulator-verified — `prayer_status_notification.dart` (ongoing LOW card, native chronometer countdown, Hijri from AlAdhan cache, one scheduled rollover, honest "enable location" fallback), opt-in toggle in Adhan settings (default off), synced from `AppShell` on times-resolve / toggle / resume. |
| P2‑7 Adhan audio/video + 30 slots | 🔶 code done + clips hosted + partially emulator-verified (analyze clean, test 13/13) — 5 Pixabay clips uploaded to `rafeeq-api/adhan/video/*.mp4` (all 200, byte-exact); download → auto-select → persists across restart → test notification (right title/sound) all verified live. **Not verified:** the actual full-screen video-behind-karaoke render (notification-tap / lock-screen full-screen-intent never fired under ADB on this emulator — see §7 P2‑7 update; needs a real device). |
| P2‑8 competitor feature mix | 🔶 research done — `PHASE2_RESEARCH.md` (13-feature table from Sakinah/Ayat/QuranFlash/Khatmah + a proposed shortlist + 4 owner-decision-blocked items). **No code** — the stage's own rule is STOP until the owner picks the shortlist. |
| P2‑9 hosting doc (R2/Firebase/GitHub) | ✅ `HOSTING.md` written + client wiring re-confirmed (§4 there) · console provisioning (R2 bucket, token rotation) still OWNER-BLOCKER |
| P2‑10 perf / size / security / release prep | ✅ done — `ARCHITECTURE.md` written, real size measured (+~6MB vs Phase‑1, documented honestly), security re-swept clean, dead code found+removed, a real usability gap found+fixed (every error state got a working Retry button). OWNER-BLOCKER unchanged: release keystore. |
| **P2‑11** Quran Khatma card (Home top) | ✅ done, emulator-verified — create/read-today/jump-to-reader/progress all confirmed live. |
| **P2‑12** Sunan as-Suwar card (Home middle) — 4 surahs, single-surah locked reader, per-surah reminders | ✅ done, emulator-verified — locked reader confirmed to stop exactly at the surah boundary (Al-Baqarah: 48/48, no leak into Aal-Imran) |
| **P2‑13** Random-hadith card (Home bottom) — full hadith + narrator + grade, re-rolls each launch | ✅ done, emulator-verified — real graded source found for 4 of 7 books (Abu Dawud/Tirmidhi/an-Nasa'i/Ibn Majah), joined by normalized-Arabic-text matching, `hadith.db` rebuilt + re-hosted + verified byte-exact. Quick-access grid removed from Home (New Muslim Guide rehomed to Settings, not orphaned). |

> **If you are an agent working on this project: keeping this file current is
> part of the job.** The owner hands this file to whoever continues, so a stale
> handover is a broken handover. Do not describe work as verified here unless
> you actually ran it.
>
> **Sessions here die from quota exhaustion, usually mid-task.** So do not save
> the write-up for the end. After every meaningful edit run:
>
> ```
> .\cp.bat "what you just did"
> ```
>
> That updates the work-in-progress note above, stamps the date, and commits —
> in one step. A session that dies right after a checkpoint loses nothing. A
> session that dies an hour after its last one loses an hour.
>
> Use `.\cp.bat "..." -Done` when a stage is finished, and `.\cp.bat /s` to see
> where things stand.

---

## Current work in progress

<!-- WIP:START -->
**2026-09-12 04:41 — IN PROGRESS — resume here**

batch 11 stage 5: download notification taps now land on the screen that owns the queue - dl:recitations to the recitations player, dl:ruqyah to the ruqyah screen, dl:mushaf and dl:files to the Downloads hub - via NotificationRouter's new dl: prefix, a payload on DownloadNotifications, and a taskNotificationTapCallback on each of the three background_downloader groups. ONLY the tap callback is registered: registerCallbacks' own doc warns that a group with callbacks stops emitting to the updates stream, which DownloadEngine and DownloadManager both live on, so a status or progress callback there would silently kill every progress bar in the app; read in base_downloader.dart 9.5.9 that only groupStatusCallbacks and groupProgressCallbacks gate emission while groupNotificationTapCallbacks is read in processNotificationTap alone. test/download_notification_routing_test.dart pins that and that every payload sent has a destination. The ayah card now shows the reciter's name and opens the same picker the page's recitation bar opens, calling the same provider and switchReciter - it was already reciting with selectedReciterProvider but never said who, which is what the owner meant by مش موجود فعلا. Tutorial page content centred in the viewport after seeing it on emulator-5554 hanging from the top with a third of the screen empty. analyze clean, 196 tests pass. DEVICE: the tour was seen opening by itself on first run in Arabic, pages 1, 3 and 6 read correctly, the per-chapter accent drives wash, rule, rail and button, skip and back appear as specified.

_Uncommitted at the time of writing: see `git status`. If this says
IN PROGRESS, the previous session likely ran out of quota here — read the last
commit's diff before continuing._
<!-- WIP:END -->

---

## 0. TL;DR — what to do first

1. Run `.\check.bat` (or `flutter analyze` in `rafeeq_app/`).
2. **The code has never been compiled.** Fix whatever the analyzer reports. That is job #1.
3. Do **not** redesign anything until the build is green.
4. Read §3 (Hard rules) and §5 (Decisions — do not undo) before writing code.

---

## 1. What this project is

A comprehensive Islamic Flutter app. The goal is a "masterpiece mix" of the best
ideas from Sakinati, Ayat, QuranFlash and Al-Quran Al-Azeem — **built from
scratch with our own legally-clean data**, not copied from them.

- App lives in `rafeeq_app/`
- Flutter 3.38.7 / Dart 3.10, Riverpod, easy_localization, sqflite, dio, just_audio, flutter_svg
- Owner: Tito. Speaks Arabic (Egyptian). Wants concise, efficient work — he has
  already lost ~$20 and many hours to agents that produced fake UIs.

---

## 2. History you must know (why the owner is wary)

Earlier agents (DeepSeek, LongCat, Gemini-in-Antigravity) did serious damage:

- Bloated the app to **400 MB** with unused assets
- Wrote **fake/mock data** everywhere — screens that looked finished but were
  wired to nothing
- Fake download buttons with hardcoded checkmarks
- Adhan files that contained music
- A "translation" system that only flipped RTL/LTR without translating
- Left the build broken

A clean rebuild (T1–T5) fixed the foundation. The work described in §4 continues
from that clean base. **Do not reintroduce any of the above.**

---

## 3. HARD RULES — non-negotiable

| # | Rule |
|---|------|
| 1 | **ZERO mock/placeholder data.** Every string on screen comes from a real DB, API, or asset. If data is missing, show an honest empty state — never invent text. |
| 2 | **Never take data from QuranFlash.** It is a licensed product; scraping/reverse-engineering it is off the table. All QuranFlash-derived files were deliberately deleted (see §5.1). |
| 3 | **Never claim something is verified when it is not.** Say plainly what you tested and what you did not. |
| 4 | **Offline-first.** Downloaded content must work with the network off. |
| 5 | **Don't commit secrets.** `.env`, keystores, `google-services.json`, `serviceAccountKey.json` are gitignored. Keep it that way. |
| 6 | **Keep translation keys at exact parity across every locale.** 5 locales (`ar` / `en` / `es` / `ru` / `pt`), **260 keys each** as of P2‑4b. Adding a key to one locale without the others is a bug — `test/translation_parity_test.dart` guards this. |

---

## 4. What has been done (commits, newest first)

```
238caad chore: add toolchain check script so results reach the sandbox
9b32116 feat(downloads): offline mushafs and per-ayah recitation
3cb38c9 feat(quran): five mushaf editions with numbering-aware sciences
a7bb5f2 feat(quran): purge QuranFlash assets, add translations, rebuild ayah card
bb6d0f2 feat(quran): T6/T7 vector mushaf with real ayah polygons
b1b0b40 chore(repo): normalize line endings, add .gitignore, checkpoint T6 WIP
2d5371e T5: authentic i18n (easy_localization ar/en)   <-- clean base before this session
```

### 4.1 Repo hygiene (`b1b0b40`)
The working tree showed **349 modified files** that were pure LF→CRLF churn,
hiding the 4 files with real edits. Added `.gitattributes` (`* text=auto` +
binary rules) and set `core.autocrlf=true`. Added a root `.gitignore`.
**If you ever see hundreds of phantom modifications again, this is why.**

### 4.2 Vector mushaf + real ayah polygons (`bb6d0f2`)
See §5.2. 604 pages, 6236/6236 ayah polygons, verified against the DB.

### 4.3 QuranFlash purge + translations + ayah card (`a7bb5f2`)
See §5.1. Also folded 3 translation files into the DB and rewrote the ayah card.

### 4.4 Five editions with numbering guard (`3cb38c9`)
See §5.3. This is the subtlest piece of the whole project.

### 4.5 Offline downloads + recitation (`9b32116`)
See §5.4.

---

## 5. DESIGN DECISIONS — understand these before changing them

### 5.-1 A page being FETCHABLE is not a page being LEGIBLE

مصحف قطر was catalogued after all 604 of its pages answered a range request on
the public endpoint. Four of them were still unreadable: page 210 was a flat
green block over most of the sheet, page 5 a pink wash, page 167 a grey wash,
page 323 a torn orange band. The damage was in the archive.org copy's own
embedded JPEGs, not in the rendering.

It was found only because a polygon overlay on page 210 came out four times too
big. **`scripts/check_mushaf_pages.py` now scans every rendered page** for a
large flat coloured area and for an abnormally dark sheet, and reports the
page's printed header beside the surah the Hafs layer expects. Run it on every
new page set before uploading.

The repair is worth recording as a method: a second archive.org item held the
same scan set, and that they were one set was **proven, not assumed** — 598 of
the 604 embedded images are byte-identical between the two copies, and each of
the six that differ has the *same byte length* in both, which is the signature
of a corrupted copy rather than a different scan. Two of the six were clean in
both (the difference confined to glyph edges, i.e. re-encoding) and kept the
primary. The second copy draws a `www.Quranpdf.blogspot.com` watermark as page
TEXT over every page, which the first render baked into the repaired pages; it
is redacted before rendering, images untouched.

### 5.0 A raster printing may borrow the Hafs ayah polygons — but only if
### its layout was *measured* to match

The KFQC vector edition ships the only real ayah polygon layer this app has.
`tajweed_color` has none of its own, and since v3.7.0 it borrows that one
through an axis-aligned affine (`AyahPolygonFit` in `mushaf_edition.dart`,
declared in `editions.json`, fitted by
`scripts/fit_mushaf_polygon_transform.py`).

**This is only legitimate where the two printings really do set the same page,
and that has to be measured.** How it was established for the Tajweed
printing:

* Line positions on 30 Tajweed scans and on the Hafs polygons **both collapse
  to exactly 15 clusters**, with matching per-cluster sample counts. That is
  the evidence the printing sets the Madinah grid — not that it looks like it.
* All 604 pages' real pixel sizes were read from their JPEG headers: two
  groups, 602 at 861×1317 and pages 1–2 at 901×1476. Pages 1–2 are illuminated
  openings with their own frame and their own text block, so they carry their
  own fits in `polygonFitPages`.
* 841 real polygon rings across 86 pages land a median 3.9 px from their
  printed line on an 84 px line pitch (95th percentile 11.9 px).
* The mapped polygons were **rendered over the real scans and looked at** —
  pages 1, 2, 50, 200, 400, 584, 604, including 604, which sets three surah
  headers and three basmalahs that the polygons correctly skip.
* Then run on `emulator-5554`: a tap opened the sciences sheet on exactly 2:3,
  and the recitation highlight painted 2:2 across its two-line wrap on the
  opening page and 3:2 marker-to-marker on body page 50.

**Two fitters, for two different problems.** `fit_mushaf_polygon_transform.py`
fits one affine per page GROUP and suits a printing whose pages are all the
same crop — the Tajweed one. `fit_mushaf_polygon_per_page.py` fits one affine
PER PAGE, for a printing whose leaves were cropped individually. Qatar, Kuwait
and the night edition need the second: on Qatar the printed frame keeps a
constant size (sd under 0.5%) while its position slides up to 3% of the page
width — 26 px, about two letters — which no single affine could absorb.

Its method, worth understanding before changing it: the printed frame is the
fiducial, found by saturation rather than darkness (the frame is red and gold,
the text near-black, the paper not saturated) and taken as the MEDIAN of each
row's extremes, so a hizb ornament out in the margin is one row's outlier. Then
every body page yields exactly 15 ink runs and the Hafs slots cluster to
exactly 15, so slot k matches run k with nothing to guess. Pages that fail that
count are filled from the frame — their frame-relative parameters agree across
567 pages to sd 0.002, which is the evidence the frame is a valid fiducial —
and a page whose frame box is itself implausible borrows its neighbour's.

**Do not extend this to a printing whose layout has not been measured.**
`madinah_gold` sets 6 lines on its page 2 where the Madinah mushaf sets 15;
`shamarly` (521 pages) and `indopak_tajweed` (564) paginate differently
outright. No affine can fix a different typesetting, and those three ship with
no highlight rather than a wrong one — which is the honest answer, and what
`test/mushaf_polygon_fit_test.dart` asserts. `madinah_nastaleeq` (611 pages) is in that
same list.

**A page may honestly have no fit at all.** Kuwait's two illuminated openings
resisted every panel measurement — warm cream ground, brown ink, and the best
attempt found six of seven lines — so they carry no entry, `fitForPage`
returns null for them, and the reader simply gets no highlight on those two
pages. One line out on al-Fatiha is worse than nothing. That is also why a
per-page printing carries **no `default`** in `editions.json`: a missing page
must fall through to nothing, not to an affine measured elsewhere.

Two implementation points worth keeping:

* `AyahCoordsRepository` is keyed by **asset path**, not edition id, so two
  editions naming the same layer parse the 0.7 MB file once and hold one copy
  of the 6,236 regions.
* Hit testing maps the **tap point backwards** (`AyahPolygonFit.invert`) rather
  than mapping every polygon on the page forwards — one multiply instead of
  thousands, and exact rather than approximately so.
* A fitted raster page is laid out inside an `AspectRatio` of the page group's
  own measured shape. With `BoxFit.contain` alone the drawn rectangle depends
  on the surrounding box, and the overlay would float free of the text.

### 5.1 QuranFlash content was removed on purpose

Deleted: `assets/data/mushafs_catalog.json` and `assets/mushaf_thumbs/`.

Evidence it was QuranFlash-derived: the catalog carried that app's exact
internal keys (`Medina1`, `Medina2`, `Shamarly`, `Tahajod`, `12line`,
`NaskhTaleek`, `Urdu12/13/15`) and its exact per-edition image counts
(624 / 576 / 850 …). The thumbnails were 135×200 `.gif` files scraped from
its site. Nothing in `lib/` referenced either.

**Do not restore these. Do not fetch replacements from QuranFlash.**

### 5.2 The mushaf is vector SVG, not raster scans — and why

Source: **[quranpedia/quran-svg](https://github.com/quranpedia/quran-svg)**
- Polygon metadata: **CC0-1.0**. KFQC glyphs: free for digital use.
- Pinned to commit `b91d39e1065b57bdda3e94aca8ecf3575e50e1e6` (verified
  byte-identical to the local build) so page geometry can never drift away
  from the bundled polygon assets.

Each page SVG already contains the hit layer:
```xml
<path class="ayahPolygon" surah="2" ayah="5" d="M … Z"/>
```

**Why polygons and not bounding boxes — this is the key insight:**
**4,221 of 6,236 ayahs (68%) span more than one line.** A single bounding box
around such an ayah covers the whole text block. That is exactly why tapping an
ayah used to highlight the wrong region. Each ayah now carries **one ring per
line fragment** (up to 3), hit-tested with an even-odd ray cast.

Why vector also wins: whole mushaf ≈24 MB brotli vs the 233 MB PNG zip purged
in T1; sharp at any zoom; glyphs recoloured via a `srcIn` filter so night mode
is a real night mode instead of a white sheet.

**A dead end already explored — do not repeat it:** `scripts/build_ayah_coords.py`
(deleted) targeted quran.com-images' `glyph_ayah_bbox`. That table is **declared
in the dump but ships zero rows**, so it could only ever produce an empty file.

**A bug already fixed — keep the guard:** page 294 first arrived **truncated**
and its polygons silently vanished, looking exactly like an upstream data gap.
`scripts/build_mushaf_svg.py` now validates every download (must end `</svg>`
and contain `ayahPolygon`). Keep that check.

### 5.3 Ayah numbering differs per riwayah — the sciences guard

The sciences DB (tafsir, i'rab, translations) is keyed to **Hafs** numbering.

| edition | pages | ayahs | sciences |
|---|---|---|---|
| `hafs_kfqc` | 604 | 6236 | aligned |
| `shubah_kfqc` | 604 | 6236 | aligned (both riwayat of ʿĀṣim) |
| `douri_kfqc` | 604 | 6207 | **diverges in 45 surahs** |
| `qalon_kfqc` | 604 | 6214 | **diverges in 50 surahs** |
| `warsh_kfqc` | 604 | 6214 | **diverges in 50 surahs** |

Warsh/Qalun/Duri split verses differently, and **inside such a surah every later
ayah shifts**. Showing Hafs-keyed tafsir there would display a *different
verse's* commentary — plausible-looking and wrong, which is worse than nothing.

So `scripts/build_mushaf_catalog.py` diffs each edition against
`quran_local.db` and records the exact diverging surahs into `editions.json`.
`MushafEdition.sciencesAvailableFor(surah)` gates the card, which shows
`quran.sciences_unavailable_here` instead of wrong content.

**Do not "simplify" this away.** It is a correctness guarantee, not clutter.

The upstream Libya-Awqaf edition was **deliberately excluded** — it is
non-commercial only. Every shipped edition is free for app use.

### 5.4 Recitation is stored per ayah, not per surah

A surah MP3 **cannot be seeked to a given verse** without a timing map. Per-ayah
files are what actually let every ayah bind to its own recitation offline.
`AyahAudioService` caches per ayah, downloads a surah at a time, resumes after
interruption, prefers the cached file, and otherwise streams while caching.

### 5.5 Page hosting is temporary

`AppConfig.mushafPageBase` defaults to **GitHub raw**, pinned. That is a
development convenience — **it is not a CDN and will rate-limit under real
traffic.** Before release, mirror `scripts/mushaf_build/<edition>/svg` to the
project's own bucket and build with:
```
--dart-define=RAFEEQ_MUSHAF_BASE=https://<bucket>/mushafs
```

### 5.6 Theme system — four variants, one seam (P2‑2)

`enum ThemeVariant { system, light, dark, rgb }` in
`lib/core/theme/theme_controller.dart` is the single source of truth
(persisted `theme_variant_v2`). `RafeeqApp` resolves it to MaterialApp's
`theme`/`darkTheme`/`themeMode`; **only `rgb`** also gets a global
`builder` that wraps the navigator in `RgbScaffoldBackground` (the animated
Islamic-geometry backdrop). `AppTheme.rgb()`'s scaffold is **transparent on
purpose** so the backdrop shows through every screen — do not "fix" that to
an opaque colour. Adding a 5th theme = one enum case + one `AppTheme.xxx()` +
one arm in `RafeeqApp`'s `switch`; no screen changes. The RGB backdrop
animation stops itself when the OS "reduce motion" setting is on or the
`settings.motion_effects` toggle is off.

### 5.7 Library book **text** editions come from al-Maktaba al-Shamela (P2‑4b)

Owner decision, 2026-09-02: the **نص** edition of every library book is
sourced from `shamela.ws` (owner confirmed downloading Shamela's book texts is
fine — "كل حاجة مرفوعة عليه"). `scripts/build_book_text.py` scrapes it into
`books/text/<id>.json` on `tito423/rafeeq-api`; `book_text_reader_screen.dart`
renders it.

**Licence reality — flagged, not hidden.** All 5 underlying classical texts
are public domain (authors d. 597–751 AH). A modern *muḥaqqiq*'s apparatus can
still carry copyright: the Arnaut editions (Riyad / book 12014, and the taʿlīq
on Mukhtasar Minhaj al-Qasidin / 98087) and the Shawish edition (al-ʿUbudiyya
/ 22647) are in copyright for the *taḥqīq*. Mitigations in place:
`build_book_text.py` extracts only the author's running text + section
headings and **drops the `div.hamesh` footnote apparatus**; each book's full
edition + editor line (`TextEdition.sourceLabel`) is shown in the reader at
all times and is one tap from "فتح في الشاملة". The owner chose Shamela
knowingly on this basis. If a future edition looks heavily
apparatus-dependent, prefer a plainer PD edition of the same text (that is
why al-Fawaid uses Shamela 6832 / دار الكتب العلمية 1973, **not** the
apparatus-heavy 2019 عطاءات العلم edition 212).

**`printReliable`** (`meta.printReliable` in the JSON): some Shamela books
carry the `[ترقيم موافق للمطبوع]` flag yet their `pageNum` values are out of
order in stretches — **Riyad as-Salihin (book 12014) drops ~100 pages four
times through the book.** The `nextId` walk still yields the correct *reading*
order (Nawawi's chapter sequence is intact — verified). So the reader shows
printed-page numbers / "go to printed page" **only when `printReliable`**;
otherwise it navigates by sequence position + the فهرس, and bookmarks are
keyed on `pageIndex` (stable) not the printed number.

---

## 6. Where things live

```
rafeeq_app/
  assets/data/
    quran_local.db                     6,236 ayahs + FTS5 (Hafs)
    quran_sciences.db          23 MB    tafsir, i'rab, word meanings, azkar, translations
    mushaf/
      editions.json                     generated catalog (5 editions)
      <edition>_polygons.json  ~0.75 MB each, normalized 0..1 per-page viewBox
    catalogs/                           adhans, audio_editions (176 ar reciters), reciters_full
  lib/
    core/config/app_config.dart         all remote URLs, pinned mushaf base
    core/db/sciences_repository.dart    tafsir / i'rab / meanings / translations / azkar
    core/services/
      mushaf_page_service.dart          SVG fetch + disk cache + prefetchEdition()
      ayah_audio_service.dart           per-ayah cache + downloadSurah()
      download_manager.dart             generic file downloader (T4)
    features/quran/
      data/ayah_coords_repository.dart  polygon regions + point-in-polygon hit test
      data/mushaf_edition.dart          MushafEdition model + providers + persistence
      presentation/screens/quran_screen.dart
      presentation/widgets/
        mushaf_page_view.dart           SvgPicture + highlight painter + tap
        mushaf_edition_sheet.dart       edition picker (previews real page 1)
        ayah_sciences_sheet.dart        4 tabs: tafsir / translation / i'rab / meanings
    features/downloads/                 Downloads screen (Mushafs | Recitations)
    features/adhan/                     Adhan settings, full-screen alert, scheduler (STAGE 1)
    features/home/data/prayer_controller.dart  location -> prayer times -> reschedules Adhan alarms
    features/library/                   Library screen: Hadith hub (tab) + Books catalog (tab, placeholder)
    core/db/hadith_repository.dart      reads the downloaded hadith.db (9 books, 40,943 hadiths)
    core/services/adhan_alarm_service.dart  native per-prayer exact alarms + notification sound
scripts/
  build_mushaf_svg.py                   SVG -> polygons  (EDITION=, PAGES=, WORKERS=, KEEP_SVG=)
  build_mushaf_catalog.py               generates editions.json + divergence data
  build_hadith_db.py                    hadith9/*.json -> pipeline_zips/hadith.{db,zip} (STAGE 2)
  ingest_translations.py                translation JSON -> DB
  check.ps1                             runs flutter, writes _check_output.txt
check.bat                               double-click wrapper for check.ps1
RAFEEQ_PIPELINE.md                      the 20-task roadmap and its status
```

**The `tito423/rafeeq-api` GitHub repo** is where large downloadable content
lives (mushaf pages are pinned to `quranpedia/quran-svg` directly instead, but
`hadith.zip` is hosted here — see `AppConfig.hadithDbUrl`/`contentBaseUrl`).
Its default branch is `master`, not `main` — a stale `contentBaseUrl` pointed
at `/main` (a 404) until STAGE 2 fixed it, since nothing had used that
constant before. The repo also still holds a `rafeeq_config.json` describing
an abandoned PNG-based mushaf design (a different repo, `Quran-PNG`, and
`api.quran.com`) — that is not the current architecture (vector SVG from
`quranpedia/quran-svg`, see §5.2) and should not be treated as one.

### Sciences DB schema (`quran_sciences.db`)
```
tafseer_texts          3,137  source, surah, ayah_start, ayah_end, text   (muyassar/jalalayn/qurtubi)
word_grammar          75,973  surah, ayah, pos, token, pos_ar, case_ar, root, lemma   (i'rab)
word_meanings         83,665  surah, ayah, pos, en
translations          18,708  surah, ayah, lang, edition, text            (en/fr/ur, 6,236 each)
translation_editions       3  lang, edition, name
azkar_sections           134
azkar_items              298
```
DB copy stamp is `sciences-v2` — **bump it if you change the DB**, or devices
keep the old copy.

---

## 7. THE CURRENT BLOCKER

### Update 2026-09-02 — `flutter analyze` is now CLEAN

Ran on Windows with Flutter 3.38.7 / Dart 3.10.7:
```
flutter pub get      # OK (63 packages have newer versions, all held by constraints — not touched)
flutter analyze      # No issues found!
```

The static-analysis pass the previous sandbox could not do is done: type
checking, null-safety, package API signatures and lints all pass. Only **13
issues** turned up, all real, all fixed in the analyzer-cleanup commit:

- **`ayah_sciences_sheet.dart` (10 errors).** `easy_localization` re-exports
  `package:intl`, whose `TextDirection` (`LTR`/`RTL`) shadowed the `dart:ui`
  enum (`rtl`/`ltr`) this file uses for text direction. Fixed with
  `import '...easy_localization.dart' hide TextDirection;`. No behaviour change —
  the file never used the intl one.
- **`app_config.dart`, `mushaf_page_service.dart` (3 info).**
  `unintended_html_in_doc_comment` — wrapped `<bucket>` / `<editionId>/<page>`
  in backticks inside doc comments.
- **`downloads_screen.dart` (1 info).** `curly_braces_in_flow_control_structures`
  — wrapped a one-line `if (mounted) setState(...)` in a block.

None of the "likely places" the previous note guessed at (flutter_svg /
just_audio / dio / FutureBuilder generics / Riverpod) actually had problems.

### Update 2026-09-02 (later) — first build + first device run (STAGE 0, partial)

`flutter build apk --debug` **succeeds** (first build ever; only Java-8
obsolete-option warnings from a plugin). Installed and run on an Android
emulator (Medium Phone API 36). Two real runtime bugs found and fixed:

1. **`quran_sciences.db` was never bundled.** `pubspec.yaml` listed
   `assets/data/quran_local.db` explicitly but not the sciences DB, so the
   whole ayah-sciences card (tafsir / translation / i'rab / meanings) would
   have thrown `Unable to load asset` on every device. Added the asset line.
2. **Read-only DBs crashed on open.** `DbHelper.openBundled` called
   `openDatabase(path, readOnly: true, version: 1)`. Passing `version:` makes
   sqflite run `PRAGMA user_version = 1` — a write — which fails with
   `SQLITE_READONLY (code 8)`. This broke the **entire Quran tab** (error
   state) and every sciences lookup. Fixed: read-only opens now use
   `openReadOnlyDatabase(path)` with no version.

**Verified working on the emulator after the fixes:**
- App launches, no crash; all 5 tabs reachable. (Azkar & Hadith are honest
  "قريباً…" stubs — expected, they are STAGES 2–3.)
- Quran **text mode**: real Uthmani Al-Fātiḥa, page 1/604, ayah numbers.
- Ayah **sciences card** (STAGE-0 check 0.4): real Muyassar + Jalalayn tafsir,
  EN (Saheeh) + FR (Hamidullah) + UR (Jalandhry) translation, per-word i'rab
  (root/lemma/case from the corpus), per-word English meanings. No placeholders.
- Settings screen: language toggle, theme toggle, downloads entry, real
  source list.

### Update 2026-09-02 (later still) — STAGE 0 GATE PASSED, all 10 on the emulator

The network wall was a **host** problem: this Windows box runs Avast "Web/Mail
Shield", which MITM-intercepts all TLS and re-signs it with
`Avast Web/Mail Shield Root`. Windows trusts that root; the emulator did not, so
every HTTPS fetch failed `CERTIFICATE_VERIFY_FAILED`. Owner approved trusting
that root in **debug** builds only — see `android/app/src/debug/` (commit
`e7b8728`): a `networkSecurityConfig` that adds the bundled Avast root next to
the system/user anchors. `src/main/` is untouched; release builds never see it.
`Dio()` usage in the app was always correct.

After that, one more **real app bug** found and fixed (commit with the audio
fix): recitation playback did nothing. `main()` initialises
`just_audio_background`, which throws on any audio source that has no
`MediaItem` tag — and `AyahAudioService` was calling `setFilePath` / `setUrl`
untagged, so every play silently caught the exception. Now it uses
`setAudioSource(AudioSource.file/uri(..., tag: MediaItem(...)))`; the sheet
passes a real "سورة • s:a" title so the media notification reads properly.

**STAGE 0 acceptance — all verified on the emulator (Medium Phone API 36):**

| # | check | result |
|---|---|---|
| 0.1 | launches, 5 tabs, no crash | ✅ (Azkar/Hadith are honest "قريباً…" stubs) |
| 0.2 | image-mode page renders, light **and** dark | ✅ glyphs recolour per theme |
| 0.3 | tap 2:6 on p.3 → **two** line fragments highlighted, not one box | ✅ — the polygon pipeline is correct |
| 0.4 | ayah card: real tafsir (Muyassar+Jalalayn) / EN+FR+UR / i'rab / meanings | ✅ no placeholders |
| 0.5 | edition picker → Warsh; picker shows the numbering warning | ✅ warning on Warsh/Qalun/Duri, not Hafs/Shubah |
| 0.6 | Warsh + a diverging surah (2) → "غير متاحين لهذه السورة في هذه الرواية", **not** tafsir | ✅ |
| 0.7 | download a mushaf → real incrementing progress | ✅ 14→88→205 pages, resumable |
| 0.8 | download one surah's recitation | ✅ 7 real per-ayah mp3s on disk |
| 0.9 | network OFF → cached pages render, uncached show honest error, downloaded audio plays | ✅ (audio only after the MediaItem fix) |
| 0.10 | paging smooth | ✅ no dropped-frame/Davey logs paging cached pages; re-judge feel on a real low-end device — fix if needed is `vector_graphics` `.vec`, not raster |

**Bugs found but NOT fixed (out of STAGE-0 scope — track separately):**
_Most of these were the PHASE 2 Stage P2‑1 sweep — see `PHASE2.md`. Status
updated 2026-09-02._
- ~~**Mushaf download stops when you leave the Mushafs tab.**~~ **FIXED (P2‑1.4),
  emulator-verified.** Root cause: `prefetchEdition` was fire-and-forget and the
  Downloads tile owned the observation, losing it when the tile was rebuilt on a
  tab switch. Now `MushafPageService` publishes a `PrefetchProgress`
  (`ChangeNotifier`) per edition; the tile re-attaches to a running job in
  `initState`. Verified live: started Hafs, switched to التلاوات and back —
  progress had continued 3 → 27 → 39 → 51 and the tile still showed the bar, not
  the Download button. (P2‑5 folds this into a unified manager.)
- ~~**Reader mode (text/image) is not persisted.**~~ **FIXED (P2‑1.3),
  emulator-verified.** `quran_screen.dart` persists `_mode` under
  `SharedPreferences` key `quran_reader_mode`; restored in `initState`. Verified:
  switched to image mode → `am force-stop` → relaunch → still image mode.
- ~~`android/app/src/main/res/raw/` still ships 6 `.m4a` "adhan" files~~ —
  **fixed in STAGE 1**: the fake files are deleted; the 10 real adhans now
  also live in `res/raw/` (needed for the native alarm sound, see below).
- ~~Text-mode surah header renders `سورة سورةُ الفاتحة` (doubled "سورة").~~
  **FIXED (P2‑1.1), emulator-verified.** The DB `name_ar` already contains
  "سُورَةُ …"; `mushaf_text_page.dart` now renders it directly.
- ~~Stray `()` under the last ayah on a text-mode page.~~ **FIXED (P2‑1.2),
  emulator-verified.** Removed the trailing decorative `﴿ ﴾` `Text` widget.
- ~~Settings: `المصادر والمأسى` should be `المصادر والمراجع`~~ — **fixed in STAGE 1.**
- ~~Launcher icon is a square JPG, no alpha / adaptive shape.~~ **FIXED
  (P2‑1.5), emulator-verified.** Icon designed in-house (owner: "design it
  yourself") — originally a rub‑el‑hizb guiding star over a receding path,
  teal/gold. **Redesigned again 2026‑09‑03** (owner ask) into a mosque
  silhouette on the app's real `AppColors` palette — see the 2026‑09‑03 §7
  update below; that pass also found and fixed a real bug in this icon's
  render pipeline (the adaptive foreground PNG had no alpha channel at all,
  present since this original P2‑1.5 commit). Source SVGs + regen steps in
  `rafeeq_app/assets/icon/src/`. Adaptive fg/bg via `flutter_launcher_icons`
  (`mipmap-anydpi-v26/ic_launcher.xml`). Old `app_icon.jpg` deleted;
  `assets/icon/` dropped from the Flutter bundle (build-time only,
  ~0.9 MB lighter).
- ~~i'rab root/lemma show Buckwalter translit ("Hmd", "rbb") not Arabic.~~
  **FIXED (P2‑1.6), emulator-verified + unit-tested.** New
  `lib/core/utils/buckwalter.dart` (`buckwalterToArabic` / `buckwalterForDisplay`)
  + `test/buckwalter_test.dart` (6 cases). `_IrabTab` now shows الجذر: سمو /
  الكلمة: ٱسْم etc. `flutter test` = 11/11 green.

### Update 2026-09-02 — STAGE 1 (Adhan system), built and emulator-verified

Owner approved treating the STAGE 0 emulator run as sufficient and moving on
(rather than requiring a physical device first) — see the WIP note above.
Built all of WORK_QUEUE T10–T13:

- **`lib/features/adhan/`** — `AdhanSettingsScreen` (picker with real preview
  via a tagged `just_audio` player, custom-adhan import via `file_picker`,
  per-prayer mode + sound override, a battery-optimization-exemption card,
  per-prayer "تجربة" test button), `AdhanFullScreenScreen` (karaoke text,
  Stop/Mute), `adhan_scheduler.dart` (resolves settings + catalog into real
  `AdhanAlarmService.scheduleDaily` calls), `adhan_settings_provider.dart` /
  `adhan_catalog_provider.dart` (Riverpod, SharedPreferences-backed).
- **`lib/core/services/adhan_alarm_service.dart`** rewritten: one small
  notification channel per (mode, sound) pair — channels are immutable on
  Android, so the sound/vibration config lives in the channel id, not in a
  per-prayer channel. `AndroidNotificationCategory.alarm` +
  `AudioAttributesUsage.alarm`, `fullScreenIntent` only for mode "full".
- **`lib/features/home/` real prayer times**: `PrayerController` fetches
  location → `PrayerTimesService` → reschedules every prayer's alarm; Home
  shows an honest "enable location" card when denied (never a fake city).
- **Native additions**: `MainActivity.kt` gained a `contentUriForFile` method
  channel (FileProvider, for a custom adhan's sound URI) and a `FileProvider`
  + `res/xml/file_paths.xml` in the manifest. The 6 fake `res/raw/*.m4a`
  files are gone; the 10 real `assets/audio/adhan/azan*.mp3` are now **also**
  `res/raw/azan*.mp3` — required because `RawResourceAndroidNotificationSound`
  needs a compiled Android resource, not a Flutter asset path.

**Why the sound is native, not Dart:** `zonedSchedule`'s alarm fires through
`flutter_local_notifications`' own Java `BroadcastReceiver`, which does not
start the Dart VM. If the app is killed, no Dart code runs — so only Android's
own notification-sound API can possibly play the adhan. This is also why
Stop/Mute act on the *notification* (cancel it / repost it silenced) rather
than on a Dart audio player.

**STAGE 1 acceptance (WORK_QUEUE) — verified on the Android emulator, not a
physical device.** Verification method matters here: every claim below was
confirmed with `adb shell dumpsys audio` (to see the actual native
`AudioTrack`/`MediaPlayer` start/stop events, not just a UI state), `dumpsys
media_session`, and `dumpsys notification`, alongside screenshots — not
screenshots alone.

| # | check | result |
|---|---|---|
| set a prayer 2 min ahead → lock the phone → adhan fires with sound + full-screen UI | ✅ fired 4 separate times for 4 different prayers (Dhuhr, Asr, Maghrib, Fajr), each time waking the locked emulator into the full-screen karaoke view; `dumpsys audio` showed a real `com.android.systemui` `MediaPlayer` with `usage=USAGE_ALARM` starting each time |
| Fajr shows "الصلاة خير من النوم" | ✅ present in the Fajr firing, absent from the other three |
| Stop works from the alert | ✅ — but only after a real bug fix (below); confirmed via `dumpsys audio` (`event:stopped` at the tap instant) and `dumpsys notification` (`numRemovedByApp` incrementing) |
| Mute works from the alert | ✅ confirmed via `dumpsys audio` `event:stopped` at the tap instant, plus the UI switching to a "كتم" label and a disabled Mute button |
| per-prayer choice survives an app restart | ✅ set Isha to "اهتزاز فقط" (vibrate only), ran `adb shell am force-stop`, relaunched, navigated back — still vibrate-only, not reverted to the "full" default |
| preview playback in the picker | ✅ real play/stop, confirmed via `dumpsys media_session` (`state=PLAYING` with an advancing `position`) — the icon lags the real audio state by a second or two (buffering latency), not a bug |
| custom adhan from device (file picker) | 🔶 the picker button opens the real Android document picker (`com.android.documentsui`) — a full import → selection → firing alarm with the custom sound was not carried through to completion in this session |
| battery-optimization exemption button | 🔶 tap produced no dialog and no change in `dumpsys deviceidle`/whitelist on this emulator image; the manifest permission and `permission_handler` call are both standard and correct, so this reads as an emulator limitation, but it is **not confirmed** — re-test on a physical device |

**Two real bugs found by this testing and fixed, not left in:**
1. `AdhanFullScreenScreen` wrapped itself in `PopScope(canPop: false)` to stop
   an accidental back-swipe — which also blocked the Stop button's own
   `Navigator.maybePop()`, so Stop silenced the alarm but visibly did nothing.
   Fixed with `canPop: _stopped` plus `popUntil((r) => r.isFirst)` (a
   fullScreenIntent launch over a locked screen was observed to sometimes
   deliver its notification-response twice, stacking two copies of the
   screen — `popUntil` clears all of them in one Stop tap, `maybePop` only
   cleared one).
2. The adhan-picker preview's `await _preview.play()` doesn't resolve until
   playback *finishes*, not when it starts (documented in
   `ayah_audio_service.dart` for a different player, missed here first time)
   — the play/stop icon looked stuck for the whole track. Fixed with
   `unawaited(_preview.play())`, same as the existing pattern.

### Update 2026-09-02 — STAGE 2 Hadith hub: built, verified without the download

**What "verified" means here, precisely:** the real `hadith.db` (built by
`scripts/build_hadith_db.py` from the real source JSON already in this repo)
was pushed directly onto the emulator's app storage with `adb push` +
`run-as` — not downloaded through the app. That was a deliberate workaround
for the TLS problem below, so the repository/UI layer could still be proven
correct against real data. The download path (`DownloadManager` → the hosted
`hadith.zip` → unzip → same file) is architecturally the same mechanism
already proven for mushaf pages, but was **not itself exercised successfully**
this session — say so plainly if asked whether hadith downloads work.

| # | check | result |
|---|---|---|
| 9 books list with real names/authors/counts | ✅ Sahih Bukhari 97 ch./7277 hadiths, Sahih Muslim 57/7459, Sunan Abi Dawud 43/5276, Jami' al-Tirmidhi 49/4053, Sunan al-Nasa'i 52/5768, Sunan Ibn Majah 38/4345, Musnad Ahmad 8/1374, Muwatta Malik 61/1985, Sunan al-Darimi 24/3406 — all real counts, no placeholders |
| chapter list numbered/titled correctly | ✅ Bukhari's 97 chapters read 1, 2, 3 … in order with real Arabic **and** English titles ("كتاب بدء الوحى" / "Revelation", etc.) |
| hadith numbering — the "2 → 9 → 99" bug | ✅ **fixed and re-confirmed live**: Bukhari chapter 1 shows exactly its real 7 hadiths (hadith #1 is the famous "actions are by intentions"); chapter 2 crosses the two-digit boundary (8, 9, 10, 11 … 21, 22) with no break |
| hadith detail (Arabic + English narrator/text, Previous/Next) | ✅ real text both languages, navigation works |
| FTS5 search | 🔶 implemented, code-reviewed, **not interactively confirmed** — `adb shell input text` would not put text into the search field this session (Arabic input isn't supported by that adb command at all; even an ASCII term didn't register, cause not diagnosed) |
| the actual hadith.db **download** (network → zip → unzip → open) | ❌ **not verified** — blocked by the TLS problem below on every attempt |
| battery/library "Books" catalog tab | N/A — intentionally an honest placeholder, see the WIP note above |

**The TLS blocker, in detail:** `HandshakeException: CERTIFICATE_VERIFY_FAILED:
unable to get local issuer certificate` on every HTTPS call the app made this
session, including mushaf image-mode fetching (previously verified working in
STAGE 0). Checked and ruled out: the manifest's debug `networkSecurityConfig`
merge is present in the built APK (confirmed via `aapt2 dump xmltree`); the
bundled `proxy_debug_ca.pem`'s SHA-1 fingerprint is byte-identical to the
live Avast Web/Mail Shield root currently in Windows' trust store *and* to
the actual certificate `openssl s_client` observed being served for
`raw.githubusercontent.com` right now (a flat root→leaf chain, no missing
intermediate); a full emulator kill + relaunch did not clear it. The cause is
still unidentified — something about how the Avast interception is or isn't
reaching this specific emulator process changed since STAGE 0, or Dart's
engine and Android's Java networking layer handle the bundled trust anchor
differently in some case not yet isolated (mushaf pages use the same `Dio()`
client as the hadith download, which is why "different HTTP client" isn't the
answer either). Whoever has hands on the host machine next: check whether
Avast Web/Mail Shield's Web Shield is still enabled the same way it was
during STAGE 0, or just test on a physical device to sidestep the whole
question — a phone's own network never goes through the PC's Avast at all.

**Update, later the same day: the TLS blocker is gone and the download is
now actually verified.** The owner disabled Avast Web/Mail Shield entirely
(remotely, via TeamViewer) specifically to unblock this. The very first real
attempt afterward still failed — but with a plain `404`, not a TLS error,
immediately proving Avast really was the whole story. The 404 was a real,
separate bug of its own: `AppConfig.hadithDbUrl` pointed at `hadith/hadith.db`,
which was never pushed to `rafeeq-api` — only `hadith/hadith.zip` was. Fixed
the constant. After that: fresh install → tap download → real ~17 MB
transfer → unzip → the full 9-book list rendering with correct counts,
**repeated twice from a clean install each time**. The "❌ not verified" row
above is now ✅. See the WIP note at the top of this file for the two further
bugs (`setState`/Future, missing FTS5) that this real download testing then
surfaced and got fixed.

### Update 2026-09-02 — STAGE 3 Azkar & Tasbeeh: built and fully verified

Entirely offline (reads the already-bundled `quran_sciences.db`), so none of
this was affected by the TLS problem above.

| # | check | result |
|---|---|---|
| no duplicate azkar within a section | ✅ verified with a real SQL query — 0 duplicate `(section_id, body)` pairs across all 134 sections |
| tasbeeh counter counts on the **first** tap | ✅ **live-verified**: tapping the three-Quls dhikr (real target 3, parsed from its own "( ثلاث مرات )" text) once showed "3 / 1" immediately — the historical bug this check exists for (only counting after a reset) does not reproduce |
| auto-advance at the real target count | ✅ live-verified: the same item auto-advanced to item 4/25 exactly at the 3rd tap |
| fadl/source shown per dhikr | ✅ the bundled `footnote` field, shown under every dhikr's text (e.g. real Abu Dawud/Tirmidhi references) |
| haptics toggle | ✅ live-verified in the settings sheet, persisted |
| custom reminder times (no hardcoded 05:00/16:30) | ✅ live-verified: both reminders default to "متوقف" (off); picking a real time via the Material time picker (not a placeholder) updates the row and arms a real `zonedSchedule` |
| digital tasbeeh (free counter) | ✅ 33/100/1000 targets, matches Home's existing "السبحة" quick-access card |

### Update 2026-09-02 — STAGE 4 translation selector: done, emulator-verified

`AyahSciencesSheet`'s translation tab showed en/fr/ur stacked; now a
persisted dropdown (`translation_lang_provider.dart`) shows one at a time.
Verified live: ayah 1:1's translation tab opened with the dropdown on
English and only the Saheeh International text below it.

### Update 2026-09-02 — STAGE 5 New Muslim Guide: written and emulator-verified

Content lives in `lib/features/new_muslim/data/guide_content.dart` — written
by hand from mainstream, uncontroversial Sunni teaching per the owner's
explicit go-ahead, not fetched or scraped from anywhere.

| # | check | result |
|---|---|---|
| 5 topics, correct real content | ✅ pillars of Islam (5), articles of faith (6), wudu (8 steps), prayer steps (10), Quran intro (3 points) — all standard, universally-agreed teaching |
| reachable from Home | ✅ **and a real pre-existing bug fixed**: the quick-access card called `onNavigate(3)`, which STAGE 2 had silently repointed to Library when it renamed that tab slot — now pushes `NewMuslimGuideScreen` directly |
| Wudu detail renders correctly, in order | ✅ live-verified: all 8 real steps, ending with the Shahada dua shown in a Quran-font phrase box |
| bilingual (ar/en) | ✅ written by hand for each item (not through the easy_localization key system, matching how Quran/azkar/hadith text is content rather than UI chrome) |

### Update 2026-09-02 — STAGE 6 thematic search: built and now fully
### live-verified; 4 real repository-level bugs found and fixed along the way

`lib/features/search/data/topic_tree.dart` — a curated topic tree over real,
independently-verifiable ayah ranges (5 categories: aqeedah, akhlaq,
prophets' stories, rulings, the hereafter), which is the honest way to do
"find ayahs by meaning" without an offline semantic/embedding model this app
doesn't have — mislabeling keyword search as conceptual would itself be a
zero-mock-data violation. A second tab reuses `QuranRepository.search()`.
Reachable from a new icon in the Quran reader's toolbar, returning the
tapped ayah's page number so the reader can jump straight there.

| # | check | result |
|---|---|---|
| topic tree renders, all 5 categories | ✅ live-verified: العقيدة / الأخلاق / قصص الأنبياء / الأحكام / الآخرة all list with their real topics |
| a topic's real ayahs load correctly | ✅ live-verified: "الصبر" (patience) shows exactly the curated set — 2:153, 2:155, 2:156, 2:157, 3:200, 39:10 — correct Arabic text and references |
| keyword search (Quran) | ✅ implemented and re-verifiable via the same normalization now used for hadith search (see Bug #3 below) |
| tapping a result jumps the reader to that page | ✅ **confirmed on a repeat test**: tapping ayah 2:153 in the "الصبر" list navigated to page 23/604, showing that exact ayah at the bottom. The earlier "not confirmed" note reflected real tap-precision uncertainty in that session's testing, not an actual bug |

**Four real, repository-level bugs found while testing this against the now-
unblocked hadith download (all explained in full in the WIP note above,
summarized here since they were caught by Stage 6 code as much as Stage 2's):**
1. `setState(() => _future = someAsyncCall())` returns the assignment's value
   (a `Future`), which `setState` rejects at runtime — found via the hadith
   search box crashing, and it turned out an **identical, independent,
   pre-existing bug** was sitting in `mushaf_page_view.dart`'s `_retry()`
   too. Both fixed with a block body.
2. **`sqflite` on this Android build has no FTS5 module** — both
   `hadiths_fts` and `ayahs_search` (the FTS5 tables this app already
   shipped, built successfully with Python's own sqlite3) fail every query
   on-device with `SQLiteLog: (1) no such module: fts5`. Both
   `HadithRepository.search()` and `QuranRepository.search()` were rewritten
   to plain `LIKE` queries.
3. **The LIKE fix above still didn't actually work for Arabic.** Both
   `arabic` and `text_uthmani` are stored fully diacritized, so an ordinary
   undiacritized query never matches real vocalized text — confirmed
   directly against `hadith.db` with sqlite3 (`LIKE '%عمر%'` → 0 rows despite
   "عُمَرَ" appearing in the very first hadith). Fixed with a new
   `lib/core/utils/arabic_normalize.dart`, covered by a new
   `test/arabic_normalize_test.dart`.
4. **A real `OutOfMemoryError` crash** from loading all ~41k hadiths in one
   `_db.query()` call (sqflite ships the whole result set across the platform
   channel as one message; ~83MB in one shot exceeded this device's heap).
   Fixed by paging the scan (`LIMIT`/`OFFSET`, 2000 rows at a time) with no
   persistent cache, re-verified live with both a real search and a
   deliberate full-table no-match scan, neither of which crashed.

### Original context (why analysis had never run)

The previous agent worked from an isolated Linux sandbox with only the project
folder mounted: no Flutter, no Windows shell, and the Dart/Flutter SDK downloads
were blocked by that sandbox's network policy (403). Computer control was no
help either — terminals can only be granted click-only access, so commands
could not be typed.

**What that agent verified by hand across all 35 Dart files:** bracket balance,
local imports resolve, `AppColors.x` members exist, `'key'.tr()` keys exist with
ar/en parity 168/168, polygon coverage 6,236/6,236, catalog divergence figures,
pinned CDN bytes. All of that still holds and is now backed by the analyzer.

### Update 2026-09-02 — STAGE 7 (security/guest mode) & STAGE 8 (release)

Condensed here from a longer WIP note; full detail is in git at
`git show 10dbd35:HANDOVER.md`.

**STAGE 7.** Grepped all of `lib/` for `signIn`/`login`/`auth`/`FirebaseAuth`:
there is no authentication code anywhere, so "every offline feature works
without an account" is true by construction — guest mode is the only mode.
`AppConfig` re-confirmed secret-free. **One real gap fixed:**
`rafeeq_app/android/app/google-services.json` (a live Firebase config for
project `rafeeq-aldarb` — real API key + OAuth client id) had been committed
since the first commit and never gitignored. `git rm --cached`'d it (local
file untouched) and extended `rafeeq_app/.gitignore` to also cover `.env`,
`GoogleService-Info.plist`, `android/key.properties`, `*.jks`/`*.keystore`.
Risk note: a Firebase **Android** API key is designed to ship in-client and is
not a server secret (protection is API-key restrictions + Security Rules), but
it shouldn't be in git per this project's own checklist and it is in history
from commit 1 — worth the owner knowing. **Google sign-in itself is still not
built** — no `firebase_auth`/`google_sign_in` in `pubspec.yaml`; finishing it
needs the owner to register a release SHA-1 in the Firebase console (no agent
can do that). Flagged, not half-built.

**STAGE 8.** Ran `flutter clean` → `pub get` → `analyze` → `build apk --release
--split-per-abi` for real: succeeds (armeabi-v7a / arm64-v8a / x86_64 =
35.8 / 37.8 / 39.2 MB); the x86_64 APK installs and runs on a fresh emulator
(Arabic UI intact, honest "enable location" empty state, no fake data). Removed
`android:usesCleartextTraffic="true"` from the **main** manifest — a full `lib/`
grep finds zero `http://` URLs, so it was a leftover (unrelated to the
debug-only `network_security_config`, which handles the Avast TLS root and is a
separate mechanism); release now defaults to disallowing cleartext. **Still
blocked:** the release build is signed with the **debug** keystore (a
`// TODO: Add your own signing config` sits in `android/app/build.gradle.kts`).
Real signing needs the owner's own keystore/alias/passwords — an agent
generating one would lock everyone else out of re-signing updates.

### Update 2026-09-02 (next session) — STAGE 2 Library "Books" catalog finished + emulator-verified end to end

Picked up an in-flight, non-compiling edit (previous session died mid-write in
`library_screen.dart`'s `_BookCard`). Finished it: `_CatalogTab` is now a real
download/open catalog over `lib/features/library/data/book_catalog.dart` — 4
real public-domain classical texts (Riyad as-Salihin, Mukhtasar Minhaj
al-Qasidin, Ibn al-Qayyim's al-Fawaid, Ibn al-Jawzi's Sayd al-Khatir) hosted
as PDFs on archive.org. **All 4 `downloadUrl`s checked with a real `curl -L`
GET on 2026-09-02: HTTP 200, `application/pdf`;** `approxSizeBytes` is each
response's measured Content-Length (the previous session's guesses were off —
al-Fawaid was 15 MB in the catalog, actually 6.29 MB — all four are now exact).
Download reuses the same `DownloadManager` as the hadith DB; `BookReaderScreen`
opens the file with `SfPdfViewer.file`.

**Verified live on the Android emulator (Medium Phone API 36):** المكتبة →
الكتالوج lists the 4 books with real metadata and sizes; tapped تنزيل on
al-Fawaid → real download → the card flipped to فتح → the reader opened the
**real archive.org PDF** (title page: "الفوائد لابن القيم، تحقيق عصام الدين
الصبابطي، دار الحديث القاهرة"). File on disk is exactly 6,285,456 bytes,
`%PDF-1.5`. Then **airplane mode ON**, reopened from the catalog → still
renders, page-scroll to page 2 works. This is T14 done → STAGE 2 done → the
whole 20-task pipeline is now complete.

Catalog is 4 titles, honestly labeled "a starting set" — the owner's list also
named Ibn Taymiyyah, al-Hakim al-Tirmidhi, Ibn Abi al-Dunya, and al-Jaziri's
*al-Fiqh ala al-Madhahib al-Arba'ah* (1941 — needs its own licensing check,
not public-domain by author death). More can be added the same way: one
`LibraryBook` entry per title, `downloadUrl` verified with a real GET.

Also fixed `scripts/checkpoint.ps1` — it read/wrote `HANDOVER.md` through
PowerShell 5.1's ANSI default and **corrupted every Arabic char + em-dash on
each run** (one such corruption, commit `a57ac7b`, was caught and the file
restored from `10dbd35`); it now forces UTF-8 both directions and `cp.bat` is
hardened so a Git-Bash-mangled `/s` can't become a junk commit. **Run `cp.bat`
from PowerShell/cmd, not Git Bash.**

### Update 2026-09-02 — P2‑7 (Adhan audio/video): code done, verification pending the video upload

Owner ruled out YouTube/copyrighted content (the no-scraping rule stands) and
asked for a **licence-clean** mosque video. Got **5 Pixabay clips** (Pixabay
Content License — free commercial use, no attribution): `haram_makkah`,
`kaaba`, `madina_nabawi`, `mosque_prayer`, `mosque_ottoman` (1–5.5 MB each),
staged in `scripts/adhan_video_build/` (gitignored).

Code: `video_player` added; `adhan_video_catalog.dart` +
`adhan_presentation_provider.dart` (`audioOnly|video` + `videoId`, persisted,
default audio; `resolveAdhanVideoPath`); `AdhanFullScreenScreen` gains an
optional `videoPath` → muted looped `VideoPlayer` behind the karaoke text
(BoxFit.cover + scrim), gradient fallback; payload/scheduler/navigation carry
`video`; `adhan_settings_screen` `_PresentationCard` (`صوت | فيديو` +
5-clip download/pick + Pixabay source line + honest "video only while the
screen is on" note); 30-adhan cap (`AdhanCatalogService.maxTotalAdhans` +
`AdhanLimitReached`). +8 keys ×5 (parity 286). `analyze` clean, `test` 13/13.

**Left:** run `python scripts/upload_adhan_videos.py` to host the 5 clips on
`rafeeq-api/adhan/video/` (the in-session `gh api` push was classifier-blocked
— needs owner OK or a manual run), then emulator-verify the pick → download →
"تجربة" → video-behind-karaoke flow and the 30-adhan refusal.

### Update 2026-09-03 — P2‑7 clips uploaded + hosted; download/select/persist
### verified; full-screen video render **not** verified (emulator limitation)

Ran `python scripts/upload_adhan_videos.py` (owner's prompt explicitly said
"ارفع الـ5 فيديوهات … اسأل الأونر أو شغّل السكربت" — read as authorization to
just run it). All 5 uploaded to `tito423/rafeeq-api/adhan/video/<id>.mp4`.
**Every URL independently re-verified** with `curl -sIL`: HTTP 200, and
`Content-Length` byte-identical to the local file (`haram_makkah` 2,307,544 ·
`kaaba` 3,981,671 · `madina_nabawi` 5,515,868 · `mosque_ottoman` 1,717,259 ·
`mosque_prayer` 981,129 — all exact). GitHub raw serves them as
`application/octet-stream` rather than `video/mp4`, same as every other
`rafeeq-api` asset; irrelevant here since `DownloadManager` fetches raw bytes
to a local file before `video_player` ever opens them.

**Verified live on `emulator-5554`** (fresh install, `pm clear` then a normal
relaunch): صوت↔فيديو switch; downloading المسجد النبوي (madina_nabawi, the
largest clip) showed a real progress bar and completed, auto-selecting it
(مختار) — one clip auto-selects when it's the only one downloaded, matching
`AdhanPresentationState` defaulting to the first available; a silent "فيديو
الأذان — تم التنزيل" download-complete notification appeared in the shade;
tapping "تجربة" for الظهر posted a real notification titled "الصلاة — الظهر
(تجربة)" on the correct `radh_full_azan1`-family channel with the expected
Stop/Mute actions; **the video-mode selection (فيديو + المسجد النبوي) survived
a full `am force-stop` + relaunch** — confirms the `adhan_presentation_v1` /
`adhan_video_id_v1` persistence works.

**Not verified this session: the actual full-screen screen showing the video
behind the karaoke text.** This was attempted extensively and is worth
recording in detail so the next session doesn't repeat the same dead ends:

- A live tap on the notification body (the normal "app already running"
  path) reliably dismissed/re-focused the app but never navigated to
  `AdhanFullScreenScreen` — tried with visually-estimated coordinates first
  (several misses traced to a coordinate-scaling mistake: the screenshots
  Claude sees are downscaled 900×2000 from the device's real 1080×2400, so a
  position read off the image has to be **multiplied by 1.2** before sending
  it to `adb shell input tap`; several early attempts skipped that step) and
  then with `uiautomator dump`-verified exact bounds (which worked correctly
  for a native Android permission dialog in the same session) — still no
  navigation, and `adb logcat` around the tap showed **no Flutter/exception
  output at all**, i.e. not a crash, just no observed effect.
- Tried the documented real trigger — **lock the phone, let the alarm fire
  while locked** (`AndroidNotificationCategory.alarm` + `fullScreenIntent:
  true` + `MainActivity`'s `showWhenLocked`/`turnScreenOn`, per the doc
  comment in `adhan_alarm_service.dart`) — repeatedly. First found that
  Android 14+'s `USE_FULL_SCREEN_INTENT` app-op defaults to **reject** and
  has to be explicitly granted (`adb shell appops set <pkg>
  USE_FULL_SCREEN_INTENT allow`); after granting it, still nothing. Then
  found this specific AVD (`Medium Phone API 36`, Android 16) has **no
  keyguard configured by default** (`dumpsys window` → `isKeyguardShowing=
  false` even while `mWakefulness=Asleep`) — Android's fullScreenIntent
  auto-launch is documented to require the device actually be
  **keyguard-locked**, not just screen-off, so this AVD's default state can
  never satisfy it. Set a real PIN with `adb shell locksettings set-pin
  1234` to force a genuine keyguard (`isKeyguardShowing=true` confirmed) and
  tried again — the notification fired (confirmed via `dumpsys notification`)
  but the device stayed asleep with no window regaining focus, and waking it
  afterward went straight back to whatever screen was open before, never the
  full-screen adhan. Cleared the PIN again afterward
  (`locksettings clear --old 1234`) so the emulator was left in its original
  no-lock state.
- Also tried force-stopping the app to exercise the **cold-launch** payload
  path (`main.dart`'s `consumeColdLaunchPayload`) instead of the live-tap
  one — but `am force-stop` turned out to **cancel the app's own ongoing
  test notification** (confirmed via `dumpsys notification` losing the
  entry), so that path couldn't be exercised either without a live
  notification to tap.

**Why this reads as an environment/automation limitation, not a code bug:**
the wiring was re-read end to end (`AdhanPayload.tryParse`, `rootNavigatorKey`
correctly passed to `MaterialApp.navigatorKey`, `onDidReceiveNotificationResponse`'s
`default:` case calling `onOpenAdhan`, `scheduleTest`/`scheduleDaily` sharing
the exact same `_detailsFor`/payload path) and nothing looks wrong; this is
also **the same underlying native alarm/full-screen-intent mechanism STAGE 1
already verified working on this project**, with real device interaction
(lock the phone, alarm fires, full-screen karaoke view appears) — P2‑7 only
adds an optional `videoPath` parameter on top of it. Simulated touch input on
notifications/keyguard is a known-fragile target for scripted ADB interaction
in general. **Next session: verify on a real Android phone** — lock it for
real, fire a "تجربة" test from Adhan settings, and confirm the video plays
behind the karaoke text; that sidesteps every issue hit here (no keyguard
config quirk, no touch-injection uncertainty). If it still doesn't navigate
on a real phone, *then* treat it as a real bug and start from
`adhan_navigation.dart`'s `openAdhanFromPayload`.

30-adhan cap and the honest "video only while the screen is on" note were
visually re-confirmed present in the settings UI; the cap's actual refusal
behavior (importing a 31st adhan) was not re-exercised this session (no
catalog changes were made to it).

### Update 2026-09-03 — launcher icon redesigned: mosque silhouette,
### real `AppColors` palette; a real transparency bug found + fixed

Owner ask: make the launcher icon "لايق يشبه الثيم بتاع التطبيق ويكون فيها
شكل المسجد" (fitting, matching the app's theme, with a mosque shape).
Redesigned `assets/icon/src/{icon_full,icon_fg,icon_bg}.svg` — a flat gold
mosque silhouette (central onion-free hemispherical dome + crescent finial,
two smaller flanking domes, two minarets with balcony rings, an arched
doorway) over a radial background gradient now built from the **actual**
`AppColors` constants (`night` `#071625` → `primaryContainer`-ish `#0F3D33`
→ `primarySoft` `#16A085` at the centre) instead of the previous
hand-picked approximation — this is the literal reason it now "matches the
theme": same numbers as `lib/core/theme/app_colors.dart`, not just a similar
green. Gold gradients (`#F7E7AC`→`#C99E2E`/`#B4841F`) unchanged in spirit
from the original icon.

**A real bug found while doing this (present in the *previous* icon too,
not something this change introduced):** the documented regen command
(`chrome --headless --screenshot=...`) bakes an **opaque white** page
background into the PNG unless `--default-background-color=00000000` is
passed — confirmed by checking a corner pixel's alpha (`A=255`, not `0`) on
both the new render *and* the already-shipped `app_icon_foreground.png`
from the P2‑1.5 commit. For an **adaptive-icon foreground** layer this is a
real defect: without alpha, the foreground fully occludes the background
layer instead of letting it show through outside the mark. It evidently
went unnoticed in P2‑1.5's own verification. Fixed by adding the flag for
the foreground render only (`icon_full`/`icon_bg` don't need transparency,
they're meant to be fully opaque); `assets/icon/src/README.md`'s regen
recipe now includes the flag and a one-line pixel-alpha sanity check so
this can't silently regress again.

**Verified live on `emulator-5554`:** `dart run flutter_launcher_icons` →
`flutter build apk --debug` → install → home screen → app drawer: the
"Rafeeq AlDarb" icon shows the teal→navy gradient (now real `AppColors`
values) genuinely showing through the adaptive mask, with the gold mosque
mark (dome, crescent, two side domes, two minarets, dark doorway arch) all
clearly legible — cropped and zoomed in from a real screenshot to confirm,
not just eyeballed at native size. Also rendered the flat `icon_full.png` at
96×96 and 48×48 (downscaled with .NET `System.Drawing`, since Chrome's
`--window-size` doesn't rescale an SVG's own `width`/`height`) to confirm
the silhouette stays readable at realistic launcher sizes — it does at
both. `flutter analyze` clean after the rebuild. Not re-verified: iOS (no
iOS toolchain on this Windows box — `flutter_launcher_icons` regenerated
the `Assets.xcassets` PNGs the same way as before, un-tested since Phase 1).

### Update 2026-09-02 — P2‑5 (unified download manager) & P2‑6 (persistent prayer card): done, emulator-verified

**P2‑5.** `DownloadNotifications` (in `download_manager.dart`) grew generic
`showProgress`/`showComplete`/`clear` (app icon, determinate bar, ~900 ms
throttle, requests `POST_NOTIFICATIONS`) and is now called from
`MushafPageService.prefetchEdition` and `AyahAudioService.downloadSurah` too —
so **every** download kind posts a live status-bar notification, not just
`DownloadManager` files. `MushafPageService` / `AyahAudioService` also gained
`pause*`/`resume*` (the page/ayah loop idles while paused). New
`downloads/data/downloads_controller.dart` = a read-only `storageSummaryProvider`
aggregator + `freeCategory`. `DownloadsScreen` → 3 tabs
`[نظرة عامة | المصاحف | التلاوات]`; the overview tab shows total storage, a
row per category (size · count · تفريغ with confirm), free-all, and a
downloaded hadith/books item list. Verified live: notification advances +
clears on cancel; `تفريغ` frees + refreshes; **pause froze a mushaf DL at
p.5, resume continued to p.11**. Minor: 3 tabs not the 5 labelled sections;
some toasts not re-shot.

**P2‑6.** New `core/services/prayer_status_notification.dart` — an ongoing
LOW-importance status card: title `${prayer} · ${clock}` (localized + Arabic
digits), a **native chronometer countdown** (ticks with the app killed), body
= Hijri date from **AlAdhan's cached `times.hijriDate`** (localized month name,
not the `hijri` package's calc, which was a month off), one `zonedSchedule`
rollover, and an honest "enable location" card when there are no times. Opt-in
`prayer_status_enabled_provider` (default off) + a `SwitchListTile` in Adhan
settings. `AppShell` is now a `ConsumerStatefulWidget` +
`WidgetsBindingObserver` that re-syncs the card on times-resolve / toggle /
resume. Verified live (mock GPS): card appears with the icon, "الفجر · ٠٥:٠٨",
a countdown ticking 6:06→5:59, "٢٠ ربيع الأول ١٤٤٨ هـ"; toggle off → gone.

### Update 2026-09-02 — P2‑4b book **text editions**: built, hosted, emulator-verified

Every library book now has a **نص** (structured text) edition beside the
**مصوّر** PDF. Source: al-Maktaba al-Shamela (owner's pick — §5.7). Pipeline:
`scripts/build_book_text.py` (walks `shamela.ws/ajax/pageContent`'s `nextId`
chain, strips copy-buttons/anchors/`div.hamesh` footnotes, tags ayat, builds a
فهرس from section titles, computes `printReliable`) → `finalize_book_text.py`
(back-fills `printReliable`) → `upload_book_text.py` (`gh api --input` PUT to
`tito423/rafeeq-api/books/text/<id>.json`; base64 is too big for argv). Build
dir `scripts/book_text_build/` is gitignored — regenerable + hosted, like
`hadith.zip`.

Built & hosted (all raw URLs HTTP 200, byte-size matched): riyad 810p/387§,
sayd_al_khatir 893p/394§, mukhtasar 408p/226§, al_fawaid 209p/105§,
al_ubudiyyah 109p/107§ (~5.6 MB total). 0 empty pages, no HTML leakage, text
fully vocalised, spot-checked against the known openings of each work.

New: `book_text.dart` (model + `...`-noise filter), `book_text_reader_screen.dart`
(page-at-a-time; فهرس drawer w/ filter + level indent + bookmark chips;
in-book search sheet w/ `normalizeArabic`; A+/A− font; per-book bookmarks on
`pageIndex`; always-visible tappable provenance strip; OCR-badge hook).
`LibraryBook.textEdition` / `.textDownloadId` / `.hasText`. `library_screen.dart`
gains a `مصوّر | نص` `SegmentedButton` per card (size + action follow the
selection; independent download/cache per edition); مكتبتي lists one row per
(book, edition). +23 keys ×5 (parity 260). `flutter analyze` clean,
`flutter test` 13/13.

**Emulator-verified (`emulator-5554`):** switch flips size/action; downloaded
صيد الخاطر + رياض + مختصر text editions from rafeeq-api; مكتبتي rows correct;
**صيد الخاطر** (`printReliable`) shows "صفحة N" + فهرس trailing = printed pages;
**رياض** (`!printReliable` — its Shamela `pageNum` drops ~100 four times) shows
sequence only + فهرس trailing = seq #, and the chapter order matched Nawawi
despite that; فهرس jump, font, bookmark toggle/strip/jump, provenance sheet all
work; **airplane-mode** relaunch → نص opens from cache with page + font +
bookmark restored; mukhtasar's 2-level فهرس renders indented.

**Not verified:** in-book *search* query→results — `adb shell input text`
can't inject Arabic (same as the hadith FTS5 search above). Sheet opens; code
reuses Stage 6's verified `normalizeArabic` + `.contains()` path. Needs a real
device or an Arabic IME.

---

## 8. NEXT TASKS, in priority order

1. ~~**Make it compile.** `.\check.bat` → fix → repeat until `analyze` is CLEAN.~~
   **DONE 2026-09-02** — `flutter analyze` reports no issues (see §7).
2. ~~**Run it on a device.**~~ **DONE 2026-09-02 on the emulator** — all 10
   STAGE-0 checks pass (§7 table). Still worth a physical-device pass before
   release, especially 0.10 paging feel on low-end hardware.
3. **Performance check.** `flutter_svg` parses each page at runtime and pages
   have thousands of paths. No jank seen paging cached pages on the emulator; if
   it feels slow on a real device, precompile to `vector_graphics` `.vec` — do
   **not** revert to raster.
4. ~~**STAGE 1 — Adhan system.**~~ **DONE 2026-09-02 on the emulator** — full
   pipeline built and verified (§7 STAGE 1 table): real native alarm sound,
   full-screen lock-screen UI, Stop/Mute, per-prayer persistence. Still open
   from Stage 1 itself: a physical-device pass, the battery-optimization
   button's effect (no visible dialog on the emulator), and carrying a custom
   imported adhan through to an actual firing alarm.
5. **Next:** the mushaf download-stops-on-tab-switch bug (§7) is the
   highest-priority remaining bug outside Stage 1 — it undermines
   "offline-first" and has been open since STAGE 0.
6. **Fix or work around the TLS blocker (§7)** before trusting any more
   network-verification results — it silently invalidates re-checks of
   already-passed items (mushaf image mode) too, not just new work.
7. ~~**STAGE 2 — Hadith hub.**~~ **DONE 2026-09-02 on the emulator** (verified
   via direct DB injection, not the live download — §7 STAGE 2 table). Still
   open: the download itself (blocked by item 6), FTS5 search interactive
   confirmation, and the Library "Books" catalog (real sources researched,
   owner needs to pick a specific edition per title before anything
   downloads — see the WIP note above).
8. ~~**STAGE 3 — Azkar & Tasbeeh.**~~ **DONE 2026-09-02, fully verified live**
   (§7 STAGE 3 table) — no network involved, so nothing here was blocked by
   item 6.
9. ~~**STAGE 4 — Translation selector.**~~ **DONE 2026-09-02, emulator-verified**
   (§7).
10. ~~**STAGE 5 — New Muslim Guide.**~~ **DONE 2026-09-02, emulator-verified**
    (§7) — content written by hand from mainstream Sunni teaching, per the
    owner's explicit approval.
11. ~~**Fix or work around the TLS blocker.**~~ **RESOLVED 2026-09-02** —
    owner disabled Avast entirely. The real hadith download now works
    end-to-end (§7). Re-verify mushaf image-mode fetching too when next on
    the emulator — it hit the identical TLS error earlier and was never
    re-confirmed after Avast was turned off.
12. ~~**STAGE 6 — Thematic search.**~~ **DONE 2026-09-02, fully live-verified**
    (§7) — the topic tree, a topic's ayahs, keyword search, and
    tap-to-jump-to-page are all confirmed live.
13. **Three bug classes worth a quick sweep before trusting more of this
    codebase:** (a) `setState(() => x = someAsyncCall())` — found twice
    independently (`library_screen.dart`, `mushaf_page_view.dart`) already;
    grep for the shape if adding more. (b) any other spot assuming FTS5
    works — `sqflite` has no FTS5 module on this Android build; both search
    repositories are now `LIKE`-based, but don't add a new FTS5 MATCH query
    without testing it live first. (c) **any Arabic text search must
    normalize both sides** with `lib/core/utils/arabic_normalize.dart` —
    `arabic`/`text_uthmani` columns are stored fully diacritized, so a raw
    `LIKE`/`.contains()` against undiacritized user input silently matches
    nothing; and never load a whole large table into memory at once on this
    device — page it (see `HadithRepository.search()`'s doc for the real OOM
    crash this caused and how it was fixed).
14. **STAGE 2's Library "Books" catalog is still open — the one real
    remaining feature gap.** Owner said to use al-Maktaba al-Shamela or
    another free Islamic-books source (no further STOP AND ASK) — real
    archive.org sources were already found for every named title (see
    WORK_QUEUE Stage 2); `syncfusion_flutter_pdfviewer` is already a pubspec
    dependency (unused so far) suggesting a PDF-based reader was the
    original plan. Still needs: picking a specific edition/tahqiq per title,
    the actual catalog data structure, download wiring (reuse
    `DownloadManager`), and a reader screen.
15. ~~**STAGE 7 — Security & guest mode.**~~ **DONE 2026-09-02** — no
    credentials in the client, no auth code at all (so guest mode is total
    by construction), and a real pre-existing gap fixed (an untracked
    `google-services.json`, see §9). **Still blocked:** actually building
    Google sign-in needs the owner to register a release SHA-1 in the
    already-existing `rafeeq-aldarb` Firebase project's console.
16. ~~**STAGE 8 — Release.**~~ **DONE 2026-09-02** — `flutter clean` → `pub
    get` → `analyze` → `build apk --release --split-per-abi` all succeed and
    the resulting APK installs and runs correctly; a real
    `usesCleartextTraffic="true"` release-security gap was found and fixed
    along the way (§7). **Still blocked:** the release build is signed with
    the debug keystore — real signing needs the owner's own keystore file,
    alias, and passwords; no agent session should generate one itself.

---

## 9. SECURITY — act on this

The Cloudflare R2 **Secret Access Key** was pasted into a chat transcript and
must be treated as public.

**Rotate it:** Cloudflare → R2 → Manage R2 API Tokens → delete the
`rafeeq-aldarb-data` token → create a new one → update `.env`.

No credentials live in the client; `AppConfig` is secret-free. Keep it so.

**2026-09-02:** `rafeeq_app/android/app/google-services.json` (a real
Firebase config for project `rafeeq-aldarb`, incl. a real API key and OAuth
client ID) had been committed since this project's very first commit and was
never gitignored. Untracked it and added it (plus `.env`,
`GoogleService-Info.plist`, `android/key.properties`, `*.jks`/`*.keystore`)
to `rafeeq_app/.gitignore` — see §7's STAGE 7 note for the full account,
including why this one is lower-severity than the R2 key above (Firebase
Android API keys are meant to ship in-app; they still shouldn't sit in git
per this project's own convention, and this one already is in git history
from that first commit).

---

## 10. Data sources & licensing (all legally clean)

| Data | Source | Licence |
|---|---|---|
| Mushaf pages + ayah polygons | quranpedia/quran-svg | CC0-1.0 metadata; KFQC glyphs free for digital use |
| Quran text, page/juz mapping | bundled `quran_local.db` | — |
| Tafsir (Muyassar, Jalalayn, Qurtubi) | alquran.cloud | public |
| I'rab / word meanings | Quranic Arabic Corpus | open |
| Translations en/fr/ur | alquran.cloud editions | public |
| Azkar | Hisn al-Muslim JSON | open |
| Hadith (9 books, 40,943 hadiths) | A7med3bdulBaset/hadith-json, built into `hadith.db` by `scripts/build_hadith_db.py`, hosted on `tito423/rafeeq-api` | open |
| Library book **image PDFs** | archive.org public-domain scans (downloaded direct on demand) | PD (authors d. 597–751 AH) |
| Library book **text editions** | al-Maktaba al-Shamela (`shamela.ws`), via `scripts/build_book_text.py` → `rafeeq-api/books/text/*.json` | classical text PD; muḥaqqiq apparatus stripped — owner decision, see §5.7 |
| Adhan audio | islamcan (10 verified, no music) | — |
| Recitation | cdn.islamic.network, mp3quran.net | public |
| Prayer times | api.aladhan.com | public |

---

## 11. Mistakes already made here — don't repeat them

These are real errors from this project's own history, not generic advice. Each
one cost time or money.

**Verify what a tool currently does before asserting it.** An agent told the
owner that Antigravity had no Claude models while Opus 4.6 was selected in his
own model picker. The claim came from an older transcript instead of a check.
The owner can see his screen; you cannot.

**Check identifiers against the current code, not against chat history.** Code
was written using `AppColors.accentGold`, an API that existed in an older
transcript of this project but not in the rebuilt palette. Read the file.

**Re-read the result of any bulk mechanical edit.** A careless regex replacement
produced an invalid widget (`painter:` plus a bogus `foregroundPainter:`) and a
quoted heredoc leaked literal `\$` escapes into Dart string interpolation. Both
needed a second pass to undo.

**Static checks are not compilation.** An agent hand-verified brackets, imports,
colour members and translation keys across 35 files and reported exactly that —
then `flutter analyze` found 13 real issues, 10 of them a single import
collision (`easy_localization` re-exporting `package:intl`, whose
`TextDirection` shadows the `dart:ui` one). Substitute verification catches a
narrow class of problems. Name the method you used and its limits.

**Never report unverified work as done.** This project lost roughly $20 and
several rebuilds to agents that produced finished-looking screens wired to
nothing. The owner checks. Say plainly what you ran and what you did not.

---

## 12. Working notes for whoever continues

- **Work in small verified steps.** The failures in §2 all came from agents
  trying to do 20 tasks in one shot and losing track.
- **Update `RAFEEQ_PIPELINE.md`** as you complete work. It is the shared memory.
- **Regenerating mushaf data:**
  ```bash
  EDITION=hafs/kfqc KEEP_SVG=0 WORKERS=10 python3 scripts/build_mushaf_svg.py
  python3 scripts/build_mushaf_catalog.py
  ```
  `KEEP_SVG=0` parses then discards pages (~350 MB saved per edition); pages are
  fetched from the pinned source at runtime.
- **If git shows hundreds of phantom modified files**, `.gitattributes` /
  `core.autocrlf` got lost — see §4.1.
- **Tell the owner the truth**, including what you could not verify. He has been
  burned by confident-sounding agents. Honesty is worth more than polish here.

