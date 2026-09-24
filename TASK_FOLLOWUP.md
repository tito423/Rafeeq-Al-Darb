# TASK_FOLLOWUP — the live step log (read right after CLAUDE.md)

Updated after EVERY step, committed and pushed, so a session that dies mid-task
(quota, a dropped remote connection) loses nothing: the next session — this
account, the other one, or another agent — reads this and continues from
**Next step**. Newest entries at the top of the log. Log times are the PC clock, which IS Dubai time (checked against the owner: 14:23 real, 2026-09-24).

## Current task
HANDOVER 2026-09-24 ~22:00 (owner: «جهّز الدنيا», moving to the other
account). v3.62.0 released (tag 1f758e40). master is AHEAD with 8 audit-part-2
fixes: in code, analyze clean, 577 pass, NOT BUILT, NOT ON A DEVICE (one is
Kotlin and never compiled). Details + how to check each: NEXT_SESSION_PROMPT.md.

## Next step (exact)
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
