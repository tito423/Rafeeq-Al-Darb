import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rafeeq_app/features/library/data/tts_probe.dart';

/// THE experiment the spoken-reader feature rests on.
///
/// The owner asked for a reader that speaks the library's books, and asked
/// for it «متقن». The obstacle is measured rather than assumed: across a
/// random sample of 24 books the median diacritisation is 35.6%, ten are
/// under 20% and seven over 60%. So most books would have to be vowelled by
/// a model before anything could read them aloud correctly.
///
/// All of that work is wasted unless one thing is true first: that the
/// device's Arabic voice READS the harakat instead of discarding them.
/// Nobody's documentation answers it — `flutter_tts` is a wrapper, and
/// whether a voice honours combining marks is that voice's own behaviour.
///
/// So this synthesises MINIMAL PAIRS — one consonantal skeleton, two
/// vowellings that are two different words — to separate WAV files and
/// compares the bytes. Identical bytes mean the vowels were thrown away.
///
/// Run it against a device, not the test VM:
///
///     flutter test integration_test/tts_harakat_test.dart -d emulator-5554
///
/// It WRITES ITS ANSWER to tts_probe_result.txt in the app's documents
/// directory and prints it, so the finding is a record rather than a memory.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('does the Arabic voice honour harakat', (tester) async {
    final probe = TtsProbe();
    final report = StringBuffer();

    final langs = await probe.languages();
    final voices = await probe.arabicVoices();
    report.writeln('Arabic languages offered : $langs');
    report.writeln('Arabic voices offered    : ${voices.length}');
    for (final v in voices) {
      report.writeln('  ${v['name']}  (${v['locale']})');
    }

    if (langs.isEmpty) {
      report.writeln('\nVERDICT: the device offers NO Arabic TTS at all.');
      report.writeln('A spoken reader cannot be built on this engine here.');
      await _save(report.toString());
      // Not a failure of the app — a fact about the device, recorded.
      return;
    }

    final files = await probe.synthesiseAll();
    report.writeln('\nsynthesised ${files.length} files');

    var identical = 0;
    var differing = 0;
    for (final entry in TtsProbe.pairs.entries) {
      final a = files['${entry.key}_0'];
      final b = files['${entry.key}_1'];
      if (a == null || b == null) {
        report.writeln('${entry.key}: MISSING OUTPUT');
        continue;
      }
      final ba = await a.readAsBytes();
      final bb = await b.readAsBytes();
      final same = ba.length == bb.length &&
          List.generate(ba.length, (i) => ba[i] == bb[i]).every((x) => x);
      if (same) {
        identical++;
      } else {
        differing++;
      }
      report.writeln('${entry.key}: ${entry.value[0]} vs ${entry.value[1]}  '
          '-> ${ba.length} B vs ${bb.length} B  '
          '${same ? "IDENTICAL (harakat ignored)" : "different (harakat read)"}');
    }

    report.writeln('\nidentical pairs: $identical   differing pairs: $differing');
    if (differing == 0 && identical > 0) {
      report.writeln('VERDICT: this voice DISCARDS harakat. Diacritising the '
          'books would change nothing it says, so the spoken reader cannot be '
          'made correct on this engine.');
    } else if (differing > 0 && identical == 0) {
      report.writeln('VERDICT: this voice READS harakat. Vowelling the text '
          'does change what is spoken, so the reader is worth building — and '
          'the remaining problem is the quality of the vowelling.');
    } else if (identical == 0 && differing == 0) {
      report.writeln('VERDICT: NOTHING WAS SYNTHESISED. This is a fault in the '
          'probe or the engine, not an answer about harakat — do not read it '
          'as one.');
    } else {
      report.writeln('VERDICT: MIXED — it reads some and not others. Treat as '
          'unreliable until each pair is examined.');
    }

    await _save(report.toString());
  });
}

Future<void> _save(String text) async {
  // ignore: avoid_print
  print('\n===== TTS PROBE =====\n$text=====================\n');
  final dir = await getApplicationDocumentsDirectory();
  await File('${dir.path}/tts_probe_result.txt').writeAsString(text);
}
