import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../features/quotes/data/quote_repository.dart';

/// «إشعار كل مدة يحددها المالك … لما يضغط عليه يفتح كارت جوّه التطبيق».
///
/// Every notification carries a DIFFERENT quote, which is why this does not
/// use `periodicallyShowWithDuration`: that repeats one fixed title and body
/// for ever, and a saying you have already read is not a reminder. Each slot
/// is its own `zonedSchedule` with its own text and its own payload, and the
/// payload is what makes the card open on the quote the notification actually
/// showed rather than on a fresh random one.
///
/// HOW LONG IT KEEPS GOING WITHOUT THE APP, HONESTLY.
/// A rolling window is armed — [maxSlots] notifications, or 24 hours' worth,
/// whichever is fewer — and it is re-armed from scratch every time the app is
/// opened. On a phone opened daily the stream never runs dry. On a phone left
/// closed it stops at the end of the window. The alternative is a background
/// worker that re-arms itself, which is the machinery the adhan uses and is
/// not worth spending on a nudge — the same trade `PrayerReminderService`
/// documents for its own daily repeat.
class QuoteReminderService {
  QuoteReminderService._();
  static final QuoteReminderService instance = QuoteReminderService._();

  static const _channelId = 'rafeeq_quote';
  static String get _channelName => 'notif.quote_channel'.tr();

  /// One id block, so a re-arm replaces the previous window rather than
  /// stacking a second one on top of it.
  static const _baseId = 7500;

  /// Android will hold far more than this, but a window longer than a day is
  /// stale by the time it fires — the app will have been opened.
  static const maxSlots = 48;

  /// Set by `main()`; called with the payload when a quote notification is
  /// tapped, so the app can open the card.
  static void Function(String payload)? onOpenQuote;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _channelReady = false;

  @pragma('vm:entry-point')
  static void _onResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) onOpenQuote?.call(payload);
  }

  Future<void> initialize() async {
    await _plugin.initialize(
      const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      onDidReceiveNotificationResponse: _onResponse,
      onDidReceiveBackgroundNotificationResponse: _onResponse,
    );
  }

  Future<void> _ensureChannel() async {
    if (_channelReady) return;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'notif.quote_channel_desc'.tr(),
        importance: Importance.defaultImportance,
      ),
    );
    _channelReady = true;
  }

  Future<void> cancelAll() async {
    for (var i = 0; i < maxSlots; i++) {
      await _plugin.cancel(_baseId + i);
    }
  }

  /// Re-arms the whole window. [everyMinutes] of 0 means the feature is off
  /// and everything is cancelled — the same "zero is how you turn it off"
  /// contract the three prayer reminders use.
  Future<void> reschedule({
    required QuoteLibrary library,
    required int everyMinutes,
    Random? rng,
  }) async {
    await cancelAll();
    if (everyMinutes <= 0 || library.total == 0) return;
    await _ensureChannel();

    final random = rng ?? Random();
    final slots = slotCount(everyMinutes);
    final now = tz.TZDateTime.now(tz.local);

    // Drawn without replacement while the corpus lasts, so one window never
    // shows the same saying twice.
    final used = <String>{};
    for (var i = 0; i < slots; i++) {
      (int, int)? pick;
      for (var tries = 0; tries < 12; tries++) {
        final candidate = library.randomIndex(random);
        if (candidate == null) break;
        final key = Quote.key(candidate.$1, candidate.$2);
        if (used.add(key) || used.length >= library.total) {
          pick = candidate;
          break;
        }
      }
      pick ??= library.randomIndex(random);
      if (pick == null) return;

      final quote = library.at(pick.$1, pick.$2);
      if (quote == null) continue;

      await _plugin.zonedSchedule(
        _baseId + i,
        'notif.quote_title'.tr(),
        _preview(quote.text),
        now.add(Duration(minutes: everyMinutes * (i + 1))),
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            styleInformation: BigTextStyleInformation(
              _preview(quote.text),
              summaryText: quote.bookTitle,
            ),
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: Quote.key(pick.$1, pick.$2),
      );
    }
  }

  /// How many slots a window of [everyMinutes] holds: a day's worth, capped
  /// at [maxSlots]. At 30 minutes that is 48 (24 hours); at 6 hours it is 4.
  static int slotCount(int everyMinutes) {
    if (everyMinutes <= 0) return 0;
    final perDay = (24 * 60) ~/ everyMinutes;
    return perDay.clamp(1, maxSlots);
  }

  /// The notification shows the opening of the saying; the card shows all of
  /// it. Cut on a word boundary — a shade truncating mid-word looks broken in
  /// a way an ellipsis does not.
  static String _preview(String text, {int max = 140}) {
    if (text.length <= max) return text;
    final cut = text.lastIndexOf(' ', max);
    return '${text.substring(0, cut > 40 ? cut : max).trimRight()}…';
  }
}
