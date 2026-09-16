# Google Play — Data safety form, answer by answer

This is what to tick in **Play Console → App content → Data safety** for
`com.tito.rafeeq_aldarb`, with the evidence for each answer. Every claim here
was read off the code, not remembered:

* no analytics or crash-reporting library is in `pubspec.yaml` (`grep -i
  "firebase\|analytics\|crashlytics"` over `lib/` and `pubspec.yaml` returns
  nothing),
* the only first-party endpoint is `AppConfig.syncBackendUrl`
  (`rafeeq-sync-backend.int-vip00.workers.dev`), called from
  `lib/core/services/sync_service.dart` and nowhere else,
* location is read by `lib/core/services/location_service.dart` and consumed
  by `PrayerTimesService`, which computes the times on-device with the `adhan`
  package,
* content downloads go to R2, `cdn.islamic.network` and `everyayah.com`
  (`lib/core/config/app_config.dart`).

Privacy policy URL to paste into the form:
`https://pub-39dbef68a1a845d5ba669b43a59516b9.r2.dev/legal/privacy.html`

---

## Section 1 — Data collection and security

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **Yes** — but only when the user signs in for sync. |
| Is all of the user data collected by your app encrypted in transit? | **Yes** — every endpoint is HTTPS. |
| Do you provide a way for users to request that their data is deleted? | **Yes** — via the GitHub issues link in the privacy policy. |

> If you would rather not run a sync service at all, remove Google Sign-In and
> every answer below collapses to "No data collected". That is a real option:
> sync is the only reason any of this exists.

## Section 2 — Data types

### Personal info → Email address
* Collected: **Yes**. Shared: **No**.
* Processed ephemerally: **No** (it identifies the account on the server).
* Required or optional: **Optional** — the user chooses to sign in.
* Purpose: **App functionality**, **Account management**.

### Personal info → Name
* Same answers as the email address: Google's ID token carries the display
  name alongside it.

### App activity → Other user-generated content
* Collected: **Yes**. Shared: **No**. Optional.
* Purpose: **App functionality** — bookmarks, reading positions, tasbeeh
  counters and khatma/lesson progress, so they follow the reader to another
  device.

### Location (approximate or precise)
* Collected: **No**. Shared: **No**.
* Why this is the honest answer: Play defines "collected" as *transmitted off
  the device*. The coordinate never leaves the phone — prayer times are
  computed locally and the city name comes from Android's own geocoder.
  The app **requests** the location permission, which is declared separately
  in the manifest and is not a data-collection answer.

### Everything else
**Not collected**: financial info, health, messages, photos/videos, audio,
files, contacts, calendar, phone number, search history, installed apps,
device or advertising IDs, crash logs, diagnostics, in-app performance.

## Section 3 — Permissions Play will ask about separately

| Permission | Why the app declares it |
|---|---|
| `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION` | prayer times and qibla, computed on-device |
| `POST_NOTIFICATIONS` | the adhan, reminders and the next-prayer card |
| `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` | the adhan must fire at its minute, not when Doze allows |
| `USE_FULL_SCREEN_INTENT` | the full-screen adhan alert |
| `FOREGROUND_SERVICE` (+ media playback, data sync, special use) | recitation playback and content downloads that survive the screen going off |
| `RECEIVE_BOOT_COMPLETED` | re-arm the prayer alarms after a restart |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | asked once, so the adhan is not deferred |
| `SYSTEM_ALERT_WINDOW`, `TURN_SCREEN_ON`, `DISABLE_KEYGUARD` | the adhan alert over the lock screen |
| `READ_MEDIA_AUDIO` | so the reader can pick their own adhan audio file |
| `INTERNET`, `WAKE_LOCK`, `VIBRATE` | downloads, playback, vibration |

**`USE_EXACT_ALARM` needs a declaration of its own.** Play treats it as a
restricted permission: an app may keep it only if its core function is an
alarm or a calendar. A prayer-times app qualifies, but you will be asked to
say so in the form — and `SCHEDULE_EXACT_ALARM` (which the user grants) is the
safer pair to lean on if the review pushes back.

## Section 4 — Other declarations Play will want

* **Ads**: none.
* **Target audience**: general; the app collects nothing from children.
* **Content rating questionnaire**: religious/reference content, no violence,
  no user-to-user communication.
* **Financial features**: none.
* **Account deletion**: Play requires a web URL where an account can be
  deleted if the app supports account creation. Signing in with Google is not
  account *creation* in Play's sense, but the deletion route in the privacy
  policy covers the requirement; point the field at the policy URL.
