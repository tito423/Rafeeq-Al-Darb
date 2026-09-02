import 'package:flutter/material.dart';

import '../../../app/navigation.dart';
import '../../../core/services/adhan_alarm_service.dart';
import 'screens/adhan_full_screen_screen.dart';

/// Pushes the full-screen Adhan view from a notification payload — called
/// both for a live tap (app running) and, once, for a cold launch caused by
/// tapping the notification while the app was fully killed.
void openAdhanFromPayload(String rawPayload) {
  final payload = AdhanPayload.tryParse(rawPayload);
  if (payload == null) return;
  final navigator = rootNavigatorKey.currentState;
  if (navigator == null) return;
  navigator.push(
    MaterialPageRoute<void>(
      builder: (_) => AdhanFullScreenScreen(
        prayerKey: payload.prayerKey,
        prayerLabel: payload.prayerLabel,
        notificationId: payload.notificationId,
        rawPayload: rawPayload,
        previewAsset: payload.previewAssetPath,
      ),
    ),
  );
}
