import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The support sheet may only open while the More tab is the tab on screen.
///
/// It was not, and `flutter analyze` had no opinion. `AppShell` keeps every
/// tab alive in an `IndexedStack`, so `MoreScreen.build` runs on the app's
/// first frame no matter which tab is showing — the same property trap #43 is
/// about — and the post-frame callback put the sheet over **Home**, on a
/// fresh install stacked on top of the welcome tour. Two sheets over each
/// other before the reader had touched anything.
///
/// This is a source test rather than a widget test on purpose: mounting
/// `MoreScreen` means mounting the whole settings body and every provider it
/// reaches, and what needs pinning is one line of wiring. Same shape as
/// `notification_router_test.dart`, which guards a rule the compiler cannot.
void main() {
  test('the support sheet is gated on the More tab, not on being built', () {
    final src =
        File('lib/features/more/presentation/screens/more_screen.dart')
            .readAsStringSync();

    expect(src, contains('showSupportIntro'),
        reason: 'the sheet is shown from the More tab and nowhere else');

    // The gate itself: the active tab, and the tour being over.
    expect(src, contains('activeTabProvider'),
        reason: 'without this the sheet opens over whatever tab is showing');
    expect(src, contains('AppTab.more'), reason: 'gated on the wrong tab');
    expect(src, contains('tutorialRunningProvider'),
        reason: 'the welcome tour must finish before anything is asked');

    // And it is inside a condition, not fired unconditionally from build.
    final call = src.indexOf('showSupportIntro(context, ref)');
    final gate = src.indexOf('activeTabProvider');
    expect(gate, greaterThanOrEqualTo(0));
    expect(gate, lessThan(call),
        reason: 'the tab is read AFTER the sheet is posted, which is no gate');
  });

  test('no other screen opens it', () {
    final offenders = <String>[];
    for (final e in Directory('lib').listSync(recursive: true)) {
      if (e is! File || !e.path.endsWith('.dart')) continue;
      final path = e.path.replaceAll(r'\', '/');
      if (path.endsWith('more_screen.dart') ||
          path.endsWith('support_screen.dart')) {
        continue;
      }
      if (e.readAsStringSync().contains('showSupportIntro(')) {
        offenders.add(path);
      }
    }
    expect(offenders, isEmpty,
        reason: '«تظهر مرة واحدة في الأول» — one place asks, and it is المزيد:\n'
            '${offenders.join('\n')}');
  });
}
