import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/services/audio_failure.dart';

/// The line the reader is shown when nothing plays.
///
/// It exists because «التلاوة مش شغالة» arrived with nothing to act on: the
/// app caught the exception in a bare `catch (_)`, threw away both the host
/// and the reason, and showed one untranslatable-into-usefulness sentence.
/// Whatever this returns ends up in a screenshot, so it has to name the host
/// and say which KIND of failure it was.
void main() {
  const url = 'https://everyayah.com/data/Alafasy_128kbps/001001.mp3';

  test('names the host', () {
    expect(
      AudioFailure.describe(url, Exception('x')),
      startsWith('everyayah.com'),
    );
  });

  test('tells a timeout from a refusal from a certificate', () {
    expect(AudioFailure.describe(url, TimeoutException('x')),
        contains('timeout'));
    expect(
      AudioFailure.describe(
          url, const HandshakeException('CERTIFICATE_VERIFY_FAILED')),
      contains('ssl'),
    );
    expect(
      AudioFailure.describe(
          url, const SocketException('Failed host lookup: everyayah.com')),
      contains('dns'),
    );
    expect(
      AudioFailure.describe(
          url, const SocketException('Connection refused')),
      contains('network'),
    );
  });

  test('carries an HTTP status through, which is how a 403 would have shown',
      () {
    // The 157 unplayable reciters answered 403 for months in silence.
    final line = AudioFailure.describe(
      'https://cdn.islamic.network/quran/audio/128/ar.ahmedalhammad/1.mp3',
      Exception('Source error: response status code: 403'),
    );
    expect(line, contains('cdn.islamic.network'));
    expect(line, contains('403'));
  });

  test('a host that answered nothing at all still gets a line', () {
    final line = AudioFailure.describe(url, StateError('boom'));
    expect(line, contains('everyayah.com'));
    expect(line.trim(), isNot('everyayah.com —'));
  });
}
