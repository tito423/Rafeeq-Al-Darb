import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../app/app_locale_provider.dart';

/// One recitation of a reciter on mp3quran.net — a riwayah and a style
/// («حفص عن عاصم - مرتل», «المصحف المجود»), served as one MP3 per surah.
class Mp3Moshaf {
  final int id;
  final String name;

  /// Folder URL ending in `/`; surah N is `<server>NNN.mp3`.
  final String server;
  final List<int> surahs;

  const Mp3Moshaf({
    required this.id,
    required this.name,
    required this.server,
    required this.surahs,
  });

  factory Mp3Moshaf.fromJson(Map<String, dynamic> j) => Mp3Moshaf(
        id: (j['id'] as num).toInt(),
        name: (j['name'] as String? ?? '').trim(),
        server: j['server'] as String? ?? '',
        surahs: [
          for (final s in (j['surah_list'] as String? ?? '').split(','))
            ?int.tryParse(s.trim()),
        ]..sort(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'server': server,
        'surah_list': surahs.join(','),
      };

  String urlFor(int surah) =>
      '$server${surah.toString().padLeft(3, '0')}.mp3';
}

class Mp3Reciter {
  final int id;
  final String name;
  final List<Mp3Moshaf> moshafs;

  const Mp3Reciter({required this.id, required this.name, required this.moshafs});

  factory Mp3Reciter.fromJson(Map<String, dynamic> j) => Mp3Reciter(
        id: (j['id'] as num).toInt(),
        name: (j['name'] as String? ?? '').trim(),
        moshafs: [
          for (final m in (j['moshaf'] as List<dynamic>? ?? const []))
            Mp3Moshaf.fromJson(m as Map<String, dynamic>),
        ],
      );
}

/// The catalogue of «تحميل تلاوات القرآن»: mp3quran.net's public API v3.
///
/// Chosen over the alternatives because it is a documented JSON API rather
/// than a site to scrape, and because it was measured before a line of this
/// was written (2026-09-11): 241 reciters and 287 recitations, every moshaf id
/// unique, every `server` on https, every `surah_total` equal to the length of
/// its `surah_list`, and real files answering a range request with
/// `206 audio/mpeg` from a Cloudflare edge.
///
/// The list is cached on disk after every successful fetch, so a reader who
/// has opened this screen once can browse it offline — and the downloaded
/// recitations never depend on it at all.
class Mp3QuranApi {
  Mp3QuranApi._();

  static const _base = 'https://www.mp3quran.net/api/v3';

  /// The API's own language codes. Urdu gets the Arabic list: its Urdu names
  /// came back as SEO keyword strings («قرآن,کریم,آڈیو,لائبریری,MP3…») rather
  /// than reciters' names.
  static String languageFor(String locale) => switch (locale) {
        'en' => 'eng',
        'fr' || 'ru' || 'es' || 'pt' => locale,
        _ => 'ar',
      };

  static Future<File> _cacheFile(String lang) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'quran_audio', 'cache'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return File(p.join(dir.path, 'reciters_$lang.json'));
  }

  static Future<List<Mp3Reciter>> reciters(String locale) async {
    final lang = languageFor(locale);
    final cache = await _cacheFile(lang);
    try {
      final res = await Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        responseType: ResponseType.plain,
      )).get<String>('$_base/reciters', queryParameters: {'language': lang});
      final raw = res.data ?? '';
      final list = parse(raw);
      if (list.isNotEmpty) {
        await cache.writeAsString(raw, flush: true);
        return list;
      }
    } catch (_) {
      // fall through to the cached copy
    }
    if (cache.existsSync()) {
      final list = parse(await cache.readAsString());
      if (list.isNotEmpty) return list;
    }
    throw const SocketException('mp3quran reciters unavailable');
  }

  static List<Mp3Reciter> parse(String raw) {
    try {
      final doc = jsonDecode(raw) as Map<String, dynamic>;
      final list = [
        for (final r in doc['reciters'] as List<dynamic>)
          Mp3Reciter.fromJson(r as Map<String, dynamic>),
      ]..removeWhere((r) => r.moshafs.isEmpty || r.name.isEmpty);
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    } catch (_) {
      return const [];
    }
  }
}

final mp3RecitersProvider = FutureProvider<List<Mp3Reciter>>(
  (ref) => Mp3QuranApi.reciters(ref.watch(appLocaleProvider)),
);
