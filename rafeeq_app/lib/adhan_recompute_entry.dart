import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'core/models/adhan_calculation.dart';

/// A headless calculation isolate: no UI, plugin registration, GPS or network.
Future<void> runAdhanRecompute() async {
  WidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.tito.rafeeq_aldarb/adhan_recompute');
  channel.setMethodCallHandler((call) async {
    if (call.method != 'calculate') throw MissingPluginException();
    return nextAdhanTriggers(call.arguments as Map<Object?, Object?>);
  });
  await channel.invokeMethod<void>('ready');
}
