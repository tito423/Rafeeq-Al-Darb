import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The manifest may not ask for a permission the app does not exercise.
///
/// THE DEFECT THIS EXISTS FOR. `SYSTEM_ALERT_WINDOW` — «draw over other
/// apps», the most abusable permission Android has — was declared with a
/// comment calling it «a fallback path for the Adhan alert on OEM skins that
/// throttle a background full-screen-intent launch». **There was no
/// fallback.** The repo contains no `canDrawOverlays`, no
/// `TYPE_APPLICATION_OVERLAY`, no `ACTION_MANAGE_OVERLAY_PERMISSION`. It was
/// declared for code nobody wrote, on an app that ships as a sideloaded APK.
///
/// AND THE FIRST AUDIT SCRIPT PASSED IT. Its evidence needle for that
/// permission included the bare word `overlay`, which matches
/// `page_overlay.dart`, Flutter's own `Overlay`, and a dozen colour names. A
/// check that can pass on an unrelated word is not a check — same family as
/// trap #47, where a normaliser returned the empty string and the test
/// compared it against another empty string. So the needles here are the
/// **actual API symbols** the permission gates, and nothing looser.
void main() {
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();

  /// Manifest text with XML comments removed. The removal notes deliberately
  /// name the permission they removed, and a search that counted those would
  /// report it as still declared.
  final declared = manifest.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

  List<String> sourceFiles() => [
        for (final dir in ['lib', 'android/app/src/main/kotlin'])
          if (Directory(dir).existsSync())
            ...Directory(dir)
                .listSync(recursive: true)
                .whereType<File>()
                .where((f) =>
                    f.path.endsWith('.dart') || f.path.endsWith('.kt')),
      ].map((f) => f.readAsStringSync()).toList();

  test('SYSTEM_ALERT_WINDOW is declared only together with its code', () {
    // Re-declared on 2026-09-29 in the same commit as `AssistantOverlay.kt`
    // (owner: «رفيق فوق أي تطبيق»), which is exactly what the 2026-09-17
    // removal note asked for. The permission and the code must agree in both
    // directions: no permission without the code that uses it, and no
    // overlay API without the permission that gates it.
    const overlayApis = [
      'canDrawOverlays',
      'TYPE_APPLICATION_OVERLAY',
      'ACTION_MANAGE_OVERLAY_PERMISSION',
    ];
    final used = sourceFiles()
        .any((src) => overlayApis.any((api) => src.contains(api)));
    final has = declared.contains('android.permission.SYSTEM_ALERT_WINDOW');
    expect(has, used,
        reason: 'declared=$has but overlay code present=$used - they must '
            'agree (an unused permission is abusable; an ungated API fails '
            'silently at runtime)');
  });

  test('only the assistant overlay draws over other apps', () {
    // The permission is the most abusable one Android has; the only file that
    // may use its APIs is the assistant's own small card.
    const overlayApis = [
      'TYPE_APPLICATION_OVERLAY',
      'ACTION_MANAGE_OVERLAY_PERMISSION',
    ];
    final offenders = <String>[];
    for (final dir in const ['android/app/src/main/kotlin', 'lib']) {
      if (!Directory(dir).existsSync()) continue;
      for (final f in Directory(dir).listSync(recursive: true).whereType<File>()) {
        if (!(f.path.endsWith('.kt') || f.path.endsWith('.dart'))) continue;
        if (f.path.endsWith('AssistantOverlay.kt')) continue;
        final src = f.readAsStringSync();
        if (overlayApis.any(src.contains)) offenders.add(f.path);
      }
    }
    expect(offenders, isEmpty);
  });

  test('the adhan still has what it needs to cross the lock screen', () {
    // Removing one permission must not have taken the feature with it. The
    // adhan surfaces through a full-screen-intent notification launching
    // AdhanActivity, which sets its own window flags.
    for (final needed in const [
      'android.permission.USE_FULL_SCREEN_INTENT',
      'android.permission.TURN_SCREEN_ON',
      'android.permission.DISABLE_KEYGUARD',
    ]) {
      expect(declared.contains(needed), isTrue, reason: 'missing $needed');
    }
    final activity = File(
      'android/app/src/main/kotlin/com/tito/rafeeq_aldarb/adhan/'
      'AdhanActivity.kt',
    );
    expect(activity.existsSync(), isTrue);
    final kt = activity.readAsStringSync();
    for (final flag in const [
      'FLAG_SHOW_WHEN_LOCKED',
      'FLAG_TURN_SCREEN_ON',
      'FLAG_DISMISS_KEYGUARD',
    ]) {
      expect(kt.contains(flag), isTrue,
          reason: 'AdhanActivity no longer sets $flag, so the alert would '
              'not appear over the lock screen');
    }
  });

  test('no permission is declared twice', () {
    final all = RegExp(r'android:name="(android\.permission\.[A-Z_]+)"')
        .allMatches(declared)
        .map((m) => m.group(1)!)
        .toList();
    final seen = <String>{};
    final dupes = all.where((p) => !seen.add(p)).toList();
    expect(dupes, isEmpty, reason: 'declared more than once: $dupes');
  });
}
