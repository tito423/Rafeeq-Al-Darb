import 'dart:io';

/// What a server answers a HEAD for [url], or null when nothing answered
/// at all — which, for a public file host, means the phone has no usable
/// connection.
///
/// The players need the difference: just_audio reports every failed source
/// as «(0) Source error». A 404 means THIS file is missing and another voice
/// can stand in; no answer means every host is out of reach and the right
/// thing is to wait — announcing a substitute voice there told the reader
/// something false (seen on emulator-5554 with the network cut, 2026-09-24).
Future<int?> httpStatusOf(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
    return null;
  }
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
  try {
    final req = await client.headUrl(uri).timeout(const Duration(seconds: 6));
    // R2 refuses a request with no User-Agent (CLAUDE.md trap #19).
    req.headers.set(HttpHeaders.userAgentHeader, 'RafeeqAlDarb');
    final res = await req.close().timeout(const Duration(seconds: 6));
    return res.statusCode;
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}
