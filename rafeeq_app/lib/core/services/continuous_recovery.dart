part of 'ayah_audio_service.dart';

/// Keeps continuous recitation going when a verse cannot be fetched.
///
/// «دايما حط خطة احتياطية بحيث التطبيق ميعطلش ويقف لأي سبب» (2026-09-24).
/// The first load of a surah already tried the reciter's other host, but a
/// verse that failed AFTER the playlist was running — a dropped connection,
/// one file missing on one host — raised an error nobody listened to, and
/// the recitation simply went quiet.
///
/// Each failure moves one step down, and every step is spent once:
///  1. the reciter's next host for the whole surah, from the failed verse
///     (R2 → everyayah → islamic.network, as [RecitationSource.urlsFor]
///     orders them; the shift is kept for the rest of the run, so a host
///     that is down is not asked again every surah);
///  2. the app's default voice, al-Minshawi murattal, which the app holds on
///     its own bucket — and the reader is told ([continuousVoiceNotice]);
///  3. past the failing verse to the next one, rather than stopping.
///
/// Module state rather than fields: [AyahAudioService] is a single instance
/// and its file sits at its size ceiling (test/code_layout_test.dart).
StreamSubscription<PlaybackEvent>? _contErrSub;
int _contHostShift = 0;
int _contShiftToken = -1;
bool _contRecovering = false;

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

extension _ContinuousRecovery on AyahAudioService {
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

  /// Which of the reciter's hosts every verse comes from; back to the first
  /// whenever a new recitation is started.
  int get _hostShift {
    if (_contShiftToken != _continuousToken) {
      _contShiftToken = _continuousToken;
      _contHostShift = 0;
    }
    return _contHostShift;
  }

  void _watchContinuousErrors(int token, QuranRepository repo) {
    _contErrSub?.cancel();
    _contErrSub = _player.playbackEventStream.listen((_) {}, onError: (Object _) {
      if (token != _continuousToken || _contRecovering) return;
      final i = _player.currentIndex ?? 0;
      if (i < 0 || i >= _continuousAyahs.length) return;
      unawaited(_recoverContinuous(_continuousAyahs[i], repo, token));
    });
  }

  /// A surah that would not load from any of the reciter's hosts. The
  /// default voice is tried once; past that the phone is most likely offline,
  /// and skipping verse after verse would only spend a timeout on each — so
  /// it stops and says so, as it always did.
  Future<void> _continuousLoadFailed(
      Ayah a, QuranRepository repo, int token) async {
    if (token != _continuousToken) return;
    if (_continuousEdition != AyahAudioService.defaultEdition) {
      _continuousEdition = AyahAudioService.defaultEdition;
      _contHostShift = 0;
      _noticeVoice();
      await _loadSurahIntoPlayer(
        surahId: a.surahId,
        startAyahNumber: a.ayahNumber,
        repo: repo,
        token: token,
      );
      return;
    }
    await stopContinuous();
    continuousError.value = ContinuousError.loadFailed;
  }

  /// Takes the next step for verse [a], after it failed while the surah was
  /// already playing. True when a reload was started.
  Future<bool> _recoverContinuous(Ayah a, QuranRepository repo, int token) async {
    if (_contRecovering) return false;
    _contRecovering = true;
    try {
      final hosts = RecitationSource.urlsFor(
        edition: _continuousEdition,
        surah: a.surahId,
        ayah: a.ayahNumber,
        globalAyah: 1,
      ).length;
      var start = a.ayahNumber;
      if (_hostShift + 1 < hosts) {
        _contHostShift++;
      } else if (_continuousEdition != AyahAudioService.defaultEdition) {
        _continuousEdition = AyahAudioService.defaultEdition;
        _contHostShift = 0;
        _noticeVoice();
      } else {
        _contHostShift = 0;
        start = a.ayahNumber + 1;
        final last = _continuousAyahs.isEmpty ? 0 : _continuousAyahs.last.ayahNumber;
        if (start > last) {
          await _advanceToNextSurah(a.surahId, repo, token);
          return true;
        }
      }
      if (token != _continuousToken) return false;
      await _loadSurahIntoPlayer(
        surahId: a.surahId,
        startAyahNumber: start,
        repo: repo,
        token: token,
      );
      return true;
    } finally {
      _contRecovering = false;
    }
  }
}
