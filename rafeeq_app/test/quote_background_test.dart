import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The photographic backgrounds, checked against the two rules that decided
/// which ones could be shipped at all.
///
/// **The licence.** CLAUDE.md trap #18: a free image is not automatically free
/// to rehost. Only public-domain and CC0 files from Wikimedia Commons were
/// taken, each one checked through the API rather than trusted from a
/// site-wide claim. CC BY and CC BY-SA were excluded on purpose. If a file
/// ever appears here under another licence, that decision has been undone by
/// accident.
///
/// **The contrast.** Trap #15: a translucent layer over a ground composites to
/// something neither colour predicts, and three mushaf themes shipped at
/// 2.3–2.6 : 1 because a pairing was judged by eye. Every image's brightest
/// 60-pixel region was measured through the exact scrim the card draws, and
/// the number is recorded per image.
void main() {
  final doc = jsonDecode(
    File('assets/data/quote_backgrounds.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final images = (doc['images'] as List<dynamic>).cast<Map<String, dynamic>>();

  test('every background is public domain or CC0', () {
    expect(images, isNotEmpty);
    final ok = RegExp(r'^(public domain|cc0|cc-zero|pd-|no restrictions)',
        caseSensitive: false);
    for (final i in images) {
      final licence = (i['licence'] as String? ?? '').trim();
      expect(ok.hasMatch(licence), isTrue,
          reason: '${i['id']} is "$licence" — only PD and CC0 were cleared '
              'for rehosting, and CC BY/BY-SA were excluded on purpose');
    }
  });

  test('every background records where its licence can be checked', () {
    for (final i in images) {
      expect((i['page'] as String? ?? ''), contains('commons.wikimedia.org'),
          reason: '${i['id']} has no Commons page to verify against');
    }
  });

  test('every background clears 4.5:1 through the scrim', () {
    for (final i in images) {
      expect((i['contrast'] as num).toDouble(), greaterThanOrEqualTo(4.5),
          reason: '${i['id']} measures ${i['contrast']}:1 — the saying would '
              'be hard to read where the picture is brightest');
    }
  });

  test('the manifest and the bundled files are the same set', () {
    // A manifest entry with no file is a card that opens blank; a file with
    // no entry is an image nobody checked the licence of.
    final dir = Directory('assets/quote_backgrounds');
    expect(dir.existsSync(), isTrue);
    final onDisk = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.jpg'))
        .map((f) => f.uri.pathSegments.last.replaceAll('.jpg', ''))
        .toSet();
    final listed = images.map((i) => i['id'] as String).toSet();
    expect(listed.difference(onDisk), isEmpty,
        reason: 'listed but not bundled');
    expect(onDisk.difference(listed), isEmpty,
        reason: 'bundled but not listed — its licence was never recorded');
  });

  test('the scrim the app draws is the scrim they were measured through', () {
    final scrim = doc['scrim'] as Map<String, dynamic>;
    expect(scrim['argb'], '0xCC071626');
    // 0xCC of 0xFF is 80%, which is what the measurement used.
    expect((scrim['alpha'] as num).toDouble(), closeTo(0.80, 0.005));
  });
}
