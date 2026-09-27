import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'ayah_audio_service.dart';

/// Where the continuous recitation last was - reciter, surah, verse - kept
/// across the app being sent to the background, killed, or the phone
/// restarted, so «التلاوة المستمرة» can carry on with the same reciter from
/// the same verse (owner, 2026-09-27: «عاوز لما أرجع تاني وأضغط على التلاوة
/// المستمرة ... يكمل نفس القارئ مباشرة»).
///
/// Kept out of ayah_audio_service.dart (at its length ceiling): it only
/// listens to [AyahAudioService.continuous].
class RecitationResume {
  const RecitationResume(this.edition, this.surah, this.ayah);
  final String edition;
  final int surah;
  final int ayah;

  static const _key = 'recite_resume_v1';
  static RecitationResume? _last;
  static bool _started = false;

  /// The last position, or null when nothing has been recited yet.
  static Future<RecitationResume?> load() async {
    if (_last != null) return _last;
    final v = (await SharedPreferences.getInstance()).getString(_key);
    final p = v?.split('|');
    if (p == null || p.length != 3) return null;
    final s = int.tryParse(p[1]), a = int.tryParse(p[2]);
    if (s == null || a == null) return null;
    return _last = RecitationResume(p[0], s, a);
  }

  /// Starts recording every verse the continuous recitation reaches.
  /// Called once at launch.
  static void watch() {
    if (_started) return;
    _started = true;
    final audio = AyahAudioService.instance;
    audio.continuous.addListener(() {
      final c = audio.continuous.value;
      if (!c.active || c.surahId == null || c.ayahNumber == null) return;
      final r = RecitationResume(
          audio.continuousEdition, c.surahId!, c.ayahNumber!);
      if (_last != null &&
          _last!.edition == r.edition &&
          _last!.surah == r.surah &&
          _last!.ayah == r.ayah) {
        return;
      }
      _last = r;
      unawaited(SharedPreferences.getInstance().then((p) =>
          p.setString(_key, '${r.edition}|${r.surah}|${r.ayah}')));
    });
  }
}
