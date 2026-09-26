# TASK_FOLLOWUP — the live step log (read right after CLAUDE.md)

Updated after EVERY step, committed and pushed, so a session that dies mid-task
(quota, a dropped remote connection) loses nothing: the next session — this
account, the other one, or another agent — reads this and continues from
**Next step**. Newest entries at the top of the log. Log times are the PC clock, which IS Dubai time (checked against the owner: 14:23 real, 2026-09-24).

## Current task
HANDOVER 2026-09-25 ~15:50 (owner: «اكتب الخطة وظبط ملفات البدء»). Released
v3.63.7 (tag c6f8d3ac). Owner reviewed 10 videos + 11 screenshots from his
phone item by item -> a 5-stage plan in NEXT_SESSION_PROMPT.md, numbered with
his numbers. NO code touched for any plan item yet.

## Next step (exact)
SESSION 2026-09-26 ~02:10-02:40 (quota 5h 0%, weekly 68%). OWNER: landscape is
DELIBERATE - «عاوز التطبيق مناسب جدا لجميع انواع الشاشات ... في وضع الاورينتيشن».
Do NOT lock portrait (tried, reverted). Findings (Xiaomi video, frames seen):
boot turns sideways at 0.7 s (OS: phone flat, stale sensor ROTATION_90; Chrome and
MIUI Gallery open sideways too); intro clip BoxFit.cover cut the emblem + wordmark.
DONE IN CODE (not built/seen): splash_screen.dart `_WholeClip` - when the screen is
wider than 720x1280, clip shown whole (contain) over a blurred first frame.
DONE IN CODE ~02:30 (analyze clean, NOT built): HeadedListLayout (permissions + initial-downloads screens two panes sideways); showFittedSheet on 18 plain-column sheets (were clipped at 9/16 height, sign-in offer buttons unreachable sideways). Location+notifications granted on the Xiaomi by owner order.
DONE IN CODE ~02:40 (analyze clean, 587 pass, NOT built): tour slides side by side sideways; AppShell NavigationRail (scrollable, 7 tabs) instead of the bottom bar sideways + navigationRailTheme. BUILD started ~02:40.
FOUND ~02:40 on the Xiaomi (text mushaf, al-Fatiha): ayah markers REVERSED within each line (5 after basmala). Cause measured: Flutter 3.38.7 engine gives RTL-line placeholder boxes in visual order (selection boxes of the placeholder char too). FIX in code (593 pass): mushaf/ayah_marker.dart FlowingMarkersPainter + resolveMarkerSlots (slot left of each verse closing space); WidgetSpan only reserves room; test rtl_ayah_marker_order_test. NOT yet seen on device. Rebuilding.
(Times corrected: earlier lines said 02:45/03:05/03:20 - guesses; the PC clock read 02:55 at install.) BUILD 02:55:39 installed on the Xiaomi 02:55:50 (install -r OK). SEEN PORTRAIT: al-Fatiha markers 1-7 in order, incl. 2 and 6 opening the next line. NEXT: owner turns the phone sideways -> see splash (whole clip), rail, Fatiha sideways, a sheet, More -> initial downloads (two panes).
SEEN SIDEWAYS 03:00-03:05 on the Xiaomi (build 02:55): al-Fatiha markers 1-7 in order; rail + full-height home; language sheet whole; support sheet with both buttons; initial downloads two panes; tour side by side. FAULT: NavigationRail tiles 61dp x7 > 351dp -> Library cut, More below the edge. FIX in code (593 pass): side_tabs.dart SideTabs shares the height by 7. Rebuilding.
BUILD 03:0x installed 03:09:52 on the Xiaomi: SideTabs SEEN sideways, all 7 tabs with names, no scrolling. BLOCKED ON OWNER: Avast One on his phone popped «Suspicious app found - Rafeeq Al-Darb, Detection ID 3d1dc328d456, recommend uninstalling» right after this install. Dialog left untouched. Do not dismiss/uninstall; ask him. Still to see sideways: Prayer/Adhkar/Tasbeeh/Library tab contents; splash clip after a long absence.
OWNER 03:15: «اظبط الشكل والتصميم في الاورينتيشن ... كانه تاب شغال بالعرض». Avast dialog gone from his screen (he handled it). DONE IN CODE (593 pass): TwoPaneScroll (core/widgets) - Home (date+prayer | reading cards), Prayer (compass sized to height | links), More (6 groups in 2 columns); Adhkar grid 200dp tiles aspect 1.2 sideways. Building. NEXT: see them, then Library + pushed screens (downloads, surah list, adhkar reader, hadith, settings).
SEEN 03:22 build 03:21:38: Home two columns, Prayer compass|links, Adhkar 4x2 tiles, More two columns - all good. DONE IN CODE next: adhkar reader counter beside the dhikr sideways; Library pills beside the title sideways. Building.
SEEN 03:31 build 03:30:44: Library pills beside title (3 authors in view), adhkar reader counter beside dhikr, khatma OK. NEXT: settings expanded, hadith tab, book reader, surah index, hifz, hajj, tajweed, player.
DONE IN CODE ~03:45: PairedListView/PairedColumn (two cards a row sideways; header/footer full width; test paired_list_view_test) on reciters list, tajweed levels, hifz surahs, ruqyah recordings, dedications. Hajj left one column on purpose (sequential steps that expand). Building.
SEEN 03:53-03:55 on emulator-5554 (build 03:50, rotated with adb emu rotate; Arabic RTL): tabs on the right, Home 2 cols, More 2 cols, reciters 2 a row in RTL reading order, tajweed 2x2, hifz surahs paired, ruqyah 6 recordings 3x2. Xiaomi went upright at 03:50 (owner holding it) - my landscape taps opened the clock-face picker twice, nothing changed (Minimal kept). Dedications empty on emulator (pairs covered by test). NEXT: book reader + surah index sideways.
DONE IN CODE ~04:05: library authors/categories/my-library paired; book reader actions in a side column sideways (BookListenAction keyed so rotating does not stop the voice); AppShell tab stack GlobalKey (_tabsKey) - without it rotating rebuilt every tab (lost mushaf page etc.). Building; verify on emulator incl. state kept across rotation.
SEEN 04:08 on emulator (build 04:07:35): tab state KEPT across rotation (Library > My library stayed selected sideways->upright); my-library books paired sideways, one column upright; book reader actions in a side column. UNVERIFIED ON DEVICE: listening survives rotation (BookListenAction GlobalKey) - the book tried (Arba'in Nawawi) is not read aloud (0% diacritised); needs a diacritised book.
OWNER 04:50 «لسه فيه حاجة ناقصة» / «انا بسالك انا معرفش» -> full sweep of all 57 screens/sheets. DONE IN CODE ~05:15: splash PREVIEW used BoxFit.cover too (now shared WholeClip, SEEN sideways: whole emblem + wordmark); preview + adhkar category app bars drew DARK icons/title (AppBarTheme iconTheme/titleTextStyle beat foregroundColor) -> white given outright; readableInsets (680dp centred) on settings subpages, about, sources, adhan settings, adjustments, location; ayah sciences sheet 2 columns sideways + wider; nine collections + hadith texts paired; hadith chapter numbers were LATIN in Arabic -> localizeDigits; channels/websites/encyclopedia paired; tasbeeh rounds label 5px from edge -> padding; downloads 2 columns (StorageAutoRefresh extracted, ceiling 870->829). Building.
SEEN 05:19-05:23 (build 05:18:47): downloads 2 cols; splash preview app bar WHITE now. DONE IN CODE after it: downloads books count was Latin 35 beside Arabic digits -> localizeDigits; standalone Settings page (home header) paired sideways (SettingsBody paired:true, equalHeights:false because sections open in place). Building.
SEEN 05:30-05:33 (build 05:30:09): settings page 2x4; tasbeeh rounds off the edge; nine books paired; Bukhari chapters 2 cols with ARABIC digits; encyclopedia/channels/websites paired; sciences sheet 2 cols wide, i'rab 2:31 with framed 2:23 ref at full height. NEXT: khatma create sheet, sunan sheet, quote/card screens, search, azan player, hifz session, adhan bg, location, ayah reciter, makharij, level screens, about, sources, link manage, adhkar category bar.
SEEN ~05:35-05:48 (build 05:30:09): khatma sheet scrolls to its button; home hadith card; quote fullscreen; about/sources (readable width); adhan settings readable; azan preview sideways; hadeethenc detail; adhkar category bar WHITE (fix seen); hifz paired + session; books search. My earlier claim that tuhfa lesson numbers were Latin was WRONG (zoom: Arabic) - nothing changed there; Bukhari claim re-checked TRUE. DONE IN CODE (not built): makharij diagram - AspectRatio under a tight width came out wide+short, markers off the drawing -> Center + 62% height sideways; adhan backgrounds 4 across sideways; adhkar sections list paired; support page readable width. NEXT: build, see makharij (sideways AND upright), backgrounds, adhkar sections; link-manage + focus picker not yet opened.
NOW: tour every screen in LANDSCAPE on the Xiaomi (current build), list faults,
fix all, ONE build_github_release.bat, install -r, record boot + tour again.
Then the old list below (phone checks, 222 refs).

SESSION 2026-09-26 ~02:05 (quota 5h 89%). HEAD 645a3b12. build_github_release.bat
RUNNING (emulator killed first). Owner's XIAOMI is on adb: BYKRKJPRC6O7FMHU.
NEXT (exact):
1. When the build ends: adb -s BYKRKJPRC6O7FMHU install -r rafeeq_appuildpp\outputslutter-apkpp-release.apk
   (phone is SILENT-sensitive: do not play audio). Check lastUpdateTime.
2. On the phone: Quran -> البقرة ص2 line order (KFGQPC font); long-press 2:5 -> download pack
   (32.1 MB) -> الإعراب; 2:31 framed ref to 2:23; 24:21 shows «[تصويب عن ...]».
3. Owner rule «مينفعش التساهل»: the 222 unproved references (scripts/irab_daas_refs_for_owner.md)
   must be CHASED like the commentary was - other i'rab books on tafsir.app
   (get.php?src=aljadwal|iraab-aldarweesh|aliraab-almuyassar&s=&a=&ver=1) name the
   earlier ayah for «مثلها» - not parked with the owner.
4. Cosmetic: Shamela mid-sentence line breaks inside sections (2:23 «فعل ماض / ناقص»).
5. Release only if the owner asks.
SEEN on emulator earlier (01:25 build, before the commentary fix): 2:5, 2:31->2:23, Sources.

SESSION 2026-09-26 00:00-02:30 (i'rab). DONE+PUSHED: 27/27 damaged sections
from the print; 6 Qur'an quotes corrected to the mushaf with evidence
(scripts/irab_daas_quran_corrections.json); references resolver (215 proved
of 467 shown; 222 in scripts/irab_daas_refs_for_owner.md, NOT shown); app
tab rewritten (commit 347323d8); pack v2 uploaded to sciences/v2/ + GitHub
mirror, AppConfig v2 (3a467d15). NOT YET SEEN ON A DEVICE.
NEXT (exact): build_github_release.bat was started ~02:30 with the emulator
OFF. When it ends: start emulator-5554, install buildpp\outputs\...signed APK over the old one, re-check lastUpdateTime (trap 56), open Quran
-> long-press 2:5 -> الإعراب: expect the pack download to be offered (v2),
download it, then SEE: 2:5 text + gold quotes + source header; 55:16
(«سبق إعرابها» + framed 55:13); 29:1 (-> 3:1); 22:27 section shows
«مَعْلُوماتٍ»; Sources screen has the Shamela 23584 row. Then report to
owner. Open for owner: book-commentary mismatches at 10:56, 22:60, 24:21
(asked: leave + note?); the 222 unproved references list.

SESSION 2026-09-25 20:05 (quota 5h 1%, weekly 57%, RC off). Tour recapture
FINISHED: 7 langs x 32 webp (636-724 KB each) + frames.json, now in git
and in pubspec. I'rab: corpus_labels.py rewrite RUN on the local
quran_sciences.db 19:59 (عَلَى = «حرف جر», no «جمع»; 0 prepositions with
جمع) but NOT uploaded to R2 and sciencesDbVersion still v1.
OWNER 20:20 DECISION (i'rab): source = «إعراب القرآن الكريم» للدعاس
وحميدان والقاسم (Shamela 23584, Dar al-Munir/al-Farabi 1425). Corpus tags
(root/wazn) may stay ONLY if 100% certain - «لو منتش متاكد منهم مليون
المية متحطهومش». So: corpus labels are NOT uploaded; plan = read Daas
pages by hand, parser, hand-check a sample, show owner, then replace.
Corpus root/lemma only after a cross-check against an independent source
with zero disagreements - else removed.
NOW (i'rab): transcribe the remaining 22 damaged sections from the print (log 23:39; 5 done), rebuild final, then APP: replace word_grammar i'rab with section rows (table irab_daas: surah, ayah_from, ayah_to, text), show «إعراب القرآن الكريم - الدعاس وحميدان والقاسم (دار النمير/دار الفارابي)» on the ayah sheet + Sources + CONTENT-LICENSES, drop corpus labels (owner: only if 100% certain), bump sciencesDbVersion v2, upload pack, see on device. Phone check DONE: order correct on the phone (emulator-only fault); confirm once with the KFGQPC build. OLDER NOW: wait for OCR of the print (see log 21:06), run arbitrate_irab_daas.py on all 3,639 sections, read the «?» and doubtful ones off the page images, build the final text. OLDER: Daas crawl + diff (see log 20:45); next = parse e-quran pages, normalise, diff vs Shamela sections, damaged -> check printed PDF, then report to owner BEFORE any app change. NEXT (2) i'rab (OLD plan, superseded by Daas): py -3 scripts/upload_sciences_pack.py, update sciencesDbBytes,
bump sciencesDbVersion v2, see the sheet for 2:5 on the emulator.

(Older) Owner (18:10): «هات المصدر الأوثق وحط عليه كل اللي عملناه» after asking if a
trusted free source exists. DONE IN CODE, NOT BUILT/SEEN: ayah text = KFGQPC
hafsData v18 (two copies identical 6236/6236), font KFGQPCHafs (licence:
free use/copy/distribute, unmodified), basmala line = 1:1 (kBasmala), DB
stamp quran-v2-kfgqpc, search hamza compose + U+06E1 sukun mapping,
Sources + CONTENT-LICENSES. 591 pass. ALSO NOT SEEN: the ayah-download ANR fix.
NEXT: build (emulator OFF), install, SEE: text mushaf al-Kahf 18:31 (no
meem), 12:39 (no extra ى), a surah head with the basmala line, search
«امرئ» and «عدن», tap «تلاوة آية بآية» and measure main-thread CPU.
Then plan items 2.. + mushaf themes for special surahs/sunan (owner 17:56),
then RELEASE (owner asked 17:40).

(History below.)
After the release: nothing ordered. Still open (need the owner or a fresh
device): largest font in LANDSCAPE; «Enable location» with NO cached fix
(clear app data or fresh device); city line ar->ur first-switch delay.
Audit-2 items 6-8 and the matrix rows «theme/locale switch while playing»,
«background + back while playing/downloading», «dark + RGB contrast»,
«slow network» are DONE (see log 2026-09-24 22:54-23:57 and 2026-09-25).

(History) SESSION 2026-09-25 11:12. 3.63.1 (diacritisation fix
91d82a33) built + installed on owner's phone. FIXED since in d7a482c2 and
SEEN on the phone at 11:27 - the three below:
FOUND on phone at system font «Huge» (font_scale 1.45) + Bold:
1. Tasbeeh PORTRAIT: counter circle shrank to a dot (controls take the
   height, FittedBox shrinks the counter) - same class as the landscape
   bug; tasbeeh_screen.dart ~line 499 only handles wide+short. Fix: let
   the portrait column scroll with the counter at a minimum size.
2. Library sub-tabs: «Categories» / «My library» drawn tiny next to
   «Audio» (per-label shrink-to-fit) - make them uniform.
3. Home: centre (next-prayer) tile shows «12:11» without «PM»; side
   tiles keep it.
SEEN OK at 1.45: Quran page, Prayer/qibla, Adhkar grid, More, book reader.
Location switch OFF (owner did it): app launch -> 0 Google dialog
launches (logcat LocationSettingsChecker = 0), Home keeps Dubai times.
Owner's phone left with font Huge/Bold and location OFF - his settings.

SESSION 2026-09-25 10:25 (owner: release now, 1 hour, his phone
AB3S6R4C04016607 BRP-NX1 Android 12 connected - KEEP IT SILENT, people
asleep). Bumped 3.63.0+65 (pubspec + AboutScreen), analyze clean,
DONE 10:33: v3.63.0 published + verified, v3.62.0 deleted. NOW: phone
checks (About, manual location Tanta, back to automatic). Was: install over old build on the
phone (volume muted), check Support + About 3.63.0, location off->on
path (old item 2); delete v3.62.0+tag, gh release create v3.63.0
--target master with scratchpad notes, verify tag == HEAD.

SESSION 2026-09-25 ~05:15: owner orders A (contrast, 3 themes) and B
(manual location, bundled list) DONE and SEEN on build 15 = master.
Reported to the owner. NOT released - 3.63.0 only if he asks (bump
pubspec + AboutScreen, build_github_release.bat with the emulator OFF,
delete v3.62.0 + tag, keep v3.51.0 and content-*, tag == HEAD).
Still open from before: location OFF -> button -> settings -> ON ->
times appear (needs a real phone); audit part 2 items 6-8.

SESSION 2026-09-25 ~04:55. Build 14 (= d7ed9a35) on emulator. Light
re-crawl: hadith icons gone. Fixed in code since (28eba2c7, NOT BUILT):
21 multi-line flat-gold icons, player TabBar label, theme chip icon
(onPrimaryContainer). 588 pass (one run hung at ui_strings_translated_test
for 13 min and was killed; the rerun passed in 64 s - watch for it).
SEEN by chance: Fajr adhan fired 04:50 on build 14, screen + synced
text, Stop works. RGB crawl on build 14 running -> confirm filled
buttons read (onPrimary fix), eye the rest; then build 15, final light
+ RGB scan, HANDOVER, report to owner.

SESSION 2026-09-25 ~04:15. Dark crawl (build 13): every flag eyed, all
false (card/chip borders, icon rings, map dots, photo-card edges, scrim).
RGB crawl: REAL - white on the RGB primary #22E0C6 = 1.67:1 on every
filled button. FIXED: onPrimary + FilledButton foreground picked by
measured contrast (white unless < 4.5, else #06131A);
test/theme_on_primary_test.dart fails old (1.67) passes new. NOT BUILT.
NEXT: build 14, re-crawl light + rgb, eye what is left (widgets with
explicit Colors.white on primary would still show), RGB m_player and
m_set_theme were not reached - run them with the 3rd arg.

SESSION 2026-09-25 ~03:50. ORDER A light crawl on build 13: 34/34 reached
(ui_crawl.py paths fixed: Library sub-tab named per target; optional 3rd
arg = only these targets). Every flag eyed. Real ones FIXED in code, NOT
BUILT: 35 flat-gold ICONS on theme surfaces -> goldText (skipped: adhan
screen, snackbar, player, reader - own dark grounds); hadith section
icons; NonArabicReadingCard icon/labels/«Quran.com v4 API» badge; 5
avatar ChoiceChips drew the check over the icon -> showCheckmark false.
False flags: icon ring edges on More cards, the scrim behind sheets,
disabled fasting time row (disabled = exempt), adhkar page dots (the
«1 / 17» under them reads). NEXT: dark crawl (build 13), then RGB, then
build 14 and re-scan light to confirm.

SESSION 2026-09-25 ~03:27. ORDER B (manual location) DONE + SEEN on build
13 = master e3ddb0d5, offline (airplane + location off): bundled list,
Tanta pick -> times + name; Qibla 258 -> 138 (= independent great-circle
calc 138); calc method Umm al-Qura -> Egyptian: Fajr 6:23->6:18, Isha
9:19->9:07 same day; back to Automatic -> Dubai 4:50 + qibla 258.
Emulator left: Umm al-Qura, Automatic, airplane ON, location OFF.
NEXT: order A contrast - airplane off, `py -3 scripts/ui_crawl.py
%TEMP%\crawl light`, then contrast_scan, eye-check every flag; fix
TARGETS labels that were not reached; then dark and RGB.

SESSION 2026-09-25 ~03:20. Build 12 SEEN offline (airplane + location off):
bundled list first unpack 5.3 s; Tanta -> Fajr 6:23 / Sunrise 7:46 phone
time (Dubai sunrise 6:09 + 97 min longitude = 7:46, exact); Dubai found;
coordinates Makkah -> Fajr 5:54 / Sunrise 7:10 (= 6:10 Makkah time).
FOUND: Qibla kept Dubai's 258° (computed once in a kept-alive tab) - FIXED:
ManualLocationStore.changes + Qibla listens. NOT BUILT. Emulator NOTE:
`emu kill` + restart resumes an OLD snapshot (app reverted to build 9,
airplane reset) - reinstall after every emulator restart.
Next: build 13, qibla follows Tanta/Makkah, change calc method -> times
change, back to Automatic. Then contrast crawl.

SESSION 2026-09-25 ~03:10. Build 11 SEEN (airplane + location off):
bundled list ready in <8 s, «Tanta» -> «Tanta, Egypt» first in ~2.8 s,
picked -> Home name «Tanta, Egypt» BUT Fajr still Dubai's 4:50. CAUSE:
PrayerTimesService answered from a cache keyed by DATE ONLY before
calculating (also broke same-day method/madhab changes and travel). FIXED:
always calculate; cache only on throw. test/prayer_times_place_test.dart
fails on old code (04:50 == 04:50), passes now. Next: build 12, redo
Tanta -> times must change; also change calc method -> times change;
Dubai; coordinates; back to automatic; qibla. Then contrast crawl.

SESSION 2026-09-25 ~03:00. Build 10 SEEN: the hosted city-list download
went to «World city list ready» (the build-9 46 % failure did not recur).
Then OWNER: «خلي مواقيت مدن العالم بندلد في التطبيق ... دول خمسة ميجا بس»
-> list now BUNDLED (assets/data/cities.tsv.gz, 5,080,747 B, same bytes as
R2), unpacked once on first open of Prayer location (no download button;
«Preparing the city list…»). 583 pass, analyze clean, NOT BUILT. Next:
build 11 (emulator OFF), install, open Prayer location -> ready without
network, then airplane+GPS off search Tanta/Dubai, pick -> Home times +
name, qibla; coordinates; back to automatic. Then contrast crawl.

HANDOVER 2026-09-25 ~02:10 (owner: quota ending). Exact resume steps are
in NEXT_PROMPT.md. Short: both orders A (contrast) and B (manual location)
are in code; build 9 showed the location screen + online search working;
the city-list DOWNLOAD failed at 46 % (Isolate.run captured the State) -
fixed in code (top-level _prepareOffThread/_searchOffThread), NOT BUILT.
Contrast fixes NOT yet seen on a device. Rebuild, verify both, report.

OWNER 2026-09-25 ~00:55, two orders (in this order):
A. Contrast: gold-on-cream and ANY text not clearly readable, app-wide,
   fixed now. Method: measure WCAG contrast of text colour vs its ground
   (4.5:1 body, 3:1 large) from code + screenshots, fix every failure.
B. Manual location in the prayer location settings: type a city name,
   pick it, works OFFLINE and with GPS off; the app builds on it. Needs a
   bundled, credited city list (GeoNames, CC BY 4.0 - verify licence and
   fields live before using).
STATE 2026-09-25 00:43: build 7 (signed, on emulator) = master. Every fix
of this session SEEN on the emulator except the one item below.
1. Reported to the owner; release 3.63.0 ONLY if he asks (bump pubspec +
   AboutScreen, build_github_release.bat with the emulator OFF, delete
   v3.62.0 + tag, keep v3.51.0 and content-*, tag == HEAD).
2. UNVERIFIED (emulator GPS stopped delivering fixes after
   `cmd location set-location-enabled` off/on - «last location=null»
   even after a reboot): location switched OFF -> card button -> location
   settings -> switch ON -> back -> times appear. Everything before «times
   appear» was seen on build 7; the refresh-with-a-fix step was seen on
   build 5. Redo on a real phone or a fresh AVD.
3. Open, not changed: gold surah names on cream (Home «Selected surahs»)
   are low contrast; after «Later» on the permissions page Home still
   asks location, notifications and audio on first open (by design).

AUDIT PART 2 - gaps not covered by part 1, each on the emulator:
1. [x] splash preview vs recitation: with sound it pauses the recitation
       (one sound, OK) but it STAYED paused after - FIXED in code: resumes
       on close. Muted preview: recitation plays on (seen).
2. [~] offline: FOUND tasmee download cut by airplane mode showed a raw
       English «DioException [connection error] … github.com». FIXED in code:
       core/utils/user_error.dart (errors.offline / errors.generic) in tasmee,
       hifz, sign-in; DownloadManager task.error no longer the plugin's
       English description. Offline (airplane): Home+times+city, Quran,
       Prayer/qibla, Adhkar backgrounds, Library all open (seen). Tasmee retry
       after network back works (seen 9%).
       FOUND: reader-voice (WorkManager) cut by airplane mode -> plugin
       reports `canceled` (TaskRunner: isTaskStopped), dialog closed, row
       «Not installed», but WM re-ran it and it FINISHED 21:21:22 while the
       row still said Not installed. FIXED in code: DownloadManager treats
       `canceled` as queued unless the reader cancelled (_userCanceled).
   offline: airplane mode - home/quran/prayer/adhkar/library open;
       a download cut mid-way (tasmee dio, voice WorkManager) + recovery
3. [x] reboot: all 5 adhan alarms + rollover re-armed without opening the
       app (seen; the 2nd 04:50 line is AlarmManager's «next wake», same alarm)
4. [x] taps: FOUND azkar/khatma/tasbih reminders had NO payload - tap only
       opened Home. FIXED: open:<screen> payloads + app/notification_open.dart,
       test/reminder_tap_routing_test.dart 4/4. Device: needs the build.
5. [x] permissions denied (seen): mic -> «Microphone permission is needed»,
       no recording; location -> Home + qibla keep the saved fix, city shown.
       FOUND: notifications asked TWICE back to back (plugin ask, then
       permission_handler ask when still denied) -> 2nd refusal = USER_FIXED.
       FIXED: one ask (alarm_permissions_service.dart), 577 pass.
       FOUND (serious): notifications refused + app in background -> adhan
       plays on the alarm stream with NO screen and NO notification
       (BAL_BLOCK in logcat), opening the app showed a normal screen: no way
       to stop it. FIXED in Kotlin: MainActivity.onResume opens AdhanActivity
       while an adhan plays and notifications are off. Needs the build.
6. [ ] rotation/landscape + largest font scale: overflow on main screens
7. [ ] Urdu (RTL, Latin digits) quick pass
8. [ ] ruqyah / tajweed / device-files audio vs book reader & adhan
Then ONE build, verify both fixes above + anything fixed here, release.

## FULL AUDIT MATRIX (owner 19:55: «full audit in all app aspects»)
Sound sources (grep, 20:00): SHARED just_audio player (ayah/queue/
continuous/surah player/ruqyah/device files/tajweed/azkar/dedications/
search/sunan), BOOK READER (TTS or open voice on its own MediaPlayer, no
audio focus), NATIVE ADHAN (AdhanPlayer.kt, focus TRANSIENT_EXCLUSIVE, also
the settings preview), TASMEE MIC, SPLASH VIDEO.
- [x] adhan vs recitation (prev session) · [x] adhan during download
- [x] book reader vs recitation (prev) · [x] tasmee vs listen/recitation
- [x] delete playing surah recitation · [x] delete playing per-ayah (VERIFIED build 2:
  PLAYING -> NONE, 0 players) · [x] download state app-wide · [x] qibla 258 = computed 258.2
- [x] ADHAN vs BOOK READER: CONFIRMED BUG 20:10 (Isha moved +27 min):
  USAGE_ALARM + SPEECH MediaPlayers both started, reading went on after
  Stop. FIXED in code: VoicePlayerChannel.kt holds audio focus (transient
  loss pauses, gain resumes same chunk, loss stops, released 1.5 s after
  the last chunk); phone TTS path: BookSpeaker listens to AudioSession
  interruptions (pause -> re-read chunk, unknown -> stop, duck ignored),
  test/book_speaker_focus_test.dart 3/3. VERIFIED on build 2 (20:31): the
  reader holds focus (GAIN, SPEECH); at the adhan SPEECH -> paused, only
  USAGE_ALARM plays; after Stop the same player (piid 455) -> started,
  reading resumed on the same page. Phone-TTS path: unit-tested only (the
  emulator has no Arabic TTS engine).
- [x] adhan vs tasmee recording: FIXED (poll AdhanNative.state() 1 s ->
  discard) and VERIFIED build 2 20:43: recording dropped at the adhan, no
  recording config left, panel back to Start reciting, nothing marked · [x] focus mode vs adhan: focus mode is in-app only (no lock task/DND);
  VERIFIED 20:46: Dhuhr test adhan fired full screen over focus-mode
  Tasbeeh, Stop -> back to focus mode, 0 players
- [x] notifications count (trap 33): every service uses fixed ids ->
  bounded, EXCEPT sunan-surah reminders (id per surah per weekday: 4
  surahs daily = 28/week undismissed > 25 -> adhan notification dropped).
  FIXED: timeoutAfter 20 h. Prayer reminders max 15, azkar 3, khatma 1/k. · [ ] theme/locale switch while playing
- [ ] app to background + back while playing/downloading
- [ ] slow network: onboarding probe (fixed, rebuild)
- [x] reciter header contrast: VERIFIED build 2 (white/white70 readable)
- [ ] dark + RGB theme contrast scan

## Settled facts
- SEEN on emulator (3.62.0 signed, 19:32-19:39): voice download started in
  onboarding shows «Downloading 0%->2%» live in Settings > Book reader
  (was a plain download offer); onboarding rows show both downloads with %;
  tasmee: «Listen» greyed while recording and pressing it plays nothing
  (media_session NONE); moving to ayah 2 mid-recording cancelled it, Listen
  back, nothing marked.
- SEEN (19:40-19:44, fresh install, umts then full): tasmee download started
  in onboarding shows in the Hifz panel «Downloading 0%» + Cancel; left the
  panel 20 s, came back at 33% (old build cancelled it on leave); then 90%
  -> «Start reciting» on its own. Isha adhan fired 19:43 during it (full
  screen, USAGE_ALARM MediaPlayer), Stop -> nothing playing, panel intact.
- FOUND (not fixed yet): on the slow (umts) network the onboarding
  per-ayah recitation row says «No server answered right now» and its
  button is DISABLED - the servers answer, just slowly. Look at the probe
  timeout in offline_pack_tiles.dart (_Probe). FIXED in code (15 s +
  retry button), needs the next build.
- SEEN 19:47: surah recitation (Toubayti, Fatiha downloaded) PLAYING from
  device -> «Delete downloads» -> Delete: media_session NONE, mini player
  gone, rows back to download icons.
- FOUND + FIXED in code: reciter screen header (player theme, always a dark
  ground) drew the moshaf name and «0 of 114 surahs downloaded» in the
  app's onSurface - dark on dark in the LIGHT theme, unreadable. Now
  white/white70. Needs the next build.
- FOUND 19:52 on device: per-ayah reciter (Alafasy, Fatiha) playing from
  the reciter screen -> delete reciter -> files gone but audio PLAYED ON
  (AudioTrack started, moved to next ayah, streamed from network). The
  18:49 fix only checked continuous recitation. FIXED in code:
  deleteReciter also stops a queue/single ayah whose MediaItem tag is
  `edition:global` of that reciter. 570 pass. Needs the next build.
- Checked, NOT a bug: Downloads «Books 35 · 86.6 MB» on a fresh install =
  the 35 built-in books (builtinBookIds, all installed); the 36th asset
  file is the Jazariyyah sharh read directly by the tajweed course. The emulator's Quran tab opens full screen - Back
  returns Home (not a bug; Display sheet ate one Back).
- VERIFIED on emulator (3.61.0 fresh install, 16:00-16:04): onboarding title/blurb + all 6 rows with measured sizes, smallest recommended (Banna 383.6, Basit 449.0), total 1.3 GB (= 1278.5 MB summed); علوم القرآن download screenrecorded 0->90%: row never re-wraps or moves; More colours gold/blue/teal/red/blue/gold, Reminders sub-cards red; Hifz: jump button gone; a fine-sampled thumb arc on 2:255 at font 1.3 SCROLLS the page and keeps 255; a sideways swipe still turns to 256.
- FOUND + FIXED after the build: «شرح التطبيق» (TutorialEntryCard) stayed gold under Tools — now reads MoreGroupAccent. Needs the rebuild, then release.

- C1 backgrounds come from R2: after `pm clear`, opening Adhkar + new-Muslim
  made 6 connections, all to 104.18.50.34/104.18.54.45 (= the r2.dev
  bucket), zero to Unsplash (151.101.x / 146.75.x) or GitHub; images drawn.
  Method: emulator `-http-proxy` + logging proxy (TRAPS #53).

## Build 3 verification (signed build 22:20, Kotlin compiled OK)
- [x] 1 adhan + notifications off: VERIFIED 22:26 - notif revoked, Dhuhr
  Test in Per-prayer settings (NOT the play icon in the home prayer sheet,
  that is only the voice preview), HOME at once -> BAL_BLOCK in logcat,
  launcher on top, alarm player started; opening the app -> AdhanActivity
  on top with Stop; Stop -> player stopped, back to MainActivity.
- [x] 2 one notification ask: VERIFIED 22:30 (pm clear) - tapping the
  Notifications row: ONE system dialog, denied -> flags USER_SET (not
  FIXED). «Allow them» chain: location, notifications (once), audio,
  battery - one notification dialog.
- [x] 7 umts onboarding: VERIFIED 22:33 - ayah row recommends al-Banna
  383.6 MB. NEW FINDING: «Complete recitation» row said «No server
  answered» on umts (Mp3QuranApi.reciters, 160 KB catalogue, failed on the
  first try while the page's other requests ran); retry tap loaded it in
  ~37 s (Abdulbasit). TO FIX: auto-retry in _SurahRecitationPackTileState._load.
- [x] 3 WM airplane: VERIFIED 22:33 - voice at 17% kept «17%» + Cancel
  through airplane mode (was «Not installed» before); network back ->
  WM re-ran both files (TaskRunner: downloaded 22:33:45 / 22:33:55),
  row turned to the green check by itself.
  NOTE: the onboarding tasmee row, cut by airplane, silently went back to
  «Download» (no message there); item 4 is checked in the Hifz panel.
- [x] 4 offline text: VERIFIED 22:42 - Hifz > Fatiha > Download the model,
  airplane at 16% -> red «No internet connection» under the button (was
  raw DioException English).
  NOTE (first run, fresh data): after «Later» on the permissions page,
  Home still asked location + music/audio on first open (system dialogs).
- [x] 5 reminder tap: VERIFIED 22:47 - Adhkar settings sheet, morning
  reminder set 22:47 (text-input picker), app in background; notification
  «Morning adhkar» posted, tapped from the shade -> «Morning» adhkar
  screen 1/17. (Reminder left ON at 22:47 on the emulator.)
- [x] 6 splash preview: VERIFIED 22:49 - Toubayti al-Baqara streaming
  (PLAYING), Preview intro video with sound -> session PAUSED, recitation
  player piid 207 paused; Back -> video piid 215 stopped, piid 207
  started, session PLAYING.
- [x] 8 city on locale: VERIFIED 22:50 - Home, English -> العربية: 1.5 s
  later the city line already reads «دبي، الإمارات العربية المتحدة».
ALL 8 VERIFIED on build 3.
- FIX (build 4 needed): complete-recitation row now tries the mp3quran
  catalogue 3 times (5 s, 10 s apart) before «no server answered».
  analyze clean, 577 pass. NOT yet on a device.
- LANDSCAPE (22:54, Arabic): Home, Quran reader, Prayer, Adhkar, Library,
  More OK. FOUND: Tasbeeh counter circle shrank to a DOT (controls took
  the whole height, FittedBox scaled the 250 px circle to ~0) - nothing
  to tap. FIXED in code: wide+short (<600 high) -> controls scroll on one
  side, counter full size on the other; portrait unchanged. analyze
  clean, NOT yet on a device (build 4).
- URDU (22:57): RTL, Latin digits, all tabs Urdu EXCEPT the Adhkar cards,
  which stayed in the previous language (Arabic) until a restart: the tab
  is built `const _SectionsTab()` and never rebuilt on locale change.
  FIXED: `context.locale;` in _SectionsTab.build. 577 pass, NOT on device.
- OPEN: city line - first ar->ur switch still Arabic at 4 s; two later
  switches (ar and ur) updated in <2 s. Cause not established (release
  build has no geocoder log). Re-check on build 4 with a fresh pm clear.
- BUILD 4 (23:05) verified: complete-recitation row on umts + pm clear
  filled by itself in ~90 s (Abdulbasit 449 MB), never «no server».
- FOUND on build 4 (fresh install, «Later» on the permissions page):
  Home asked location, notifications, audio, then LOCATION AGAIN -> two
  refusals = USER_FIXED. Second ask was LocationService._fetchPosition
  racing requestStartupGrants. FIXED: the service never prompts (startup
  ask, Home button, permission rows do; resume re-fetch covers a grant).
  577 pass, needs build 5. Settings-path grant + resume -> times shown
  (seen). Granting on the onboarding page -> times shown (seen).
  (A pm grant while the app stayed foreground left the card «denied» and
  its button logged «No requestable permission» - adb-only, not a user
  path; not changed.)
- MATRIX on build 4 (scripts/ui_matrix_sweep.py, sheets in
  %TEMP%/sweep): en + ar x light/dark/rgb x portrait/landscape READ.
  FOUND+FIXED (need build 5): quote-of-the-day arrows swapped («> <» in
  en and ar; hadith card beside it is right) - icons swapped back;
  Adhkar grid in landscape had 2 columns, cards taller than the screen,
  titles below the fold -> max 260 dp per card. Tasbeeh landscape fix
  SEEN working on build 4. Gold surah names on cream (Home «Selected
  surahs») low contrast - noted, owner's gold design, not changed.
  es ru pt fr ur DONE (23:35-23:57): 7 langs x 3 themes x 2 orientations
  = 42 sheets read. FOUND+FIXED: daily-hadith EXPLANATION (in the UI
  language) drawn by ArabicText = forced RTL -> Portuguese words reordered
  («O Profeta» at the line end). Now Text for LTR languages. Build-4 fix
  SEEN: fr -> ur switch, Adhkar cards in Urdu at once.
  BUILD 5 (00:00, 25 Sep) VERIFIED: fresh install + «Later» -> location
  asked ONCE (then notifications, audio), flags USER_SET not FIXED;
  quote arrows «< >», next/prev work; pt explanation reads LTR; Adhkar
  landscape 5 per row, titles visible.
  FOUND on build 5: «Enable location» with permission GRANTED but no fix
  (cold-boot emulator had last location=null; same for a phone with its
  location switch OFF) -> card stays, button asks a held permission,
  nothing. With a fix (adb emu geo fix x12) the button works (seen).
  REGRESSION from the build-5 change: Qibla's button relied on the
  service prompting -> would ask nothing. FIXED both: LocationService.
  askToEnable() (ask if denied / app settings if forever / location
  settings if the switch is off), used by Home and Qibla. 577 pass.
  NEXT: build 6; verify location switch OFF -> button opens location
  settings; Qibla button prompts on a fresh install.
  FOUND on build 6 (serious, OLD - not from today): phone location switch
  OFF -> Google Play «turn on device location» dialog; «No thanks» ->
  resume -> refresh -> getCurrentPosition -> dialog again: 6 launches in
  a row (logcat START LocationSettingsCheckerActivity), no way out.
  FIXED: _fetchPosition returns null when the service is off (cached fix
  used); only the card's button opens location settings. 577 pass.
  BUILD 7 VERIFIED (00:30-00:42): switch OFF + fresh install -> 0 Google
  dialog launches (was 6+); card button -> Settings$LocationSettings
  Activity; Qibla «Try again» after one refusal -> system dialog ->
  allow -> «Qibla direction: 258°» and Home shows the times (resume).
  (Was: build 7 -> verify: switch off + fresh install = no dialog loop,
  card button opens location settings, switch on + geo fix -> times;
  Qibla button prompts on a fresh install.
  NOTE: after an emulator cold boot, accelerometer_rotation is 1 again -
  set it to 0 before user_rotation, or screenshots stay portrait.
- OWNER 23:00: full matrix - every feature x 4 themes x 7 languages x
  portrait/landscape. Plan: build 4, then scripted screenshot sweep,
  reviewed by eye.

## Log
- 2026-09-26 07:02 - Makharij diagram kept its shape (Center), adhan backgrounds 4 across, adhkar sections paired, support readable (not built)
- 2026-09-26 05:32 - Seen sideways: settings, tasbeeh, hadith lists, library tabs, sciences sheet with i'rab
- 2026-09-26 05:26 - Sideways: settings page paired, Arabic digits in download counts; preview bar seen white
- 2026-09-26 05:13 - Landscape sweep: splash preview, dark app bars, readable forms, sciences sheet, hadith, library tabs, downloads
- 2026-09-26 04:49 - Splash preview used BoxFit.cover too - both now share WholeClip
- 2026-09-26 04:09 - Seen on emulator: tab state kept across rotation, reader side column, paired library
- 2026-09-26 04:03 - Sideways: paired library lists, reader actions in a side column; tab state kept across rotation
- 2026-09-26 03:55 - Seen sideways on the emulator (Arabic): paired card lists in RTL order
- 2026-09-26 03:46 - Sideways card lists two a row: reciters, tajweed levels, hifz, ruqyah, dedications
- 2026-09-26 03:31 - Seen sideways: library header, adhkar reader, khatma
- 2026-09-26 03:26 - Landscape: adhkar counter beside the dhikr, library tabs beside the title
- 2026-09-26 03:18 - Tablet-style landscape: two scrolling columns on Home, Prayer and More; wider adhkar tiles (593 pass, building)
- 2026-09-26 03:10 - SideTabs seen on the Xiaomi; Avast One flagged the sideloaded build - waiting on the owner
- 2026-09-26 03:06 - Sideways tabs share the height by seven (the rail hid More below the edge on the Xiaomi); rest of the landscape fixes seen
- 2026-09-26 02:57 - Seen on the Xiaomi (portrait): al-Fatiha ayah markers 1-7 in order after the fix
- 2026-09-26 02:52 - Text mushaf: ayah markers were reversed within each RTL line (engine placeholder order); painted from each verse's own words now (593 pass, not on device yet)
- 2026-09-26 02:34 - Landscape: navigation rail sideways, tour slides side by side (587 pass, building)
- 2026-09-26 02:25 - Landscape: two-pane onboarding screens, fitted bottom sheets (analyze clean, not built)
- 2026-09-26 02:16 - Splash shows the whole portrait intro in landscape (not built yet); landscape tour next
- 2026-09-26 02:05 - HANDOVER (owner: «شيل التطبيق وسطبه تاني وجهز الدنيا»): Xiaomi uninstall+reinstall clean 02:02:48, not opened. analyze clean, 587 pass, hosted 10/10 206 (+GitHub v2). HANDOVER row, NEXT_SESSION_PROMPT, NEXT_PROMPT rewritten. Stopped here on the owner's order - next session.
- 2026-09-26 01:53 - TASK_FOLLOWUP: Xiaomi install + chase the 222 refs next (quota 89%)
- 2026-09-26 01:53 - OWNER RULE «مينفعش التساهل في علم يمس القرآن» (CLAUDE.md 1.2 + memory no-leniency-quran): the 3 commentary mismatches were CHASED, not parked. 4th witness tafsir.app iraab-daas has the same errors -> the authors' own. Fixed from named books read on tafsir.app get.php: 10:56 «هو مبتدأ» (الجدول، درويش، الميسر); 22:60 «وعفو خبر إن وغفور خبر ثان» (الإعراب الميسر); 24:21 «والله مبتدأ وسميع خبر أول وعليم خبر ثان» (درويش) - each marked in the text «[تصويب عن ... ؛ وفي الأصل: ...]». Sources row tafsir.app + CONTENT-LICENSES. Pack v2 re-uploaded 32,146,611 B (R2 206 + GitHub 206), AppConfig + pinned test updated. analyze clean, 587 pass. Next: signed build for the owner's Xiaomi (he is connecting it).
- 2026-09-26 01:34 - i'rab tab SEEN on emulator: 2:5 source+text, 2:31 framed ref to 2:23, Sources row
- 2026-09-26 01:34 - SEEN on emulator-5554 (signed build 3.63.7 code+i'rab, installed 01:25:56 over the debug build): sheet offered the pack at 32.1 MB, downloaded, tafsir shown; الإعراب for 2:5 = source header (authors, دار النمير ودار الفارابي ط1 1425) + «يعرب الكتاب الآيات من ١ إلى ٥ معًا» + book text with gold quotes; 2:31 shows «إن كنتم صادقين» انظر الآية ٢٣ and UNDER it the framed «إعراب سورة البقرة الآية ٢٣ كما ورد في الكتاب» with 2:23's section; Sources screen shows the Shamela/Da'as row. Hosted v2 zip re-downloaded: 6 corrections present, 3,639 sections/6,236 ayahs, 215 refs, no word_grammar. NOT released (v3.63.7 still published; ask owner). Target text keeps Shamela's line breaks mid-sentence (e.g. 2:23 «فعل ماض / ناقص») - cosmetic, next.
- 2026-09-26 01:15 - TASK_FOLLOWUP: exact device-check plan while the signed build runs
- 2026-09-26 01:15 - Sciences pack v2 UPLOADED under a NEW key sciences/v2/quran_sciences.zip (32,146,462 B, PK, no Content-Encoding, public range 206) + GitHub content-mirror asset (206, same size); v1 object left for 3.63.7 (range 206). AppConfig: url v2, bytes 32146462, version v2. FIXED a trap: _adoptBundledCopy stamped the old bundled sciences-v9 DB with the CURRENT version - would have passed a no-irab DB as v2; now stamps v1. CONTENT-LICENSES entry added (rights not cleared, owner's Shamela ruling). analyze clean. Next: signed build (emulator OFF), install, SEE the i'rab tab (2:5, 55:16 ref, 29:1->3:1, 22:28 correction), pack download.
- 2026-09-26 01:11 - APP SIDE (code only, NOT uploaded, NOT seen on device): scripts/build_irab_daas_table.py puts irab_daas (3,639 sections = 6,236 ayahs) + irab_daas_refs (215) into the LOCAL quran_sciences.db and drops word_grammar; build_sciences_db.py calls it. New IrabTab = book text (quotes gold) + proved references framed under the book's line + source header; pack screen row = book / 6,236 ayahs; Sources entry shamela 23584; 5 keys x 7 locales; QuranGrammarParser + test removed. analyze clean, 587 pass (594-7). Title page read: authors أحمد عبيد الدعاس، أحمد محمد حميدان، إسماعيل محمود القاسم; دار النمير (Shamela says المنير - print wins) ودار الفارابي ط1 1425. Next: upload pack under a NEW key so v3.63.7 keeps its v1 pack, sciencesDbVersion v2 + bytes, CONTENT-LICENSES, then signed build on emulator.
- 2026-09-26 00:48 - evidence: 37:169 print speck image
- 2026-09-26 00:48 - 37:169 «متعلقان»: print shows a dot over the ع (reads متغلقان) - it is the book's grammar term, not Qur'an; kept «متعلقان» as Shamela+KSU; image scripts/evidence/print_37_169_mutaallaqan.png sent to owner. Next: APP side (irab_daas table, ayah sheet, Sources, CONTENT-LICENSES, drop corpus labels, sciences pack v2).
- 2026-09-26 00:48 - OWNER RULE (CLAUDE.md 1.2 exception): Qur'an words quoted in a book are corrected to the mushaf after a by-eye check of the Madinah page + the print, with evidence image and record. scripts/check_irab_daas_quotes.py checked 59,532 quotes: 86 not in their ayah; read all - glosses/comparisons/spelling except 6 real, each seen on mushaf + print: 44:49 الكريم, 10:56 هو, 22:28 معلومات, 22:60 لعفو غفور, 24:21 والله سميع عليم (book), 3:107 رحمة (Shamela typo). Applied in build (quran_word_corrected=6), record scripts/irab_daas_quran_corrections.json, images scripts/evidence/. 22:61 print misquotes «سميع عليم» but Shamela already has «بصير» = shipped correct. Earlier reply gave wrong line numbers (44:49 is line 7, 10:56 end of line 4) - corrected in the record.
- 2026-09-26 00:41 - i'rab refs: owner list with proposals for the 222 unproven
- 2026-09-26 00:41 - Refs: the 59 'quote not found' are «سبق إعراب مثلها / ما يشبهها» = a PATTERN, not an ayah (4:15 «إن الله كان توابا رحيما»). Not shown. scripts/propose_irab_daas_refs.py writes scripts/irab_daas_refs_for_owner.md: 222 items (82 with a proposed nearest-similar ayah, 58 no quote, 36 one-word, 69 held numbers); 30 'own section' need nothing. App shows the book's sentence as-is there. Next: APP side - irab_daas table + ayah sheet.
- 2026-09-26 00:40 - i'rab refs: identical-ayah rule (215 of 467 shown)
- 2026-09-26 00:40 - Refs: rule 4 'identical' = a section ayah word-for-word equal to an earlier ayah (not when the book wrote a number - 3:1 «الآية ٢٥٤» had matched 2:1 «الم»; not when 2+ section ayahs have twins - 77:41-45, 26:136-145). Now 215 of 467 shown (103 quote, 60 number, 35 identical, 15 previous, 2 surah-start), 252 open. Next: 'not accepted' numbered refs - read print for the unclear ones.
- 2026-09-26 00:39 - CLAUDE.md 2.0b: do not report Remote Control (owner)
- 2026-09-26 00:39 - Owner: stop reporting Remote Control / suggesting claude rc (he gets every session on the phone automatically; ListAgents cannot see it). CLAUDE.md §2.0b rewritten, NEXT_PROMPT.md first-reply line fixed. Next: i'rab refs - identical-ayah rule for the 94 no-quote refs.
- 2026-09-26 00:35 - i'rab refs: shown only when the target is proven (179 of 467)
- 2026-09-26 00:35 - Owner: never TODO(human) - decide myself (memory saved). accept() rule: shown only if PROVEN - book's quote found in the target ayah, or (no quote) 3 consecutive shared words (2 was too weak: 34:39->34:16 passed). Now: 179 of 467 shown (102 quote, 60 number, 15 previous, 2 surah-start); 34:39 and 7:197 correctly held back; 288 open. Next: categorise open list for the owner, then app side.
- 2026-09-26 00:28 - i'rab refs: numbers checked vs print; acceptance rule left to owner
- 2026-09-26 00:28 - Ref numbers vs print OCR (scripts/check_irab_daas_ref_numbers.py): 64 same, 36 OCR-unseen, 7 'differ' = OCR noise on the ones read. READ ON THE PAGE: 7:197 «الآية (١٠)» and 34:39 «الآية ١٦» are the BOOK's numbers, yet the targets share no wording (34:39's phrase is in 34:36) -> policy needed: accept() in resolve_irab_daas_refs.py is TODO(human), waiting for the owner. Next: owner fills accept(), re-run, then app side.
- 2026-09-26 00:26 - i'rab refs resolver WIP: 244 of 467 resolved, numbers not yet checked vs print
- 2026-09-26 00:26 - Step 3 WIP: scripts/resolve_irab_daas_refs.py (NOT final, NOT in the app). 467 references in 423 sections; 244 resolved (107 by the book's ayah number, 104 by identical earlier quote, 31 'previous', 2 surah-start), 223 open for the owner. Fixed on real cases: skeleton across word boundaries (27:64->23:88, 40:62->40:28 false hits), «أمّن» vs «مَن», يا joined in the mushaf, «قبلها» false 'previous'. FOUND: ayah NUMBERS were never checked vs the print (arbitration compared words only) - 34:39 says «الآية ١٦» where the matching ayah is 34:36. Next: check every number against the print OCR.
- 2026-09-26 00:19 - build_irab_daas_final.py now USES the print transcriptions for the 27 damaged sections (base='print'), and exits if the transcribed set != the damaged set. Rebuilt: 3,639 = 3,612 shamela + 27 print; diff vs previous build = exactly those 27. Next: step 3 - «سبق إعرابها» references (owner requirement, log 23:45).
- 2026-09-26 00:18 - Daas: all 27 damaged sections transcribed from the print
- 2026-09-26 00:18 - Daas print: ALL 27 of 27 transcribed (+78:40 vol3 416, +81:10 vol3 423 - KSU had «معطوفة على الاية رقم 9» x4 garbage). check: 16 words in neither copy across 9 sections, every one read on the print. Next: wire build_irab_daas_final.py to use the transcriptions for these 27, rebuild.
- 2026-09-26 00:17 - Daas: 25 of 27 transcribed from the print (+51:40)
- 2026-09-26 00:17 - Daas print: 25 of 27 (+51:40-44 vol3 265-266, 0 new). Next: 78:40 (vol3 416), 81:10 (vol3 423).
- 2026-09-26 00:16 - Daas: 24 of 27 transcribed from the print (+44:44)
- 2026-09-26 00:16 - Daas print: 24 of 27 (+44:44-53 vol3 212). OWNER-CHECK: the print quotes 44:49 as «العزيز الحكيم» (ayah: الْعَزِيزُ الْكَرِيمُ) - book's own misquote, kept undiacritised as printed, not corrected. Next: 51:40 (vol3 265-266).
- 2026-09-26 00:16 - Daas: 23 of 27 transcribed from the print (+40:79)
- 2026-09-26 00:16 - Daas print: 23 of 27 (+40:79-82 vol3 166; KSU is TRUNCATED there («الفا.....»), Shamela lost first letters in 40:81 - both repaired from the print). Next: 44:44 (vol3 212).
- 2026-09-26 00:15 - Daas: 22 of 27 transcribed from the print (+37:168)
- 2026-09-26 00:15 - Daas print: 22 of 27 (+37:168-173 vol3 117, 0 new). OWNER-CHECK: in «به» متعلقان بكفروا the print shows a speck over the ع (reads like «متغلقان» at 300 dpi); both digital copies have «متعلقان» - kept متعلقان, flagged. Next: 40:79 (vol3 166).
- 2026-09-26 00:14 - Daas: 21 of 27 transcribed from the print (+30:47)
- 2026-09-26 00:14 - Daas print: 21 of 27 (+30:47 vol3 20, 0 new; print quotes «فجاؤوهم», kept the KSU diacritised quote form per method). Next: 37:168 (vol3 117).
- 2026-09-26 00:14 - Daas: 20 of 27 transcribed from the print (+27:44)
- 2026-09-26 00:14 - Daas print: 20 of 27 (+27:44 vol2 408). Next: 30:47 (vol3 20).
- 2026-09-26 00:13 - Daas: 19 of 27 transcribed from the print (+26:10, 26:15)
- 2026-09-26 00:13 - Daas print: 19 of 27 (+26:10-14 vol2 380, +26:15-18 vol2 380-381, 0 new words each). Next: 27:44 (vol2 408).
- 2026-09-26 00:12 - Daas: 17 of 27 transcribed from the print (+23:21)
- 2026-09-26 00:12 - Daas print: 17 of 27 (+23:21-23 vol2 326-327, 0 new). Next: 26:10 (vol2 380).
- 2026-09-26 00:11 - Daas: 16 of 27 transcribed from the print (+20:91)
- 2026-09-26 00:11 - Daas print: 16 of 27 (+20:91-94 vol2 269-270, 279 words; 2 new: وقرئ (print spelling), «ابن أمّ» (KSU «بن أم») - both on the print). Next: 23:21 (vol2 326-327).
- 2026-09-26 00:11 - Daas: 15 of 27 transcribed from the print (+18:47)
- 2026-09-26 00:11 - Daas print: 15 of 27 (+18:47-48 vol2 220-221, 161 words; 2 new «وعرضوا», بجئتمونا - both on the print). Next: 20:91 (vol2 269-270).
- 2026-09-26 00:10 - Daas: 14 of 27 transcribed from the print (+16:32)
- 2026-09-26 00:10 - Daas print: 14 of 27 (+16:32-33 vol2 157-158, 175 words; 1 new «ينظرون» = print, KSU «تنظرون» wrong). Next: 18:47 (vol2 220-221).
- 2026-09-26 00:09 - Daas: 13 of 27 transcribed from the print (+12:86)
- 2026-09-26 00:09 - Daas print: 13 of 27 (+12:86-87 vol2 102-103, 241 words; 4 new words all read on the print: تقديره «أنا», «وحزني», «إلى الله», بتيئسوا - KSU garbled all four). Next: 16:32 (vol2 157-158).
- 2026-09-26 00:08 - Daas: 12 of 27 transcribed from the print (+10:64)
- 2026-09-26 00:08 - Daas print: 12 of 27 (+10:64-66 vol2 34, 192 words; «وفي الآخرة» is a quote in the print, KSU lost it; KSU «إِنَّ نافية»/«أَلا أداة حصر» are wrong - print «إن»/«إلا»; print's «اسم لا» for مَن kept as the book's text). Next: 12:86 (vol2 102-103).
- 2026-09-26 00:08 - Daas: 11 of 27 transcribed from the print (+10:55)
- 2026-09-26 00:08 - Daas print: 11 of 27 (+10:55-58 vol2 32, 246 words; 1 new word «وهو» = the print's own quote for 10:56 whose ayah reads «هُوَ يُحْيِي» - book text kept undiacritised, NOT corrected; tell owner). Next: 10:64 (vol2 34).
- 2026-09-26 00:07 - Daas: 10 of 27 transcribed from the print (+4:172)
- 2026-09-26 00:07 - Daas print: 10 of 27 (+4:172 vol1 237-238, 182 words / 0 new). Next: 10:55 (vol2 32).
- 2026-09-26 00:06 - Daas: 9 of 27 transcribed from the print (+3:116)
- 2026-09-26 00:06 - Daas print: 9 of 27 (+3:116 vol1 155-156, 166 words / 0 new; print's paragraph break between ayahs kept as \n, ayah ref digits Arabic-Indic like the print). Next: 4:172 (vol1 237-238).
- 2026-09-26 00:05 - Daas: 8 of 27 transcribed from the print (+64:15, 2:147)
- 2026-09-26 00:05 - Daas print: 8 of 27 (+64:15 vol3 351, +2:147 vol1 62). 2:147 has 2 words in neither copy, both read on the print: «بلا الناهية» (KSU «بال»), «أينما» one word (KSU «أين ما»). Next: 3:116 (vol1 155-156).
- 2026-09-26 00:04 - Daas: 6 of 27 transcribed from the print (+6:130)
- 2026-09-26 00:04 - Daas print transcription: 6 of 27 (+6:130, vol1 pdf 334-335, check 198 words / 0 in neither copy; print's own typo «نعلق به» kept). Next: 64:15 (vol3 351), then the list.
- 2026-09-25 23:44 - HANDOVER: analyze clean, 594 pass, 9/9 hosted 206; i'rab resume point; next prompt
- 2026-09-25 23:45 - OWNER REQUIREMENT: where the book says «سبق إعرابها / تقدم إعرابها / انظر الآية N / ينظر الآية N / يراجع…» the i'rab tab must SHOW the actual i'rab, not the phrase. Measured on the final text: 393 sections mention an earlier i'rab, 63 are ONLY a reference, 105 carry an ayah number. Plan (not done): keep the book's sentence (it is the book) and render the referenced section's i'rab under it, labelled «إعراب الآية N كما ورد في الكتاب»; target = the named ayah, or for «مثيلها/السابقة» the nearest earlier ayah with the identical text (KFGQPC) - anything not resolvable that way goes to a list for the owner, never guessed. HANDOVER written (analyze clean, 594 pass, 9/9 hosted 206).
- 2026-09-25 23:39 - Daas: 5 of 27 transcribed from the print; exact resume point logged (quota 85%)
- 2026-09-25 23:39 - Daas transcription from the PRINT: 5 of 27 done (106:3, 87:11, 72:15, 55:66, 8:13) in scripts/irab_daas_print_transcriptions.json, each checked (0 words in neither copy). Method that works: start from the KSU text, read it against the printed page word by word, use the print's punctuation, «» around quoted words, keep the diacritised quote forms. Stopped at 5-hour quota 85%: page images must be ZOOMED per column (a 3-page strip at 2/3 scale is not legible) - next: 6:130 (vol1 pdf 334-335), 64:15 (vol3 351), then the rest. Remaining 22: 2:147, 3:116, 4:172, 6:130, 10:55, 10:64, 12:86, 16:32, 18:47, 20:91, 23:21, 26:10, 26:15, 27:44, 30:47, 37:168, 40:79, 44:44, 51:40, 64:15, 78:40, 81:10. Tool: py -3 scripts/irab_daas_transcribe.py show <s> <a> <pdf_dir> <out.png> / check. PDFs: archive.org i3rb-krn-d3s (re-download to the scratchpad if gone). Then: build_irab_daas_final.py must USE the transcriptions for these 27 (not the KSU splice) - wire that in, rebuild, then the app side.
- 2026-09-25 23:39 - Daas: 5 of 27 damaged sections transcribed from the print (+55:66, 8:13)
- 2026-09-25 23:38 - Daas: 3 of 27 damaged sections transcribed from the print (106:3, 87:11, 72:15), checked word by word
- 2026-09-25 23:30 - Owner phone shows the mushaf lines in the right order: the reversal was an emulator rendering fault
- 2026-09-25 23:30 - OWNER'S PHONE (3.63.7, Amiri, Impeller): al-Baqara p.2 line 1 «الٓمٓ ١ ذَٰلِكَ…» and 2:6-13 all in the RIGHT order (his screenshots). => the reversed lines were an EMULATOR rendering fault (Impeller on emulated GLES; seen with both fonts, Skia correct). No app change. Still to see once: the KFGQPC build on his phone, same page.
- 2026-09-25 23:17 - Log time corrected to the clock (23:17)
- 2026-09-25 23:17 - Daas final build: 3,612 sections from Shamela backed by the print; 27 damaged sections to transcribe from the printed page
- 2026-09-25 23:17 - Daas final build (scripts/build_irab_daas_final.py -> temp_phase1/irab_daas_final.json): 3,612 sections = Shamela text as is (+ join 768 broken lines, drop 4 structure lines) - backed by the print (54,434 8-word chunks, 24 doubtful, all 24 read and correct). 27 sections are ones Shamela DAMAGED; there the KSU copy is NOT clean either (12:86 KSU garbled «(إنما أشكو بثي)», stray harakat «استفهامَ», glued «أويأتي»). DECISION: transcribe those 27 sections from the PRINTED page (vol, pdf idx given), then check every word against Shamela, KSU and the OCR. The 27: 2:147-148 [[1, 62]]; 3:116-117 [[1, 155], [1, 156]]; 4:172-173 [[1, 237], [1, 238]]; 6:130-130 [[1, 334], [1, 335]]; 8:13-13 [[1, 419]]; 10:55-58 [[2, 32]]; 10:64-66 [[2, 34]]; 12:86-87 [[2, 102], [2, 103]]; 16:32-33 [[2, 157], [2, 158]]; 18:47-48 [[2, 220], [2, 221]]; 20:91-94 [[2, 269], [2, 270]]; 23:21-23 [[2, 326], [2, 327]]; 26:10-14 [[2, 380]]; 26:15-18 [[2, 380], [2, 381]]; 27:44-44 [[2, 408]]; 30:47-47 [[3, 20]]; 37:168-173 [[3, 117]]; 40:79-82 [[3, 166]]; 44:44-53 [[3, 212]]; 51:40-44 [[3, 265], [3, 266]]; 55:66-66 [[3, 296]]; 64:15-15 [[3, 351]]; 72:15-15 [[3, 390]]; 78:40-40 [[3, 416]]; 81:10-14 [[3, 423]]; 87:11-11 [[3, 440]]; 106:3-3 [[3, 470]]. Also KSU inserts its OWN notes («لا يوجد إعراب لهذه الآية في كتاب مشكل إعراب القرآن للدعاس», «تقدم إعرابها» x3) - never use. Rendering: FOUND text mushaf lines drawn reversed under Impeller on the emulator (Skia correct); waiting for the owner's phone check (Baqara p.2 line 1: ١ or ٢ next to الٓمٓ). Emulator holds a DEBUG build (Impeller on, Amiri) - reinstall a signed build before any device check.
- 2026-09-25 23:03 - Daas: every disputed place decided against the printed page; verdicts file; parser fix for 19:14
- 2026-09-25 23:03 - Daas: ALL 165 undecided items decided (scripts/irab_daas_verdicts.json, content-keyed): 30+ read off crops, 23 off full pages, rules confirmed by the print (KSU missing a passage -> Shamela; Shamela dropped first letters -> KSU only if the exact word is on the printed page or is the ayah word in the KFGQPC text; KSU-added ayah wording -> Shamela; Shamela glued words -> KSU). FOUND: KSU copy is NOT independent of Shamela (inherits stray harakat) and some of its repairs are wrong (16:33 «تنظرون»; print «ينظرون» -> taken from the print), and it misassigns text per ayah (55:19->55:20, 69:2->69:1) -> the book's own sections stay. 78:40 Shamela damaged throughout -> whole section from KSU minus its ayah prefix. Parser fixed: 19:14-17 had ayah text glued into the i'rab (1 section). 4 Shamela structure lines ([الجزء الثاني] etc.) to strip; 768 line breaks after a quoted word in 240 sections to join (formatting only). Re-running arbitration on the fixed parse. NEXT: build_irab_daas_final.py (A base; sections with KSU wins -> KSU base + A-win splices; «» formatting; strip/join), re-check final vs print OCR, then app side (table + UI + source credit).
- 2026-09-25 22:33 - Daas: whole print OCRd; 99.95% of agreed text confirmed by the print; review crops for the rest
- 2026-09-25 22:32 - Daas print OCR DONE 1,418/1,418. Full arbitration (3,631 of 3,639 sections judged; 8 unjudged = pages at volume edges, check by hand): 54,352 agreed 8-word chunks, 26 contradicted by the print (0.05%); differences: 395 spacing-only (Shamela kept), 3,119 print->Shamela, 49 print->KSU, 230 undecided in 113 sections. Found Shamela damage pattern: first letter of every word dropped inside some quoted ayahs (2:148 «لكل جهه و وليها»); added exact-word-on-page tie-breaker, re-running. winocr.ps1 now emits line boxes (WINOCR_BOXES=1); irab_daas_review_crops.py cuts the disputed lines out of the print, 10 per sheet, readings in review.txt (scratchpad/daas/review).
- 2026-09-25 21:56 - Mushaf line order wrong under Impeller on the emulator (Skia correct); test for RTL order; asked owner to check his phone
- 2026-09-25 21:57 - FOUND on emulator-5554: text mushaf lines drawn in the wrong order under IMPELLER (OpenGLES, emulation EGL). KFGQPC+Impeller (release 20:58 build): al-Rahman p.531 line 1 reversed (ٱلرَّحۡمَٰنُ at the left, markers 1..4 from the right). Amiri+Impeller (debug, font swapped temporarily, reverted): words right but markers swapped (٢ beside الٓمٓ). KFGQPC+SKIA (debug, EnableImpeller=false in the manifest, reverted): CORRECT (18:1 line zoomed). Layout itself correct: long-press at the right end opened 55:1; test/mushaf_rtl_order_test.dart (wrapped, justified lines) passes for both fonts. Real phones UNKNOWN - asked the owner to look at al-Baqara line 1 on his phone (3.63.7, Amiri, Impeller): ١ or ٢ beside الٓمٓ. If ٢ -> ship with EnableImpeller=false. Emulator now has a DEBUG build (app data wiped by the uninstall).
- 2026-09-25 21:06 - Daas: printed edition as third witness (Windows Arabic OCR of all pages) and the arbitration script
- 2026-09-25 21:06 - Daas third witness: the PRINT. scripts/winocr.ps1 (Windows OCR ar-SA, reads the commentary well; ornate ayah lines weak), ocr_irab_daas_print.py OCRing all 1,418 pages (2.4-2.9 s/page, background, resumable -> temp_phase1/irab_daas_print_ocr.jsonl; PDFs in the session scratchpad, re-download from archive.org i3rb-krn-d3s if lost). arbitrate_irab_daas.py: locates each Shamela page on the PDF by word-trigram overlap (offset differs per volume), then for every A/B difference tests both readings (+3 words context) against the print (margin 0.06, else «?» for eyes), and flags 8-word chunks where A+B agree but the print does not. First 57 sections: 13 differences, print sided with Shamela in 9, 4 undecided.
- 2026-09-25 21:00 - Tour v2 pictures (8 whole screens, 7 languages) captured and seen on the emulator; Daas printed edition located
- 2026-09-25 21:01 - Tour v2 SEEN on emulator (signed build installed 20:58:43, cold start): quick tour 9/9 (welcome + Home, Quran, Prayer, Adhkar, Tasbeeh, Hifz, Recitations, Tajweed), each the whole screen framed in its colour, Arabic after switching from Urdu on stop 1, last button «تم». Capture: 238 pictures (7 x 34), 4.61 MB. Daas printed edition found: archive.org i3rb-krn-d3s, 3 vols 478/459/481 pages (the alfirdwsiy2018 zip's vol 3 is truncated, 0 pages); title page «دار النمير - دار الفارابي» (Shamela's «المنير» is a typo), Baqara on printed p.9 = Shamela pageNum 9. archive.org OCR is Latin garbage; Windows OCR has ar-SA -> third witness.
- 2026-09-25 20:44 - Daas: two digital copies agree on the scholar text for 90% of sections; 313 sections need the printed page
- 2026-09-25 20:44 - Tour v2 capture build installed 20:41:30; ar captured: all 8 whole screens seen by eye (hifz list shows the emulator's plans, «7 of 7» on every surah). Other 6 languages capturing.
- 2026-09-25 20:44 - Daas diff (scripts/diff_irab_daas.py + quoted-Quran stripped, temp_phase1/irab_daas_diff2.json), 3,639 sections: 1,547 same commentary word for word (2,043 ayahs); 1,779 differ ONLY by e-quran adding ayah wording (3,542 ayahs) -> scholar's text agrees on 3,326 sections / 5,585 ayahs = 90%. Needs arbitration: 58 Shamela-damaged (135 ayahs, e-quran clean), 39 e-quran missing/short (75 ayahs, e.g. 2:270 «لا يوجد إعراب», Shamela has it), 216 real wording differences (441 ayahs). Shamela damage is wider than unbalanced «»: glued words (12:86 «مستأنفةنما»). Arbiter = printed edition; PDF download needs owner's OK (asked).
- 2026-09-25 20:37 - Quick tour = 8 main screens shown whole; Play Store gallery moved out of the app to R2
- 2026-09-25 20:37 (commit time; first written «21:10», a guess) - Owner: quick tour = 8 MAIN screens shown whole (Home, Quran, Prayer, Adhkar, Tasbeeh, Hifz, Recitations, Tajweed), not small features. Done in code (TutorialChapter.whole, full-screen frame, new keys quick_recite/quick_tajweed, welcome no longer says Skip is at the top). tutorial_overlay split into parts (was 1013 > 800 lines). Owner: Play Store gallery OUT of the app, kept on R2: store/google_play/** + in_app_540/*.jpg uploaded, 36 objects 206 + size match; FeatureGalleryScreen, assets/tutorial_shots, build_tutorial_shots.py, key tutorial.gallery removed. 592 pass, analyze clean. NEW PICTURES NOT CAPTURED YET (quick_* webp are the old small-feature shots; quick_recite/quick_tajweed have none -> those two stops are hidden until captured). e-quran crawl DONE 6236/6236, 0 failed (170 MB, gitignored).
- 2026-09-25 20:23 - Daas i'rab: Shamela crawled and cut into 3,639 sections (full coverage); damage found; second copy crawling
- 2026-09-25 20:23 - Daas i'rab: Shamela 23584 crawled (1399 pages, scripts/shamela_raw/irab_daas.jsonl); parse_irab_daas.py -> 3,639 book sections covering all 6,236 ayahs exactly once (0 gaps, 0 overlaps vs quran_local.db). FOUND: Shamela copy damaged (first letter of «» dropped, lines shuffled) in >= 58 sections / 124 ayahs (unbalanced «»); tafsir.app serves the SAME damaged text (not independent). Second copy: e-quran.com slug eerab (= KSU Ayat slug), clean at 4:172; crawling all 6,236 pages (fetch_irab_daas_equran.py) to diff section by section. Also found: word_grammar (corpus) has 6,122 ayahs, not 6,236.
- 2026-09-25 20:16 - Tour pictures seen on the emulator (quick 7/7, full 27/27); owner chose the Daas i'rab
- 2026-09-25 20:17 - Tour pictures SEEN on emulator (signed build 20:11, lastUpdateTime 20:11:28): quick tour 7/7 in ur->ar switch, full tour 27/27 in ar - every stop shows its webp picture, frame on the named element, no stop blank. Picture state is the capture device's (Cairo, 07:51, hifz list with plans). Owner chose Daas for i'rab (20:20).
- 2026-09-25 20:06 - Tour pictures recaptured in 7 languages (32 each) committed and listed in pubspec; i'rab label rewrite scripts added
- 2026-09-25 19:45 - Tour as screenshots (TourSlides + capture build + script); account and reciter cards follow the theme
- 2026-09-25 19:45 - Owner: the tour must be PICTURES of the screens («اسكرين شوتات»), in the reader's language. Done in code: TourSlides (image + framed feature + bubble, nothing behind it touchable); capture build (--dart-define=RAFEEQ_TOUR_CAPTURE=true) walks both tours in all 7 languages, logs TOURCAP lines; scripts/capture_tour.py screenshots, crops, writes assets/tour/<lang>/<key>.webp + frames.json. First run: ar 32 pictures 644 KB, then it stopped (last stops skipped called _finish) - fixed; recapturing. Also item 14: account card back side theme-aware (was fixed dark green), reciter panel follows light theme (pale ground, dark ink). SEEN on emulator build 19:14: More groups one-open + sections open as screens (tasbih reminders full screen), Audio tab «−» removes (89->88), location in Times & date, New Muslim gone. assets/tour NOT yet in pubspec (release build would show no pictures).
- 2026-09-25 19:10 - More: header-to-top on open, sections open as screens; tour hifz stop shows the hifz screen
- 2026-09-25 19:10 - Item 10 More: a group opening scrolls its own header to the top after the closing one settles (no chase); any CollapsibleSection inside a More group opens as its own screen. Tour hifz stop per owner («مش كارت الحفظ، شاشته»): TutorialChapter.screen draws HifzScreen under the tour, frame on the plans section (TourAnchor.hifzPlans). Code only, NOT BUILT.
- 2026-09-25 19:06 - Quick tour in the owner order, no library, last stop on the hifz card
- 2026-09-25 19:06 - Item 11 tour: owner chose (18:5x) Home > Quran > Prayer&Qibla > Tasbeeh > Adhkar > Hifz, NO library anywhere in the tour (a store build without the library is planned). Quick tour rebuilt, last stop framed on the hifz card (new anchor moreHifz), full tour library stop removed, keys quick_hifz_* in 7 locales, quick_library/quick_more/library_tabs keys removed. 592 pass. NOT BUILT.
- 2026-09-25 18:59 - Stage 2 items 9, 12, 13: New Muslim guide removed, reciter badge icon, juz without frame
- 2026-09-25 18:59 - Stage 2 items 9 (New Muslim guide deleted: feature folder, More card + subtitle, keys new_muslim.* and orphan home.new_muslim in 7 locales, its mention in tutorial.more_body and about.src_unsplash), 12 (reciter badge: open-mushaf icon, no list number), 13 (juz pill: no frame) in code. 592 pass. NOT BUILT.
- 2026-09-25 18:54 - Stage 1 items 2,5,6,7 and stage 2 item 8 (code, 592 pass)
- 2026-09-25 18:54 - Stage 1 items 2,5,6,7 + stage 2 item 8 in code (592 pass, NOT BUILT): 2 = the Audio (مسموعة) list drew from the whole catalogue so «−» said removed and the book stayed (authors/categories verified working on emulator, undo works); 5 = quran.stop in 7 locales + test for keys inside (…).tr() (fails without the key); 6 = sciencesRepositoryProvider re-reads itself when the pack completes (a background completion left it null); 7 = could NOT reproduce «not marked until re-enter» (flow works on emulator, qibla 136° for Cairo); «تحديد يدوي» row now focuses the search; 8 = location + auto-update moved to Times & date screen. ANR round 2 on emulator: 11-20 ticks/s (was 40-50), ~22 ms main thread per ayah - not an ANR, still jank; real fix = per-surah zips (not done). Special-surah image mode night paper SEEN.
- 2026-09-25 18:35 - KFGQPC text seen on emulator; ANR round 2 (no files tracking, status-only ayah tasks); paper chips in special-surah reader
- 2026-09-25 18:50 - SEEN on emulator-5554 (build installed 18:23:50): new text + KFGQPC font live - 18:31 «عدن» no meem, staggered kasratan drawn (Amiri would draw U+0656 as a small alif; it does not), final ya dotless as in print; al-Kahf opens with the basmala line then 18:1 «ٱلۡحَمۡدُ». ANR NOT fixed yet: main thread still ~40 ticks/s after the tap (idle 0). Now: files group no longer tracked in the plugin DB, ayah tasks status-only, completion notify throttled; special-surah reader image mode gets the paper chips + ground. 591 pass. (Log times 18:05/18:40 above were estimates, not the clock - the clock read 18:21 at install.)
- 2026-09-25 18:17 - Ayah text: King Fahd Complex hafs v18 + its font (replaces Tanzil 1.0: false iqlab meems, 5 text errors); not built
- 2026-09-25 18:40 - Text mushaf moved to the King Fahd Complex text+font (code+data, 591 pass, not built).
- 2026-09-25 17:59 - Ayah download ANR: feed the plugin queue 12 at a time, set-based counts (not built); text mushaf source audit
- 2026-09-25 18:05 - ANR PROVEN: tap «تلاوة آية بآية» -> main thread ~50% busy for ever on emulator-5554 (/proc task stat, 50 ticks/s); MemoryTaskQueue.getNextTask = 7.7 ms per call with 6,236 waiting (bench), twice per finished ayah. Fix in code (backlog+window 12), 589 pass. Text mushaf audit: see Next step A.
- 2026-09-25 17:23 - Stage 1 item 1 SEEN on emulator: back leaves screens whose card started open; library shows one app bar
- 2026-09-25 17:23 - Item 1 SEEN on emulator-5554 (APK built 17:18, installed 17:20:37, cold start): Downloads > Book reader voice > arrow returns to Downloads; Downloads > Books shows ONE bar «Library» with its own arrow; Categories (first shelf open) > system back > Downloads in one press; Authors > tap Ibn Kathir (user-opened) > back closes the card and stays (old rule kept). analyze clean, 589 pass.
- 2026-09-25 17:09 - Stage 1 item 1: back dead behind a card that started open; library double app bar (code + test, not built)
- 2026-09-25 17:10 - Item 1 cause PROVEN on emulator-5554 (3.63.7): Downloads > Book reader voice, arrow AND system back both dead. accordion.dart: canPop counted any open card, the back handler only closes cards in _opened (user-opened); a card built open (initiallyOpen / initiallyExpanded: voice screen, library Categories first shelf, recitations <=3 reciters) blocked pop with nothing to close. Fix: count only _opened. Test added (fails old, passes new). LibraryRoute no longer wraps LibraryScreen in a 2nd Scaffold. Not built yet.
- 2026-09-25 15:50 - HANDOVER: analyze clean, 588 pass, 8 hosted paths 206, 7 locales x 1,833 keys, 239 books, hadith.db 109,731,840 B, v3.63.7 APK 270,769,028 B. Plan written (NEXT_SESSION_PROMPT.md), NEXT_PROMPT.md rewritten.
- 2026-09-25 15:30 - Owner sent 8 screenshots + 9 screen recordings from his Xiaomi (3.63.7), asked for a REPORT ONLY, no changes. Findings (unverified in code, from frames): back arrows not responding (Book reader settings, Library opened from More), double app bar «الكتب»+«المكتبة», ayah-download notification done>total (1488/1485), Initial downloads says «no server» while the ayah download runs, per-ayah list shows 0/114 during download, More accordion jumps + long reminder text inline, account name dark on dark, i'rab «على» = «جمع», odd «خطوات الصلاة» icon, tour step 8 highlights the player card, mushaf size line clipped. Waiting for owner to pick.
- 2026-09-25 14:44 - v3.63.7 published: final ring-cropped icon without prayer beads
- 2026-09-25 14:44 - FINAL icon: owner's 1024 image WITHOUT prayer beads (he regenerated it after the inpaint attempt smeared the stand), cropped to the ring (box 24,30-997,1003). Preview shown, owner approved («انشر»), seen on emulator launcher. v3.63.7 PUBLISHED (tag == HEAD c6f8d3ac, sha256 b3c22dc8 = local), v3.63.5 deleted (3.63.6 was never published). Not yet on the owner's Xiaomi.
- 2026-09-25 14:16 - v3.63.5 published: owner's 1024 icon
- 2026-09-25 14:17 - Owner's 1024 square icon used as given, bg #9BC4B3 (image edge median), seen on emulator launcher. v3.63.5 PUBLISHED (tag == HEAD 6e3114a3, sha256 39b559da = local), v3.63.4 deleted. Not yet on the owner's Xiaomi.
- 2026-09-25 14:00 - v3.63.4 published: owner's light app icon
- 2026-09-25 14:00 - Owner's LIGHT app icon (cropped from his 512x279 banner, no redraw) + adaptive bg #F7FCFF, seen on emulator launcher. v3.63.4 PUBLISHED (tag == HEAD 5bb2c9eb, sha256 3a1f95f8 = local), v3.63.3 deleted. Not yet on the owner's Xiaomi.
- 2026-09-25 13:44 - v3.63.3 published (download ANR + lock-stop fixes, Later, revisit); icon question pending
- 2026-09-25 13:45 - Owner video (Xiaomi): ANR at onboarding + downloads die on screen lock. FIXED 9aadd313 (sciences unzip off UI isolate; mushaf retries with backoff instead of stopping after 3 errors) + «Later» + Downloads > Initial downloads. SEEN on emulator-5554 (fresh install): ANR 0, sciences unzipped while mushaf ran; screen off + 15 s network cut: mushaf 170 -> 290. v3.63.3 PUBLISHED (tag == HEAD e762db38, sha256 c9a11217 = local), v3.63.2 deleted. NOT yet on the owner's Xiaomi. PENDING owner answer: app icon «فاتح» (A: he sends a light icon / B: adaptive background cream / C: default light theme).
- 2026-09-25 12:03 - FINAL v3.63.2 published and verified; v3.63.1 deleted; landscape large-font tasbeeh fixed and seen
- 2026-09-25 12:04 - FINAL v3.63.2 PUBLISHED: tag == HEAD 88e77914, asset sha256 92860ddc = local; v3.63.1 + tag deleted. Landscape at font 1.45 (owner rotated): Home/Prayer/Adhkar/Library/More fine; Tasbeeh circle was ~65 dp -> footer moved beside it, SEEN full size, tap 2->3. Remaining open: «Enable location» with no cached fix; city ar->ur first-switch delay.
- 2026-09-25 11:49 - v3.63.1 published and verified (tag == HEAD, digest = local); v3.63.0 deleted
- 2026-09-25 11:49 - v3.63.1 PUBLISHED: tag == HEAD afa4a8a9, asset RafeeqAlDarb-v3.63.1.apk 270,576,516 B sha256 6913d7de = local file; v3.63.0 + tag deleted; v3.51.0 + content-* kept.
- 2026-09-25 11:47 - PHONE: device file (Music) + Dhuhr Test -> paused 66.3 s, Stop -> resumed 66.4 s; tajweed example plays on the shared player (clip shorter than the 8 s test); theme Light->Dark and language en->ar while playing: same player PLAYING, city in Arabic at once; HOME 12 s while playing: still PLAYING; 108 MB ruqyah download finished with the app in background. Phone restored to Light + English, playback stopped.
- 2026-09-25 11:27 - Font 1.45 fixes seen on owner's phone: Home PM, tasbeeh counter full size and counting, uniform library tabs
- 2026-09-25 11:27 - d7a482c2 built + installed on owner's phone (font 1.45 bold): Home «12:11 PM» whole; Tasbeeh full circle, 2 taps -> Total 2; Library sub-tabs one uniform size. The 3 findings of 11:12 are FIXED and SEEN. Build = 3.63.1+66 code, NOT released.
- 2026-09-25 11:12 - Phone at font 1.45 + location off: no dialog loop; found tasbeeh counter dot, tiny library tabs, missing PM on Home centre tile (unfixed, logged)
- 2026-09-25 11:04 - 3.63.1 on owner's phone: diacritisation fix seen, adhan pauses/resumes book reader voice and ruqyah, book reader stops ruqyah
- 2026-09-25 11:05 - PHONE 3.63.1: enhanced voice downloaded (260.7 MB, owner OK); Dhuhr Test fired while the book reader read Ihkam: voice player piid 4207 PAUSED, adhan USAGE_ALARM started, full screen + notification Stop/Mute; Stop -> 4207 STARTED again, next chunk 4223 followed; reader stopped -> 0 players. (Was unit-tested / emulator-only before; now seen on a real phone.)
- 2026-09-25 11:02 - PHONE: ruqyah + adhan preview -> ruqyah PAUSED, alarm player started; Stop -> ruqyah resumed same position (76.1 s). FOUND: Ihkam al-Ahkam (visibly vowelled) said «only 0% harakat» - 28 books never measured, default 0. FIXED 91d82a33 (measured, Ihkam 83.4%), 3.63.1+66 built + installed on phone: Listen offered. Phone TTS vs ruqyah: ruqyah -> NONE (one sound). Enhanced voice downloading (owner OK). 3.63.1 NOT released - ask owner.
- 2026-09-25 10:39 - 3.63.0 seen on the owner's phone: About version, manual location Tanta (times + qibla match hand calc), back to Automatic
- 2026-09-25 10:40 - OWNER'S PHONE (BRP-NX1, Android 12, 3.63.0 release APK): About «v3.63.0»; Prayer location -> Tanta (offline list, typed in Latin) -> Home «Tanta, Egypt», sunrise 7:46 / Dhuhr 1:48 PM phone time (hand calc: solar noon lon 31.0 = 09:48 UTC = 13:48 Dubai), qibla 259 -> 138; back to Automatic -> Dubai 12:11, qibla 259. Phone left on Automatic. NOT done on the phone (sound / system settings, people asleep): location switch off->on path, largest font, ruqyah/tajweed/device-files audio conflicts.
- 2026-09-25 10:33 - v3.63.0 published and verified (tag == HEAD, asset digest = local); v3.62.0 deleted; installed on owner's phone
- 2026-09-25 10:33 - v3.63.0 PUBLISHED (tag == HEAD 6145c3c9, asset sha256 673d5353 = local file), v3.62.0 + tag deleted; installed on owner's phone BRP-NX1 over the old build: onboarding, location + notification grant, Home Dubai times, Support button seen
- 2026-09-25 05:15 - build 15: last contrast fixes seen (player/tajweed/hadith clean, chip fixed, RGB player+theme clean); HANDOVER updated
- 2026-09-25 04:55 - 21 more gold icons + player tab + chip icon fixed (28eba2c7, unbuilt); Fajr adhan seen firing on time on build 14
- 2026-09-25 04:15 - dark clean; RGB filled buttons white-on-cyan 1.67:1 fixed via measured onPrimary (unbuilt)
- 2026-09-25 03:50 - contrast light crawl complete + eyed; 35 gold icons, reading card, chip checkmarks fixed (unbuilt)
- 2026-09-25 03:27 - build 13: manual location fully verified offline (times, name, qibla 138 = calc, method change, back to automatic)
- 2026-09-25 03:20 - build 12: times follow the manual place (Tanta/Makkah checked by hand); FOUND qibla stuck on old place - fixed (changes notifier), building 13
- 2026-09-25 03:10 - build 11: bundled list works offline; FOUND times cached by date only (place/method changes ignored until midnight) - fixed + test, building 12
- 2026-09-25 03:00 - build 10: hosted list download reached «ready»; owner asked to BUNDLE it - done in code (asset + ensureReady), 583 pass, unbuilt
- 2026-09-25 02:35 - download error surfaced (userErrorText + logcat), build 10 started
- 2026-09-25 02:09 - HANDOVER (quota): city-list download failed at 46% on build 9 (Isolate.run captured State) - moved to top-level functions, unbuilt; contrast fixes unseen on device; NEXT_PROMPT.md rewritten
- 2026-09-25 01:52 - Manual prayer location UI (Adhan settings > Prayer location): automatic / offline world list search / online geocoder / coordinates; 20 keys x 7 locales; GeoNames credited on Sources; 582 pass; building 9
- 2026-09-25 01:42 - Contrast: goldText() on 25 files where flat gold was text on a theme surface (scan found them); quote card gold measured on its palette; manual location core (ManualPlace store, CityCatalog download+offline search tested on real data, LocationService prefers it); 582 pass, unbuilt, no UI yet
- 2026-09-25 01:27 - Manual location (order B): world city list (GeoNames cities1000, 171,075 places, CC BY 4.0) hosted on R2 geo/cities.tsv.gz + GitHub mirror, NOT bundled (owner: no size growth); both hosts answer 206
- 2026-09-25 01:04 - Contrast (owner order A): measured scan tool + readableOn/fillForWhiteText; fixed tasbeeh pills/title, selected surahs, quote mark, Home dates, side prayer tiles, Library tabs (unbuilt)
- 2026-09-25 00:43 - Build 7 verified: no location-dialog loop with location off, card button opens location settings, Qibla asks again and finds 258
- 2026-09-25 00:25 - Location switch off: Google dialog re-raised on every resume (endless) - service no longer requests a fix when location is off; building 7
- 2026-09-25 00:15 - Build 5 verified (one location ask, quote arrows, pt explanation, adhkar landscape); enable-location buttons now handle a switched-off location and Qibla asks again (askToEnable)
- 2026-09-24 23:59 - Matrix done (7 languages x 3 themes x 2 orientations): hadith explanation was forced RTL in LTR languages - fixed; 577 pass; building 5
- 2026-09-24 23:34 - Matrix en+ar read: quote arrows were swapped, adhkar grid 2 columns in landscape - both fixed (unbuilt)
- 2026-09-24 23:21 - Build 4: recitation row retry verified; location was asked twice on first run (service raced the startup ask) - service no longer prompts; matrix sweep script
- 2026-09-24 23:03 - Urdu pass: adhkar cards kept the old language after a switch (const tab) - now depend on locale; owner asked for full theme x language x orientation matrix
- 2026-09-24 22:56 - Landscape audit: tasbeeh counter shrank to a dot - side-by-side layout when wide and short (unbuilt)
- 2026-09-24 22:52 - All 8 audit-2 fixes verified on build 3 (item 8 city on locale switch); complete-recitation row retries the catalogue 3 times (577 pass, unbuilt)
- 2026-09-24 22:50 - Verified item 6: splash preview pauses then resumes the recitation
- 2026-09-24 22:47 - Verified item 5: morning adhkar reminder tap opens the Morning adhkar screen
- 2026-09-24 22:42 - Verified item 4: tasmee download offline shows localized No internet connection
- 2026-09-24 22:38 - Verified item 3: reader-voice download survives airplane mode and completes
- 2026-09-24 22:32 - Verified items 2 (one notification ask) and 7 (umts recommends Banna); found complete-recitation row fails first try on umts
- 2026-09-24 22:26 - Build 3 signed (Kotlin compiled); item 1 adhan-without-notifications Stop verified on emulator
- 2026-09-24 22:27 - Build 3 signed OK (Kotlin compiled); item 1 (adhan with notifications off shows Stop on app open) VERIFIED on emulator
- 2026-09-24 22:16 - Resumed session: emulator off, release build of the 8 unbuilt fixes running
- 2026-09-24 (new session) - Resumed: quota 5h 0% / weekly 69%; RC not connected; emulator off; build_github_release.bat running (step 1)
- 2026-09-24 21:53 - Handover: verified (analyze, 577 tests, 8 hosted paths 206), measured, HANDOVER/NEXT_SESSION_PROMPT/NEXT_PROMPT rewritten; 8 fixes unbuilt
- 2026-09-24 21:47 - Audit 2: notification permission asked twice (fixed); adhan with notifications off had no Stop anywhere (fixed in MainActivity.onResume)
- 2026-09-24 21:32 - Audit 2: reminders open their screen (open: payloads, 4 tests); reboot re-arms adhan (seen)
- 2026-09-24 21:25 - Audit 2: network drop mid-download was reported as a cancel (WorkManager stop) - now waiting; offline screens seen OK
- 2026-09-24 21:16 - Audit 2: splash preview resumes recitation; raw exception texts replaced by localized messages (user_error.dart)
- 2026-09-24 21:08 - Fix: slow-line probe keeps timed-out hosts (right recommendation); city name re-read from saved coordinates on language switch; audit part 2 list
- 2026-09-24 20:55 - v3.62.0 released and verified (tag == HEAD, asset re-downloaded byte-identical); v3.61.0 deleted
- 2026-09-24 20:53 - v3.62.0 ready: audit complete on device, notes + HANDOVER updated; publishing
- 2026-09-24 20:46 - Verified on build 2: adhan discards a tasmee recording; adhan over focus mode and back
- 2026-09-24 20:36 - Verified on build 2: per-ayah delete stops playback; reciter header readable
- 2026-09-24 20:35 - Verified on build 2: per-ayah delete stops playback; reciter header readable
- 2026-09-24 20:31 - Verified on device: adhan pauses the book reader and it resumes after
- 2026-09-24 20:23 - Build 2 of 3.62.0 signed (focus/tasmee/sunan/per-ayah delete/probe/header fixes in); verifying on emulator
- 2026-09-24 20:19 - Audit: adhan+book reader played together (seen) -> audio focus in voice player + TTS interruptions (3 tests); tasmee discards recording on adhan; sunan reminders self-clear (trap 33); 573 pass
- 2026-09-24 20:02 - Full audit matrix written (owner: audit every aspect); qibla verified 258 vs computed 258.2
- 2026-09-24 20:01 - Found on device: deleting a per-ayah reciter left its queue playing from the network; fixed (tag check), 570 pass
- 2026-09-24 19:48 - Seen: deleting a playing surah recitation stops it; fixed unreadable reciter header text in light theme
- 2026-09-24 19:45 - Onboarding ayah-reciter probe: 15 s timeout and a retry when no host answered (was disabled on a slow line); analyze clean, needs the next build
- 2026-09-24 19:44 - Seen on device: tasmee download survives leaving the panel, shared with onboarding; adhan during download OK; found slow-network probe disables ayah row
- 2026-09-24 19:40 - Seen on device: voice download state in Settings, tasmee listen-disabled + ayah-change cancel
- 2026-09-24 19:31 - 3.62.0 signed build done (download-state fix in); owner 19:30: finish whole-app conflict audit first - remaining pairs logged; emulator starting
- 2026-09-24 19:26 - Download state audit done: only tasmee + voice held widget state (fixed); 570 tests pass; building 3.62.0 for device verification
- 2026-09-24 19:24 - Download state app-wide (1/2): tasmee model and enhanced voice downloads owned by TasmeeEngine/OpenVoice, not widgets; panel, pack rows, voice settings and reader sheet show downloading %/installed; analyze clean, not on device
- 2026-09-24 18:50 - Session stopped by owner: TASK_FOLLOWUP next steps exact (download-state buttons, one build, verify, then release 3.62.0)
- 2026-09-24 18:49 - Queued: download buttons show downloading/done state app-wide
- 2026-09-24 18:49 - Conflict: deleting the recitation/surah being played now stops it first; audit notes
- 2026-09-24 18:45 - Conflict: tasmee recording vs listen (both ran at once, verified on device) - listen disabled while recording; ayah change mid-recording cancels it
- 2026-09-24 18:36 - Conflict audit: 4 pairs tested on device (auto-scroll, recitation sync, adhan, book reader); ui_find.py tool
- 2026-09-24 18:07 - Auto-scroll/page-turn conflict: dwell on pages that fit; _current from onPageChanged only (found on device with recitation)
- 2026-09-24 17:48 - 3.62.0: recitation/auto-scroll sync (note in own file, under ceiling), AudioExclusive (book reader vs recitation, tasmee silences all), 570 tests pass
- 2026-09-24 17:31 - PLAN 4a result recorded
- 2026-09-24 17:30 - PLAN 4a measured: base == tiny on accuracy (446/500 each), 3.2x slower, 1.9x size -> tiny stays; recitation/auto-scroll sync in code
- 2026-09-24 17:26 - Queued: sync continuous recitation with auto-scroll; ASR tiny-vs-base script added (running)
- 2026-09-24 17:02 - Location fix verified on fresh install (Dubai + times at once); 570 tests pass; post-3.61 fixes ready, release pending owner
- 2026-09-24 16:53 - Location stuck after first-run permission: reproduced + fix (invalidate prayer controller at onboarding end); building to verify
- 2026-09-24 16:48 - Hajj summary: pillars and obligations under separate headings; summary seen on emulator (Umrah + Hajj, ayah 2:198-199 from mushaf)
- 2026-09-24 16:43 - Prayer times re-verified LIVE vs AlAdhan: 2400 times, 20 methods x 5 cities (Dubai added) x 2 dates x 2 schools, worst 2 min
- 2026-09-24 16:36 - Umrah/Hajj summary card (verbatim excerpts, ayah from mushaf, 7 locales); 570 tests pass; building
- 2026-09-24 16:33 - checkpoint.ps1 warns about untracked source files; trap 55
- 2026-09-24 16:32 - Add measurement scripts and hajj summary files to git
- 2026-09-24 16:32 - Scroll stall root-caused from owner video (7 same-direction stalls while scrolling up); emulator numbers corrected; measurement scripts kept
- 2026-09-24 16:28 - Hajj/Umrah summary data + verbatim test (2/2 pass); trap 54 (flutter test during a build breaks it)
- 2026-09-24 16:24 - Hifz scroll stall: page built once (SingleChildScrollView) instead of lazy ListView; before = 2 stalls 911/1019 ms (emulator), owner video 7 x ~200 ms; after-measurement pending
- 2026-09-24 16:20 - Scroll-stall evidence + candidate logged; waiting for owner's second video
- 2026-09-24 16:16 - Correction logged: hifz bug is a scroll stall, not ayah flip; measuring
- 2026-09-24 16:10 - v3.61.0 released and verified (tag == HEAD); next: Umrah/Hajj summaries
- 2026-09-24 16:08 - 3.61.0 final build verified (tutorial card teal under Tools); releasing
- 2026-09-24 16:04 - 3.61.0 verified on emulator (onboarding rows, jump fix, More colours, Hifz arc); tutorial card follows group colour
- 2026-09-24 15:56 - Owner order logged: Umrah/Hajj quick summaries after the release
- 2026-09-24 15:53 - TASK_FOLLOWUP next steps rewritten (build running)
- 2026-09-24 15:53 - TASK_FOLLOWUP next steps rewritten (build running)
- 2026-09-24 15:52 - Bump 3.61.0; release build started
- 2026-09-24 15:51 - Hifz: vertical thumb arc no longer flips the ayah (reproduced 255->256 on emulator; fix: 3x slop + clearly-sideways path check); jump button/sheet removed; More main-card colours alternate
- 2026-09-24 15:39 - Stage 1 rows: ayah reciter (host probe, smallest recommended), whole recitation, tasmee, voice, measured total; 7 locales; analyze clean, not yet on device
- 2026-09-24 15:36 - Stage 1: shared OfflinePackRow + R2-measured mushaf/whole-recitation sizes; owner's queued orders logged
- 2026-09-24 15:17 - C1 proven served from R2 via logging proxy; new rules 1.7b (certainty) and no-lazy-shortcuts; trap 53
- 2026-09-24 14:50 - Stage 1 item 3: per-ayah reciter sizes measured (35 reciters, everyayah listings) and bundled as a catalogue
- 2026-09-24 14:46 - Stage 1 item 1: title/blurb in 7 locales; C1 backgrounds seen on emulator (adhkar + new-Muslim render)
- 2026-09-24 14:38 - Stage 1 item 2: ContentPackTile fixed-width trailing slot + tabular digits + cancel (unverified)
- 2026-09-24 14:09 - checkpoint.ps1 regex rebuilt with chr(92) (trap 11); log line verified
- 2026-09-24 ~15:30 — Working rules settled (d56ee71f); TRAPS.md split out;
  AGENTS.md made a pointer to CLAUDE.md; this file created. v3.60.0 is the
  latest release; master has D1/B1/B5/C1 unreleased.
