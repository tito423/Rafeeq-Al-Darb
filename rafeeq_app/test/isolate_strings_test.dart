import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The download notification shipped reading `notif.dl_recit_running_title` —
/// the key itself, in the owner's notification shade.
///
/// The keys were never missing. `DownloadEngine.ensureInitialized` calls
/// `.tr()`, and `.tr()` resolves through `Localization.instance`, which does
/// not exist outside the `EasyLocalization` widget tree — a headless
/// `background_downloader` isolate gets the key back and says nothing about
/// it. `IsolateStrings` reads the same JSON asset instead.
///
/// Two things are pinned here:
///
///  * every key the engine looks up really is in all seven locale files, so
///    the async path cannot fall through to returning a key either;
///  * the engine does not go back to `.tr()`, which would compile, analyze
///    clean, and silently reproduce the screenshot.
void main() {
  final engine = File('lib/core/services/download_engine.dart').readAsStringSync();

  test('the engine resolves its notification strings off the asset', () {
    expect(engine.contains("'.tr()"), isFalse,
        reason: 'download_engine.dart runs where Localization.instance does '
            'not exist; .tr() there returns the key. Use IsolateStrings.tr.');
    expect(engine.contains('IsolateStrings.tr('), isTrue);
  });

  test('every key it looks up exists in all 7 locales', () {
    final keys = RegExp(r"IsolateStrings\.tr\('([^']+)'\)")
        .allMatches(engine)
        .map((m) => m.group(1)!)
        .toSet();
    expect(keys, isNotEmpty, reason: 'the lookup pattern stopped matching');

    final files = Directory('assets/translations')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList();
    expect(files.length, 7);

    final missing = <String>[];
    for (final f in files) {
      final map = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      for (final key in keys) {
        dynamic node = map;
        for (final part in key.split('.')) {
          node = node is Map<String, dynamic> ? node[part] : null;
        }
        if (node is! String || node.isEmpty) {
          missing.add('${f.uri.pathSegments.last}: $key');
        }
      }
    }
    expect(missing, isEmpty, reason: missing.join('\n'));
  });
}
