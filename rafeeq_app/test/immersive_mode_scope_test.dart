import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `SystemChrome.setEnabledSystemUIMode` is process-wide, so a screen that
/// sets it must also be a screen that can take it back.
///
/// THE DEFECT THIS EXISTS FOR, MEASURED ON emulator-5554.
/// `QuranScreen` hid the system bars for its full-screen mushaf and restored
/// them in `dispose`. But it is a kept-alive tab inside `AppShell`'s
/// `IndexedStack`: built on the app's first frame, never disposed. So once
/// `_restoreState` read a stored «ملء الشاشة» of true, **the whole app** ran
/// in `immersiveSticky` for the rest of the process — and that mode peeks the
/// bars back on any interaction before hiding them again, which resizes the
/// window twice every time a keyboard opens.
///
/// That is the owner's «لما لوحة المفاتيح بتظهر الشاشة بتعمل فليكر… حاصل في
/// أي حتة في التطبيق». Recording the library search screen at 15 fps showed
/// the keyboard bouncing up, part-way down and up again with the status bar
/// flashing with it, and `dumpsys window` on that screen — which asks for
/// nothing of the kind — reported `type=statusBars … visible=false`.
///
/// The rule now: the mode follows the active tab. These assertions hold that
/// in place, because the failure is invisible to both the analyzer and to any
/// test that only looks at the Quran screen.
void main() {
  final quran = File(
    'lib/features/quran/presentation/screens/quran_screen.dart',
  ).readAsStringSync();

  test('the Quran tab lifts its immersive mode when it is not the active tab',
      () {
    expect(quran.contains('ref.listen<int>(activeTabProvider'), isTrue,
        reason: 'nothing lifts the mode when the reader leaves the tab');
    expect(quran.contains('_syncImmersiveToTab'), isTrue);
    expect(quran.contains('AppTab.quran'), isTrue,
        reason: 'the mode has to be scoped to this tab by name, not by a '
            'bare index that a reordered bar would silently break');
  });

  test('and never applies it while another tab is showing', () {
    // Every call site must be guarded. `_applyImmersive(` appears in its own
    // declaration plus the guarded calls; the declaration is excluded here.
    final calls = RegExp(r'_applyImmersive\(([^)]*)\)')
        .allMatches(quran)
        .map((m) => m.group(1)!)
        .toList();
    expect(calls, isNotEmpty);
    final body = quran.split('\n');
    for (var i = 0; i < body.length; i++) {
      final line = body[i];
      if (!line.contains('_applyImmersive(')) continue;
      if (line.contains('void _applyImmersive(')) continue;
      final guardedOnThisLine =
          line.contains('_isActiveTab') || line.contains('AppTab.quran');
      // `_syncImmersiveToTab` is itself the guard, and `_restoreState` and
      // `_setPageFillScreen` each test `_isActiveTab` on the same line.
      final insideSync = i > 0 &&
          body.sublist((i - 4).clamp(0, i), i)
              .any((l) => l.contains('_syncImmersiveToTab(int tab)'));
      expect(guardedOnThisLine || insideSync, isTrue,
          reason: 'unguarded _applyImmersive at line ${i + 1}: '
              'this sets a PROCESS-WIDE mode from a tab that is never '
              'disposed — ${line.trim()}');
    }
  });

  test('a pushed screen that hides the bars still restores them on dispose',
      () {
    // The other caller is a real route, so `dispose` is enough there — but it
    // has to actually be there.
    final surah = File(
      'lib/features/sunan_suwar/presentation/single_surah_screen.dart',
    ).readAsStringSync();
    final disposeAt = surah.indexOf('void dispose()');
    expect(disposeAt, greaterThan(0));
    final disposeBody = surah.substring(disposeAt, disposeAt + 600);
    expect(disposeBody.contains('SystemUiMode.edgeToEdge'), isTrue,
        reason: 'this screen hides the system bars and must give them back');
  });
}
