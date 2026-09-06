import 'package:flutter/services.dart';

import '../models/adhan_mode.dart';
import '../models/adhan_option.dart';

/// Which native source plays an adhan. Mirrors `AdhanSpec.SOUND_*` in Kotlin.
enum AdhanSoundType {
  /// A bundled muezzin in `android/app/src/main/res/raw/`.
  raw,

  /// A `content://` URI (kept for completeness — nothing produces one today).
  uri,

  /// An absolute path to a file the user imported. The native player runs in
  /// this app's own process, so it reads app-private storage directly and
  /// needs no FileProvider round-trip.
  file,

  /// Vibrate / silent modes: there is nothing to play.
  none,
}

/// One prayer's complete adhan instruction, in the shape the native side
/// understands. Built once by [AdhanNative.specFor] so scheduling, the
/// preview and the alert screen can never drift apart.
class AdhanSpec {
  final String prayerKey;
  final String prayerLabel;
  final AdhanMode mode;
  final AdhanSoundType soundType;
  final String? soundValue;

  /// The same bundled recording as a Flutter asset
  /// (`assets/audio/adhan/azanN.mp3`). The native player falls back to it
  /// when the `res/raw` resource cannot be resolved — which is exactly what
  /// release builds used to do, because R8's resource shrinker stripped
  /// `res/raw/azan*` (see `android/app/src/main/res/raw/keep.xml`).
  final String? assetPath;

  final String? videoPath;
  final int hour;
  final int minute;

  const AdhanSpec({
    required this.prayerKey,
    required this.prayerLabel,
    required this.mode,
    required this.soundType,
    required this.soundValue,
    this.assetPath,
    this.videoPath,
    this.hour = 0,
    this.minute = 0,
  });

  Map<String, Object?> toMap() => {
    'prayerKey': prayerKey,
    'prayerLabel': prayerLabel,
    'mode': mode.name,
    'soundType': soundType.name,
    'soundValue': soundValue,
    'assetPath': assetPath,
    'videoPath': videoPath,
    'hour': hour,
    'minute': minute,
    'daily': true,
  };

  /// Rebuilt from the route `AdhanActivity` hands the `adhanMain` entrypoint.
  static AdhanSpec fromJson(Map<String, dynamic> m) => AdhanSpec(
    prayerKey: m['prayerKey'] as String? ?? 'dhuhr',
    prayerLabel: m['prayerLabel'] as String? ?? '',
    mode: AdhanMode.fromName(m['mode'] as String?),
    soundType: AdhanSoundType.values.firstWhere(
      (t) => t.name == m['soundType'],
      orElse: () => AdhanSoundType.none,
    ),
    soundValue: m['soundValue'] as String?,
    assetPath: m['assetPath'] as String?,
    videoPath: m['videoPath'] as String?,
    hour: (m['hour'] as num?)?.toInt() ?? 0,
    minute: (m['minute'] as num?)?.toInt() ?? 0,
  );
}

/// A snapshot of the native player, polled by the alert screen so its
/// karaoke subtitles ride the *real* playback position rather than a timer
/// that only approximates it.
class AdhanPlaybackState {
  final bool playing;
  final bool muted;
  final Duration position;
  final Duration duration;

  /// True while [AdhanService] is holding a real firing (as opposed to the
  /// settings-screen preview, which runs the player without the service).
  final bool firing;

  const AdhanPlaybackState({
    required this.playing,
    required this.muted,
    required this.position,
    required this.duration,
    required this.firing,
  });

  static const idle = AdhanPlaybackState(
    playing: false,
    muted: false,
    position: Duration.zero,
    duration: Duration.zero,
    firing: false,
  );

  static AdhanPlaybackState fromMap(Map<Object?, Object?> m) =>
      AdhanPlaybackState(
        playing: m['playing'] as bool? ?? false,
        muted: m['muted'] as bool? ?? false,
        position: Duration(milliseconds: (m['positionMs'] as num?)?.toInt() ?? 0),
        duration: Duration(milliseconds: (m['durationMs'] as num?)?.toInt() ?? 0),
        firing: m['firing'] as bool? ?? false,
      );
}

/// The Dart face of the native Adhan engine (`android/.../kotlin/.../adhan/`).
///
/// Everything about an adhan — arming the alarm, playing the sound, stopping
/// it, muting it, reading its position — happens natively, and this class is
/// the only way Dart talks to it. Two deliberate consequences:
///
///  * **The sound never goes through `just_audio`.** The app initialises
///    `just_audio_background`, whose platform implementation throws
///    *"just_audio_background supports only a single player instance"* for
///    every `AudioPlayer` after the first — a slot the Quran recitation
///    player already holds. That is why the old full-screen adhan and its
///    preview came up silent: `setAsset` was failing and the failure was
///    swallowed. A native `MediaPlayer` on the alarm stream has no such
///    limit, and is the only thing that can sound at all when the app is
///    dead.
///  * **Preview and the real adhan share one path.** "تجربة" plays through
///    the same [AdhanPlayer] the alarm uses, so it genuinely tests what will
///    fire, and its Stop/Mute buttons exercise the real controls.
class AdhanNative {
  AdhanNative._();

  static const _player = MethodChannel('com.tito.rafeeq_aldarb/adhan_player');
  static const _alarm = MethodChannel('com.tito.rafeeq_aldarb/adhan_alarm');

  /// Builds the native spec for one prayer from the user's chosen sound.
  /// Vibrate/silent modes deliberately resolve to [AdhanSoundType.none] —
  /// the native side then knows there is nothing to play, instead of
  /// carrying a sound it must remember not to use.
  static AdhanSpec specFor({
    required String prayerKey,
    required String prayerLabel,
    required AdhanMode mode,
    required AdhanOption option,
    String? videoPath,
    int hour = 0,
    int minute = 0,
  }) {
    final silentMode = mode == AdhanMode.vibrate || mode == AdhanMode.silent;
    final AdhanSoundType type;
    final String? value;
    String? asset;
    if (silentMode) {
      type = AdhanSoundType.none;
      value = null;
    } else if (option.isCustom && option.filePath != null) {
      type = AdhanSoundType.file;
      value = option.filePath;
    } else if (option.rawResource != null) {
      type = AdhanSoundType.raw;
      value = option.rawResource;
      asset = option.assetPath;
    } else {
      type = AdhanSoundType.none;
      value = null;
    }
    return AdhanSpec(
      prayerKey: prayerKey,
      prayerLabel: prayerLabel,
      mode: mode,
      soundType: type,
      soundValue: value,
      assetPath: asset,
      videoPath: videoPath,
      hour: hour,
      minute: minute,
    );
  }

  // ── playback ─────────────────────────────────────────────────────────

  /// Starts [spec]'s sound right now, without an alarm, a notification or a
  /// foreground service — the settings-screen preview. Returns false when
  /// the sound could not be opened (a deleted custom file, say), so the
  /// caller can tell the user instead of showing a mute screen.
  static Future<bool> preview(AdhanSpec spec) async {
    try {
      return await _player.invokeMethod<bool>('preview', spec.toMap()) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Stops everything: the preview player *and* a real firing (whose service
  /// also drops its notification and wake lock). Safe when nothing is running.
  static Future<void> stop() async {
    try {
      await _player.invokeMethod<void>('stop');
    } catch (_) {
      // Best-effort by design: this is what the Stop button calls, and the
      // UI must dismiss whether or not the platform call succeeded.
    }
  }

  static Future<void> mute() async {
    try {
      await _player.invokeMethod<void>('mute');
    } catch (_) {}
  }

  static Future<AdhanPlaybackState> state() async {
    try {
      final m = await _player.invokeMethod<Map<Object?, Object?>>('state');
      return m == null ? AdhanPlaybackState.idle : AdhanPlaybackState.fromMap(m);
    } catch (_) {
      return AdhanPlaybackState.idle;
    }
  }

  /// Closes `AdhanActivity` itself. Only meaningful inside the alert screen's
  /// own engine — the alert is its own task, so there is no route to pop.
  static Future<void> closeAlertScreen() async {
    try {
      await _player.invokeMethod<void>('close');
    } catch (_) {}
  }

  // ── scheduling ───────────────────────────────────────────────────────

  /// Replaces the whole daily schedule. Returns false when the OS refused
  /// *exact* alarms and armed them approximately instead.
  static Future<bool> scheduleDaily(List<AdhanSpec> prayers) async {
    try {
      return await _alarm.invokeMethod<bool>('scheduleDaily', {
            'prayers': prayers.map((p) => p.toMap()).toList(),
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Fires one prayer's adhan [delay] from now, through the identical alarm
  /// → receiver → service path a real prayer takes, under its own request
  /// code so it cannot disturb the daily schedule.
  static Future<bool> scheduleTest(
    AdhanSpec prayer, {
    Duration delay = const Duration(seconds: 8),
  }) async {
    try {
      return await _alarm.invokeMethod<bool>('scheduleTest', {
            'prayer': prayer.toMap(),
            'delaySeconds': delay.inSeconds,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> cancelAll() async {
    try {
      await _alarm.invokeMethod<void>('cancelAll');
    } catch (_) {}
  }

  static Future<bool> canScheduleExact() async {
    try {
      return await _alarm.invokeMethod<bool>('canScheduleExact') ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> openExactAlarmSettings() async {
    try {
      await _alarm.invokeMethod<void>('openExactAlarmSettings');
    } catch (_) {}
  }
}
