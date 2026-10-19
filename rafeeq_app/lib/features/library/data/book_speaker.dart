import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/services/audio_exclusive.dart';
import 'tts/book_voice_pref.dart';
import 'tts/open_voice.dart';

/// Reads a book's page aloud, one sentence at a time.
///
/// WHAT THIS IS ALLOWED TO READ, and why that is the whole design. Arabic
/// without harakat is genuinely ambiguous — one consonantal skeleton is
/// several different words — so in a scholarly religious text a wrong vowel
/// is a wrong MEANING, not a wrong accent. Every book in the catalogue
/// therefore carries `diacritisedPct`, measured against the hosted text, and
/// only a book at or above 80% is offered to this class. 83 of 213 qualify.
///
/// That the voice actually USES the harakat was established before any of
/// this was written, by `integration_test/tts_harakat_test.dart`: four
/// minimal pairs — كَتَبَ/كُتُبٌ, عِلْمٌ/عَلَمٌ, سَأَلَ/سُئِلَ, رَجُلٌ/رَجُلًا —
/// synthesised to separate files and compared byte for byte. All four differ,
/// reproducibly. If they had matched, this class would not exist.
///
/// THE TEXT IS NEVER NORMALISED ON THE WAY IN. Every other Arabic path in
/// this app strips diacritics to compare or to search; this one is the exact
/// opposite, and passes the book's own vowelled text through untouched. The
/// harakat are the entire point.
class BookSpeaker {
  BookSpeaker({FlutterTts? tts, Stream<AudioInterruptionEvent>? interruptions})
    : _tts = tts ?? FlutterTts(),
      _interruptions = interruptions;

  final FlutterTts _tts;
  bool _disposed = false;
  static BookSpeaker? _owner;
  static Future<void>? _handoff;
  static Future<void>? _nativeStops;

  bool _current(int gen) => !_disposed && gen == _gen;

  /// Serialise claims, not utterances: stop must interrupt a speaking chunk.
  Future<bool> _claim(int gen) async {
    final previous = _handoff;
    final finished = Completer<void>();
    _handoff = finished.future;
    try {
      if (previous != null) await previous;
      if (!_current(gen)) return false;
      await AudioExclusive.silenceAll();
      if (!_current(gen)) return false;
      await _nativeStops;
      if (!_current(gen)) return false;
      _owner = this;
      AudioExclusive.speakerStarted(stop);
      return true;
    } finally {
      finished.complete();
      if (identical(_handoff, finished.future)) _handoff = null;
    }
  }

  void _finish(int gen, int index, int total) {
    if (!_current(gen)) return;
    if (identical(_owner, this)) _owner = null;
    AudioExclusive.speakerStopped(stop);
    _speaking = false;
    _emit(BookSpeakerState(speaking: false, chunk: index, total: total));
  }

  /// Audio-focus interruptions for the phone voice. flutter_tts 4.2.5 asks
  /// for focus with an EMPTY change listener, so nothing paused it: the
  /// adhan and a page being read played at once (seen with the open voice
  /// on emulator-5554, 2026-09-24; its native player now handles focus
  /// itself). Null: the app's AudioSession. A test passes its own.
  final Stream<AudioInterruptionEvent>? _interruptions;

  /// Set while another sound (the adhan, a call) holds the focus; the
  /// reading loop waits on it, then reads the interrupted chunk again.
  Completer<void>? _held;

  Future<StreamSubscription<AudioInterruptionEvent>?> _watchFocus(
    int gen,
  ) async {
    var events = _interruptions;
    if (events == null) {
      try {
        final session = await AudioSession.instance;
        if (!_current(gen)) return null;
        await session.setActive(true);
        if (!_current(gen)) return null;
        events = session.interruptionEventStream;
      } catch (e) {
        debugPrint('BookSpeaker: no audio session: $e');
        return null;
      }
    }
    return events.listen((e) {
      if (!_current(gen) || !_speaking || !identical(_owner, this)) return;
      if (!e.begin) {
        final h = _held;
        _held = null;
        h?.complete();
      } else if (e.type == AudioInterruptionType.unknown) {
        unawaited(stop()); // focus gone for good: another app's audio
      } else if (e.type == AudioInterruptionType.pause && _held == null) {
        _held = Completer<void>();
        unawaited(_tts.stop());
      }
    });
  }

  /// Android's `TextToSpeech` refuses an utterance past a platform maximum,
  /// so a page has to be cut up regardless of how it reads. Cutting on
  /// SENTENCES rather than a character count also gives the voice its
  /// prosody: a clause broken mid-way is read with the wrong intonation even
  /// when every phoneme is right.
  static const _maxChunk = 3500;

  /// Arabic full stop, question mark and the sentence-ending marks a Shamela
  /// text actually uses, including «؛» and the ayah separator, so a chunk
  /// ends where the author ended a thought.
  static final _sentenceEnd = RegExp(r'[.؟!؛۔]+\s*');

  bool _speaking = false;
  bool get isSpeaking => _speaking;

  final _stateController = StreamController<BookSpeakerState>.broadcast();
  Stream<BookSpeakerState> get state => _stateController.stream;

  /// Stops and loops still running after the reader closed (dispose) must
  /// not write to the closed stream - «Cannot add new events after calling
  /// close», seen when leaving the reader on emulator-5554.
  void _emit(BookSpeakerState s) {
    if (!_stateController.isClosed) _stateController.add(s);
  }

  /// Splits a page into utterances the engine will accept and the ear will
  /// follow. Public so a test can check the splitting without a device.
  static List<String> chunk(String text, {int max = _maxChunk}) {
    final clean = text.trim();
    if (clean.isEmpty) return const [];

    final sentences = <String>[];
    var start = 0;
    for (final m in _sentenceEnd.allMatches(clean)) {
      sentences.add(clean.substring(start, m.end).trim());
      start = m.end;
    }
    if (start < clean.length) sentences.add(clean.substring(start).trim());

    // Re-join short sentences so the voice is not stopped every few words,
    // and split any single sentence that is still over the platform limit.
    final out = <String>[];
    final buf = StringBuffer();
    for (final s in sentences) {
      if (s.isEmpty) continue;
      if (s.length >= max) {
        if (buf.isNotEmpty) {
          out.add(buf.toString().trim());
          buf.clear();
        }
        out.addAll(_splitLong(s, max));
        continue;
      }
      if (buf.length + s.length + 1 > max) {
        out.add(buf.toString().trim());
        buf.clear();
      }
      if (buf.isNotEmpty) buf.write(' ');
      buf.write(s);
    }
    if (buf.isNotEmpty) out.add(buf.toString().trim());
    return out.where((c) => c.isNotEmpty).toList();
  }

  /// Cuts one over-long sentence, preferring a comma, then a space, so no
  /// word is ever broken in two — a half word is a mispronounced word.
  static List<String> _splitLong(String s, int max) {
    final out = <String>[];
    var rest = s;
    while (rest.length > max) {
      var cut = rest.lastIndexOf('،', max);
      if (cut < max ~/ 3) cut = rest.lastIndexOf(' ', max);
      if (cut <= 0) cut = max;
      out.add(
        rest
            .substring(0, cut + (cut < rest.length && rest[cut] == '،' ? 1 : 0))
            .trim(),
      );
      rest = rest.substring(cut).replaceFirst(RegExp(r'^[،\s]+'), '');
    }
    if (rest.trim().isNotEmpty) out.add(rest.trim());
    return out;
  }

  /// Picks an Arabic voice, preferring one that lives ON THE DEVICE.
  ///
  /// This app is offline-first and the reader is most wanted where there is
  /// no signal — walking, driving, on a plane. Google's Arabic set ships both
  /// `-local` and `-network` variants of the same voices; taking the local
  /// one means the reader keeps working with the radio off, and costs the
  /// user nothing in data.
  Future<String?> _preferLocalArabicVoice(int gen) async {
    final raw = await _tts.getVoices;
    if (!_current(gen)) return null;
    if (raw is! List) return null;
    final arabic = raw
        .whereType<Map>()
        .map((v) => v.map((k, val) => MapEntry('$k', '$val')))
        .where((v) => (v['locale'] ?? '').toLowerCase().startsWith('ar'))
        .toList();
    if (arabic.isEmpty) return null;
    final local = pickArabicVoice(arabic);
    await _tts.setVoice({'name': local['name']!, 'locale': local['locale']!});
    return local['name'];
  }

  /// True when this device can speak Arabic at all.
  ///
  /// Asks `isLanguageAvailable` FIRST and only falls back to listing. On a
  /// freshly constructed `FlutterTts` the engine is not bound yet, and
  /// `getLanguages` came back without Arabic on a device that plainly had
  /// nine Arabic voices — the first run of `tts_harakat_test` failed on
  /// exactly that, with `available` false and the probe beside it reporting
  /// `[ar]`. `isLanguageAvailable` waits for the binding; the list is kept as
  /// a second opinion for engines that do not implement it.
  Future<bool> get available async {
    if (_disposed) return false;
    final gen = _gen;
    final open = await _useOpenVoice();
    if (!_current(gen)) return false;
    if (open) return true;
    try {
      final direct = await _tts.isLanguageAvailable('ar');
      if (!_current(gen)) return false;
      if (direct == true) return true;
    } catch (e) {
      debugPrint('BookSpeaker: isLanguageAvailable threw: $e');
    }
    try {
      if (!_current(gen)) return false;
      final langs = await _tts.getLanguages;
      if (!_current(gen)) return false;
      if (langs is! List) return false;
      return langs.any((l) => '$l'.toLowerCase().startsWith('ar'));
    } catch (e) {
      debugPrint('BookSpeaker: getLanguages threw: $e');
      return false;
    }
  }

  Future<void> speak(String pageText, {double rate = 0.45}) async {
    if (_disposed) return;
    final stopping = stop();
    final gen = ++_gen;
    await stopping;
    if (!_current(gen)) return;
    // Not over a recitation, and a recitation started later stops this
    // (`AudioExclusive`): the two used to play at once.
    if (!await _claim(gen)) return;
    final open = await _useOpenVoice();
    if (!_current(gen)) return;
    if (open) {
      final done = await _speakOpen(pageText, gen);
      if (!_current(gen)) return;
      if (done) return;
      // The open voice failed on this device (a model that would not load,
      // an input it refused). Read the page in the phone's voice rather
      // than leave the listener in silence; the failure is in the log.
    }
    final chunks = chunk(pageText);
    if (chunks.isEmpty) {
      _finish(gen, 0, 0);
      return;
    }

    _speaking = true;

    try {
      await _tts.setLanguage('ar');
      if (!_current(gen)) return;
      await _preferLocalArabicVoice(gen);
      if (!_current(gen)) return;
      await _tts.setSpeechRate(rate);
      if (!_current(gen)) return;
      // Wait for each utterance so the chunks queue in order rather than
      // racing; without it the engine drops or overlaps them.
      await _tts.awaitSpeakCompletion(true);
      if (!_current(gen)) return;
    } catch (e) {
      debugPrint('BookSpeaker: engine setup failed: $e');
      _finish(gen, 0, 0);
      return;
    }

    final focus = await _watchFocus(gen);
    var index = 0;
    for (; index < chunks.length; index++) {
      if (!_current(gen)) break;
      _emit(
        BookSpeakerState(speaking: true, chunk: index, total: chunks.length),
      );
      try {
        await _tts.speak(chunks[index]);
      } catch (e) {
        debugPrint('BookSpeaker: chunk $index failed: $e');
        break;
      }
      if (!_current(gen)) break;
      final held = _held;
      if (held != null) {
        await held.future;
        if (!_current(gen)) break;
        index--; // the interrupted chunk again, from its start
      }
    }
    await focus?.cancel();

    _finish(gen, index, chunks.length);
  }

  /// The owner's choice in Settings, and only when the pack is really there.
  static Future<bool> _useOpenVoice() async =>
      await BookVoicePref.load() == BookVoice.open &&
      await OpenVoice.isInstalled();

  static const _voicePlayer = MethodChannel(
    'com.tito.rafeeq_aldarb/voice_player',
  );

  /// The voice is fed short chunks: its cost grows with input length and the
  /// first sound waits for the whole first chunk, so a sentence or two at a
  /// time keeps the start quick while the next chunk renders during playback.
  static const _openChunk = 220;
  static const _firstChunk = 90;

  /// Reads the page in the open voice (the one the owner chose for its
  /// tafkhim of the divine name). Returns false if it could not start, so
  /// the caller falls back; true once it has read or been stopped.
  Future<bool> _speakOpen(String pageText, int gen) async {
    // The same operation token covers model loading, rendering and playback.
    bool stale() => !_current(gen);
    var chunks = chunk(pageText, max: _openChunk);
    if (chunks.isEmpty) {
      _finish(gen, 0, 0);
      return true;
    }
    // The first sound waits for the whole first chunk to be synthesised, so
    // that one is cut short (~90 characters, still at a word): the voice
    // starts sooner and the rest renders while it speaks.
    if (chunks.first.length > _firstChunk) {
      chunks = [..._splitLong(chunks.first, _firstChunk), ...chunks.skip(1)];
    }
    var index = 0;
    _speaking = true;
    final tmp = await getTemporaryDirectory();
    if (stale()) return true;
    final dir = await tmp.createTemp('book_voice_');
    if (stale()) {
      await dir.delete(recursive: true);
      return true;
    }

    Future<String> render(int i) async {
      final samples = await OpenVoice.instance.synthesize(chunks[i]);
      // A stale render must not overwrite the newer run's alternating files.
      final f = File(p.join(dir.path, '${i % 2}.wav'));
      await f.writeAsBytes(OpenVoice.wav(samples), flush: true);
      return f.path;
    }

    Future<String>? next = render(0);
    Future<void> cleanup() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    }

    var started = false;
    try {
      for (; index < chunks.length; index++) {
        final path = await next!;
        next = null;
        if (stale()) break;
        started = true;
        next = index + 1 < chunks.length ? render(index + 1) : null;
        _emit(
          BookSpeakerState(speaking: true, chunk: index, total: chunks.length),
        );
        final ended = await _voicePlayer.invokeMethod<bool>('play', {
          'path': path,
        });
        if (ended != true) break;
      }
    } catch (e) {
      debugPrint('BookSpeaker: open voice failed at chunk $index: $e');
      next?.ignore();
      if (!started && !stale()) {
        if (next != null) {
          next.whenComplete(cleanup).ignore();
        } else {
          await cleanup();
        }
        _speaking = false;
        return false;
      }
    }
    if (next != null) {
      next.whenComplete(cleanup).ignore();
    } else {
      await cleanup();
    }
    _finish(gen, index, chunks.length);
    return true;
  }

  int _gen = 0;

  Future<void> stop() async {
    final owns = identical(_owner, this);
    if (owns) _owner = null;
    AudioExclusive.speakerStopped(stop);
    _gen++;
    final held = _held;
    _held = null;
    held?.complete();
    _speaking = false;
    _emit(const BookSpeakerState(speaking: false, chunk: 0, total: 0));
    if (!owns) return;
    // Issue both stops now; a delayed first reply must not stop a newer run.
    Future<void> ignoreFailure(Future<dynamic> call) async {
      try {
        await call;
      } catch (_) {}
    }

    final pending = Future.wait<void>([
      ?_nativeStops,
      ignoreFailure(_voicePlayer.invokeMethod<void>('stop')),
      ignoreFailure(_tts.stop()),
    ]);
    final stopped = pending.then((_) {});
    _nativeStops = stopped;
    try {
      await stopped;
    } finally {
      if (identical(_nativeStops, stopped)) _nativeStops = null;
    }
  }

  void dispose() {
    if (_disposed) return;
    unawaited(stop());
    _disposed = true;
    _stateController.close();
  }
}

@immutable
class BookSpeakerState {
  const BookSpeakerState({
    required this.speaking,
    required this.chunk,
    required this.total,
  });

  final bool speaking;
  final int chunk;
  final int total;
}

/// The text of one page, as the voice should receive it.
///
/// SKIPS QUR'AN. A paragraph Shamela marked as an ayah (`kind == 'aya'`) is
/// never handed to the engine. This is not a technical limit — the voice
/// would happily say the words. It is that the Qur'an is recited, not read
/// out by a speech synthesiser, and this app already carries real recitations
/// by named qurra' for exactly that. A synthetic voice performing an ayah,
/// with a synthesiser's stresses and pauses, is not something to ship into a
/// Muslim's ear because it was easy to do.
///
/// The ayah is skipped silently rather than replaced with a chime or a gap
/// announcement, because the reader can see the page: the ayah is on it, set
/// in the Quran face, where it always was.
///
/// Headings and citations ARE read — they are the author's own words and the
/// listener has no other way to know where he is in the book.
String pageSpeechText(Iterable<({String text, String kind})> paras) => paras
    .where((p) => p.kind != 'aya')
    .map((p) => p.text.trim())
    .where((t) => t.isNotEmpty)
    .join('\n');

/// A MAN's voice, on the device if possible.
///
/// «عاوزه رجل مش أنثى لأنه تطبيق إسلامي». The reader used to take the first
/// `-local` voice the engine listed, which on Google's engine is
/// `ar-xa-x-arz` — a woman's voice. Voice names say nothing about sex, so it
/// was measured: every Arabic voice on emulator-5554 spoke the same sentence
/// (`tool/tts_samples_main.dart`) and its median pitch was read on the host.
/// `ard` 135.6 Hz and `are` 144.6 Hz are male; `arz` 206.9 Hz and `arc`
/// 235.3 Hz are female (network variants within 10 Hz of the local ones).
///
/// Preference: a measured male voice on the device, then the same over the
/// network, then any voice whose name says it is male, then the first local
/// voice. An engine that has no male Arabic voice at all still reads — in
/// the voice it has — rather than refusing.
@visibleForTesting
Map<String, String> pickArabicVoice(List<Map<String, String>> arabic) {
  const maleOrder = ['ar-xa-x-ard', 'ar-xa-x-are'];
  String name(Map<String, String> v) => (v['name'] ?? '').toLowerCase();
  for (final suffix in ['-local', '-network']) {
    for (final m in maleOrder) {
      final hit = arabic.where((v) => name(v) == '$m$suffix').firstOrNull;
      if (hit != null) return hit;
    }
  }
  final saysMale = arabic
      .where((v) => name(v).contains('male') && !name(v).contains('female'))
      .firstOrNull;
  if (saysMale != null) return saysMale;
  return arabic.firstWhere(
    (v) => name(v).contains('-local'),
    orElse: () => arabic.first,
  );
}
