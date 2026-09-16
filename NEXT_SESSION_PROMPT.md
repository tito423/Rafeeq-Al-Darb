# Rafiq Al-Darb — next session brief

**Last written:** 2026-09-16 at dawn, on a clean tree: `flutter analyze lib
test` clean, `flutter test` **243 passed**, every hosted path range-requested
and answering 206 (see `HANDOVER.md` → "Verified 2026-09-16 dawn").

**`v3.25.0` is the published release**, tag at `abd74b5`. **`master` is six
commits ahead of it and that work is not released** — it is verified and
installed on the owner's Honor, but the word to publish never came. That is
the first question to ask him.

**A rule was added to `CLAUDE.md` this session (§6, §7): the next-session
prompt is written ONLY when he says «جهّز الدنيا».** Not at the end of a
batch, not to round off a reply. Finish the work and report it.

**What the dawn session did, in one paragraph.** His batch: a new app icon
cropped from his own artwork with nothing else touched; his new splash clip,
cut at 7 s and **silenced** because its voice mispronounced «قرآني» and a
voice cannot be re-recorded here; the wordmark it used to burn in — whose
tashkeel was wrong on both words — now drawn by the app, correctly pointed,
inside the video's own coordinate space. Then the light theme, which he said
was unreadable «خاصة في قسم عن التطبيق»: the cause was one colour used in many
places, and it was measured rather than judged — gold as text is **2.10 : 1**
on white, and `goldOn(scheme)` takes it to 5.49 while keeping 9.87 on the
night themes. About's own dua turned out to be `Colors.white` on a panel that
follows the theme. Then his list: six settings sections and the library's
authors and hadith sections collapsed by default; the ruqyah's duplicated
headphones action removed, its theme fixed, and the tafsir card's own reciter
chip put beside the play button — wired to the queue, so choosing سعود الشريم
really does recite in his voice, which was watched happening on his phone.

**Two bugs in that work were found only by looking at a device**, and both are
worth remembering: a listener that never called `setState`, so the caption was
computed once at zero and never drawn; and AmiriQuran being a *Quranic* face,
which drew «قرآني» as «قرآنی» with its marks adrift.

`NEXT_PROMPT.md` is the paste-ready message; this file is the longer brief it
points at.

---

## How this project works now — read before planning

1. **`CLAUDE.md` is the contract.** Nothing is done until it has been seen on
   `emulator-5554`; nothing fake; religious content held to a higher standard.
2. **The owner tests every release on his own phone** and sends recordings and
   screenshots. Look at them properly: a recording becomes a contact sheet with
   ShareX's ffmpeg (`C:\Program Files\ShareX\ffmpeg.exe`,
   `-vf "fps=3,scale=240:-1,tile=6x5"`). The last flicker was diagnosed exactly
   that way.
3. **The owner sometimes hands work to a second agent** (Antigravity / Gemini).
   `AGENT_TASK_PROMPT.md` is the guarded brief for that. The last time, the
   other agent built real features but also: committed `node_modules`, left
   screenshots in the repo, rewrote 2,700 lines per locale file, published a
   release with a provider that crashed start-up, and wired a sign-in button
   that never published its result. **Treat anything it shipped as unverified
   until you have run it.**
4. **Quota.** He reads it as a number climbing to 100 (last reading: 97, on
   2026-09-13; the week may have reset since). Ask for it first. Releases are
   his call and cost him real budget — one per batch, when he says, and never
   left unpublished when the budget is closing.
5. **Replies in Egyptian Arabic; every string in the app in Modern Standard
   Arabic.**

---

## Open work, in order

### 1. Ask about the release (first job)

Six commits of verified, phone-tested work sit unreleased on `master`. He was
asked and had not answered. If he says yes: bump `pubspec.yaml` to `3.26.0+27`
and `AboutScreen.appVersion` to match (a test holds them equal), build, run
`scripts/sign_release.py` until it prints `OK: rotated`, delete `v3.25.0` and
its tag, publish `v3.26.0` from `master`, and check the tag's SHA equals
`HEAD`. Release notes in Arabic, and honest about the splash being silent and
why.

### 2. The Tuhfa download, on a real phone

The level-one screen works — ten lessons, the book's own vowelled headings,
الضباع's note under the matn in smaller type, «إتمام الدرس» moving the header
to «أنجزت ١ من ١٠» — **but that was seen with the book file placed on the
device by hand.** On `emulator-5554` nothing hosted can be downloaded at all;
see the addition to `CLAUDE.md` trap #13 for the certificate that proves why,
and for the `run-as` recipe if you need to do it again.

So: install v3.25.0 on the Honor, open المزيد ← تعليم التجويد ← المستوى الأول
with the network on, and watch it fetch `tuhfat_al_atfal`. If it shows «يلزم
تنزيل نصّ الدروس», `adb logcat | grep tuhfaBookProvider` prints the reason.
Then update the Xiaomi, which is two releases behind.

### 3. Sync — finish proving it (owner's current priority)

Built by the second agent, repaired by this session, **never seen working
between two devices**. What is known:

* Google for identity only (`email`/`profile` — non-sensitive, so no
  verification and no seven-day re-prompt); `AppConfig.googleServerClientId`
  is the Web client ID. Two Android OAuth clients exist (debug fingerprint
  `BE:6D:45:79:0B:95:BA:8F:5E:03:B2:4F:DA:30:03:EC:85:D0:8A:40`, release
  `1B:6B:6C:67:D2:5B:6E:93:8B:3E:F8:93:F4:D2:94:A2:87:5A:2D:B3`).
* Worker + D1 in `sync_backend/`, live at
  `https://rafeeq-sync-backend.int-vip00.workers.dev`, on the Cloudflare
  account **`Int.vip00@gmail.com's Account`** — not the owner's main email.
  `scripts/.env` has `CF_WORKERS_TOKEN` (Workers + D1, tested) and
  `CF_ACCOUNT_ID`. The older `CF_API_TOKEN` is R2-only.
* The Worker checks `iss`, `aud`, `exp` through `tokeninfo` and scopes every
  query by the verified `sub`. **Measured: no token → 401.**

To do, in order: ask the owner what the card did on his phone (it now shows
the error if sign-in fails); sign in on the emulator; set a counter and a
khatma position; clear app data or use a second AVD, sign in again, **see the
same numbers**; then the security checks nobody has run — a forged token must
get 401, and a valid token must never return another `sub`'s rows — and check
whether a re-sent counter batch double-counts (the owner's rule is SUM, so an
unguarded retry inflates tasbeeh). Also: the owner wanted sign-in offered once
at first launch with a working «تخطّي»; only the More card exists.

### 4. Per-ayah recitation downloads — verify from zero

Built by the second agent, **never run by anyone**. The owner's words about the
last attempt: «فشل فشل ذريع». Entry: Downloads → «تلاوات الآيات». Download a
whole surah, `adb shell cmd connectivity airplane-mode enable`, play it ayah by
ayah, look at the screen. Read trap #45 before touching download callbacks.

### 5. The two fixes in 3.24.1/3.24.2 that were not seen on a device

* The Quran-tab flicker (`_appliedUiMode` guard in `quran_screen.dart`). Measure
  it the way trap #43 says: `dumpsys window | grep statusBars`, and
  `dumpsys gfxinfo … reset` / act / read.
* The sign-in card now surfacing its result.

### 6. Still not proven

* The prayer-notification countdown jumping seconds — the rebase happens twice
  per prayer now, but the jump never reproduced on the emulator.

### 7. Waiting on the owner

* 11 clips under `adhan/video/` on R2 (~74 MB) — delete or keep.
* A working address for Mishkat.
* Whether to re-bundle only the first ~20 Hafs pages so the mushaf opens with
  no network (offered, unanswered).

---

## Traps met this stretch (worth adding to `CLAUDE.md` if they recur)

* **A provider whose default throws is a start-up crash waiting for a read.**
  `sharedPreferencesProvider` threw `UnimplementedError` and `main()` overrode a
  *different* provider; reads during start-up killed `runApp` before the first
  frame, and the native splash just stayed.
* **Re-applying `immersiveSticky` is not a no-op** — it resizes the window and
  can loop through `build`.
* **A crawled batch can re-fetch a book already shipped** (Shamela 592 was in the
  catalogue twice) and **inherit the seed book's author** (al-Albani's ten books
  claimed al-Bukhari). Check ids against the catalogue and read the card.
* **Bash command substitution eats backticks in `git commit -m`.** Write the
  message to a file and use `git commit -F`.
