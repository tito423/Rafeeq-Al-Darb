# background_downloader 9.5.9 — vendored with one patch

Upstream: https://pub.dev/packages/background_downloader (BSD-3, LICENSE kept).

The only change is in `android/.../Notifications.kt`, marked `RAFEEQ PATCH`:
each notification gets a FIXED `when` (the group's creation time, or the
task's first-seen time) and `setOnlyAlertOnce(true)`. Upstream builds every
update with `when = now`, so each progress tick re-sorted the notification
shade — the owner's «الإشعارات بتجري ورا بعضها وتتبدّل أماكنها» while many
files downloaded. To upgrade: copy the new version here and re-apply.
