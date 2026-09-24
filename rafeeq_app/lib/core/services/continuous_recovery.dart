part of 'ayah_audio_service.dart';

/// Keeps continuous recitation going when a verse cannot be fetched — and
/// NEVER by skipping it.
///
/// «مفيش حاجة اسمها تخطي آية أو حتى كلمة … مش عايز التطبيق ده يقف لأي سبب»
/// (2026-09-24). The first load of a surah already tried a second host, but a
/// verse that failed AFTER the playlist was running — a dropped connection,
/// one file missing on one host — raised an error nobody listened to, and
/// the recitation went quiet.
///
/// On a failure, from the failed verse, each step once:
///  1. the reciter's next host for the rest of the surah, down the chain
///     [RecitationSource.urlsFor] orders (the phone's own copy, R2,
///     everyayah, islamic.network); the shift is kept for the run, so a
///     host that is down is not asked again every surah;
///  2. the app's default voice, al-Minshawi murattal, which the app keeps on
///     its own bucket — announced ([continuousVoiceNotice]), never silent;
///  3. HOLD at that verse ([ContinuousRecitation.waiting]): the bar says so,
///     and the run tries again — the reader's own reciter first — every
///     [_retryAfter] and at once when the network comes back.
///
/// Module state rather than fields: [AyahAudioService] is a single instance
/// and its file sits at its size ceiling (test/code_layout_test.dart).
StreamSubscription<PlayerException>? _contErrSub;
int _contHostShift = 0;
int _contShiftToken = -1;
String _contChosenEdition = AyahAudioService.defaultEdition;
bool _contRecovering = false;
bool _contRetrying = false;
Timer? _contRetryTimer;
StreamSubscription<List<ConnectivityResult>>? _contNetSub;
const _retryAfter = Duration(seconds: 20);
String? _contHeldVerse;

/// Set once in `main()`: shows that another voice has taken over.
void Function()? continuousVoiceNotice;
DateTime? _lastVoiceNotice;

/// Once per half-minute: a memorisation loop repeating a verse five times
/// must not stack five identical messages.
void _noticeVoice() {
  final now = DateTime.now();
  if (_lastVoiceNotice != null &&
      now.difference(_lastVoiceNotice!) < const Duration(seconds: 30)) {
    return;
  }
  _lastVoiceNotice = now;
  continuousVoiceNotice?.call();
}

/// Set once in `main()`: a single verse is being waited for ("s:a").
void Function(String verse)? ayahWaitingNotice;

void _cancelHold() {
  _contRetryTimer?.cancel();
  _contRetryTimer = null;
  _contNetSub?.cancel();
  _contNetSub = null;
}

extension _ContinuousRecovery on AyahAudioService {
  /// A long track (a ruqyah recording) from the first of its hosts that
  /// opens: R2, then the same bytes on GitHub Releases (ContentMirrors).
  Future<void> _setFirstReachable(String url, MediaItem tag) =>
      ContentMirrors.fetchFirst<void>(
        url,
        (u) async => _player.setAudioSource(AudioSource.uri(Uri.parse(u), tag: tag)),
      );

  /// True when a server answered for [a] on the host in use — the file is
  /// the problem and another voice may help. False when nothing answered:
  /// no connection, so a substitute would fail too and the message would
  /// be untrue; the run waits instead.
  Future<bool> _serverAnswered(Ayah a) async {
    final urls = RecitationSource.urlsFor(
      edition: _continuousEdition,
      surah: a.surahId,
      ayah: a.ayahNumber,
      globalAyah: 1,
    );
    final url = urls[_contHostShift.clamp(0, urls.length - 1)];
    return !url.startsWith('http') || await httpStatusOf(url) != null;
  }

  /// A single verse (hifz «استمع», the ayah card, a topic list) that no host
  /// of the chosen reciter could give: the same verse in the default voice,
  /// which the app keeps on its own bucket, rather than silence.
  Future<bool> _playBackupVoice(
      Ayah ayah, QuranRepository repo, String? title) async {
    final ok = await play(ayah, repo,
        edition: AyahAudioService.defaultEdition, title: title);
    if (ok) _noticeVoice();
    return ok;
  }

  /// A verse of a queue (hifz «استمع», a topic list) that nothing could
  /// play. Waits for the connection to change or [_retryAfter], whichever
  /// is first, then asks the loop to try the SAME verse again. False only
  /// when the loop was stopped or superseded meanwhile.
  Future<bool> _waitForSource(int token, Ayah a) async {
    if (token != _queueToken) return false;
    ayahWaitingNotice?.call('${a.surahId}:${a.ayahNumber}');
    final done = Completer<void>();
    final sub = Connectivity().onConnectivityChanged.listen((r) {
      if (r.any((c) => c != ConnectivityResult.none) && !done.isCompleted) {
        done.complete();
      }
    });
    final poll = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (token != _queueToken && !done.isCompleted) done.complete();
    });
    await done.future.timeout(_retryAfter, onTimeout: () {});
    poll.cancel();
    await sub.cancel();
    return token == _queueToken;
  }

  /// Which of the reciter's hosts every verse comes from; back to the first,
  /// and the reader's own reciter remembered, whenever a new run starts.
  int get _hostShift {
    if (_contShiftToken != _continuousToken) {
      _contShiftToken = _continuousToken;
      _contHostShift = 0;
      _contChosenEdition = _continuousEdition;
      _contHeldVerse = null;
      _cancelHold();
    }
    return _contHostShift;
  }

  void _watchContinuousErrors(int token, QuranRepository repo) {
    _contErrSub?.cancel();
    // just_audio 0.10 reports a failed source on `errorStream`, as a value;
    // `playbackEventStream` carries no stream error for it at all (read in
    // just_audio.dart 0.10.6, `_errorSubject`). Listening there was deaf:
    // seen on emulator-5554 with the network cut, the run sat idle.
    _contErrSub = _player.errorStream.listen((e) {
      // A load in progress reports its own failure by throwing, and
      // [_loadSurahIntoPlayer] handles that; every load marks the run
      // `buffering` until a verse is actually sounding.
      if (token != _continuousToken || _contRecovering) return;
      if (continuous.value.buffering) return;
      final i = e.index ?? _player.currentIndex ?? 0;
      if (i < 0 || i >= _continuousAyahs.length) return;
      unawaited(_recoverContinuous(_continuousAyahs[i], repo, token));
    });
  }

  /// A surah that would not load from any of the reciter's hosts: the
  /// default voice once, then hold at the verse.
  Future<void> _continuousLoadFailed(
      Ayah a, QuranRepository repo, int token) async {
    if (token != _continuousToken) return;
    if (_continuousEdition != AyahAudioService.defaultEdition &&
        await _serverAnswered(a)) {
      _continuousEdition = AyahAudioService.defaultEdition;
      _contHostShift = 0;
      _noticeVoice();
      continuous.value = continuous.value.copyWith(buffering: true);
      await _loadSurahIntoPlayer(
        surahId: a.surahId,
        startAyahNumber: a.ayahNumber,
        repo: repo,
        token: token,
      );
      return;
    }
    await _holdAt(a, repo, token);
  }

  /// Takes the next step for verse [a], after it failed while the surah was
  /// already playing.
  Future<void> _recoverContinuous(Ayah a, QuranRepository repo, int token) async {
    if (_contRecovering) return;
    _contRecovering = true;
    try {
      final hosts = RecitationSource.urlsFor(
        edition: _continuousEdition,
        surah: a.surahId,
        ayah: a.ayahNumber,
        globalAyah: 1,
      ).length;
      if (_hostShift + 1 < hosts) {
        _contHostShift++;
      } else if (_continuousEdition != AyahAudioService.defaultEdition &&
          await _serverAnswered(a)) {
        _continuousEdition = AyahAudioService.defaultEdition;
        _contHostShift = 0;
        _noticeVoice();
      } else {
        await _holdAt(a, repo, token);
        return;
      }
      if (token != _continuousToken) return;
      continuous.value = continuous.value.copyWith(buffering: true);
      await _loadSurahIntoPlayer(
        surahId: a.surahId,
        startAyahNumber: a.ayahNumber,
        repo: repo,
        token: token,
      );
    } finally {
      _contRecovering = false;
    }
  }

  /// Nothing answered for verse [a]. Stay on it — highlighted, the bar
  /// saying why — and try again from it: after [_retryAfter], and at once
  /// when the phone's connection changes to something usable.
  Future<void> _holdAt(Ayah a, QuranRepository repo, int token) async {
    if (token != _continuousToken) return;
    try {
      await _player.stop();
    } catch (_) {}
    continuous.value = ContinuousRecitation(
      active: true,
      surahId: a.surahId,
      ayahNumber: a.ayahNumber,
      waiting: true,
    );
    // Said once per verse, and not only in the bar: in full-screen reading
    // the bar is not drawn at all, and a silent pause looks like a fault.
    final verse = '${a.surahId}:${a.ayahNumber}';
    if (_contHeldVerse != verse) ayahWaitingNotice?.call(verse);
    _contHeldVerse = verse;
    _cancelHold();

    Future<void> retry() async {
      if (token != _continuousToken || !continuous.value.waiting) {
        _cancelHold();
        return;
      }
      if (_contRetrying) return;
      _contRetrying = true;
      _cancelHold();
      try {
        // The reader's own reciter first, from its first host: whatever
        // failed may have come back.
        _continuousEdition = _contChosenEdition;
        _contHostShift = 0;
        continuous.value = continuous.value.copyWith(buffering: true);
        await _loadSurahIntoPlayer(
          surahId: a.surahId,
          startAyahNumber: a.ayahNumber,
          repo: repo,
          token: token,
        );
      } finally {
        _contRetrying = false;
      }
    }

    // PERIODIC, not one-shot: a retry that arrives while the previous one is
    // still loading is dropped, and a one-shot timer (or a single network
    // event) dropped that way left the run holding for good — seen on
    // emulator-5554, network back and 2:150 still waiting a minute later.
    _contRetryTimer = Timer.periodic(_retryAfter, (_) => unawaited(retry()));
    _contNetSub = Connectivity().onConnectivityChanged.listen((r) {
      if (r.any((c) => c != ConnectivityResult.none)) unawaited(retry());
    });
  }
}
