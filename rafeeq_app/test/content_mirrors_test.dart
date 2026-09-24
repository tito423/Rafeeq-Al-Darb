import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/config/app_config.dart';
import 'package:rafeeq_app/core/config/content_mirrors.dart';

/// The app's list of mirrored folders and the upload script's must be the
/// same list: a folder the app believes mirrored but the script never
/// uploads is a fallback that 404s exactly when it is needed.
void main() {
  test('ContentMirrors.githubReleases equals the script RELEASES', () {
    final py = File('../scripts/github_content_mirror.py').readAsStringSync();
    final block = RegExp(r'RELEASES = \{(.*?)\n\}', dotAll: true)
        .firstMatch(py)!
        .group(1)!;
    final script = <String, List<String>>{};
    for (final m in RegExp(r'"([a-z-]+)":\s*\[(.*?)\]', dotAll: true)
        .allMatches(block)) {
      script[m.group(1)!] = [
        for (final p in RegExp(r'"([^"]+)"').allMatches(m.group(2)!)) p.group(1)!
      ];
    }
    expect(script, isNotEmpty);
    expect(script, ContentMirrors.githubReleases);
  });

  test('a mirrored book gets R2 first, then its GitHub asset', () {
    final u = '${AppConfig.contentBaseUrl}/books/text/la_tahzan.json';
    expect(ContentMirrors.of(u), [
      u,
      'https://github.com/tito423/Rafeeq-Al-Darb/releases/download/'
          'content-mirror/books__text__la_tahzan.json',
    ]);
  });

  test('an r2.dev URL (a hop from a custom domain) still reaches GitHub', () {
    const u = '${ContentMirrors.r2DevBase}/hadith/hadith.zip';
    expect(ContentMirrors.of(u), [
      u,
      'https://github.com/tito423/Rafeeq-Al-Darb/releases/download/'
          'content-mirror/hadith__hadith.zip',
    ]);
  });

  test('per-ayah recitation and foreign hosts are not rewritten', () {
    final ayah =
        '${AppConfig.contentBaseUrl}/recitations/ayah/Alafasy_128kbps/001001.mp3';
    expect(ContentMirrors.of(ayah), [ayah]);
    const other = 'https://everyayah.com/data/Husary_128kbps/001001.mp3';
    expect(ContentMirrors.of(other), [other]);
  });

  test('fetchFirst falls through to the mirror and rethrows when all fail',
      () async {
    final u = '${AppConfig.contentBaseUrl}/hadith/hadith.zip';
    final tried = <String>[];
    final r = await ContentMirrors.fetchFirst<int>(u, (x) async {
      tried.add(x);
      if (x == u) throw const SocketException('down');
      return 42;
    });
    expect(r, 42);
    expect(tried.length, 2);
    await expectLater(
      ContentMirrors.fetchFirst<int>(u, (_) async => 0, accept: (v) => v > 0),
      throwsA(isA<StateError>()),
    );
  });
}
