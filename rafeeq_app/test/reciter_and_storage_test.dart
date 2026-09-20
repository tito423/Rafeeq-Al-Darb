import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Two holes the owner found by using the app, 2026-09-20.
///
/// 1. «لما بشغل تكرار فالمنشاوي بيشتغل لوحده حتى لو اخترت قارئ غيره».
///    `AyahAudioService.playQueue` and `playRepeated` took
///    `String edition = defaultEdition` - `ar.minshawimujawwad` - and two
///    call sites never passed one: the memorisation repeat on the ayah card
///    and «تشغيل الكل» on a search topic. Everything else passed
///    `selectedReciterProvider`, so the app looked like it honoured the
///    reader's choice and two paths quietly did not. The parameter is
///    `required` now; the compiler found the second one.
///
/// 2. «قاعدة بيانات الحديث في التنزيلات مش شغالة». The storage hub sized
///    every bucket from `DownloadManager`'s artifact registry, and
///    `hadith.db` does not come from there - it is unpacked from the bundled
///    `hadith.zip`. So the row read zero with 109,731,840 bytes behind it and
///    «تفريغ» freed nothing. `quran_sciences.db` had the same hole for any
///    install that adopted the old bundled copy.
void main() {
  String read(String path) {
    final f = File(path);
    expect(f.existsSync(), isTrue, reason: '$path is missing');
    return f.readAsStringSync();
  }

  test('a reciter can no longer be left to a default', () {
    final service = read('lib/core/services/ayah_audio_service.dart');
    for (final method in ['playQueue', 'playRepeated']) {
      final start = service.indexOf('Future<void> $method(');
      expect(start, greaterThan(-1), reason: '$method is gone');
      final signature = service.substring(start, service.indexOf('}', start));
      expect(signature, contains('required String edition'),
          reason: '$method took a default reciter again; a caller that '
              'forgets it plays al-Minshawi whoever the reader chose');
      expect(signature, isNot(contains('String edition = ')),
          reason: '$method must not default its reciter');
    }
  });

  test('both queue call sites pass the reader’s own reciter', () {
    for (final path in [
      'lib/features/quran/presentation/widgets/ayah_sciences/sciences_header.dart',
      'lib/features/search/presentation/screens/search_screen.dart',
    ]) {
      final source = read(path);
      expect(source, contains('selectedReciterProvider'), reason: path);
      expect(source, contains('edition: ref.read(selectedReciterProvider)'),
          reason: '$path starts playback without naming the reciter');
    }
  });

  test('the repeat banner ends with the audio, not with a timer', () {
    final header = read('lib/features/quran/presentation/widgets/'
        'ayah_sciences/sciences_header.dart');
    // It was a 4-second SnackBar and the owner photographed it still sitting
    // over the Downloads screen and the mushaf minutes later; reproduced on
    // emulator-5554, still there after a tab switch and a restart of the
    // reading. The banner is closed by the playback future completing now.
    expect(header, contains('rootScaffoldMessengerKey'),
        reason: 'show it on the app-level messenger, not a sheet’s');
    expect(header, contains('repeat.whenComplete'),
        reason: 'the banner has to be closed when the audio stops');
    expect(header, isNot(contains("duration: const Duration(seconds: 4)")),
        reason: 'a timed toast for audio that is still playing is what stuck');
  });

  test('the SnackBar action has a colour of its own', () {
    final theme = read('lib/core/theme/app_theme.dart');
    expect(theme, contains('actionTextColor:'),
        reason: 'Material’s default action colour is for ITS dark SnackBar; '
            'on this pale one «إيقاف» was invisible');
  });

  test('the storage hub measures the two databases it cannot see as artifacts',
      () {
    final controller =
        read('lib/features/downloads/data/downloads_controller.dart');
    expect(controller, contains("downloadedDbBytes('hadith.db')"));
    expect(controller, contains("downloadedDbBytes('quran_sciences.db')"));
    final free =
        controller.substring(controller.indexOf('Future<void> freeCategory'));
    expect(free, contains("deleteDownloaded('hadith.db')"),
        reason: '«تفريغ» on the hadith row has to remove the real file');
    expect(free, contains("deleteDownloaded('quran_sciences.db')"));
  });
}
