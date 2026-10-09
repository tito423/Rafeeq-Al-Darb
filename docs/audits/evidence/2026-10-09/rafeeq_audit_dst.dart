import 'dart:convert';
import 'package:timezone/data/latest.dart' as data;
import 'package:timezone/timezone.dart' as tz;
void main() {
  data.initializeTimeZones();
  final london = tz.getLocation('Europe/London');
  final today = tz.TZDateTime(london, 2026, 3, 28, 8);
  final actual = today.add(const Duration(days: 1));
  final expected = tz.TZDateTime(london, 2026, 3, 29, 8);
  final late = tz.TZDateTime(london, 2026, 3, 28, 23, 30);
  print(jsonEncode({
    'source': 'prayer_reminder_service.dart:206 and the same add(Duration(days:1)) in khatma/adhkar/sunan/shelf/tasbih reminders',
    'today': today.toIso8601String(),
    'actual_next': actual.toIso8601String(),
    'expected_same_wall_clock': expected.toIso8601String(),
    'drift_minutes': actual.difference(expected).inMinutes,
    'late_evening': late.toIso8601String(),
    'late_plus_24_hours': late.add(const Duration(days: 1)).toIso8601String(),
  }));
}
