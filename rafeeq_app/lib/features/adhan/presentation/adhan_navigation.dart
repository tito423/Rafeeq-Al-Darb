import 'package:flutter/material.dart';

import '../../../app/navigation.dart';
import '../../../core/services/adhan_alarm_service.dart';
import 'screens/adhan_full_screen_screen.dart';

/// True while `AdhanFullScreenScreen` is actually on top of the navigator —
/// guards both [openAdhanFromPayload] callers (the Intent-based path *and*
/// P3‑43 #2's resume-time active-notification fallback) against pushing a
/// second copy on top of itself if both happen to fire close together.
bool _adhanScreenShowing = false;

/// Pushes the full-screen Adhan view from a notification payload — called
/// for a live tap (app running), once for a cold launch caused by tapping
/// the notification while the app was fully killed, and (P3‑43 #2) as a
/// fallback on every app resume when an Adhan notification is confirmed
/// still active but the Intent-based path above didn't already navigate —
/// some device skins resume the app's last screen on a locked-screen
/// full-screen-intent launch instead of faithfully re-delivering the
/// notification's Intent, which no app-level code can control.
void openAdhanFromPayload(String rawPayload) {
  if (_adhanScreenShowing) return;
  final payload = AdhanPayload.tryParse(rawPayload);
  if (payload == null) return;
  final navigator = rootNavigatorKey.currentState;
  if (navigator == null) return;
  _adhanScreenShowing = true;
  navigator
      .push(
        MaterialPageRoute<void>(
          builder: (_) => AdhanFullScreenScreen(
            prayerKey: payload.prayerKey,
            prayerLabel: payload.prayerLabel,
            notificationId: payload.notificationId,
            rawPayload: rawPayload,
            audioAsset: payload.previewAssetPath,
            audioFilePath: payload.audioFilePath,
            videoPath: payload.videoPath,
          ),
        ),
      )
      .whenComplete(() => _adhanScreenShowing = false);
}
