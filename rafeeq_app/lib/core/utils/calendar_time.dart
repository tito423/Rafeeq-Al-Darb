import 'package:timezone/timezone.dart' as tz;

/// Advance the calendar date while keeping the local wall-clock fields.
DateTime addCalendarDays(DateTime date, int days) {
  if (date is tz.TZDateTime) {
    return tz.TZDateTime(
      date.location,
      date.year,
      date.month,
      date.day + days,
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
      date.microsecond,
    );
  }
  final create = date.isUtc ? DateTime.utc : DateTime.new;
  return create(
    date.year,
    date.month,
    date.day + days,
    date.hour,
    date.minute,
    date.second,
    date.millisecond,
    date.microsecond,
  );
}

/// The next selected day at a clock time, in [now]'s timezone (or tz.local).
/// A null weekday set means every day.
tz.TZDateTime nextReminderTime(
  int hour,
  int minute, {
  Set<int>? weekdays,
  tz.TZDateTime? now,
}) {
  if (weekdays != null &&
      (weekdays.isEmpty || weekdays.any((day) => day < 1 || day > 7))) {
    throw ArgumentError.value(weekdays, 'weekdays');
  }
  final current = now ?? tz.TZDateTime.now(tz.local);
  var at = tz.TZDateTime(
    current.location,
    current.year,
    current.month,
    current.day,
    hour,
    minute,
  );
  while (!at.isAfter(current) ||
      (weekdays != null && !weekdays.contains(at.weekday))) {
    at = addCalendarDays(at, 1) as tz.TZDateTime;
  }
  return at;
}
