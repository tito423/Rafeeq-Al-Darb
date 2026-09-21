import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A translation key whose value is a plural OBJECT must be read with
/// `.plural()` / `pluralN`, never with `.tr()` / `trn`.
///
/// «علوم القران … مش فيها اي حاجة وبتطلع صفحة رصاصي» (2026-09-21).
///
/// `quran.pages_count` is a six-category CLDR plural, and
/// `sciences_pack_screen.dart` read it with `trn(...)`. easy_localization
/// resolves the key to the Map and hands it back, so the line threw
/// `type '_Map<String, dynamic>' is not a subtype of type 'String'` — every
/// time, on every device that had the pack. Nothing caught it:
///
///  * `flutter analyze` sees a `String` function returning a `String`.
///  * the screen only reaches that line once a 131.68 MB database is on the
///    device, so no one who had not downloaded the pack could ever see it.
///  * and in a RELEASE build a thrown build does not show an error. Flutter
///    draws `RenderErrorBox`, a flat `Color(0xF0C0C0C0)` rectangle with no
///    text, which is why the report was "a grey page" rather than a crash.
///
/// One line, and علوم القرآن had never once managed to list its own contents.
/// The same mistake anywhere else would look the same, so it is checked for
/// everywhere rather than fixed in one place.
///
/// Proven against the broken code before being trusted (trap #23): restoring
/// `trn('quran.pages_count', ...)` fails this test naming that exact file.
void main() {
  test('no plural key is read with tr()', () {
    const cats = {'zero', 'one', 'two', 'few', 'many', 'other'};
    final ar = jsonDecode(
        File('assets/translations/ar.json').readAsStringSync()) as Map;

    final plurals = <String>{};
    ar.forEach((section, body) {
      if (body is! Map) return;
      body.forEach((key, value) {
        if (value is Map &&
            value.isNotEmpty &&
            value.keys.every((k) => cats.contains(k))) {
          plurals.add('$section.$key');
        }
      });
    });
    expect(plurals, isNotEmpty,
        reason: 'no plural keys found — the scan stopped working');
    expect(plurals, contains('quran.pages_count'),
        reason: 'the key this test was written for');

    final offenders = <String>[];
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final src = f.readAsStringSync();
      for (final key in plurals) {
        // Every read of the key, with just enough either side to tell which
        // call it belongs to.
        for (final m in RegExp("'${RegExp.escape(key)}'").allMatches(src)) {
          final before =
              src.substring((m.start - 10).clamp(0, src.length), m.start);
          final after = src.substring(
              m.end, (m.end + 12).clamp(0, src.length));
          final isPlural =
              before.contains('pluralN(') || after.contains('.plural(');
          final isTr = before.contains('trn(') || after.contains('.tr(');
          if (isTr && !isPlural) {
            offenders.add('$key  (${f.path})');
          }
        }
      }
    }

    expect(offenders, isEmpty,
        reason: 'these read a plural OBJECT as a string; each one throws '
            '«type \'_Map<String, dynamic>\' is not a subtype of type '
            '\'String\'» and, in a release build, paints a blank grey page: '
            '${offenders.join(", ")}');
  });
}
