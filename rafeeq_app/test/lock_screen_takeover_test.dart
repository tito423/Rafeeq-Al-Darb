import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Only the adhan may draw over the lock screen.
///
/// «التطبيق ساعات بيفتح بعد اللوك اسكرين» and «الأذان التجربة بيفتح على شاشة
/// الإعدادات بتاعة الأذان مش أذان الفيديو لو عملت لوك للفون» turned out to be
/// the same defect: `MainActivity` carried `showWhenLocked` and `turnScreenOn`
/// — in the manifest and again in code — on the mistaken reasoning that the
/// adhan alert arrives there. It does not; `AdhanActivity` is the alert, in
/// its own task.
///
/// What those flags actually did was let **any** launch of the app draw over
/// the keyguard: a quote reminder, a surah reminder, a finished download. That
/// is a privacy problem, not only a surprise — the phone is locked and the app
/// is open on it.
///
/// This fails the build if either flag comes back to MainActivity, and if the
/// adhan ever stops being able to take the lock screen itself.
void main() {
  final manifest =
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
  final mainActivity = File(
    'android/app/src/main/kotlin/com/tito/rafeeq_aldarb/MainActivity.kt',
  ).readAsStringSync();
  final adhanActivity = File(
    'android/app/src/main/kotlin/com/tito/rafeeq_aldarb/adhan/AdhanActivity.kt',
  ).readAsStringSync();

  /// The `<activity>` block for a given android:name.
  String activityBlock(String name) {
    final start = manifest.indexOf('android:name=".$name"');
    expect(start, greaterThan(0), reason: '$name is not in the manifest');
    final open = manifest.lastIndexOf('<activity', start);
    final end = manifest.indexOf('</activity>', start);
    return manifest.substring(open, end < 0 ? manifest.length : end);
  }

  test('MainActivity does not declare a lock-screen takeover', () {
    final block = activityBlock('MainActivity');
    expect(block.contains('showWhenLocked'), isFalse,
        reason: 'every notification tap would open the app on a locked phone');
    expect(block.contains('turnScreenOn'), isFalse);
  });

  test('MainActivity does not ask for one in code either', () {
    // It was set in both places, so checking one would have missed it.
    expect(mainActivity.contains('setShowWhenLocked'), isFalse);
    expect(mainActivity.contains('setTurnScreenOn'), isFalse);
    expect(mainActivity.contains('FLAG_SHOW_WHEN_LOCKED'), isFalse);
  });

  test('the adhan alert still takes the lock screen — that is its job', () {
    final block = activityBlock('adhan.AdhanActivity');
    expect(block.contains('android:showWhenLocked="true"'), isTrue);
    expect(block.contains('android:turnScreenOn="true"'), isTrue);
    expect(adhanActivity.contains('setShowWhenLocked(true)'), isTrue);
    expect(adhanActivity.contains('setTurnScreenOn(true)'), isTrue);
  });

  test('every adhan route opens the adhan screen, not the app', () {
    final notifications = File(
      'android/app/src/main/kotlin/com/tito/rafeeq_aldarb/adhan/'
      'AdhanNotifications.kt',
    ).readAsStringSync();
    final scheduler = File(
      'android/app/src/main/kotlin/com/tito/rafeeq_aldarb/adhan/'
      'AdhanScheduler.kt',
    ).readAsStringSync();
    // Not in a comment — the real thing.
    bool usesMainActivity(String src) => src
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('*'))
        .where((l) => !l.trimLeft().startsWith('//'))
        .any((l) => l.contains('MainActivity'));

    expect(usesMainActivity(notifications), isFalse,
        reason: 'tapping a sounding adhan must reach Stop and Mute, not the '
            'screen the app happened to be left on');
    expect(usesMainActivity(scheduler), isFalse,
        reason: "setAlarmClock's show-intent is the alarm's own UI");
  });
}
