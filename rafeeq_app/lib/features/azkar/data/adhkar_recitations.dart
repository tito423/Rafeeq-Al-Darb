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
import 'azkar_backgrounds.dart';
import 'azkar_categories.dart';

/// The photograph behind the morning or the evening listening screen: the
/// same licensed photos as the adhkar cards (azkar_backgrounds.dart, credited
/// on Sources) - the Faisal Mosque at sunrise, minarets at sunset.
String adhkarListenBackground(AdhkarTime t) =>
    azkarCategoryBackgrounds[t == AdhkarTime.evening
        ? AzkarCategory.evening
        : AzkarCategory.morning]!;

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

String _r2(String file) =>
    '${AppConfig.contentBaseUrl}/azkar/recitations/$file';

const _ih =
    'https://d1.islamhouse.com/data/ar/ih_sounds/chain_01/Mishari_Raashid/Azkar_AlSba7_w_AlMsa/';
const _iaSeven = 'https://archive.org/details/azkar_alsabah_w_almsaa';
const _iaSix =
    'https://archive.org/details/AthkarAlsabahAbdulazizBi356856835685683356568';

/// **2026-10-08** (owner: «حاول تدور على اذكار … مفصله اذكار الصباح واذكار
/// المساء غير اللي هي متولده بالصوت», then «دوس»): real voices back, each
/// morning and evening separate. Every file below was transcribed
/// (scripts/verify_adhkar_recordings.py, faster-whisper small, its opening
/// 8 and closing 2 minutes; report scripts/out/adhkar_verify.json) and kept
/// only when it says the words of ITS time - «أصبحنا وأصبح الملك لله» in the
/// morning, «أمسينا وأمسى الملك لله» in the evening - or announces itself
/// («أذكار الصباح بصوت …»), and ends on a closing dhikr rather than cut off.
/// Turned away: Hassan Saleh and Muhammad Jibreel (nothing told their two
/// files apart), Yahya Hawwa (a 4:45 morning with no Ayat al-Kursi). The
/// archive.org files are served from R2 (owner, 2026-10-02: archive.org is
/// slow), same bytes, sizes checked after upload; al-Afasy streams from
/// IslamHouse. Names are as the sources give them.
final adhkarRecitations = <AdhkarRecitation>[
  for (final (id, ar, en, m, e, url, page) in [
    (
      'alafasy',
      'مشاري راشد العفاسي',
      'Mishary Rashid Alafasy',
      (33333722, 833),
      (24109982, 602),
      'ih',
      'https://islamhouse.com/ar/audios/92368/',
    ),
    (
      'fares_abbad',
      'فارس عباد',
      'Fares Abbad',
      (19736031, 1233),
      (14516557, 907),
      'r2',
      _iaSeven,
    ),
    (
      'samir_albashiri',
      'سمير البشيري',
      'Samir al-Bashiri',
      (9228119, 577),
      (8640887, 540),
      'r2',
      _iaSeven,
    ),
    (
      'rami_muhammad',
      'رامي محمد',
      'Rami Muhammad',
      (15586532, 974),
      (19665396, 1229),
      'r2',
      _iaSeven,
    ),
    (
      'abdulaziz_bin_ibrahim',
      'عبد العزيز بن إبراهيم',
      'Abdulaziz bin Ibrahim',
      (18882240, 1172),
      (15442854, 957),
      'r2',
      _iaSix,
    ),
    (
      'faisal_labban',
      'فيصل لبان',
      'Faisal Labban',
      (7302418, 448),
      (7638457, 469),
      'r2',
      _iaSix,
    ),
  ])
    for (final (time, size) in [
      (AdhkarTime.morning, m),
      (AdhkarTime.evening, e),
    ])
      AdhkarRecitation(
        id: '${id}_${time.name}',
        reciterAr: ar,
        reciterEn: en,
        time: time,
        url: url == 'ih'
            ? '$_ih${time == AdhkarTime.morning ? 'ar_1434_Azkar_AlSba7' : 'ar_1434_Azkar_AlMsa'}.mp3'
            : _r2('${id}_${time.name}.mp3'),
        bytes: size.$1,
        seconds: size.$2,
        sourceName: url == 'ih' ? 'IslamHouse' : 'archive.org',
        sourcePage: page,
      ),
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
