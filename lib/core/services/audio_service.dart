import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'github_config_service.dart';

// ── Reciter config ────────────────────────────────────────────────────────────

class Reciter {
  final String id;
  final String nameAr;
  final String nameEn;
  final String everyayahIdentifier; // everyayah.com folder (per-ayah audio)
  final String mp3quranIdentifier; // mp3quran.net server path (full-surah audio)
  final String fallbackSurahUrl; // secondary fallback url pattern

  const Reciter({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.everyayahIdentifier,
    required this.mp3quranIdentifier,
    required this.fallbackSurahUrl,
  });
}

const kReciters = [
  Reciter(
    id: 'mishary',
    nameAr: 'مشاري راشد العفاسي',
    nameEn: 'Mishary Al-Afasy',
    everyayahIdentifier: 'Alafasy_128kbps',
    mp3quranIdentifier: 'https://server8.mp3quran.net/afs',
    fallbackSurahUrl: 'https://download.quranicaudio.com/quran/mishaari_raashid_al_3afaasee',
  ),
  Reciter(
    id: 'husary',
    nameAr: 'محمود خليل الحصري',
    nameEn: 'Mahmoud Khalil Al-Husary',
    everyayahIdentifier: 'Husary_128kbps',
    mp3quranIdentifier: 'https://server13.mp3quran.net/husr',
    fallbackSurahUrl: 'https://download.quranicaudio.com/quran/mahmood_khaleel_al-husaree_iza3ah',
  ),
  Reciter(
    id: 'abdulbasit',
    nameAr: 'عبد الباسط عبد الصمد (مرتل)',
    nameEn: 'Abdul Basit Abd us-Samad',
    everyayahIdentifier: 'Abdul_Basit_Murattal_192kbps',
    mp3quranIdentifier: 'https://server7.mp3quran.net/basit',
    fallbackSurahUrl: 'https://download.quranicaudio.com/quran/abdulbaset_mujawwad',
  ),
  Reciter(
    id: 'minshawi',
    nameAr: 'محمد صديق المنشاوي (مرتل)',
    nameEn: 'Muhammad Siddiq Al-Minshawi',
    everyayahIdentifier: 'Minshawy_Murattal_128kbps',
    mp3quranIdentifier: 'https://server10.mp3quran.net/minsh',
    fallbackSurahUrl: 'https://download.quranicaudio.com/quran/muhammad_siddeeq_al-minshaawee',
  ),
  Reciter(
    id: 'ghamdi',
    nameAr: 'سعد الغامدي',
    nameEn: 'Saad Al-Ghamdi',
    everyayahIdentifier: 'Ghamadi_40kbps',
    mp3quranIdentifier: 'https://server7.mp3quran.net/s_gmd',
    fallbackSurahUrl: 'https://download.quranicaudio.com/quran/sa3d_al-ghaamidee',
  ),
  Reciter(
    id: 'muaiqly',
    nameAr: 'ماهر المعيقلي',
    nameEn: 'Maher Al-Muaiqly',
    everyayahIdentifier: 'MaherAlMuaiqly128kbps',
    mp3quranIdentifier: 'https://server12.mp3quran.net/maher',
    fallbackSurahUrl: 'https://download.quranicaudio.com/quran/maher_almu3aiqly',
  ),
];

// ── Audio state ───────────────────────────────────────────────────────────────

enum AudioStatus { stopped, loading, playing, paused, error }

class AudioState {
  final AudioStatus status;
  final int? surahNumber;
  final int? ayahNumber;
  final String? reciterId;
  final String? errorMessage;
  final Duration position;
  final Duration duration;
  final double speed;
  final bool isLooping;

  const AudioState({
    this.status = AudioStatus.stopped,
    this.surahNumber,
    this.ayahNumber,
    this.reciterId,
    this.errorMessage,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.speed = 1.0,
    this.isLooping = false,
  });

  AudioState copyWith({
    AudioStatus? status,
    int? surahNumber,
    int? ayahNumber,
    String? reciterId,
    String? errorMessage,
    Duration? position,
    Duration? duration,
    double? speed,
    bool? isLooping,
  }) => AudioState(
    status: status ?? this.status,
    surahNumber: surahNumber ?? this.surahNumber,
    ayahNumber: ayahNumber ?? this.ayahNumber,
    reciterId: reciterId ?? this.reciterId,
    errorMessage: errorMessage ?? this.errorMessage,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    speed: speed ?? this.speed,
    isLooping: isLooping ?? this.isLooping,
  );

  bool get isPlaying => status == AudioStatus.playing;
  bool get isLoading => status == AudioStatus.loading;
}

// ── Audio Service ─────────────────────────────────────────────────────────────

class AudioService extends StateNotifier<AudioState> {
  final AudioPlayer _player = AudioPlayer();
  final Ref _ref;
  void Function()? _onCompleteCallback;

  AudioService(this._ref) : super(const AudioState()) {
    _player.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        if (state.isLooping) {
          _player.seek(Duration.zero);
          _player.play();
        } else {
          state = state.copyWith(status: AudioStatus.stopped);
          if (_onCompleteCallback != null) {
            final cb = _onCompleteCallback;
            _onCompleteCallback = null;
            cb?.call();
          }
        }
      }
    });

    _player.positionStream.listen((pos) {
      state = state.copyWith(position: pos);
    });

    _player.durationStream.listen((dur) {
      if (dur != null) state = state.copyWith(duration: dur);
    });
  }

  String _buildEveryayahUrl(String baseUrl, String everyayahId, int surah, int ayah) {
    final s = surah.toString().padLeft(3, '0');
    final a = ayah.toString().padLeft(3, '0');
    return '$baseUrl$everyayahId/$s$a.mp3';
  }

  Future<void> playAyah({
    required int surahNumber,
    required int ayahNumber,
    String reciterId = 'mishary',
    void Function()? onComplete,
  }) async {
    _onCompleteCallback = onComplete;
    final reciter = kReciters.firstWhere(
      (r) => r.id == reciterId,
      orElse: () => kReciters.first,
    );

    // If same ayah is paused, resume
    if (state.surahNumber == surahNumber &&
        state.ayahNumber == ayahNumber &&
        state.status == AudioStatus.paused) {
      await _player.play();
      state = state.copyWith(status: AudioStatus.playing);
      return;
    }

    // If same ayah is playing, pause
    if (state.surahNumber == surahNumber &&
        state.ayahNumber == ayahNumber &&
        state.status == AudioStatus.playing) {
      await _player.pause();
      state = state.copyWith(status: AudioStatus.paused);
      return;
    }

    state = state.copyWith(
      status: AudioStatus.loading,
      surahNumber: surahNumber,
      ayahNumber: ayahNumber,
      reciterId: reciterId,
    );

    try {
      final configVal = _ref.read(githubConfigProvider).valueOrNull;
      final baseUrl = configVal?.apis.quranAudioBackup ?? 'https://everyayah.com/data/';
      
      final url = _buildEveryayahUrl(
        baseUrl,
        reciter.everyayahIdentifier,
        surahNumber,
        ayahNumber,
      );

      final dir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${dir.path}/audio_cache');
      if (!cacheDir.existsSync()) cacheDir.createSync(recursive: true);

      final cacheFile = File('${cacheDir.path}/${reciter.everyayahIdentifier}_${surahNumber}_$ayahNumber.mp3');
      
      await _player.stop();
      if (cacheFile.existsSync() && cacheFile.lengthSync() > 1000) {
        await _player.setAudioSource(AudioSource.uri(Uri.file(cacheFile.path)));
      } else {
        await _player.setAudioSource(LockCachingAudioSource(Uri.parse(url), cacheFile: cacheFile));
      }
      
      await _player.setSpeed(state.speed);
      await _player.play();
      state = state.copyWith(status: AudioStatus.playing);
    } catch (e) {
      state = state.copyWith(
        status: AudioStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> playSurah({
    required int surahNumber,
    String reciterId = 'mishary',
  }) async {
    final reciter = kReciters.firstWhere(
      (r) => r.id == reciterId,
      orElse: () => kReciters.first,
    );

    // If same surah is paused, resume
    if (state.surahNumber == surahNumber &&
        state.ayahNumber == null &&
        state.reciterId == reciterId &&
        state.status == AudioStatus.paused) {
      await _player.play();
      state = state.copyWith(status: AudioStatus.playing);
      return;
    }

    state = state.copyWith(
      status: AudioStatus.loading,
      surahNumber: surahNumber,
      ayahNumber: null,
      reciterId: reciterId,
    );

    try {
      final s = surahNumber.toString().padLeft(3, '0');
      final primaryUrl = '${reciter.mp3quranIdentifier}/$s.mp3';
      final fallbackUrl = '${reciter.fallbackSurahUrl}/$s.mp3';

      final dir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${dir.path}/audio_cache');
      if (!cacheDir.existsSync()) cacheDir.createSync(recursive: true);

      final cacheFile = File('${cacheDir.path}/surah_${reciter.id}_$surahNumber.mp3');

      await _player.stop();
      if (cacheFile.existsSync() && cacheFile.lengthSync() > 10000) {
        await _player.setAudioSource(AudioSource.uri(Uri.file(cacheFile.path)));
      } else {
        try {
          await _player.setAudioSource(LockCachingAudioSource(Uri.parse(primaryUrl), cacheFile: cacheFile));
        } catch (_) {
          // Fallback to secondary source
          await _player.setAudioSource(LockCachingAudioSource(Uri.parse(fallbackUrl), cacheFile: cacheFile));
        }
      }
      
      await _player.setSpeed(state.speed);
      await _player.play();
      state = state.copyWith(status: AudioStatus.playing);
    } catch (e) {
      state = state.copyWith(
        status: AudioStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> togglePlayPause() async {
    if (state.isPlaying) {
      await pause();
    } else if (state.status == AudioStatus.paused) {
      await resume();
    }
  }

  Future<void> pause() async {
    await _player.pause();
    state = state.copyWith(status: AudioStatus.paused);
  }

  Future<void> resume() async {
    await _player.play();
    state = state.copyWith(status: AudioStatus.playing);
  }

  Future<void> stop() async {
    await _player.stop();
    state = const AudioState();
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Future<void> seekForward([Duration offset = const Duration(seconds: 10)]) async {
    final newPos = state.position + offset;
    final maxPos = state.duration;
    if (maxPos > Duration.zero && newPos > maxPos) {
      await _player.seek(maxPos);
    } else {
      await _player.seek(newPos);
    }
  }

  Future<void> seekBackward([Duration offset = const Duration(seconds: 10)]) async {
    final newPos = state.position - offset;
    if (newPos < Duration.zero) {
      await _player.seek(Duration.zero);
    } else {
      await _player.seek(newPos);
    }
  }

  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
    state = state.copyWith(speed: speed);
  }

  void toggleLoop() {
    state = state.copyWith(isLooping: !state.isLooping);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}

// ── Providers ────────────────────────────────────────────────────────────────

final audioServiceProvider = StateNotifierProvider<AudioService, AudioState>(
  (ref) => AudioService(ref),
);

final selectedReciterProvider = StateProvider<String>((ref) => 'mishary');
