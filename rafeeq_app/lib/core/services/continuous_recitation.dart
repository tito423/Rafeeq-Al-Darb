/// What a continuous recitation is doing right now — the state the mushaf
/// screens watch to place the highlight and draw the recitation bar.
///
/// Split out of `ayah_audio_service.dart`, which is at its length ceiling.
class ContinuousRecitation {
  final bool active;

  /// The verse currently sounding, or null before the first one starts.
  final int? surahId;
  final int? ayahNumber;

  /// True while the child sounding is the surah's **basmala** rather than
  /// verse 1. The playlist puts the reciter's own basmala (his recording of
  /// 1:1) ahead of verse 1 for every surah but al-Fatiha and at-Tawbah, and
  /// [surahId]/[ayahNumber] still read as verse 1 then — the text mushaf sets
  /// the basmala on its own line and needs to know which of the two to mark.
  final bool basmala;

  /// Position within the surah being recited, for a progress readout.
  final int indexInSurah;
  final int totalInSurah;

  /// True while the next surah's sources are being prepared, so the UI can
  /// say "جارٍ التحميل" instead of looking frozen between surahs.
  final bool buffering;

  /// The run is nominally still active but the platform player has gone —
  /// Android released it while the app sat in the background. The verse and
  /// position are still meaningful (they are where to resume from); what is
  /// not true any more is that anything is sounding. Set on app resume by
  /// [AyahAudioService.onAppResumed].
  final bool stalled;

  /// Every source for this verse failed, the backup voice included. The run
  /// HOLDS here — it never skips a verse — and resumes from this very verse
  /// by itself as soon as a source answers (see continuous_recovery.dart).
  final bool waiting;

  const ContinuousRecitation({
    this.active = false,
    this.surahId,
    this.ayahNumber,
    this.basmala = false,
    this.indexInSurah = 0,
    this.totalInSurah = 0,
    this.buffering = false,
    this.stalled = false,
    this.waiting = false,
  });

  static const stopped = ContinuousRecitation();

  ContinuousRecitation copyWith({bool? stalled, bool? buffering, bool? waiting}) =>
      ContinuousRecitation(
        active: active,
        surahId: surahId,
        ayahNumber: ayahNumber,
        basmala: basmala,
        indexInSurah: indexInSurah,
        totalInSurah: totalInSurah,
        buffering: buffering ?? this.buffering,
        stalled: stalled ?? this.stalled,
        waiting: waiting ?? this.waiting,
      );

  bool isAyah(int surah, int ayah) =>
      active && surahId == surah && ayahNumber == ayah;
}

/// Why a continuous recitation could not start or carry on.
enum ContinuousError {
  /// The verses' audio could not be opened, even after the player itself was
  /// rebuilt. Network, or a source that genuinely is not there.
  loadFailed,
}
