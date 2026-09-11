import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A full recitation downloads in surah order, and a surah that is only
/// waiting in the native queue says so.
///
/// background_downloader's HoldingQueue releases tasks by priority, then by
/// `creationTime`. All 110 tasks of a recitation were created in the same
/// millisecond, so the release order was arbitrary — on the emulator surahs
/// 3, 4, 7, 10, 15, 9, 18, 2 went first and al-Fatiha was still held after
/// sixteen others had finished. Its `enqueued` status was shown as a running
/// 0% bar, and the reciter card announced «جارٍ تنزيل سورة الفاتحة — 0%».
void main() {
  final lib = File('lib/features/quran_audio/data/quran_audio_library.dart')
      .readAsStringSync();

  test('each task carries its own creation time', () {
    final at = lib.indexOf('void _enqueue(');
    expect(at, greaterThan(0));
    final body = lib.substring(at, lib.indexOf('void _onUpdate(', at));
    expect(body, contains('creationTime:'));
    expect(lib, contains('_enqueue(e, want[i], at: batch.add(Duration(milliseconds: i)))'));
  });

  test('a held task is queued, not running', () {
    final at = lib.indexOf('status == TaskStatus.enqueued');
    expect(at, greaterThan(0));
    final branch = lib.substring(at, at + 260);
    expect(branch, contains('SurahAudioState.queued'));
    expect(branch, isNot(contains('SurahAudioState.running')));
  });
}
