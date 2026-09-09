import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/services/recitation_source.dart';

/// `startContinuous(edition:)` names a **reciter**, never a mushaf printing.
///
/// This exists because one call site got that wrong and it was invisible to
/// `flutter analyze`: both are `String`. The Quran reader's per-ayah play
/// handler passed `edition?.id ?? 'hafs_kfqc'` — the *mushaf* id — so every
/// verse resolved to `cdn.islamic.network/quran/audio/128/hafs_kfqc/<n>.mp3`,
/// which 404s. `setAudioSource` threw, the catch arm called
/// `stopContinuous()`, and so picking a verse mid-recitation **stopped** the
/// recitation instead of moving it, which is exactly what the owner reported:
/// «لما بشغل التلاوة المستمرة واجي اختار آية … بتقف التلاوة مش بتشتغل».
///
/// Proven to reproduce before being trusted: with `'hafs_kfqc'` put back at
/// `quran_screen.dart`, the first test below fails naming that line.
void main() {
  final lib = Directory('lib');
  final editions = json.decode(
    File('assets/data/mushaf/editions.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final mushafIds = <String>{
    for (final e in editions['editions'] as List<dynamic>)
      (e as Map<String, dynamic>)['id'] as String,
  };

  /// Every `edition:` argument that appears inside a `startContinuous(` call,
  /// paired with the file and line it came from.
  List<(String file, int line, String value)> continuousEditionArgs() {
    final found = <(String, int, String)>[];
    for (final f in lib.listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!lines[i].contains('startContinuous(')) continue;
        // The argument list runs until the closing paren; scanning a bounded
        // window is enough and keeps this a text test rather than a parser.
        for (var j = i; j < lines.length && j < i + 14; j++) {
          final m = RegExp(r'\bedition:\s*(.+?),\s*$').firstMatch(lines[j]);
          if (m != null) {
            found.add((f.path, j + 1, m.group(1)!.trim()));
            break;
          }
          if (lines[j].contains(');')) break;
        }
      }
    }
    return found;
  }

  test('no startContinuous call passes a mushaf edition id as the reciter', () {
    final args = continuousEditionArgs();
    expect(args, isNotEmpty,
        reason: 'the scan found no startContinuous call sites at all — the '
            'test has stopped testing anything');
    for (final (file, line, value) in args) {
      for (final id in mushafIds) {
        expect(value.contains("'$id'"), isFalse,
            reason: '$file:$line passes the mushaf printing "$id" where a '
                'reciter id belongs: edition: $value');
      }
    }
  });

  test('the default reciter has a verified per-ayah mirror', () {
    // A reciter with no everyayah folder still plays (islamic.network only),
    // but the default one is what a fresh install downloads whole surahs
    // from, so it must be on the resumable, range-serving host.
    expect(RecitationSource.hasVerifiedMirror('ar.minshawimujawwad'), isTrue);
  });

  test('a mushaf id used as a reciter yields no verified mirror', () {
    // The other half of the bug: nothing in the URL builder rejects a wrong
    // id, it just silently produces a 404 path. This pins that fact so the
    // first test is understood as the only guard there is.
    for (final id in mushafIds) {
      expect(RecitationSource.hasVerifiedMirror(id), isFalse);
    }
  });
}
