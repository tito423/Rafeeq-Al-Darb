import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/utils/byte_formatter.dart';
import 'package:rafeeq_app/core/utils/digits.dart';

/// CLAUDE.md trap #16, pinned.
///
/// «60.5 MB» rendered as «MB 60.5» on every size label in the app, because a
/// numeral is bidi-weak and takes its direction from what surrounds it. There
/// were **five** copies of the formatter and every one of them had the same
/// bug. `byte_formatter.dart` was written to be the only one — and then a
/// sixth appeared anyway, in `QuranTranslationInfo.sizeLabel`, built by hand
/// and missing the same left-to-right isolate.
///
/// So the invariant is a test now, not a note.
void main() {
  test('nothing builds its own byte label', () {
    // A string literal that is a bare unit right after an interpolation or a
    // number — `'$x MB'`, `'${...} KB'` — is the shape of the bug.
    final offenders = <String>[];
    final pattern = RegExp(r"""(\}|[0-9])\s*(B|KB|MB|GB)'""");
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      if (f.path.endsWith('byte_formatter.dart')) continue;
      for (final line in f.readAsLinesSync()) {
        final code = line.trimLeft();
        if (code.startsWith('//') || code.startsWith('///')) continue;
        if (pattern.hasMatch(line)) offenders.add('${f.path}: $line');
      }
    }
    expect(offenders, isEmpty,
        reason: 'use formatBytes/formatBytesBinary — a hand-built size label '
            'has no LTR isolate and reverses in Arabic:\n'
            '${offenders.join("\n")}');
  });

  test('a size is wrapped so it cannot reverse in an Arabic paragraph', () {
    // U+2066 LEFT-TO-RIGHT ISOLATE … U+2069 POP DIRECTIONAL ISOLATE.
    for (final s in [
      formatBytes(512),
      formatBytes(1500),
      formatBytes(12626797),
      formatBytesBinary(2307544),
    ]) {
      expect(s.codeUnitAt(0), 0x2066, reason: s);
      expect(s.codeUnitAt(s.length - 1), 0x2069, reason: s);
    }
  });

  test('the decimal and binary formatters disagree, on purpose', () {
    // 1,048,576 bytes is «1.0 MB» binary and «1.0 MB» decimal only by
    // coincidence of rounding; 1,500,000 separates them, and the Downloads
    // screen must keep agreeing with Android's own storage figures.
    //
    // Asserted in ENGLISH, because what this test is about is the NUMBER -
    // 1.5 against 1.4 - and not which digits draw it. The Arabic shaping is
    // pinned separately below.
    uiLanguageCode = 'en';
    expect(formatBytes(1500000), contains('1.5 MB'));
    expect(formatBytesBinary(1500000), contains('1.4 MB'));
  });

  test('a size is written in the reader own numerals', () {
    // The Downloads screen read «0 B» under «المساحة المستخدمة», and a
    // library card printed a Latin size directly beneath «توفي ٧٧٤ هـ» -
    // two numbering systems, one card. Seen on emulator-5554.
    uiLanguageCode = 'ar';
    expect(formatBytes(1500000), contains('١.٥ MB'));
    expect(formatBytes(512), contains('٥١٢ B'));

    // The UNIT stays Latin, and the isolate that trap #16 is about survives.
    final s = formatBytes(1500000);
    expect(s, contains('MB'));
    expect(s.codeUnitAt(0), 0x2066);
    expect(s.codeUnitAt(s.length - 1), 0x2069);

    // A language that writes Latin digits is untouched.
    uiLanguageCode = 'ru';
    expect(formatBytes(1500000), contains('1.5 MB'));

    uiLanguageCode = 'ar';
  });

  test('no translation string writes a file size into its prose', () {
    // THE DEFECT. `library.hadith_download_hint` read «تنزيل لمرة واحدة
    // (~١٦ م.ب)» in Arabic and "~16 MB" in the other six. The real
    // hadith.zip is 22,235,941 bytes — 22.2 MB — so the figure the reader was
    // asked to agree to had drifted 39% low, and on mobile data that is the
    // difference he is actually agreeing to. It also wrote the unit as «م.ب»
    // while every size the app formats says «MB».
    //
    // A size belongs to the file, not to a sentence. It is now
    // `AppConfig.hadithDbBytes`, measured with head_object against the
    // bucket, passed through formatBytes into a `{}`.
    //
    // Written with plain string scanning rather than one clever regex,
    // because the first version of this test was a regex full of \u escapes,
    // it passed on the broken strings, and a test that cannot see the bug it
    // was written for is worse than no test (CLAUDE.md trap #47). This one
    // was proved by putting «~16 MB» and «~١٦ م.ب» back and watching it fail.
    const units = ['MB', 'KB', 'GB', 'Mo', 'Ko', 'Go', 'МБ', 'КБ', 'ГБ',
        'م.ب', 'ك.ب', 'ج.ب', 'میگا'];
    bool isDigit(String c) {
      final r = c.runes.first;
      return (r >= 0x30 && r <= 0x39) || // 0-9
          (r >= 0x660 && r <= 0x669) || // Arabic-Indic
          (r >= 0x6F0 && r <= 0x6F9); // extended Arabic-Indic
    }

    final offenders = <String>[];
    for (final f in Directory('assets/translations')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        for (final u in units) {
          var at = line.indexOf(u);
          while (at > 0) {
            // A unit counts only when a number leads into it, so prose that
            // merely mentions a unit is not flagged.
            var k = at - 1;
            while (k >= 0 && (line[k] == ' ' || line[k] == ' ')) {
              k--;
            }
            if (k >= 0 && isDigit(line[k])) {
              offenders.add('${f.path}:${i + 1}  ${line.trim()}');
              break;
            }
            at = line.indexOf(u, at + 1);
          }
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'A size written into a sentence goes stale silently — this '
            'one had drifted 39% low. Measure it, put it in AppConfig, and '
            'pass formatBytes() as an argument:\n${offenders.join('\n')}');
  });
}
