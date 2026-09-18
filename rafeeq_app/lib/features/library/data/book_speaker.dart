import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

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
  BookSpeaker({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;

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

  int _index = 0;
  List<String> _chunks = const [];
  bool _cancelled = false;

  /// Splits a page into utterances the engine will accept and the ear will
  /// follow. Public so a test can check the splitting without a device.
  static List<String> chunk(String text) {
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
      if (s.length >= _maxChunk) {
        if (buf.isNotEmpty) {
          out.add(buf.toString().trim());
          buf.clear();
        }
        for (var i = 0; i < s.length; i += _maxChunk) {
          out.add(s.substring(i, i + _maxChunk > s.length ? s.length : i + _maxChunk));
        }
        continue;
      }
      if (buf.length + s.length + 1 > _maxChunk) {
        out.add(buf.toString().trim());
        buf.clear();
      }
      if (buf.isNotEmpty) buf.write(' ');
      buf.write(s);
    }
    if (buf.isNotEmpty) out.add(buf.toString().trim());
    return out.where((c) => c.isNotEmpty).toList();
  }

  /// Picks an Arabic voice, preferring one that lives ON THE DEVICE.
  ///
  /// This app is offline-first and the reader is most wanted where there is
  /// no signal — walking, driving, on a plane. Google's Arabic set ships both
  /// `-local` and `-network` variants of the same voices; taking the local
  /// one means the reader keeps working with the radio off, and costs the
  /// user nothing in data.
  Future<String?> _preferLocalArabicVoice() async {
    final raw = await _tts.getVoices;
    if (raw is! List) return null;
    final arabic = raw
        .whereType<Map>()
        .map((v) => v.map((k, val) => MapEntry('$k', '$val')))
        .where((v) => (v['locale'] ?? '').toLowerCase().startsWith('ar'))
        .toList();
    if (arabic.isEmpty) return null;
    final local = arabic.firstWhere(
      (v) => (v['name'] ?? '').contains('-local'),
      orElse: () => arabic.first,
    );
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
    try {
      final direct = await _tts.isLanguageAvailable('ar');
      if (direct == true) return true;
    } catch (e) {
      debugPrint('BookSpeaker: isLanguageAvailable threw: $e');
    }
    try {
      final langs = await _tts.getLanguages;
      if (langs is! List) return false;
      return langs.any((l) => '$l'.toLowerCase().startsWith('ar'));
    } catch (e) {
      debugPrint('BookSpeaker: getLanguages threw: $e');
      return false;
    }
  }

  Future<void> speak(String pageText, {double rate = 0.45}) async {
    await stop();
    _chunks = chunk(pageText);
    if (_chunks.isEmpty) return;

    _cancelled = false;
    _index = 0;
    _speaking = true;

    try {
      await _tts.setLanguage('ar');
      await _preferLocalArabicVoice();
      await _tts.setSpeechRate(rate);
      // Wait for each utterance so the chunks queue in order rather than
      // racing; without it the engine drops or overlaps them.
      await _tts.awaitSpeakCompletion(true);
    } catch (e) {
      debugPrint('BookSpeaker: engine setup failed: $e');
      _speaking = false;
      _stateController.add(BookSpeakerState(speaking: false, chunk: 0, total: 0));
      return;
    }

    for (; _index < _chunks.length; _index++) {
      if (_cancelled) break;
      _stateController.add(BookSpeakerState(
        speaking: true,
        chunk: _index,
        total: _chunks.length,
      ));
      try {
        await _tts.speak(_chunks[_index]);
      } catch (e) {
        debugPrint('BookSpeaker: chunk $_index failed: $e');
        break;
      }
    }

    _speaking = false;
    _stateController.add(BookSpeakerState(
      speaking: false,
      chunk: _index,
      total: _chunks.length,
    ));
  }

  Future<void> stop() async {
    _cancelled = true;
    _speaking = false;
    try {
      await _tts.stop();
    } catch (_) {}
    _stateController.add(const BookSpeakerState(speaking: false, chunk: 0, total: 0));
  }

  void dispose() {
    _cancelled = true;
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
