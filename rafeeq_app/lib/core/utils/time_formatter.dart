import 'package:intl/intl.dart';

/// Formats a HH:mm 24h time string into a 12-hour AM/PM string.
String formatTime12h(String hhmm) {
  if (hhmm == '--:--' || hhmm.isEmpty) return hhmm;
  try {
    final parts = hhmm.split(':');
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
    return DateFormat('h:mm a').format(dt);
  } catch (_) {
    return hhmm;
  }
}
