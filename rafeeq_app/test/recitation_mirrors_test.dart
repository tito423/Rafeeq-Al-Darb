import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/services/recitation_mirrors.dart';
import 'package:rafeeq_app/features/quran_audio/data/mp3quran_api.dart';

void main() {
  test('the parts match the script that uploads them', () {
    final py = File('../scripts/github_mirror_recitations.py').readAsStringSync();
    final m = RegExp(r'AYAH_PART_STARTS = \[([0-9, ]+)\]').firstMatch(py)!;
    expect(m.group(1)!.split(',').map((s) => int.parse(s.trim())).toList(),
        RecitationMirrors.ayahPartStarts);
  });

  test('an ayah is found in the part its surah starts', () {
    expect(RecitationMirrors.partOf(1), 1);
    expect(RecitationMirrors.partOf(6), 1);
    expect(RecitationMirrors.partOf(7), 2);
    expect(RecitationMirrors.partOf(79), 6);
    expect(RecitationMirrors.partOf(114), 7);
    expect(RecitationMirrors.ayahUrl('Husary_128kbps', 2, 255),
        'https://github.com/tito423/rafeeq-recitations/releases/download/ayah-Husary_128kbps-p1/002255.mp3');
    expect(RecitationMirrors.surahUrl(1, 36),
        'https://github.com/tito423/rafeeq-recitations/releases/download/surah-1/036.mp3');
  });

  test('a listed whole-surah set plays from the copy, the origin behind it', () {
    const m = Mp3Moshaf(id: 987654, name: 'x', server: 'https://server.example/x/', surahs: [1]);
    expect(m.urlFor(1), 'https://server.example/x/001.mp3');
    final r = RecitationMirrors.instance;
    expect(r.apply('{"version": 9999999999, "repo": "tito423/rafeeq-recitations", '
        '"ayahPartStarts": [1, 7, 16, 25, 37, 53, 80], "ayah": ["Husary_128kbps"], "surah": [987654]}'), isTrue);
    expect(m.urlFor(1), RecitationMirrors.surahUrl(987654, 1));
    expect(m.originUrlFor(1), 'https://server.example/x/001.mp3');
    expect(r.hasAyah('Husary_128kbps'), isTrue);
  });

  test('a list for another layout or an older one is refused', () {
    final r = RecitationMirrors.instance;
    expect(r.apply('{"version": 99999999999, "repo": "tito423/rafeeq-recitations", '
        '"ayahPartStarts": [1, 50], "ayah": [], "surah": []}'), isFalse);
    expect(r.apply('{"version": 1, "repo": "tito423/rafeeq-recitations", '
        '"ayahPartStarts": [1, 7, 16, 25, 37, 53, 80], "ayah": [], "surah": []}'), isFalse);
    expect(r.apply('not json'), isFalse);
  });
}
