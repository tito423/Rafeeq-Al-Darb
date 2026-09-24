import 'app_config.dart';

/// Every host that holds the same bytes as one R2 object, in the order the
/// app tries them.
///
/// «حط خمس حلول احتياطية لكل حاجة بتستغل في التطبيق» (the owner,
/// 2026-09-24). Until then almost everything hosted — the 239 books, the
/// sciences / hadith / encyclopaedia packs, the translations, the mushaf
/// pages, the voice and the tasmee model — had exactly ONE source, R2.
///
/// The second host is GitHub Releases on the app's own repository, approved
/// by the owner that day; `scripts/github_content_mirror.py` copies the R2
/// bytes there verbatim (books stay gzip without Content-Encoding, trap #6)
/// and names each asset after its R2 key with '/' → '__'. Measured on the
/// first asset: 302 to release-assets.githubusercontent.com, 200,
/// `Accept-Ranges: bytes`, a range request answered 206.
///
/// [githubReleases] must equal the script's RELEASES —
/// `test/content_mirrors_test.dart` reads the script and holds them equal,
/// so a prefix added on one side only fails the build instead of pointing
/// the app at an asset that was never uploaded.
class ContentMirrors {
  ContentMirrors._();

  static const githubRepo = 'tito423/Rafeeq-Al-Darb';

  static const Map<String, List<String>> githubReleases = {
    'content-mirror': [
      'books/text/',
      'hadeethenc/',
      'hadith/',
      'sciences/',
      'quran/translations/',
      'channels/',
      'legal/',
      'asr/whisper-tiny-ar-quran/',
      'tts/open_ar_v1/',
      'ruqyah/',
    ],
    'content-mushaf': ['mushaf/madinah_qc/'],
    'content-surah': [
      'recitations/surah/basit_murattal/',
      'recitations/surah/maher_murattal/',
    ],
  };

  /// [url] first, then every mirror of it. A URL that is not on the app's
  /// bucket, or whose folder is not mirrored, comes back alone.
  static List<String> of(String url) {
    final base = '${AppConfig.contentBaseUrl}/';
    if (!url.startsWith(base)) return [url];
    final key = url.substring(base.length);
    for (final e in githubReleases.entries) {
      if (e.value.any(key.startsWith)) {
        return [
          url,
          'https://github.com/$githubRepo/releases/download/'
              '${e.key}/${key.replaceAll('/', '__')}',
        ];
      }
    }
    return [url];
  }

  /// Tries [fetch] on each mirror of [url] in turn and returns the first
  /// result [accept] takes. The last error is rethrown when none worked.
  static Future<T> fetchFirst<T>(
    String url,
    Future<T> Function(String url) fetch, {
    bool Function(T result)? accept,
  }) async {
    Object? lastError;
    for (final u in of(url)) {
      try {
        final r = await fetch(u);
        if (accept == null || accept(r)) return r;
        lastError = StateError('rejected response from $u');
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? StateError('no source for $url');
  }
}
