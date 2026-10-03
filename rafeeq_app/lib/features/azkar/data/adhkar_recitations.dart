/// The morning and the evening adhkar to listen to or download.
///
/// **2026-10-03** (owner: «تمسح محتوى كروت اذكار الصباح … والمساء … وحط
/// بدلهم الاذكار بصوت جوجل», then «الصوت قارئ وجيميناي»): the seven
/// recordings by named reciters (IslamHouse, Internet Archive) were replaced
/// by one voicing of Hisn al-Muslim's own text in this app (azkar.db §27, §28):
/// every Qur'an passage and basmala is Mishary Alafasy's ayah recording
/// (everyayah.com), every other dhikr is Gemini TTS read once, each Gemini clip
/// transcribed back with whisper-medium and matched letter for letter
/// (lowest 96.6 %; rafeeq-control tools/azkar_voice.py, results/azkar_voice/).
/// Their files stay on the bucket (azkar/recitations/) untouched.
///
/// Earlier history: complete recordings by named
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

String _voice(String file) =>
    '${AppConfig.contentBaseUrl}/azkar/rafeeq_voice/$file';

const _source = 'https://github.com/tito423/Rafeeq-Al-Darb';

final adhkarRecitations = <AdhkarRecitation>[
  AdhkarRecitation(
    id: 'rafeeq_morning_v1',
    reciterAr: 'الآيات بصوت العفاسي والأذكار بصوت Gemini',
    reciterEn: 'Ayahs by Alafasy, adhkar by a Gemini voice',
    time: AdhkarTime.morning,
    url: _voice('morning_v1.mp3'),
    bytes: 6991979,
    seconds: 583,
    sourceName: 'رفيق الدرب',
    sourcePage: _source,
  ),
  AdhkarRecitation(
    id: 'rafeeq_evening_v1',
    reciterAr: 'الآيات بصوت العفاسي والأذكار بصوت Gemini',
    reciterEn: 'Ayahs by Alafasy, adhkar by a Gemini voice',
    time: AdhkarTime.evening,
    url: _voice('evening_v1.mp3'),
    bytes: 6773805,
    seconds: 564,
    sourceName: 'رفيق الدرب',
    sourcePage: _source,
  ),
];
