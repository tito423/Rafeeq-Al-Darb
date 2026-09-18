// A throwaway entry point, not part of the app: built with
// `flutter build apk --debug --target=tool/tts_samples_main.dart`, it asks the
// device's TTS engine to speak the same sentences in every Arabic voice it
// has, and writes each to a WAV in the app's cache for `adb run-as` to pull.
//
// Why: the owner asked for a MAN's voice («عاوزه رجل مش انثى لأنه تطبيق
// إسلامي») and for the divine name to be read with tafkhim. Voice names say
// nothing about sex, and a pronunciation is judged by ear. So the samples are
// measured (fundamental frequency, on the host) and sent to him to hear.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';

const probe = 'قالَ رسولُ اللَّهِ صلَّى اللَّهُ عليه وسلَّم: '
    'إنَّ اللَّهَ لم يُنزِلْ داءً إلا أنزلَ له دواءً.';

/// Spellings of the divine name to compare, in one carrier sentence each.
const jalala = <String, String>{
  'a_diacritised': 'واتَّقُوا اللَّهَ، إنَّ اللَّهَ غفورٌ رحيم.',
  'b_bare': 'واتقوا الله، إن الله غفور رحيم.',
  'c_dagger_alif': 'واتَّقُوا ٱللَّٰهَ، إنَّ ٱللَّٰهَ غفورٌ رحيم.',
  'd_ligature': 'واتَّقُوا ﷲ، إنَّ ﷲ غفورٌ رحيم.',
  'e_shadda_only': 'واتقوا اللّه، إن اللّه غفور رحيم.',
};

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final status = ValueNotifier<String>('starting');
  runApp(MaterialApp(
    home: Scaffold(
      body: Center(
        child: ValueListenableBuilder<String>(
          valueListenable: status,
          builder: (_, s, _) => Text(s, textDirection: TextDirection.ltr),
        ),
      ),
    ),
  ));

  final tts = FlutterTts();
  await tts.awaitSynthCompletion(true);
  await tts.setLanguage('ar');
  final dir = Directory('${(await getTemporaryDirectory()).path}/tts');
  if (dir.existsSync()) dir.deleteSync(recursive: true);
  dir.createSync(recursive: true);

  final voices = ((await tts.getVoices) as List)
      .whereType<Map>()
      .map((v) => v.map((k, val) => MapEntry('$k', '$val')))
      .where((v) => (v['locale'] ?? '').toLowerCase().startsWith('ar'))
      .toList();
  final log = StringBuffer();
  for (final v in voices) {
    log.writeln(v);
    status.value = 'voice ${v['name']}';
    await tts.setVoice({'name': v['name']!, 'locale': v['locale']!});
    await tts.synthesizeToFile(probe, '${dir.path}/voice__${v['name']}.wav', true);
  }
  File('${dir.path}/voices.txt').writeAsStringSync(log.toString());
  // Every spelling in every LOCAL voice; the male ones are picked on the host.
  for (final v in voices.where((v) => (v['name'] ?? '').contains('-local'))) {
    await tts.setVoice({'name': v['name']!, 'locale': v['locale']!});
    for (final e in jalala.entries) {
      status.value = '${v['name']} ${e.key}';
      await tts.synthesizeToFile(
          e.value, '${dir.path}/jalala__${v['name']}__${e.key}.wav', true);
    }
  }
  // Round three (2026-09-18): tafkhim of the divine name, MEASURED. A
  // heavy lam backs the long vowel after it: its second formant (F2) sits
  // low, ~1000-1300 Hz in a man's voice; a light one (بِاللَّهِ, correctly
  // light after kasra) sits ~1600+. Each spelling is spoken ALONE so the
  // host can read F2 off its vowel.
  const alone = <String, String>{
    'h_diac': 'اللَّهُ',
    'h_bare': 'الله',
    'h_alif': 'اللّاه',
    'h_alif2': 'اللَّاهُ',
    'h_hamza': 'أَللَّهُ',
    'h_lig': 'ﷲ',
    'l_billah': 'بِاللَّهِ',
    'h_ssml': '<speak><phoneme alphabet="ipa" ph="ʔɑlˤˈlˤɑːh">اللَّهُ</phoneme></speak>',
  };
  for (final vname in const ['ar-xa-x-ard-local', 'ar-xa-x-ard-network']) {
    await tts.setVoice({'name': vname, 'locale': 'ar'});
    await tts.setPitch(1.0);
    await tts.setSpeechRate(0.38);
    for (final e in alone.entries) {
      status.value = '$vname ${e.key}';
      await tts.synthesizeToFile(e.value, '${dir.path}/allah__${vname}__${e.key}.wav', true);
    }
  }
  status.value = 'DONE ${voices.length}';
}
