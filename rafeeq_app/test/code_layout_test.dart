import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The two rules the reorganisation established, so they cannot quietly rot
/// back.
///
/// WHY THIS EXISTS. Three files had grown to 1,625, 1,543 and 1,700 lines with
/// twenty-five, twenty and fourteen classes inside them. Nothing was wrong
/// with any single commit that added to them; each one added ten lines to a
/// file that was already long. That is how a file gets to 1,625 lines, and
/// `flutter analyze` has no opinion about it at any point along the way.
///
/// Splitting them also *found* things, which is the argument for the rule
/// rather than for the tidiness: `_BookCard` turned out to be drawn by two
/// different tabs while being private to the file that held both, and the
/// mushaf toolbar's three "text mushaf only" guards turned out to be three
/// different shapes of one condition.
void main() {
  final dartFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  /// Files that were already over the ceiling when it was introduced, with
  /// the length they had that day. They are allowed to exist; they are not
  /// allowed to GROW. Shrink one below the ceiling and delete its line.
  ///
  /// `book_catalog.dart` is the one permanent entry: it is 226 books' worth of
  /// catalogue rows, generated and appended to, and splitting a data file by
  /// line count would buy nothing.
  const grandfathered = <String, int>{
    'lib/features/library/data/book_catalog.dart': 4063,
    'lib/features/library/presentation/screens/book_text_reader_screen.dart': 1156,
    // The remaining 1,047 are almost entirely one State class. Breaking it up
    // is a controller extraction, not a move — see REFACTOR.md stage 3b.
    'lib/features/quran/presentation/screens/quran_screen.dart': 1047,
    'lib/features/quran/presentation/widgets/mushaf_text_page.dart': 991,
    'lib/features/quran_audio/presentation/player_screen.dart': 949,
    'lib/features/downloads/presentation/screens/downloads_screen.dart': 870,
    'lib/features/khatma/presentation/khatma_screen.dart': 859,
    'lib/features/adhan/presentation/screens/adhan_settings_screen.dart': 855,
    'lib/features/home/presentation/widgets/analog_clock_faces.dart': 828,
    'lib/core/services/ayah_audio_service.dart': 810,
  };

  const ceiling = 800;

  test('no file in lib/ grows past $ceiling lines', () {
    final tooLong = <String>[];
    for (final file in dartFiles) {
      final path = file.path.replaceAll(r'\', '/');
      final lines = file.readAsLinesSync().length;
      final allowed = grandfathered[path];
      if (allowed != null) {
        expect(lines, lessThanOrEqualTo(allowed),
            reason: '$path was $allowed lines when the ceiling was set and is '
                '$lines now. It is on the list because it was already over, '
                'not so it could keep growing — split it, or take what you '
                'are adding somewhere else.');
        continue;
      }
      if (lines > ceiling) tooLong.add('$path ($lines)');
    }
    expect(tooLong, isEmpty,
        reason: 'over $ceiling lines and not grandfathered:\n'
            '${tooLong.join('\n')}\n'
            'Split it the way library_screen, ayah_sciences_sheet and '
            'quran_screen were split: one screen or widget per file, the '
            'catalogue in data/.');
  });

  test('no catalogue or data list is declared inside presentation/', () {
    // A top-level `const xs = <T>[...]` or `final xs = <T>{...}` in a screen
    // file is content, and content inside a screen is invisible to everything
    // that is not that screen. That is literally how the app came to have TWO
    // channel lists with different entries, one of them on a screen with no
    // route to it, while the About page counted the unreachable one.
    final declaration = RegExp(
      r'^(?:const|final)\s+[A-Za-z_][A-Za-z0-9_<>,?\s]*\s*=\s*(?:const\s*)?<',
      multiLine: true,
    );
    final offenders = <String>[];
    for (final file in dartFiles) {
      final path = file.path.replaceAll(r'\', '/');
      if (!path.contains('/presentation/')) continue;
      final source = file.readAsStringSync();
      for (final m in declaration.allMatches(source)) {
        final line = '\n'.allMatches(source.substring(0, m.start)).length + 1;
        offenders.add('$path:$line  ${m.group(0)!.trim()}');
      }
    }
    expect(offenders, isEmpty,
        reason: 'these belong in the feature\'s data/ folder:\n'
            '${offenders.join('\n')}');
  });
}
