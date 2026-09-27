# ARCHITECTURE — Rafiq Al-Darb (رفيق الدرب)

**Written 2026-09-03, P2‑10; refreshed by the 2026-09-27 audit.** A map of
how the codebase is put together. It describes what's actually here, not an
aspiration. Measured 2026-09-27: 417 Dart files / 95,823 lines in `lib/`,
31 feature folders, 7 locales, 157 test files (636 tests), `flutter analyze`
at zero with the stricter lint set in `analysis_options.yaml`.

**Guards that enforce this document** (they fail `flutter test`, and CI runs
them on every push, `.github/workflows/ci.yml`):
`test/layering_test.dart` (§1's import rule), `test/code_layout_test.dart`
(no file in `lib/` past 800 lines; older long files are listed and may only
shrink), `test/translation_parity_test.dart` (§7).

---

## 1. The two top-level layers

```
lib/
  core/       — things nothing in the app is specific to: database access,
                native services, app-wide config, theming, small utilities.
                A `core/` file never imports from `features/`.
  features/   — one folder per user-facing area (31 of them: quran,
                quran_audio, adhan, azkar, library, hifz, hajj, assistant,
                shamela, …). Each one owns its own `data/` (models +
                Riverpod providers/state) and `presentation/`
                (screens + widgets). A feature *can* import `core/` and,
                sparingly, another feature's public data providers — see §4.
  app/        — the two pieces that tie every feature into one running app:
                `rafeeq_app.dart` (the `MaterialApp`, theme/locale wiring)
                and `shell/app_shell.dart` (the bottom-nav `IndexedStack`
                that keeps all seven tabs alive at once — see §5 for why
                that specific choice matters).
```

When `core/` needs something a feature owns, the feature registers it
through a hook in `core/` (dependency inversion) — e.g. `RecitationSource`
gets downloaded ayah files through a callback the `quran_audio` feature
installs at startup. It never imports the feature.

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
| **Bundled, read-only** | `quran_local.db`, `azkar.db`, `hadith.zip` (the owner asked for the hadith library built in), `cities.tsv.gz`, built-in books | Shipped inside the APK (`assets/data/`, listed in `pubspec.yaml`), copied to app storage once via `DbHelper.openBundled` (a "stamp" file busts the cache when the asset changes — bump the stamp constant, e.g. `AppConfig.hadithDbVersion`, whenever the DB changes) | Needed offline from first launch |
| **Downloaded on demand** | `quran_sciences.db` (tafsir, translations, i'rab — left the APK in 3.45.0), mushaf page images, book texts, recitations, «رفيق»'s voice pack | Hosted on R2 (`AppConfig.contentBaseUrl`), falling back to the GitHub `content-*` releases through `ContentMirrors`; stored in the app-support directory, fetched via `DownloadManager` (generic files) or a dedicated service (`MushafPageService`, `AyahAudioService` — both needed their own resumable/paginated logic, a generic downloader wasn't enough) | Too large to bundle, or genuinely optional (most users won't download every reciter or every book) |
| **User-authored, local-only** | khatma progress, sunan-suwar reminders, ayah notes, bookmarks, theme/locale choice | `SharedPreferences`, JSON-encoded for anything structured (a list of khatmas, a map of notes) | Local first; a signed-in user's chosen keys are also synced (§4) |

**Read `core/db/` before touching the database layer.** `db_helper.dart` is
the one place that knows how to open a bundled DB read-only correctly
(`openReadOnlyDatabase`, not `openDatabase(readOnly: true)` — the latter
crashes because it tries to write `PRAGMA user_version`, a real bug this
project hit once, see `HANDOVER.md` §7). `quran_repository.dart`/
`hadith_repository.dart`/`sciences_repository.dart` are the only files that
write raw SQL — every screen goes through one of them, never `sqflite`
directly.

---

## 4. Optional Google sign-in, for sync only

Nothing needs an account. Signing in with Google (`google_sign_in`, from
«المزيد») only turns on sync: `core/services/sync_service.dart` pushes the
keys listed in `syncedStateKeys` and the counters in `syncedCounterKeys` to
a Cloudflare Worker (`sync_backend/`, `AppConfig.syncBackendUrl`, D1
storage), which checks the Google token (`iss`, `aud`, `exp`) and stores
rows only under that token's `sub`. The pull filters by the same key list,
so a setting an older build synced is never restored. Signing out clears
only the synced keys and the queue, not the rest of the user's data
(audit 2026-09-24, D1). No Firebase SDK is in the app.

---

## 5. Why `AppShell` uses `IndexedStack`, not named routes

The 7 bottom-nav tabs (Home, Quran, Prayer, Azkar, Tasbih, Library, More)
are built once
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
`Navigator.push`/`MaterialPageRoute` — only the 7 root tabs are the
`IndexedStack`.

---

## 6. Native notifications: one `FlutterLocalNotificationsPlugin` instance
## per feature, each with its own channel

Ten files create a `FlutterLocalNotificationsPlugin` (counted 2026-09-27),
each a very similar shape (`_ensureChannel()` + `zonedSchedule`/`show` +
`cancel`): the prayer, azkar, khatma, sunan-suwar, fasting, quote and
tasbih reminders, `DownloadNotifications`, `PrayerStatusNotification` for
the ongoing status card, and `NotificationRouter` — the ONE tap handler for
every notification in the app (TRAPS.md #31). The adhan itself is a native
alarm scheduled by `features/adhan/data/adhan_scheduler.dart`. This is deliberate repetition rather than one shared class,
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
why the adhan hands Android a `RawResourceAndroidNotificationSound`
instead of using `just_audio`, and why Stop/Mute act on the notification
itself rather than a Dart audio player.

---

## 7. Localization: 7 locales, one parity test

`assets/translations/{ar,en,es,fr,pt,ru,ur}.json`, loaded by `easy_localization`.
`test/translation_parity_test.dart` asserts all 7 files have the exact same
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

Measured by the 2026-09-27 audit (`docs/audits/AUDIT_2026-09-27.md`):

- **Long files.** `test/code_layout_test.dart` lists the files that were
  already past 800 lines when the ceiling came in (the largest:
  `book_text_reader_screen.dart` 1,156, `quran_screen.dart` 1,057). They may only shrink.
- **Content on `r2.dev`.** Cloudflare's public development URL is
  rate-limited and uncached; a custom domain is the fix, deferred by the
  owner. The GitHub `content-*` releases are the fallback meanwhile.
- **Release signing happens outside Gradle** (`scripts/sign_release.py`,
  TRAPS.md #41), so Gradle's own output still says "debug". Always build
  with `build_github_release.bat`.
- **Held-back packages** are recorded with their reason (e.g.
  `permission_handler` stays on 12.x, TRAPS.md #52).
