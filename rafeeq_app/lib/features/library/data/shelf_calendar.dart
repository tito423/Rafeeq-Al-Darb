/// «يتعامل مع الكالندر بتاعت جوجل»: a shelf's reading time as a repeating
/// Google Calendar event.
///
/// Google Calendar's own event-template link
/// (`calendar.google.com/calendar/render?action=TEMPLATE`), opened in the
/// Calendar app when it is installed, else in the browser. The reader sees
/// the filled event and saves it himself: no account access, no calendar
/// permission, nothing written behind his back. Only the shelf's name and
/// the time go into the link.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:timezone/timezone.dart' as tz;

import 'my_shelves.dart';

const _byDay = {1: 'MO', 2: 'TU', 3: 'WE', 4: 'TH', 5: 'FR', 6: 'SA', 7: 'SU'};

String _stamp(DateTime t) =>
    '${t.year.toString().padLeft(4, '0')}'
    '${t.month.toString().padLeft(2, '0')}'
    '${t.day.toString().padLeft(2, '0')}T'
    '${t.hour.toString().padLeft(2, '0')}'
    '${t.minute.toString().padLeft(2, '0')}00';

/// The link for [shelf]'s reminder, or null when it has none. The first
/// occurrence is the next chosen weekday at the chosen time; the event lasts
/// [minutes] and repeats weekly on every chosen day.
Uri? shelfCalendarLink(Shelf shelf, {int minutes = 30}) {
  final r = shelf.reminder;
  if (r == null || r.weekdays.isEmpty) return null;
  final now = DateTime.now();
  var start = DateTime(now.year, now.month, now.day, r.hour, r.minute);
  while (!r.weekdays.contains(start.weekday) || !start.isAfter(now)) {
    start = start.add(const Duration(days: 1));
  }
  final end = start.add(Duration(minutes: minutes));
  final days = (r.weekdays.toList()..sort()).map((d) => _byDay[d]).join(',');
  return Uri.https('calendar.google.com', '/calendar/render', {
    'action': 'TEMPLATE',
    'text': 'shelves.calendar_title'.tr(args: [shelf.name]),
    'details': 'shelves.calendar_details'.tr(),
    'dates': '${_stamp(start)}/${_stamp(end)}',
    'ctz': tz.local.name,
    'recur': 'RRULE:FREQ=WEEKLY;BYDAY=$days',
  });
}
