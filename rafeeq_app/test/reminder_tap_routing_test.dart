import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/services/notification_router.dart';

/// A reminder about a screen opens that screen. The adhkar, khatma and
/// tasbih reminders were posted with no payload, so a tap only brought the
/// app forward on its Home tab (audit, 2026-09-24).
void main() {
  test('an open: payload reaches onOpen with the screen name', () {
    final got = <String>[];
    NotificationRouter.onOpen = got.add;
    NotificationRouter.route('${NotificationRouter.openPrefix}azkar_morning');
    NotificationRouter.route('${NotificationRouter.openPrefix}tasbih');
    expect(got, ['azkar_morning', 'tasbih']);
  });

  test('a surah number still goes to onSurah, not onOpen', () {
    final opened = <String>[];
    final surahs = <String>[];
    NotificationRouter.onOpen = opened.add;
    NotificationRouter.onSurah = surahs.add;
    NotificationRouter.route('18');
    expect(opened, isEmpty);
    expect(surahs, ['18']);
  });

  test('each screen reminder is armed with its open: payload', () {
    const expected = {
      'lib/core/services/azkar_reminder_service.dart': [
        "'azkar_morning'",
        "'azkar_evening'",
        "'azkar_sleep'",
        r"'${NotificationRouter.openPrefix}$screen'",
      ],
      'lib/core/services/khatma_reminder_service.dart': [
        r"'${NotificationRouter.openPrefix}khatma'",
      ],
      'lib/core/services/tasbih_reminder_service.dart': [
        r"'${NotificationRouter.openPrefix}tasbih'",
      ],
    };
    expected.forEach((path, needles) {
      final src = File(path).readAsStringSync();
      for (final n in needles) {
        expect(src, contains(n), reason: '$path lost $n');
      }
    });
  });

  test('every open: screen name has a destination', () {
    final opener = File('lib/app/notification_open.dart').readAsStringSync();
    for (final name in ['azkar_morning', 'azkar_evening', 'azkar_sleep',
        'khatma', 'tasbih']) {
      expect(opener, contains("'$name'"), reason: '$name has no screen');
    }
  });
}
