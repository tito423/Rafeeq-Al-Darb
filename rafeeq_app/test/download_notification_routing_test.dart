import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Tapping a download notification has to land on the screen that owns that
/// download — and registering the callback that makes it do so must not cost
/// the app its progress updates.
///
/// THE TRAP THIS GUARDS, READ IN THE PACKAGE'S OWN SOURCE.
/// `FileDownloader.registerCallbacks` takes three callbacks, and its doc
/// comment warns: "Tasks belonging to a group that has registered callbacks
/// will **not** emit updates to the [updates] stream." `DownloadEngine` and
/// `DownloadManager` both live on that stream — every progress bar, every
/// completion registry, every "downloaded" badge in the app. Registering a
/// status or progress callback for one of these three groups would take all of
/// that out silently: no analyzer error, no failing test, and a download that
/// looks stuck for ever. That is trap #27's shape exactly.
///
/// What the source actually does (background_downloader 9.5.9,
/// `base_downloader.dart`): `_emitStatusUpdate` consults
/// `groupStatusCallbacks`, `_emitProgressUpdate` consults
/// `groupProgressCallbacks`, and `groupNotificationTapCallbacks` is read in
/// `processNotificationTap` and nowhere else. So the tap callback alone is
/// safe — and this test holds the code to "tap callback alone".
void main() {
  final engine = File('lib/core/services/download_engine.dart')
      .readAsStringSync();

  test('the three download groups register a tap callback', () {
    for (final what in const ['files', 'recitations', 'ruqyah']) {
      expect(engine.contains("routeTap('$what')"), isTrue,
          reason: 'the $what download notification would go nowhere');
    }
    expect(engine.contains('taskNotificationTapCallback:'), isTrue);
  });

  test('and never a status or progress callback, which would kill the stream',
      () {
    expect(engine.contains('taskStatusCallback:'), isFalse,
        reason: 'this diverts the updates stream DownloadManager listens to');
    expect(engine.contains('taskProgressCallback:'), isFalse,
        reason: 'this diverts the updates stream DownloadManager listens to');
    // The listener that would go dead, still there.
    expect(engine.contains('downloader.updates.listen'), isTrue);
  });

  test('the router knows the download prefix and main wires it', () {
    final router = File('lib/core/services/notification_router.dart')
        .readAsStringSync();
    expect(router.contains("downloadPrefix = 'dl:'"), isTrue);
    expect(router.contains('onDownload?.call'), isTrue);

    final main = File('lib/main.dart').readAsStringSync();
    expect(main.contains('NotificationRouter.onDownload ='), isTrue,
        reason: 'an unwired callback drops every download tap, exactly like '
            'the empty handler NotificationRouter was written for');
  });

  test('every payload the app sends has a destination', () {
    final nav = File('lib/features/downloads/presentation/'
            'download_navigation.dart')
        .readAsStringSync();
    // The senders: the three groups above plus the mushaf page service.
    for (final what in const ['recitations', 'ruqyah', 'mushaf', 'files']) {
      expect(nav.contains("'$what'"), isTrue,
          reason: 'a notification sends dl:$what and nothing handles it');
    }
    final mushaf = File('lib/core/services/mushaf_page_service.dart')
        .readAsStringSync();
    expect(mushaf.contains('downloadPrefix}mushaf'), isTrue);
  });

  test('the grouped notification is routed natively, because the plugin cannot',
      () {
    // MEASURED on emulator-5554: a real 90 MB ruqyah download, the app left
    // on Home, its notification tapped — and the app came forward on Home.
    // `singleTask`, which the plugin's docs ask for, changed nothing. The
    // plugin's own source says why: a GROUP notification's tap intent is
    // built with an empty task string (`addTapIntent(taskWorker, "", …)`) and
    // `BDPlugin.handleIntent` skips it (`if (taskJsonMapString.isNotEmpty())`).
    // This app groups all three download kinds on purpose, so none of them
    // could ever route through the callback.
    final activity = File(
      'android/app/src/main/kotlin/com/tito/rafeeq_aldarb/MainActivity.kt',
    ).readAsStringSync();
    expect(activity.contains('com.bbflight.background_downloader.tap'), isTrue,
        reason: 'nothing reads the tap intent');
    expect(activity.contains('override fun onNewIntent'), isTrue,
        reason: 'a tap while the app runs would be dropped');
    expect(activity.contains('takePending'), isTrue,
        reason: 'a tap that launches the app cold would be dropped');
    // The ids Kotlin matches on must be the ids Dart actually sets.
    final engine =
        File('lib/core/services/download_engine.dart').readAsStringSync();
    for (final groupId in const [
      'rafeeq_files_group',
      'rafeeq_quran_audio_group',
      'rafeeq_ruqyah_group',
    ]) {
      expect(engine.contains("'$groupId'"), isTrue,
          reason: 'Dart no longer uses $groupId');
      expect(activity.contains('"$groupId"'), isTrue,
          reason: 'Kotlin does not match $groupId — that queue stops routing '
              'and nothing fails until someone taps it');
    }

    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest.contains('android:launchMode="singleTask"'), isTrue);
  });
}
