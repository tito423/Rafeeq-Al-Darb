# ARCHITECTURE — Rafiq Al-Darb (رفيق الدرب)

**Written 2026-09-03, P2‑10.** A map of how the codebase is put together —
written for the owner, who is learning to program and will study this
codebase. It describes what's actually here, not an aspiration.

---

## 1. The two top-level layers

```
lib/
  core/       — things nothing in the app is specific to: database access,
                native services, app-wide config, theming, small utilities.
                A `core/` file never imports from `features/`.
  features/   — one folder per user-facing area (quran, azkar, adhan, khatma,
                sunan_suwar, library, home, settings, downloads, search,
                new_muslim). Each one owns its own `data/` (models +
                Riverpod providers/state) and `presentation/`
                (screens + widgets). A feature *can* import `core/` and,
                sparingly, another feature's public data providers — see §4.
  app/        — the two pieces that tie every feature into one running app:
                `rafeeq_app.dart` (the `MaterialApp`, theme/locale wiring)
                and `shell/app_shell.dart` (the bottom-nav `IndexedStack`
                that keeps Home/Quran/Azkar/Library/Settings all alive at
                once — see §5 for why that specific choice matters).
```

This is a fairly standard "feature-first" Flutter layout. The rule that
actually matters day to day: **if you're not sure where a new file goes,
ask "does this concept exist without the rest of the app?"** — a database
row model or a native notification wrapper is `core/`; a screen, its
Riverpod state, and the translation keys it uses are one `features/x/`
folder.

---

## 2. State management: Riverpod, three shapes

The whole app uses `flutter_riverpod`, in three recurring shapes — knowing
which one you're looking at tells you how it behaves:

- **`FutureProvider`** — a one-shot async read, cached until something
  invalidates it. Used for anything that opens a database or the file
  system once and then just gets watched: `quranRepositoryProvider`,
  `sciencesRepositoryProvider`, `mushafDataProvider`.
- **`StateNotifierProvider`** — mutable app state with real methods on it
  (`create()`, `readToday()`, `setReminder()`…), always backed by
  `SharedPreferences` for persistence. This is the shape for anything the
  user can *change*: `KhatmaStore`, `SunanSuwarStore`, `AdhanSettingsNotifier`,
  `ThemeController`. The pattern is consistent everywhere: constructor takes
  `SharedPreferences` (via `ref.watch(sharedPrefsProvider)`, overridden once
  in `main.dart` with the real instance), restores state synchronously in
  the constructor, every mutating method updates `state` *and* awaits a
  `_persist()` write.
- **Plain `Provider`** — a pure derivation of something else, no state of
  its own: `activeKhatmasProvider` (filters+sorts `khatmaStoreProvider`'s
  list), `downloads_controller.dart`'s `storageSummaryProvider` (aggregates
  three separate download engines into one read-only view).

**One deliberate cross-feature seam worth knowing about:**
`quran_jump_provider.dart` is a bare `StateProvider<int?>` that
`HomeScreen`'s khatma/sunan-suwar cards write to and `QuranScreen` consumes
via `ref.listen` — needed because `AppShell`'s `IndexedStack` keeps Home and
Quran mounted as siblings with no push/pop relationship, so there's no
`Navigator.pop(page)` to ride on the way `SearchScreen` does. If you ever
need another screen to say "open the reader at page X," this is the
provider to reuse, not a new one.

---

## 3. Data: three different sources, on purpose

| Kind | Example | Where it lives on-device | Why this shape |
|---|---|---|---|
| **Bundled, read-only** | `quran_local.db`, `quran_sciences.db` | Shipped inside the APK (`assets/data/`), copied to app storage once via `DbHelper.openBundled` (a "stamp" file busts the cache when the asset changes — bump the stamp constant whenever you touch the DB's schema or content) | Needed offline from first launch, small enough (≈30 MB combined) to ship in the install |
| **Downloaded on demand** | mushaf page SVGs, `hadith.zip`, book PDFs/texts, adhan video clips, per-ayah recitation | App-support directory, fetched via `DownloadManager` (generic files) or a dedicated service (`MushafPageService`, `AyahAudioService` — both needed their own resumable/paginated logic, a generic downloader wasn't enough) | Too large to bundle, or genuinely optional (most users won't download every reciter or every book) |
| **User-authored, local-only** | khatma progress, sunan-suwar reminders, ayah notes, bookmarks, theme/locale choice | `SharedPreferences`, JSON-encoded for anything structured (a list of khatmas, a map of notes) | No accounts exist (§4 below) — nothing to sync to, so this is the whole story, not a cache in front of a server |

**Read `core/db/` before touching the database layer.** `db_helper.dart` is
the one place that knows how to open a bundled DB read-only correctly
(`openReadOnlyDatabase`, not `openDatabase(readOnly: true)` — the latter
crashes because it tries to write `PRAGMA user_version`, a real bug this
project hit once, see `HANDOVER.md` §7). `quran_repository.dart`/
`hadith_repository.dart`/`sciences_repository.dart` are the only files that
write raw SQL — every screen goes through one of them, never `sqflite`
directly.

---

## 4. No accounts, on purpose (for now)

Grep `lib/` for `signIn`/`FirebaseAuth`/`google_sign_in` and you'll find
nothing — this is deliberate, not unfinished. Every feature in the app
today is either bundled or downloaded content, or purely local state, so
there has never been a reason to identify a user across devices. The one
Firebase project that exists (`rafeeq-aldarb`, see `HOSTING.md` §4) is
provisioned but has zero SDK code talking to it — it's there for the day a
real cross-device feature (the leading candidate: a shared/group khatma,
researched in `PHASE2_RESEARCH.md` but not approved to build) actually
needs it. Don't add `firebase_core` speculatively; it's real install-size
weight for a feature nothing uses yet.

---

## 5. Why `AppShell` uses `IndexedStack`, not named routes

The 5 bottom-nav tabs (Home/Quran/Azkar/Library/Settings) are built once
into a `List<Widget>` and shown via `IndexedStack(index: _index, ...)` —
every tab's widget tree, and therefore its Riverpod state and scroll
position, stays alive the whole time the app runs, switching tabs is
purely a paint-time decision, not a rebuild. This is why:
- the Quran reader remembers its page/font/zoom when you switch away and
  back without any extra persistence code for that specific case;
- cross-tab navigation (§2's `quran_jump_provider.dart`) needs its own
  small seam instead of a normal push — there's no route stack between
  siblings in an `IndexedStack`.

Screens reached by drilling in from a tab (library book reader, ayah
sciences sheet, khatma/sunan-suwar detail, settings sub-screens) use normal
`Navigator.push`/`MaterialPageRoute` — only the 5 root tabs are the
`IndexedStack`.

---

## 6. Native notifications: one `FlutterLocalNotificationsPlugin` instance
## per feature, each with its own channel

There are five independent notification services, each a very similar
shape (`_ensureChannel()` + `zonedSchedule`/`show` + `cancel`):
`AdhanAlarmService`, `AzkarReminderService`, `KhatmaReminderService`,
`SunanSuwarReminderService`, and `DownloadManager`'s
`DownloadNotifications` — plus `PrayerStatusNotification` for the ongoing
status card. This is deliberate repetition rather than one shared class,
because each has genuinely different requirements: Adhan needs
`fullScreenIntent` + a native alarm sound + Stop/Mute actions; azkar/khatma/
sunan-suwar are plain reminders; downloads need a live progress bar;
prayer-status needs `ongoing: true` + a native chronometer. If you're
adding a 6th kind of notification, copy whichever of these is closest in
shape rather than trying to generalize — that's the pattern this codebase
has settled on.

**Why the Adhan sound itself is native, not Dart:** a `zonedSchedule`
alarm fires through a plain Android `BroadcastReceiver` that does **not**
start the Dart VM when the app is killed — so only Android's own
notification-sound API can possibly play anything at that moment. This is
why `AdhanAlarmService` hands Android a `RawResourceAndroidNotificationSound`
instead of using `just_audio`, and why Stop/Mute act on the notification
itself rather than a Dart audio player.

---

## 7. Localization: 5 locales, one parity test

`assets/translations/{ar,en,es,ru,pt}.json`, loaded by `easy_localization`.
`test/translation_parity_test.dart` asserts all 5 files have the exact same
key set and no empty values — this is a real CI-style guard, not a
suggestion: **run `flutter test` before considering any UI change done.**
Two categories of Arabic text are deliberately *not* run through the
translation system, and shouldn't be: `adhan_text.dart` (the literal adhan
wording) and `guide_content.dart` (hand-written fiqh content) — these are
religious content, not UI chrome, translating them would need a real
scholarly review this project hasn't done (flagged honestly in
`HANDOVER.md` §5.7-adjacent notes rather than auto-translated).

---

## 8. Where to look for real, working examples of each pattern

| Want to build… | Copy the shape of… |
|---|---|
| A new bundled-DB-backed screen | `sciences_repository.dart` + `ayah_sciences_sheet.dart` |
| A new downloadable content type | `AyahAudioService` (per-item, resumable) or `DownloadManager` (generic files) |
| A new persisted user-state feature | `khatma_store.dart` (`StateNotifier` + `SharedPreferences` JSON) |
| A new weekly/daily local reminder | `sunan_suwar_reminder_service.dart` / `azkar_reminder_service.dart` |
| A new Home card | `khatma_card.dart` (self-contained `ConsumerWidget`, reads its own providers) |
| A locked/restricted reader variant | `single_surah_screen.dart` (composes the same `MushafTextPage`/`MushafPageView` the main reader uses, bounded) |
| A new theme | `theme_controller.dart`'s `ThemeVariant` enum + one `AppTheme.xxx()` — see the doc comment there, it's a one-enum-case addition by design |

---

## 9. Known debt, honestly

- **Release signing** uses the debug keystore — real signing needs the
  owner's own keystore, alias, and passwords (P2‑10's own owner-blocker,
  `android/app/build.gradle.kts` still has the `// TODO`).
- **Mushaf pages are pinned to GitHub raw**, not a real CDN — fine for this
  project's own testing traffic, not for real users (`HOSTING.md` §3 has
  the migration plan).
- **No physical-device pass yet** — everything in this document has only
  been verified on `emulator-5554`, never a real phone (flagged repeatedly
  in `HANDOVER.md`, still true as of this writing).
