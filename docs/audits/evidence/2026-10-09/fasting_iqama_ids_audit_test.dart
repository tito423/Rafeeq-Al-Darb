import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:rafeeq_app/features/fasting/data/fasting_reminder_service.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  test('turning fasting reminders off cancels iqama notification IDs', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    final canceled = <int>[];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'cancel') {
        canceled.add((call.arguments as Map)['id'] as int);
      }
      return null;
    });
    await FastingReminderService.instance.reschedule([]);
    expect(canceled, containsAll([7300, 7301, 7302, 7303, 7304]));
    expect(canceled.length, 50);
    print('AUDIT_FASTING_IQAMA: actual fasting service disabling reminders '
        'canceled ${canceled.first}-${canceled.last}, including all five iqama IDs');
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });
}
