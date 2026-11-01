import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'book_speaker.dart';
import 'book_text.dart';

/// One sentence (or two short ones) the voice reads at a time, and where it
/// sits in its paragraph, so the reader can light exactly what is heard.
@immutable
class ReadChunk {
  const ReadChunk(this.para, this.start, this.end, this.text);

  /// Index into the page's `paras`.
  final int para;

  /// Character range inside that paragraph's text (vowelled, as stored).
  final int start;
  final int end;
  final String text;
}

enum ReadAloudState { idle, preparing, playing, paused }

/// The book reader's listening session: which page and sentence are being
/// read, at what pace, until when - and everything the player bar, the
/// notification and the highlighted sentence show.
///
/// WHY IT EXISTS. «قارئ الكتب سئ جدا» (owner, 2026-11-01). The voice was not
/// the problem (Supertonic-3, measured best of the offline Arabic voices on
/// 2026-10-19/20; nothing better found on 2026-11-01). The player around it
/// was: it could only stop, and a stop began the page again from its top;
/// turning the page by hand silenced it; nothing showed which sentence was
/// being read; the pace was fixed; there was no sleep timer, no resume point
/// and no control outside the open screen. This class holds all of that, so
/// the speaker below it stays only a voice.
///
/// Sentences never cross a paragraph, so each one maps to one span on the
/// page. Qur'an paragraphs are not read (see [pageSpeechText]).
class BookReadAloud extends ChangeNotifier {
  BookReadAloud({required this.bookId, BookSpeaker? speaker})
    : _speaker = speaker ?? BookSpeaker() {
    _loadSpeed();
    BookSpeaker.onControl = _onControl;
  }

  final String bookId;
  final BookSpeaker _speaker;

  BookText? _doc;
  ReadAloudState state = ReadAloudState.idle;
  int page = 0;
  List<ReadChunk> chunks = const [];
  int index = 0;
  bool whole = true;
  double speed = 1.0;

  /// Turns the screen when the voice moves to the next page: (from, to).
  void Function(int from, int to)? onTurnPage;

  /// Builds the notification's text and labels in the reader's language.
  ({String title, String text, Map<String, String> labels}) Function(int page)?
  describe;

  static const speeds = [0.75, 1.0, 1.25, 1.5];

  /// Sleep timer: stop at the end of this page, or at [sleepAt].
  bool sleepEndOfPage = false;
  DateTime? sleepAt;
  Timer? _sleepTimer;
  Timer? _sleepTick;

  int _run = 0;
  bool _heldInPlace = false;
  bool _disposed = false;

  bool get active => state != ReadAloudState.idle;
  ReadChunk? get current =>
      active && index < chunks.length ? chunks[index] : null;

  static const _kSpeed = 'book_read_speed';
  String get _kPoint => 'booktext_${bookId}_listen';

  Future<void> _loadSpeed() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getDouble(_kSpeed);
    if (v != null && speeds.contains(v)) speed = v;
  }

  /// The page and sentence the last listening stopped at, if any.
  Future<(int, int)?> savedPoint() async {
    final prefs = await SharedPreferences.getInstance();
    final parts = (prefs.getString(_kPoint) ?? '').split(':');
    if (parts.length != 2) return null;
    final p = int.tryParse(parts[0]), c = int.tryParse(parts[1]);
    return p == null || c == null ? null : (p, c);
  }

  Future<void> _savePoint() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPoint, '$page:$index');
  }

  /// Splits a page into the sentences the voice reads, each one placed in
  /// its paragraph. Public for the tests.
  static List<ReadChunk> chunksOf(
    List<({String text, String kind})> paras, {
    int max = BookSpeaker.openChunk,
  }) {
    final out = <ReadChunk>[];
    for (var i = 0; i < paras.length; i++) {
      final para = paras[i];
      if (para.kind == 'aya') continue;
      final text = para.text;
      var cursor = 0;
      final pieces = BookSpeaker.chunk(text, max: max);
      final starts = <int>[];
      for (final piece in pieces) {
        final head = piece.substring(0, piece.length < 12 ? piece.length : 12);
        var at = text.indexOf(head, cursor);
        if (at < 0) at = cursor;
        starts.add(at);
        cursor = at + 1;
      }
      for (var k = 0; k < pieces.length; k++) {
        var end = k + 1 < starts.length ? starts[k + 1] : text.length;
        while (end > starts[k] && text[end - 1].trim().isEmpty) {
          end--;
        }
        final spoken = speakable(pieces[k]);
        // A lone «ــ» between a hadith and its commentary was handed to the
        // voice as a sentence of its own (seen on emulator, 2026-11-01).
        if (!_letter.hasMatch(spoken)) continue;
        out.add(ReadChunk(i, starts[k], end, spoken));
      }
    }
    return out;
  }

  // Arabic letters, not the tatweel U+0640: Ihkam al-Ahkam separates a
  // hadith from its commentary with a paragraph «ــ» (two tatweels).
  static final _letter = RegExp('[ء-ؿف-ي]');

  /// Qur'an quoted INSIDE a paragraph - Shamela sets it in {…} (or ﴿…﴾),
  /// usually followed by its reference «[محمد: ٣٦]» - is left out of what
  /// the voice says, for the same reason a whole ayah paragraph is
  /// ([pageSpeechText]): the Qur'an is recited, not read by a synthesiser.
  /// Ihkam al-Ahkam page 2 had «{إِنَّمَا الْحَيَاةُ الدُّنْيَا لَعِبٌ}
  /// [محمد: ٣٦]» read aloud mid-sentence (emulator, 2026-11-01). The
  /// sentence is still lit on the page with the ayah in it.
  static String speakable(String s) => s
      .replaceAll(_quotedAyah, ' ')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();
  static final _quotedAyah = RegExp(
    r'(\{[^{}]*\}|﴿[^﴾]*﴾)\s*(\[[^\[\]]*\])?',
  );

  List<ReadChunk> _chunksFor(int p) => chunksOf(
    _doc!.pages[p].paras.map((x) => (text: x.text, kind: x.kind)).toList(),
  );

  /// Starts reading [doc] at page [from] (sentence [chunk]); [toEnd] goes on
  /// to the end of the book, turning the pages.
  Future<void> start(
    BookText doc,
    int from, {
    required bool toEnd,
    int chunk = 0,
  }) async {
    _doc = doc;
    page = from.clamp(0, doc.pages.length - 1);
    whole = toEnd;
    chunks = _chunksFor(page);
    index = chunk.clamp(0, chunks.isEmpty ? 0 : chunks.length - 1);
    await _go();
  }

  Future<void> _go() async {
    final run = ++_run;
    _heldInPlace = false;
    _set(ReadAloudState.preparing);
    await _loop(run);
  }

  Future<void> _loop(int run) async {
    while (run == _run && !_disposed) {
      if (chunks.isEmpty || index >= chunks.length) {
        if (!_nextPage()) return _finished();
        continue;
      }
      final reached = await _speaker.speakChunks(
        [for (final c in chunks) c.text],
        from: index,
        speed: speed,
        onChunk: (i) {
          if (run != _run) return;
          index = i;
          if (state == ReadAloudState.preparing) state = ReadAloudState.playing;
          unawaited(_savePoint());
          _notice();
          notifyListeners();
        },
      );
      if (run != _run || _disposed) return; // paused, skipped, stopped here
      if (reached < chunks.length) {
        // Cut short from outside: a recitation started, or the focus was
        // lost for good. Hold the place rather than lose it.
        index = reached;
        _run++;
        _set(ReadAloudState.paused);
        return;
      }
      if (sleepEndOfPage) {
        sleepEndOfPage = false;
        _nextPage();
        _run++;
        _set(ReadAloudState.paused);
        return;
      }
      if (!whole || !_nextPage()) return _finished();
    }
  }

  bool _nextPage() {
    final doc = _doc;
    if (doc == null || page >= doc.pages.length - 1) return false;
    final from = page;
    page++;
    chunks = _chunksFor(page);
    index = 0;
    unawaited(_savePoint());
    onTurnPage?.call(from, page);
    return true;
  }

  void _finished() {
    _run++;
    _cancelSleep();
    _set(ReadAloudState.idle);
  }

  Future<void> pause() async {
    if (state != ReadAloudState.playing && state != ReadAloudState.preparing) {
      return;
    }
    if (await _speaker.pause()) {
      _heldInPlace = true;
    } else {
      _run++;
      await _speaker.stop();
    }
    _set(ReadAloudState.paused);
  }

  Future<void> resume() async {
    if (state != ReadAloudState.paused) return;
    if (_heldInPlace) {
      _heldInPlace = false;
      await _speaker.resume();
      _set(ReadAloudState.playing);
    } else {
      await _go();
    }
  }

  Future<void> toggle() => state == ReadAloudState.paused ? resume() : pause();

  Future<void> stop() async {
    _run++;
    _heldInPlace = false;
    _cancelSleep();
    await _speaker.stop();
    _set(ReadAloudState.idle);
  }

  /// The next or the previous sentence; past the page's last one, the next
  /// page.
  Future<void> skip(int delta) async {
    if (!active) return;
    var target = index + delta;
    if (target >= chunks.length) {
      _run++;
      await _speaker.stop();
      if (!_nextPage()) return stop();
      target = 0;
    }
    _run++;
    await _speaker.stop();
    index = target.clamp(0, chunks.isEmpty ? 0 : chunks.length - 1);
    await _go();
  }

  Future<void> setSpeed(double v) async {
    speed = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kSpeed, v);
    notifyListeners();
    // The sentence already rendered is at the old pace: read it again.
    if (state == ReadAloudState.playing || state == ReadAloudState.preparing) {
      _run++;
      await _speaker.stop();
      await _go();
    }
  }

  /// [minutes] 0 turns the timer off; -1 stops at the end of this page.
  void setSleep(int minutes) {
    _cancelSleep();
    if (minutes < 0) {
      sleepEndOfPage = true;
    } else if (minutes > 0) {
      sleepAt = DateTime.now().add(Duration(minutes: minutes));
      _sleepTimer = Timer(Duration(minutes: minutes), () {
        sleepAt = null;
        _sleepTick?.cancel();
        pause();
      });
      _sleepTick = Timer.periodic(
        const Duration(seconds: 30),
        (_) => notifyListeners(),
      );
    }
    notifyListeners();
  }

  void _cancelSleep() {
    sleepEndOfPage = false;
    sleepAt = null;
    _sleepTimer?.cancel();
    _sleepTick?.cancel();
  }

  void _onControl(String what) {
    switch (what) {
      case 'play':
        resume();
      case 'pause':
        pause();
      case 'next':
        skip(1);
      case 'previous':
        skip(-1);
      case 'stop':
        stop();
    }
  }

  void _set(ReadAloudState s) {
    if (_disposed) return;
    state = s;
    _notice();
    notifyListeners();
  }

  void _notice() {
    if (state == ReadAloudState.idle) {
      unawaited(BookSpeaker.notice());
      return;
    }
    final d = describe?.call(page);
    if (d == null) return;
    unawaited(BookSpeaker.notice(
      title: d.title,
      text: d.text,
      playing: state != ReadAloudState.paused,
      labels: d.labels,
    ));
  }

  @override
  void dispose() {
    if (_disposed) return;
    _run++;
    _cancelSleep();
    unawaited(BookSpeaker.notice());
    BookSpeaker.onControl = null;
    _speaker.dispose();
    _disposed = true;
    super.dispose();
  }
}
