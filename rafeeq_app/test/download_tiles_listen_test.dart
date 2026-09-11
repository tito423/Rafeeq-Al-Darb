import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The mushaf download card has to SUBSCRIBE to the download it shows.
///
/// v3.17.0–3.17.2 shipped with `_progress.addListener(_onProgress);` glued to
/// the end of the comment line above it — a patch script dropped the newline —
/// so the call was part of the comment. `flutter analyze` was clean, every
/// test passed, and on a fresh install the owner pressed «تحميل» and the card
/// sat on «0 / 604» with its button, while the service notification already
/// read «157 / 604». «زراير تحميل المصاحف مش شغالة في الواجهة».
///
/// This fails on that source: it looks for the call at the start of a code
/// line, not anywhere in the file.
void main() {
  for (final path in [
    'lib/features/downloads/presentation/widgets/mushaf_download_tile.dart',
    'lib/features/downloads/presentation/widgets/mushaf_preview_sheet.dart',
  ]) {
    test('$path subscribes to the download progress', () {
      final lines = File(path).readAsLinesSync();
      final live = lines.where(
        (l) => l.trimLeft().startsWith('_progress.addListener(_onProgress);'),
      );
      expect(live, isNotEmpty,
          reason: 'the listener is missing or commented out, so the card '
              'never moves while its download runs');
    });
  }
}
