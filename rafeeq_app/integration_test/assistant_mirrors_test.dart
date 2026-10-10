import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rafeeq_app/core/config/content_mirrors.dart';
import 'package:rafeeq_app/features/assistant/data/rafeeq_voice_pack.dart';
import 'package:rafeeq_app/features/assistant/data/voice_pack_http.dart';

/// Run on the owned audit emulator, not the owner's app-data emulator.
/// Forces only the primary failure; mirror requests use real Android TLS/HTTP.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final file in [...voicePackFiles, ...accuratePackFiles]) {
    testWidgets(
      'real mirror for ${file.folder}/${file.name}',
      (tester) async {
        final client = createVoicePackHttpClient()
          ..connectionTimeout = const Duration(seconds: 30);
        client.badCertificateCallback = (certificate, host, port) {
          debugPrint(
            'Rejected TLS certificate for $host:$port: '
            '${certificate.subject}; issuer ${certificate.issuer}',
          );
          return false;
        };
        final tried = <String>[];
        try {
          await ContentMirrors.fetchFirst<void>(file.url, (url) async {
            tried.add(url);
            if (!url.startsWith('https://github.com/')) {
              throw const SocketException('primary unavailable for regression');
            }
            final uri = Uri.parse(url);
            final headers = await (await client.headUrl(uri)).close();
            expect(headers.statusCode, HttpStatus.ok);
            expect(headers.contentLength, file.bytes);
            await headers.drain<void>();
            // Token files are small enough to verify actual bytes as well.
            if (file.name == 'tokens.txt') {
              final response = await (await client.getUrl(uri)).close();
              expect(response.statusCode, HttpStatus.ok);
              var count = 0;
              final digest = await sha256
                  .bind(
                    response.map((chunk) {
                      count += chunk.length;
                      return chunk;
                    }),
                  )
                  .single;
              expect(count, file.bytes);
              expect(digest.toString(), file.sha256);
            }
          });
          expect(tried.first, file.url);
          expect(tried.last, contains('asr__${file.folder}__${file.name}'));
        } finally {
          client.close(force: true);
        }
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }
  for (final url in [
    'https://expired.x1.test-certs.letsencrypt.org/',
    'https://self-signed.badssl.com/',
  ]) {
    testWidgets('rejects invalid TLS at $url', (tester) async {
      final client = createVoicePackHttpClient()
        ..connectionTimeout = const Duration(seconds: 30);
      try {
        await expectLater(
          client.getUrl(Uri.parse(url)).then((request) => request.close()),
          throwsA(isA<HandshakeException>()),
        );
      } finally {
        client.close(force: true);
      }
    });
  }
}
