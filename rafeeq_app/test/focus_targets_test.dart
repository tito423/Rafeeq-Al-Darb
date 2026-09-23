import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/app/shell/tab_request_provider.dart';
import 'package:rafeeq_app/features/settings/data/focus_mode_provider.dart';
import 'package:rafeeq_app/features/settings/presentation/widgets/focus_mode_picker.dart';

/// «وضع التركيز» locks the app onto one `IndexedStack` slot, and every way
/// that can go wrong is silent at compile time:
///
/// * a target whose card has no icon/colour crashes the sheet on `!`;
/// * a target whose name or description is missing from a locale renders the
///   raw key on screen (trap #8);
/// * a target pointing past the last destination reaches `NavigationBar`'s
///   `selectedIndex` and asserts.
///
/// None of that is what «الحفظ والتسميع» being *on* the sheet means — that is
/// proven by opening it on a device, not here.
void main() {
  const locales = ['ar', 'en', 'es', 'ru', 'pt', 'fr', 'ur'];

  Map<String, dynamic> focusBlock(String locale) {
    final raw = File('assets/translations/$locale.json').readAsStringSync();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return json['focus'] as Map<String, dynamic>;
  }

  test('every focus target has a card to draw', () {
    for (final target in FocusTarget.values) {
      expect(focusTargetLook[target], isNotNull,
          reason: '${target.name} has no icon/accent — the sheet uses `!`');
    }
  });

  test('every focus target is named in all seven locales', () {
    for (final locale in locales) {
      final block = focusBlock(locale);
      for (final target in FocusTarget.values) {
        for (final key in [target.titleKey, target.bodyKey]) {
          final leaf = key.split('.').last;
          expect(block[leaf], isA<String>(),
              reason: '$locale is missing $key');
          expect((block[leaf] as String).trim(), isNotEmpty,
              reason: '$locale has $key empty');
        }
      }
    }
  });

  test('targets pin distinct slots, and only a non-tab one is off the bar',
      () {
    final slots = FocusTarget.values.map((t) => t.tab).toList();
    expect(slots.toSet().length, slots.length, reason: 'two targets, one slot');
    for (final target in FocusTarget.values) {
      expect(target.tab, greaterThanOrEqualTo(0));
      // The shell's stack is the seven destinations plus the one focus-only
      // slot, so nothing may point past it.
      expect(target.tab, lessThanOrEqualTo(AppTab.focusHifz),
          reason: '${target.name} points past the last stack child');
      expect(target.isTab, target.tab < AppTab.navCount);
    }
    // `AppTab.more` is the last button on the bar; the focus-only slot is the
    // very next index, which is what makes the stack exactly one longer.
    expect(AppTab.navCount, AppTab.more + 1);
    expect(AppTab.focusHifz, AppTab.navCount);
    expect(FocusTarget.hifz.isTab, isFalse);
  });
}
