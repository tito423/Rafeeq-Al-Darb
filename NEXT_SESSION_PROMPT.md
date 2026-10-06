> **2026-10-07:** the current brief is `NEXT_PROMPT.md` + the top of `TASK_FOLLOWUP.md` (own i'rab 1 + 66-114 by hand, next al-Talaq 65; adhkar 138/302; quiz +231 not started); what follows below is older context.

# Next session — Rafiq Al-Darb (written 2026-10-02 ~01:30 Dubai)

Read CLAUDE.md (mandatory), then the top entries of TASK_FOLLOWUP.md (they hold the exact detail, commands and file paths), then TRAPS.md for the area you touch (24, 31, 43, 44, 55, 56, 57 matter here). Reply to the owner in Egyptian Arabic; app strings stay MSA.

## Where things are
- **Published: v3.74.0** (tag 7e2637d7). Releases on GitHub: v3.74.0, v3.51.0 (restore point), content-* prereleases - nothing else.
- **master is past v3.74.0** with R1-R3 below, not released. Release only when the owner asks; he wants everything in the list fixed together first. He is testing v3.74.0 on his Honor and will send more items - append them to the R-list in TASK_FOLLOWUP.md.
- At handover: analyze clean, 695 tests pass, hosted content 7/7 206.

## The next-release list (in this order)
1. **R6 + R5 first - reproduce on emulator-5554 before changing anything.** Owner saw TWO app entries in Recents, both on the Quran tab; and reopening from the background / the recitation notification lands on the mushaf in full screen with no app bar and no bottom nav, Back leaves the app. MainActivity is singleTask with taskAffinity="". Steps: play a recitation -> Home key -> tap the notification; then the same after `adb shell am kill com.tito.rafeeq_aldarb`; check `adb shell dumpsys activity recents`. Fix so there is one task, Back from the mushaf always reaches the shell (Home tab with the nav bar), and full screen has a visible way back to the nav. His video: uploads/7892e937-SVID_20261002_004100_1.mp4 (frames already read: Quran full screen -> Back -> launcher).
2. **R1, R2, R3 on the emulator** (code done, tests pass, never seen): «شغل الآية بصوت الشيخ محمد المنشاوي» with a recitation playing and with none; play one adhkar recording from the listen screen (now from R2 azkar/recitations/); the size line under ayah reciters («التلاوة كاملة: …») and beside each moshaf in the full-surah list. Also check whether the 5 moshafs with unsized surahs (listed in commit b9819891) actually play those surahs.
3. **R7 - wait for the owner's choice**, then build it: own copies of the recitations (ayah 57.7 GB, full 409.9 GB). Options given to him: (1) all free on GitHub Releases, (2) ayah on R2 (~$0.72/month) + full on GitHub, (3) all on R2 (~$6/month). mp3quran now 301s every serverN folder to cdn.mp3quran.net (files still 206, no listings).
4. **R4 - kids stories, after 11:00 Dubai (quota reset):** voice jannatayn, dawud, dhabih, khidr (moods ready in E:/DevEnv/kids_voice/<id>/moods.json, plan in E:/DevEnv/kids_voice/new/plan.tsv); re-voice isa 15 and dhulqarnayn 8 (gemini-3.8-flash-tts, their stories' model) and salih 3+4 (gemini-3.8-flash-lite-tts). AI Studio UI: one new tab per run (Chrome allows one download per tab); helper and queue in the page's localStorage (__h, __q, __i, __step). Then the per-story pipeline in TASK_FOLLOWUP.md (rec.wav, mix_story.py, words_json.py, render, sheet, entries x7 + assistant + STORIES, --upload, mirror, emulator). One model per story; word audit (new/word_audit.py) before anything ships.
5. When the list is done and the owner asks: release (build_github_release.bat, bump version + AboutScreen, delete the previous release except v3.51.0 and content-*, tag = HEAD, give him both links).

## Not verified on a real phone
Live tasmee, Bluetooth headset tasmee, Rafeeq with the app closed (Honor/Xiaomi), the kids story videos (emulator decoder shows blocky patches; files clean in ffmpeg).
