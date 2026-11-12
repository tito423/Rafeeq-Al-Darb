import 'dart:convert';

// The public barrel does not export `Localization`; this engine has no
// plugins, so easy_localization's own loader (SharedPreferences) cannot run
// and the translations are loaded the way the tests load them.
// ignore: implementation_imports
import 'package:easy_localization/src/localization.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'core/models/adhan_calculation.dart';
import 'core/services/prayer_status_notification.dart';

/// A headless calculation isolate: no UI, plugin registration, GPS or network.
///
/// Two jobs: the adhan alarms' next instants (`calculate`), and the status
/// card's month of events (`cardSchedule`), rebuilt daily by the native
/// `PrayerCardJob` so the card never runs out while the app stays closed.
Future<void> runAdhanRecompute() async {
  WidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.tito.rafeeq_aldarb/adhan_recompute');
  channel.setMethodCallHandler((call) async {
    switch (call.method) {
      case 'calculate':
        return nextAdhanTriggers(call.arguments as Map<Object?, Object?>);
      case 'cardSchedule':
        return _cardSchedule(call.arguments as Map<Object?, Object?>);
    }
    throw MissingPluginException();
  });
  await channel.invokeMethod<void>('ready');
}

Future<List<Map<String, Object>>> _cardSchedule(
    Map<Object?, Object?> args) async {
  final locale = args['locale'] as String? ?? 'ar';
  final raw = await rootBundle.loadString('assets/translations/$locale.json');
  Localization.load(
    Locale(locale),
    translations: Translations(jsonDecode(raw) as Map<String, dynamic>),
    ignorePluralRules: false,
  );
  await initializeDateFormatting(locale);
  Intl.defaultLocale = locale;
  return PrayerStatusNotification.instance.backgroundSchedule(
    inputs: args['inputs']! as String,
    localeCode: locale,
    city: args['city'] as String? ?? '',
    hijriOffset: (args['hijriOffset'] as num?)?.toInt() ?? 0,
    officialHijri: args['hijri'] as String?,
  );
}
