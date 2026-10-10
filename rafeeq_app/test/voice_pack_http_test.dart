import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/assistant/data/voice_pack_http.dart';

void main() {
  test('ASR TLS root matches the official public ISRG Root X1 certificate', () {
    final body = voicePackIsrgRootX1
        .replaceAll('-----BEGIN CERTIFICATE-----', '')
        .replaceAll('-----END CERTIFICATE-----', '')
        .replaceAll(RegExp(r'\s'), '');
    expect(
      sha256.convert(base64.decode(body)).toString(),
      '96bcec06264976f37460779acf28c5a7cfe8a3c0aae11a8ffcee05c0bddf08c6',
    );
    final client = createVoicePackHttpClient();
    client.close(force: true);
  });
}
