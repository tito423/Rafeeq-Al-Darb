import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// One tap handler, one owner.
///
/// `FlutterLocalNotificationsPlugin` is a singleton and `initialize` installs
/// exactly one `onDidReceiveNotificationResponse` for the whole app. Five
/// services were each calling it, two of them with `(_) {}`, and the last one
/// to run won — which on a real device meant `PrayerStatusNotification`'s
/// empty handler (installed lazily from `AppShell`'s first frame, after
/// `main()`) swallowed every notification tap in the app. The quote card did
/// not open; neither had the سنن السور reminder, silently, for as long as
/// that code has existed.
///
/// A widget test cannot catch that — it needs the real plugin and a real tap.
/// What CAN be pinned is the invariant that produced it: only
/// `NotificationRouter` may call `initialize`.
void main() {
  test('NotificationRouter is the only caller of plugin initialize', () {
    final offenders = <String>[];
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      if (f.path.endsWith('notification_router.dart')) continue;
      final src = f.readAsStringSync();
      if (RegExp(r'\b\w*[Pp]lugin\.initialize\(').hasMatch(src)) {
        offenders.add(f.path);
      }
    }
    expect(offenders, isEmpty,
        reason: 'these call FlutterLocalNotificationsPlugin.initialize '
            'directly and will steal the app\'s only tap handler: '
            '${offenders.join(", ")}');
  });

  test('nothing installs a tap handler that throws the tap away', () {
    final offenders = <String>[];
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      // Comment lines are skipped: `notification_router.dart` and the two
      // services it replaced all QUOTE the old empty handler in their doc
      // comments, which is the point of those comments.
      final code = f
          .readAsLinesSync()
          .where((l) => !l.trimLeft().startsWith('//'))
          .join(' ')
          .replaceAll(RegExp(r'\s+'), ' ');
      if (code.contains('onDidReceiveNotificationResponse: (_) { }') ||
          code.contains('onDidReceiveNotificationResponse: (_) {}')) {
        offenders.add(f.path);
      }
    }
    expect(offenders, isEmpty,
        reason: 'an empty tap handler silently disables every notification '
            'tap in the app: ${offenders.join(", ")}');
  });
}
