import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:rafeeq_app/features/library/data/book_speaker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The phone voice and the adhan played at once: flutter_tts asks for audio
/// focus with an empty listener, so nothing ever paused it. BookSpeaker now
/// listens for the interruption itself. These drive it with a fake engine
/// and a hand-made interruption stream - the emulator has no Arabic TTS
/// engine, so this path cannot be heard there.
class _FakeTts extends FlutterTts {
  final spoken = <String>[];
  Completer<void>? _current;

  /// Completes the chunk being "spoken" now.
  void finishChunk() => _current?.complete();

  @override
  Future<dynamic> speak(String text, {bool focus = false}) {
    spoken.add(text);
    _current = Completer<void>();
    return _current!.future;
  }

  @override
  Future<dynamic> stop() async => _current?.complete();
  @override
  Future<dynamic> setLanguage(String language) async => 1;
  @override
  Future<dynamic> setSpeechRate(double rate) async => 1;
  @override
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion) async => 1;
  @override
  Future<dynamic> get getVoices async => const [];
  @override
  Future<dynamic> setVoice(Map<String, String> voice) async => 1;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'book_voice': 'device'});
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  AudioInterruptionEvent ev(bool begin, AudioInterruptionType type) =>
      AudioInterruptionEvent(begin, type);

  test('an adhan pauses the reading and the same chunk is read again after',
      () async {
    final tts = _FakeTts();
    final focus = StreamController<AudioInterruptionEvent>.broadcast();
    final s = BookSpeaker(tts: tts, interruptions: focus.stream);
    final reading = s.speak('الجملة الأولى. الجملة الثانية.');
    for (var i = 0; i < 20 && tts.spoken.isEmpty; i++) {
      await settle();
    }
    expect(tts.spoken, hasLength(1));
    final first = tts.spoken.single;

    focus.add(ev(true, AudioInterruptionType.pause)); // the adhan
    await settle();
    await settle();
    // Stopped mid-chunk, and nothing further is spoken while it holds.
    expect(tts.spoken, hasLength(1));

    focus.add(ev(false, AudioInterruptionType.pause)); // adhan over
    await settle();
    await settle();
    expect(tts.spoken, hasLength(2));
    expect(tts.spoken.last, first, reason: 'the interrupted chunk again');

    tts.finishChunk();
    for (var i = 0; i < 20 && s.isSpeaking; i++) {
      await settle();
    }
    await reading.timeout(const Duration(seconds: 2));
    await focus.close();
  });

  test('losing the focus for good stops the reading', () async {
    final tts = _FakeTts();
    final focus = StreamController<AudioInterruptionEvent>.broadcast();
    final s = BookSpeaker(tts: tts, interruptions: focus.stream);
    final reading = s.speak('الجملة الأولى. الجملة الثانية.');
    for (var i = 0; i < 20 && tts.spoken.isEmpty; i++) {
      await settle();
    }
    focus.add(ev(true, AudioInterruptionType.unknown));
    await reading.timeout(const Duration(seconds: 2));
    expect(s.isSpeaking, isFalse);
    expect(tts.spoken, hasLength(1));
    await focus.close();
  });

  test('a duck does not stop the reading', () async {
    final tts = _FakeTts();
    final focus = StreamController<AudioInterruptionEvent>.broadcast();
    final s = BookSpeaker(tts: tts, interruptions: focus.stream);
    final reading = s.speak('جملة واحدة فقط.');
    for (var i = 0; i < 20 && tts.spoken.isEmpty; i++) {
      await settle();
    }
    focus.add(ev(true, AudioInterruptionType.duck));
    await settle();
    expect(s.isSpeaking, isTrue);
    tts.finishChunk();
    await reading.timeout(const Duration(seconds: 2));
    expect(tts.spoken, hasLength(1));
    await focus.close();
  });
}
