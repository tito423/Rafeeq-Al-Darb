import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/rafeeq_app.dart' show sharedPrefsProvider;

/// P3‑21: whether the first-run mushaf-pick/download onboarding screen has
/// already been shown. Read synchronously (off the same injected
/// [SharedPreferences] instance every other sync-read provider in this app
/// uses) so `SplashScreen` can decide where to navigate without an extra
/// async gap after its own brief animated beat.
const _kOnboardingDone = 'onboarding.completed';

final onboardingCompletedProvider = Provider<bool>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return prefs.getBool(_kOnboardingDone) ?? false;
});

Future<void> markOnboardingCompleted(SharedPreferences prefs) =>
    prefs.setBool(_kOnboardingDone, true);
