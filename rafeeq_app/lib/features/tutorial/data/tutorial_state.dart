import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/rafeeq_app.dart' show sharedPrefsProvider;

/// Whether the guided tour has ever been shown, and whether the owner wants it
/// again on every launch.
///
/// «وحطله خيارات في المزيد: يتعرض عند كل فتح، وتشغيل الآن، وزرار اسكيب في أي
/// وقت». Two separate facts, deliberately:
///
///  * [tutorialSeenProvider] — shown once, automatically, the first time the
///    app opens after the tour exists. Without this an existing install would
///    never discover it, because the toggle below starts off.
///  * [tutorialOnEveryLaunchProvider] — off by default. A tour that reappears
///    on every launch is a tour nobody asked for twice; the owner asked for
///    the *option*, so it is an option.
///
/// Both are read synchronously off the same injected [SharedPreferences] every
/// other sync provider in this app uses, so `AppShell` can decide on its first
/// frame without an async gap that would let the Home screen paint first and
/// then be covered.
const _kSeen = 'tutorial.seen_v1';
const _kEveryLaunch = 'tutorial.every_launch_v1';

final tutorialSeenProvider = Provider<bool>((ref) {
  return ref.watch(sharedPrefsProvider).getBool(_kSeen) ?? false;
});

class TutorialEveryLaunchNotifier extends StateNotifier<bool> {
  TutorialEveryLaunchNotifier(this._prefs)
      : super(_prefs.getBool(_kEveryLaunch) ?? false);

  final SharedPreferences _prefs;

  Future<void> set(bool value) async {
    state = value;
    await _prefs.setBool(_kEveryLaunch, value);
  }
}

final tutorialOnEveryLaunchProvider =
    StateNotifierProvider<TutorialEveryLaunchNotifier, bool>((ref) {
  return TutorialEveryLaunchNotifier(ref.watch(sharedPrefsProvider));
});

/// Marks the tour as seen. Called when it is closed **however** it is closed —
/// finished, skipped, or dismissed with the system back gesture — because
/// "has this ever been on screen" is the question, not "did you read it".
Future<void> markTutorialSeen(SharedPreferences prefs) =>
    prefs.setBool(_kSeen, true);

/// Whether the tour should open by itself right now.
bool shouldAutoShowTutorial(WidgetRef ref) =>
    ref.read(tutorialOnEveryLaunchProvider) || !ref.read(tutorialSeenProvider);

/// Is the tour playing right now? `AppShell` mounts the overlay on this, and
/// every way in sets it — the automatic first run, «تشغيل الآن» in المزيد.
final tutorialRunningProvider = StateProvider<bool>((ref) => false);

/// The single way out, wherever it is triggered from: the last chapter,
/// «تخطّي», or the system back gesture that `AppShell` routes in. "Seen" is
/// recorded however the reader leaves, because the question is "has this ever
/// been on screen", not "did you read it".
void endTutorial(WidgetRef ref) {
  markTutorialSeen(ref.read(sharedPrefsProvider));
  ref.read(tutorialRunningProvider.notifier).state = false;
}
