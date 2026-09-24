import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/quran_audio/data/quran_audio_player.dart';
import 'package:rafeeq_app/features/quran_audio/data/surah_fallback.dart';

/// The surah player's last backup: the same surah in another voice.
/// عبدالله البريمي (moshaf 57) lists An-Nas and mp3quran answers 404 for it —
/// the one missing file in 801 probes on 2026-09-24.
void main() {
  PlayerTrack track(String id) => PlayerTrack(
        id: id,
        title: 'سورة الناس',
        artist: 'عبدالله البريمي',
        url: 'https://server8.mp3quran.net/brmi/114.mp3',
      );

  test('a missing surah falls back to al-Basit murattal, R2 first', () {
    final fb = SurahFallback.forTrack(track('m57-s114'))!;
    expect(fb.url, endsWith('/recitations/surah/basit_murattal/114.mp3'));
    expect(fb.fallbackUrl, 'https://server7.mp3quran.net/basit/114.mp3');
    // The voice actually heard is named; the tapped surah keeps its id so
    // the list still marks it.
    expect(fb.artist, 'عبد الباسط عبد الصمد');
    expect(fb.id, 'm57-s114');
    expect(fb.title, 'سورة الناس');
  });

  test('al-Basit himself has no further backup, so the walk ends', () {
    expect(SurahFallback.forTrack(track('m53-s114')), isNull);
  });

  test('an imported device file is not a surah and gets no stand-in', () {
    expect(SurahFallback.forTrack(track('device:content://x/1')), isNull);
  });

  test('originOnly drops the mirror and keeps nothing to fall back to', () {
    const t = PlayerTrack(
      id: 'm53-s1',
      title: 'الفاتحة',
      artist: 'عبد الباسط',
      url: 'https://r2/basit_murattal/001.mp3',
      fallbackUrl: 'https://server7.mp3quran.net/basit/001.mp3',
    );
    final o = t.originOnly();
    expect(o.url, 'https://server7.mp3quran.net/basit/001.mp3');
    expect(o.fallbackUrl, isNull);
  });
}
