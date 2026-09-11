import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/quran_audio/data/mp3quran_api.dart';

/// «تحميل تلاوات القرآن» reads mp3quran.net's API v3. The record below is two
/// of Muhammad Siddiq al-Minshawi's recitations exactly as
/// `https://www.mp3quran.net/api/v3/reciters?language=ar` returned them on
/// 2026-09-11 — including the 1967 recording that has only 110 of the 114
/// surahs, which is the case a "1..114" assumption would get wrong: its
/// surah 16 does not exist on the server, and a download of it is a 404.
const _real = '''
{"reciters":[{"id":112,"name":"محمد صديق المنشاوي","letter":"م","date":"2026-08-21T11:38:47.000000Z","moshaf":[
 {"id":10924,"name":"حفص عن عاصم - تسجيل عام 1387 هـ - 1967م","rewaya_id":1,"server":"https://server10.mp3quran.net/minsh1387/","surah_total":110,"moshaf_type":120,"surah_list":"1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,17,18,19,20,21,22,25,26,27,28,29,30,31,32,33,34,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100,101,102,103,104,105,106,107,108,109,110,111,112,113,114"},
 {"id":113,"name":"المصحف المجود - المصحف المجود","rewaya_id":21,"server":"https://server10.mp3quran.net/minsh/Almusshaf-Al-Mojawwad/","surah_total":114,"moshaf_type":213,"surah_list":"1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100,101,102,103,104,105,106,107,108,109,110,111,112,113,114"}
]},{"id":999,"name":"","moshaf":[]}]}
''';

void main() {
  final reciters = Mp3QuranApi.parse(_real);

  test('a reciter with no name or no recitation is dropped', () {
    expect(reciters.map((r) => r.id), [112]);
  });

  test('the surah list is read from the record, not assumed to be 1..114', () {
    final m1967 = reciters.single.moshafs.firstWhere((m) => m.id == 10924);
    expect(m1967.surahs.length, 110);
    expect(m1967.surahs.contains(16), isFalse);
    expect(m1967.surahs.contains(23), isFalse);
    expect(m1967.surahs.first, 1);
    expect(m1967.surahs.last, 114);
  });

  test('a surah URL is the server folder plus a three-digit file name', () {
    // The same URL answered `206 audio/mpeg` to a range request.
    final mujawwad = reciters.single.moshafs.firstWhere((m) => m.id == 113);
    expect(mujawwad.urlFor(2),
        'https://server10.mp3quran.net/minsh/Almusshaf-Al-Mojawwad/002.mp3');
  });

  test('a recitation survives the library index round trip', () {
    final m = reciters.single.moshafs.first;
    final back = Mp3Moshaf.fromJson(m.toJson());
    expect(back.id, m.id);
    expect(back.server, m.server);
    expect(back.surahs, m.surahs);
  });

  test('garbage is an empty list, not a crash', () {
    expect(Mp3QuranApi.parse('<html>'), isEmpty);
  });

  test('Urdu reads the Arabic catalogue', () {
    // The Urdu response's names were SEO keyword strings, measured.
    expect(Mp3QuranApi.languageFor('ur'), 'ar');
    expect(Mp3QuranApi.languageFor('en'), 'eng');
    expect(Mp3QuranApi.languageFor('fr'), 'fr');
  });
}
