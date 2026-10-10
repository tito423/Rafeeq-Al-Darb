import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/config/notification_ids.dart';
import 'package:rafeeq_app/core/services/notification_id_upgrade.dart';
import 'package:rafeeq_app/features/khatma/data/khatma_store.dart';
import 'package:rafeeq_app/features/library/data/my_shelves.dart';
import 'package:rafeeq_app/features/library/data/shelf_reminder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  AndroidFlutterLocalNotificationsPlugin.registerWith();
  tzdata.initializeTimeZones();
  Localization.load(
    const Locale('ar'),
    translations: Translations(
      jsonDecode(File('assets/translations/ar.json').readAsStringSync())
          as Map<String, dynamic>,
    ),
  );
  tearDownAll(() => debugDefaultTargetPlatformOverride = null);
  test('notification kinds have disjoint ID ranges', () {
    const ranges = NotificationIds.ranges;
    expect(ranges.map((r) => r.name).toSet(), hasLength(ranges.length));
    for (var i = 0; i < ranges.length; i++) {
      final a = ranges[i];
      expect(a.start, greaterThan(0));
      expect(a.count, greaterThan(0));
      expect(a.endExclusive, lessThanOrEqualTo(0x7fffffff));
      for (var j = i + 1; j < ranges.length; j++) {
        final b = ranges[j];
        expect(
          a.start < b.endExclusive && b.start < a.endExclusive,
          isFalse,
          reason: '${a.name} overlaps ${b.name}',
        );
      }
    }
  });

  test('khatma IDs are collision-free and deterministic', () {
    final ids = [for (var i = 0; i < 1500; i++) 'plan-$i'];
    final assigned = NotificationIds.khatmaIds(ids);
    expect(assigned.values.toSet(), hasLength(ids.length));
    expect(NotificationIds.khatmaIds(ids.reversed), assigned);
    expect(
      assigned.values.every(
        (id) =>
            id >= NotificationIds.khatma &&
            id < NotificationIds.khatma + NotificationIds.khatmaCount,
      ),
      isTrue,
    );
  });

  test('existing and large shelf IDs stay inside their exclusive range', () {
    final range = NotificationIds.ranges.singleWhere(
      (r) => r.name == 'shelves',
    );
    expect(ShelfReminderService.notificationId(1, 3), 20013);
    for (final shelf in [1, 999, 100000, 99999999]) {
      for (var day = 1; day <= 7; day++) {
        final id = ShelfReminderService.notificationId(shelf, day);
        expect(range.contains(id), isTrue);
        expect(
          NotificationIds.ranges.where((r) => r.contains(id)),
          hasLength(1),
        );
      }
    }
    expect(
      () => ShelfReminderService.notificationId(100000000, 1),
      throwsStateError,
    );
  });

  test('every Dart notification owner uses the central ID table', () {
    // These two transport services receive IDs from their owning stores.
    const forwarded = {
      'lib/core/services/khatma_reminder_service.dart':
          'lib/features/khatma/data/khatma_store.dart',
      'lib/core/services/sunan_suwar_reminder_service.dart':
          'lib/features/sunan_suwar/data/sunan_suwar_store.dart',
    };
    final emitters = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    var checked = 0;
    for (final file in emitters) {
      final source = file.readAsStringSync();
      if (!source.contains('FlutterLocalNotificationsPlugin') ||
          !RegExp(r'\.(zonedSchedule|show)\(').hasMatch(source)) {
        continue;
      }
      final path = file.path.replaceAll('\\', '/');
      final owner = forwarded[path];
      expect(
        owner == null ? source : File(owner).readAsStringSync(),
        contains('NotificationIds.'),
        reason: '$path has an unreserved allocator',
      );
      checked++;
    }
    // Nine Dart emitters currently schedule/show notifications; native prayer
    // status and foreground services are covered separately below.
    expect(checked, 9);
  });

  test(
    'native services consume constants generated from the central Dart table',
    () {
      final table = File(
        'lib/core/config/notification_ids.dart',
      ).readAsStringSync();
      final constants = {
        for (final match in RegExp(
          r'static const int (\w+) = (\d+);',
        ).allMatches(table))
          match.group(1)!: int.parse(match.group(2)!),
      };
      for (final name in [
        'adhan',
        'assistant',
        'downloadForeground',
        'downloadItems',
        'downloadItemsCount',
        'prayerStatus',
      ]) {
        expect(constants[name], isNotNull);
      }
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      expect(gradle, contains('notification_ids.dart'));
      expect(gradle, contains('notificationIds.getValue(key)'));
      for (final file in [
        'AssistantListenService.kt',
        'DownloadForegroundService.kt',
        'PrayerCard.kt',
        'adhan/AdhanNotifications.kt',
      ]) {
        final src = File(
          'android/app/src/main/kotlin/com/tito/rafeeq_aldarb/$file',
        ).readAsStringSync();
        expect(src, contains('BuildConfig.NOTIFICATION_'));
      }
    },
  );

  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test(
    'startup re-arm awaits persisted shelves and preserves other ranges',
    () async {
      const shelf = Shelf(
        id: 1,
        name: 'Reading',
        colorIndex: 0,
        iconIndex: 0,
        reminder: ShelfReminder(weekdays: {1, 3, 7}, hour: 19, minute: 25),
      );
      SharedPreferences.setMockInitialValues({
        'library.my_shelves_v1': jsonEncode([shelf.toJson()]),
      });
      final scheduled = <int>[];
      final cancelled = <int>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'initialize') return true;
        if (call.method == 'cancel') {
          cancelled.add((call.arguments as Map)['id'] as int);
        }
        if (call.method == 'zonedSchedule') {
          scheduled.add((call.arguments as Map)['id'] as int);
        }
        return null;
      });
      final store = ShelvesNotifier();
      addTearDown(store.dispose);
      await store.rearmReminders();
      expect(scheduled, [20011, 20013, 20017]);
      expect(cancelled, [for (var day = 1; day <= 7; day++) 20010 + day]);
      expect(store.state.single.reminder!.weekdays, {1, 3, 7});
    },
  );
  for (final failCancel in [false, true]) {
    test(
      'legacy cleanup is once-only and ${failCancel ? 'retries a failed cancellation' : 'preserves unrelated alarms'}',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final cancelled = <int>[];
        var fail = failCancel;
        var pendingReads = 0;
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'pendingNotificationRequests') {
            pendingReads++;
            return [
              for (final id in [
                6001,
                7000,
                7301,
                7899,
                8000,
                NotificationIds.khatma,
              ])
                {'id': id, 'title': '', 'body': '', 'payload': ''},
            ];
          }
          if (call.method == 'cancel') {
            final id = (call.arguments as Map)['id'] as int;
            if (fail && id == 7301) {
              throw PlatformException(code: 'cancel-failed');
            }
            cancelled.add(id);
          }
          return null;
        });
        if (failCancel) {
          await expectLater(
            NotificationIdUpgrade.cleanLegacy(prefs),
            throwsA(isA<PlatformException>()),
          );
          expect(
            prefs.getBool(NotificationIdUpgrade.preferenceKey),
            isNot(true),
          );
          fail = false;
          cancelled.clear();
        }
        await NotificationIdUpgrade.cleanLegacy(prefs);
        expect(cancelled, [7000, 7301, 7899]);
        expect(prefs.getBool(NotificationIdUpgrade.preferenceKey), isTrue);
        final previousReads = pendingReads;
        await NotificationIdUpgrade.cleanLegacy(prefs);
        expect(pendingReads, previousReads);
        expect(cancelled, [7000, 7301, 7899]);
      },
    );
  }

  test(
    'restored khatmas re-arm and deletion removes obsolete IDs without cancelling prayers',
    () async {
      final plans = [
        for (final id in ['a', 'b', 'c'])
          Khatma(
            id: id,
            startDate: DateTime(2026, 10, 10),
            mode: KhatmaMode.dailyPages,
            dailyAmount: 2,
            reminderTime: const TimeOfDay(hour: 10, minute: 0),
          ),
      ];
      SharedPreferences.setMockInitialValues({
        'khatma_list_v1': jsonEncode(plans.map((k) => k.toJson()).toList()),
      });
      final prefs = await SharedPreferences.getInstance();
      final pending = <int, String>{
        7001: 'open:khatma',
        NotificationIds.prayerIqama: '',
      };
      final cancelled = <int>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        final args = call.arguments as Map?;
        if (call.method == 'pendingNotificationRequests') {
          return [
            for (final entry in pending.entries)
              {
                'id': entry.key,
                'title': '',
                'body': '',
                'payload': entry.value,
              },
          ];
        }
        if (call.method == 'cancel') {
          final id = args!['id'] as int;
          cancelled.add(id);
          pending.remove(id);
        }
        if (call.method == 'zonedSchedule') {
          pending[args!['id'] as int] = args['payload'] as String;
        }
        return null;
      });
      final store = KhatmaStore(prefs);
      addTearDown(store.dispose);
      await store.rearmReminders();
      expect(cancelled, [7001]);
      expect(pending.keys.toSet(), {
        NotificationIds.prayerIqama,
        NotificationIds.khatma,
        NotificationIds.khatma + 1,
        NotificationIds.khatma + 2,
      });
      await store.delete(plans.first);
      expect(pending.keys.toSet(), {
        NotificationIds.prayerIqama,
        NotificationIds.khatma,
        NotificationIds.khatma + 1,
      });
      expect(cancelled, isNot(contains(NotificationIds.prayerIqama)));
      expect(store.state.map((k) => k.id), ['b', 'c']);
      expect(
        (jsonDecode(prefs.getString('khatma_list_v1')!) as List),
        hasLength(2),
      );
    },
  );
}
