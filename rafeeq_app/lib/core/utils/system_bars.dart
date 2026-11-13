import 'package:flutter/services.dart';

/// Brings the status and navigation bars back after an immersive mode.
///
/// `SystemUiMode.edgeToEdge` alone does it on Android 10 and later, but
/// Android 7-9 ignore it and the bars stayed hidden - on the Quran hub and
/// on Home after leaving a full-screen mushaf (API 24, 2026-11-14). So the
/// bars are shown explicitly first, then edge-to-edge is asked for.
void showSystemBars() {
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: SystemUiOverlay.values,
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
}
