import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// No screen builds a «a / b» pair by hand — they all go through `ratio()`.
///
/// WHY THIS TEST EXISTS, and it is not the bug it guards against.
///
/// The bug is Unicode bidi rule N1: a neutral sitting BETWEEN two numbers
/// resolves to R, so `'$a / $b'` paints backwards in Arabic. That is proved
/// on the rendering side by `ratio_direction_test.dart`, and fixed by
/// `ratio()` in `lib/core/utils/byte_formatter.dart`.
///
/// What went wrong the first time was the SEARCH, not the fix. The tree was
/// swept for the literal shape `'$a / $b'`, which found six sites and missed
/// eight more — every one where the pair sat behind a `.tr()}` prefix
/// (`'${'downloads.paused'.tr()} · $done / $total'`) or behind an expression
/// (`'${_pageIndex + 1} / ${doc.pages.length}'`, the book reader's own page
/// counter). Those render exactly the same way and were exactly as broken.
///
/// So the honest guard is not "did we fix the ones we found", it is "can the
/// shape exist in the tree at all". This walks every Dart file under lib/ and
/// fails on any string literal that joins two interpolations with a spaced
/// neutral separator.
///
/// NOT flagged, deliberately: `'$surah:$ayah'`. A colon with **no spaces**
/// around it is a Common Separator directly between two numbers, so bidi rule
/// W4 absorbs it into the number run and `2:255` stays `2:255`. It is the
/// SPACES that defeat W4 and hand the separator to N1. Flagging the tight
/// form would be noise, and worse, it would teach the next reader that the
/// colon is the problem when the spaces are.
/// The separator class is `/` and `×` only. An EM DASH is deliberately
/// not in it: the app uses one to join two ARABIC runs — «القارئ — السورة»,
/// «الدرجة — المخرِّج» — and a neutral between two R runs resolves to R,
/// which is the order those are supposed to paint in. Including it flagged
/// four such lines as defects on this test's first run. N1 only reverses the
/// pair when the operands are numbers.
///
/// A HYPHEN is not in the class either, for a duller reason: Dart writes
/// subtraction inside an interpolation, so `'${out.length - n}...'` is
/// arithmetic, not a separator. It matched `time_formatter.dart` on this
/// test's second run. The proven defect is the solidus; that is what is
/// guarded.
void main() {
  test('no hand-built «a / b» pair survives anywhere under lib/', () {
    // Two interpolations joined by whitespace + a neutral + whitespace.
    final shape = RegExp(
      r"'[^'\n]*\$[A-Za-z_{][^'\n]*?[   ][/×]"
      r"[   ][^'\n]*?\$[A-Za-z_{][^'\n]*'",
    );

    final offenders = <String>[];
    final lib = Directory('lib');
    for (final f in lib.listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      // byte_formatter.dart is where the separator legitimately lives.
      if (f.path.replaceAll(r'\', '/').endsWith('core/utils/byte_formatter.dart')) {
        continue;
      }
      final lines = f.readAsStringSync().split('\n');
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // A URL or a query is not a label a reader ever sees.
        if (line.contains('http') || line.contains('://')) continue;
        for (final m in shape.allMatches(line)) {
          offenders.add('${f.path}:${i + 1}  ${m.group(0)}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'These build a number pair by hand, so they will paint '
          'backwards in Arabic. Use ratio() from byte_formatter.dart:\n'
          '${offenders.join('\n')}',
    );
  });

  test('the same shape is absent from the translation files too', () {
    // The fourteenth site was not in Dart at all: `ayah_dl.ayahs_progress`
    // was "{} / {} <noun>" in all seven locales, so the pair was assembled
    // by the translation file and no Dart fix could have reached it.
    // Same separator class, and for the same reason: `now_downloading` is
    // "{} — {}" in all seven locales and joins a RECITER to a SURAH NAME.
    // Two text runs either side of an em dash paint right-to-left in Arabic,
    // which is correct. Only a number pair reverses.
    final pairInString = RegExp(r'\{\}\s*[/×-]\s*\{\}');
    final bad = <String>[];
    for (final f in Directory('assets/translations')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))) {
      final text = f.readAsStringSync();
      for (final m in pairInString.allMatches(text)) {
        // Report the enclosing line so the key is identifiable.
        final upto = text.substring(0, m.start);
        final lineNo = '\n'.allMatches(upto).length + 1;
        bad.add('${f.path}:$lineNo  ${m.group(0)}');
      }
    }
    expect(
      bad,
      isEmpty,
      reason: 'A translation string must not join two placeholders with a '
          'separator — build the pair with ratio() and pass it as one '
          'argument:\n${bad.join('\n')}',
    );
  });

  test('nobody rebuilds the pair as a Row of Texts either', () {
    // THE SECOND WRONG FIX, which shipped and was reported as done.
    //
    // The tasbeeh counter was "fixed" by splitting «$count / $target» into
    // three Text widgets in a Row, on the reasoning that three Texts share no
    // paragraph so bidi rule N1 has no neutral to resolve. That reasoning is
    // correct and the counter STILL rendered «33 / 2» on emulator-5554 —
    // because a Row lays its children along the ambient Directionality, and
    // under RTL the FIRST child goes on the RIGHT. One reordering had simply
    // been traded for another.
    //
    // So the separator-as-its-own-widget shape is banned outright. If a
    // future layout genuinely needs it, it needs an explicit Directionality
    // around the Row and a screenshot proving the order.
    final sepWidget = RegExp(r"""Text\(\s*['"]\s*[/×]\s*['"]""");
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final lines = f.readAsStringSync().split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (sepWidget.hasMatch(lines[i])) {
          offenders.add('${f.path}:${i + 1}  ${lines[i].trim()}');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'A bare separator in its own Text gets reordered by the Row '
            'that holds it. Use ratio():\n${offenders.join('\n')}');
  });
}
