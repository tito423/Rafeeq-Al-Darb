import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/config/app_config.dart';
import 'package:rafeeq_app/core/config/content_mirrors.dart';
import 'package:rafeeq_app/features/assistant/data/rafeeq_voice_pack.dart';

/// The app's list of mirrored folders and the upload script's must be the
/// same list: a folder the app believes mirrored but the script never
/// uploads is a fallback that 404s exactly when it is needed.
void main() {
  for (final file in [...voicePackFiles, ...accuratePackFiles]) {
    test(
      'assistant pack ${file.folder}/${file.name} falls back when R2 fails',
      () async {
        final mirror =
            'https://github.com/${ContentMirrors.githubRepo}/'
            'releases/download/content-mirror/asr__${file.folder}__${file.name}';
        final tried = <String>[];
        final name = await ContentMirrors.fetchFirst<String>(file.url, (
          url,
        ) async {
          tried.add(url);
          if (url != mirror) throw const SocketException('primary unavailable');
          return file.name;
        });
        expect(name, file.name);
        expect(tried.first, file.url);
        expect(tried.last, mirror);
        expect(tried.length, greaterThan(1));
      },
    );
  }

  test('ContentMirrors.githubReleases equals the script RELEASES', () {
    final py = File('../scripts/github_content_mirror.py').readAsStringSync();
    final block = RegExp(
      r'RELEASES = \{(.*?)\n\}',
      dotAll: true,
    ).firstMatch(py)!.group(1)!;
    final script = <String, List<String>>{};
    for (final m in RegExp(
      r'"([a-z-]+)":\s*\[(.*?)\]',
      dotAll: true,
    ).allMatches(block)) {
      script[m.group(1)!] = [
        for (final p in RegExp(r'"([^"]+)"').allMatches(m.group(2)!))
          p.group(1)!,
      ];
    }
    expect(script, isNotEmpty);
    expect(script, ContentMirrors.githubReleases);
  });

  test('a mirrored book gets R2 first, then its GitHub asset', () {
    const u = '${AppConfig.contentBaseUrl}/books/text/la_tahzan.json';
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

  test('an Unsplash background is served from the bucket first, Unsplash last', () {
    const u =
        'https://images.unsplash.com/photo-1542816417-0983c9c9ad53?w=640&q=70&fit=crop';
    final chain = ContentMirrors.of(u);
    expect(
      chain.first,
      '${AppConfig.contentBaseUrl}/images/backgrounds/photo-1542816417-0983c9c9ad53.jpg',
    );
    expect(
      chain,
      contains(
        'https://github.com/tito423/Rafeeq-Al-Darb/releases/download/'
        'content-mirror/images__backgrounds__photo-1542816417-0983c9c9ad53.jpg',
      ),
    );
    expect(chain.last, u);
  });

  test('per-ayah recitation and foreign hosts are not rewritten', () {
    const ayah =
        '${AppConfig.contentBaseUrl}/recitations/ayah/Alafasy_128kbps/001001.mp3';
    expect(ContentMirrors.of(ayah), [ayah]);
    const other = 'https://everyayah.com/data/Husary_128kbps/001001.mp3';
    expect(ContentMirrors.of(other), [other]);
  });

  test(
    'fetchFirst falls through to the mirror and rethrows when all fail',
    () async {
      const u = '${AppConfig.contentBaseUrl}/hadith/hadith.zip';
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
    },
  );
}
