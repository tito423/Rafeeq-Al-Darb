/// Complete recordings of the morning and the evening adhkar, by named
/// reciters, to listen to or download (owner, 2026-09-29: «الاستماع لأذكار
/// الصباح منفردة وأذكار المساء منفردة … ولو فيه أكتر من شيخ اعمل قايمة
/// بأسمائهم مع إمكانية تنزيلهم»; and after: «مش شرط قراءة الأذكار الموجودة
/// في الأذكار … بس تكون كاملة»).
///
/// Every url below answered 206 audio/mpeg to a range request on
/// 2026-09-30; sizes are the servers' own Content-Length, durations the
/// file's own (ffmpeg for IslamHouse, archive.org's metadata for the rest).
/// IslamHouse's two are streamed from IslamHouse; the five from archive.org
/// were slow there and are served from the bucket since 2026-10-02 (same
/// bytes, archive.org credited as the source).
///
/// Where a recording holds the morning AND the evening in one file, it is
/// offered under both and says so ([AdhkarTime.both]) - cutting it in two
/// would be editing someone's recording.
library;

import '../../../core/config/app_config.dart';

enum AdhkarTime { morning, evening, both }

class AdhkarRecitation {
  final String id;
  final String reciterAr;
  final String reciterEn;
  final AdhkarTime time;
  final String url;
  final int bytes;
  final int seconds;

  /// Where it is published, as shown to the reader.
  final String sourceName;
  final String sourcePage;

  const AdhkarRecitation({
    required this.id,
    required this.reciterAr,
    required this.reciterEn,
    required this.time,
    required this.url,
    required this.bytes,
    required this.seconds,
    required this.sourceName,
    required this.sourcePage,
  });

  String get downloadId => 'adhkar_audio_$id';
  String get fileName => 'adhkar_$id.mp3';

  /// Offered for [t]: its own time, or both.
  bool fits(AdhkarTime t) => time == t || time == AdhkarTime.both;
}

const _ihDir =
    'https://d1.islamhouse.com/data/ar/ih_sounds/chain_01/Mishari_Raashid/Azkar_AlSba7_w_AlMsa';
const _ihPage = 'https://islamhouse.com/ar/audios/92368/';
const _iaPage = 'https://archive.org/details/adhkar-alsabah-walmasa';

// The archive.org item streamed slowly (owner, 2026-10-02: «بطئ»), so its
// five files are copied to the bucket byte for byte (sizes checked against
// archive.org's own) and played from there, with the GitHub mirror behind it
// (ContentMirrors). archive.org stays the credited source: [sourcePage].
String _r2(String id) => '${AppConfig.contentBaseUrl}/azkar/recitations/$id.mp3';

final adhkarRecitations = <AdhkarRecitation>[
  const AdhkarRecitation(
    id: 'alafasy_morning',
    reciterAr: 'مشاري راشد العفاسي',
    reciterEn: 'Mishary Rashid Alafasy',
    time: AdhkarTime.morning,
    url: '$_ihDir/ar_1434_Azkar_AlSba7.mp3',
    bytes: 33333722,
    seconds: 832,
    sourceName: 'IslamHouse',
    sourcePage: _ihPage,
  ),
  const AdhkarRecitation(
    id: 'alafasy_evening',
    reciterAr: 'مشاري راشد العفاسي',
    reciterEn: 'Mishary Rashid Alafasy',
    time: AdhkarTime.evening,
    url: '$_ihDir/ar_1434_Azkar_AlMsa.mp3',
    bytes: 24109982,
    seconds: 602,
    sourceName: 'IslamHouse',
    sourcePage: _ihPage,
  ),
  AdhkarRecitation(
    id: 'abkar',
    reciterAr: 'إدريس أبكر',
    reciterEn: 'Idrees Abkar',
    time: AdhkarTime.both,
    url: _r2('abkar'),
    bytes: 14529350,
    seconds: 900,
    sourceName: 'Internet Archive',
    sourcePage: _iaPage,
  ),
  AdhkarRecitation(
    id: 'ghamdi',
    reciterAr: 'سعد الغامدي',
    reciterEn: 'Saad Al-Ghamdi',
    time: AdhkarTime.both,
    url: _r2('ghamdi'),
    bytes: 7009452,
    seconds: 876,
    sourceName: 'Internet Archive',
    sourcePage: _iaPage,
  ),
  AdhkarRecitation(
    id: 'otaibi',
    reciterAr: 'سلمان العتيبي',
    reciterEn: 'Salman Al-Utaybi',
    time: AdhkarTime.both,
    url: _r2('otaibi'),
    bytes: 14691683,
    seconds: 1224,
    sourceName: 'Internet Archive',
    sourcePage: _iaPage,
  ),
  AdhkarRecitation(
    id: 'abbad',
    reciterAr: 'فارس عباد',
    reciterEn: 'Fares Abbad',
    time: AdhkarTime.both,
    url: _r2('abbad'),
    bytes: 29556402,
    seconds: 2463,
    sourceName: 'Internet Archive',
    sourcePage: _iaPage,
  ),
  AdhkarRecitation(
    id: 'rifai',
    reciterAr: 'هاني الرفاعي',
    reciterEn: 'Hani Ar-Rifai',
    time: AdhkarTime.both,
    url: _r2('rifai'),
    bytes: 16510283,
    seconds: 1024,
    sourceName: 'Internet Archive',
    sourcePage: _iaPage,
  ),
];
