/// WHY THE LAST RECITATION DID NOT START — in a form the owner can
/// photograph and send.
///
/// «التلاوة في التلاوة المستمرة مش شغالة بعد ما اختار القارئ، ولا حتى في
/// الحفظ والتسميع» arrived with nothing to act on, and the app knew more
/// than it said: it had the host and it had the exception, and threw both
/// away in a bare `catch (_)`. A screen that asked for audio and got none
/// now reads this and shows it.
///
/// It lives in its own file rather than on `AyahAudioService` because that
/// file is at the ceiling `code_layout_test` holds it to — and because
/// "what went wrong" is not playback.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../db/models.dart';
import 'recitation_source.dart';

class AudioFailure {
  AudioFailure._();

  static final AudioFailure instance = AudioFailure._();

  /// Set on every failed start, cleared on every successful one, so what a
  /// screen reads after a press belongs to that press.
  final ValueNotifier<String?> last = ValueNotifier<String?>(null);

  void clear() => last.value = null;

  void record(String url, Object error) => last.value = describe(url, error);

  /// The same, for continuous recitation, which builds its own URLs per
  /// attempt: attempt 2 is the run that asks the reciter's OTHER host, so
  /// that is the one named. Working it out here rather than at the throw
  /// keeps `ayah_audio_service.dart` under the ceiling `code_layout_test`
  /// holds it to.
  void recordContinuous(
    String edition,
    Ayah first,
    int firstGlobal,
    int attempt,
    Object error,
  ) {
    final urls = RecitationSource.urlsFor(
      edition: edition,
      surah: first.surahId,
      ayah: first.ayahNumber,
      globalAyah: firstGlobal,
    );
    record(urls[(attempt == 2 ? 1 : 0).clamp(0, urls.length - 1)], error);
  }

  /// One line: the host that refused, and what kind of refusal it was.
  ///
  /// Deliberately NOT translated. «تعذّر الاتصال» in seven languages still
  /// does not say which host answered what, and this exists to be read by
  /// whoever has to fix it.
  static String describe(String url, Object error) {
    final host = Uri.tryParse(url)?.host ?? '?';
    final text = error.toString();
    String kind;
    if (error is TimeoutException) {
      kind = 'timeout';
    } else if (text.contains('CERTIFICATE') ||
        text.contains('HandshakeException')) {
      kind = 'ssl';
    } else if (text.contains('Failed host lookup')) {
      kind = 'dns';
    } else if (text.contains('SocketException')) {
      kind = 'network';
    } else {
      final code = RegExp(r'status\s*code:?\s*(\d{3})', caseSensitive: false)
          .firstMatch(text)
          ?.group(1);
      // The bare type is useless in a screenshot: just_audio reports a dead
      // host as `PlayerException`, and it is the MESSAGE that says
      // `UnknownHostException` or `Source error`. Keep the text, trimmed.
      final flat = text.replaceAll(RegExp(r'\s+'), ' ').trim();
      kind = code != null
          ? 'http $code'
          : (flat.length > 90 ? '${flat.substring(0, 90)}…' : flat);
    }
    return '$host — $kind';
  }
}
