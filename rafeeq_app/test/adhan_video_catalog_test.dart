import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/adhan/data/adhan_video_catalog.dart';

/// The adhan background is drawn full-screen with `BoxFit.cover` on a portrait
/// phone. That is a magnifying glass: on a 1080×2400 screen a 640×360
/// landscape clip is scaled **6.7×** and most of its frame is thrown away.
///
/// The owner reported «الفيديو بتاع الأذان لما بيشتغل بتبقى جودته سيئة جدًا»,
/// and `scripts/probe_adhan_videos.py` found why — three of the ten hosted
/// clips were standard definition, and the 640×360 one was
/// `adhanVideoCatalog.first`, which is what
/// `adhan_presentation_provider.dart` uses as the default. The clip he saw
/// out of the box was the worst in the set.
///
/// These assertions are the thing that stops that coming back. The numbers in
/// the catalogue are measured, so they are checked against the measurement.
void main() {
  test('the DEFAULT is HD — that is the one the owner sees unasked', () {
    final first = adhanVideoCatalog.first;
    final shortSide = first.width < first.height ? first.width : first.height;
    expect(shortSide, greaterThanOrEqualTo(1080),
        reason: 'the default was a 640x360 clip scaled 6.7x by BoxFit.cover, '
            'which is what «جودته سيئة جدًا» was describing');
    expect(first.isPortrait, isTrue,
        reason: 'the adhan screen is portrait; a landscape default is scaled '
            'hard and cropped to a sliver');
  });

  test('SD clips are offered last, never first', () {
    var seenSd = false;
    for (final v in adhanVideoCatalog) {
      final shortSide = v.width < v.height ? v.width : v.height;
      if (shortSide < 720) {
        seenSd = true;
      } else {
        expect(seenSd, isFalse,
            reason: '${v.id} is HD but sits after an SD clip — the list is '
                'ordered best-first and the default is its head');
      }
    }
  });

  test('every clip is what its label says, verified frame by frame', () {
    // Six of the ten hosted clips were NOT the scene the app named them: a
    // Pakistani flag was «رحاب مسجد», gold calligraphy was «الكعبة المشرّفة
    // عن قرب», a cartoon was «ساحات الحرم المكي». They were caught by pulling
    // four frames from each clip and looking, not by reading the catalogue.
    // `adhan_video_content.json` is that record; nothing may be offered that
    // is not in it and marked to keep.
    final file = File('../adhan_video_content.json');
    expect(file.existsSync(), isTrue,
        reason: 'the record of what each clip shows is missing');
    final content =
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    for (final v in adhanVideoCatalog) {
      final row = content[v.id] as Map<String, dynamic>?;
      expect(row, isNotNull,
          reason: '${v.id} is offered but its frames were never checked');
      expect(row!['keep'], isTrue,
          reason: '${v.id} was checked and marked not to keep: ${row['why']}');
      expect((row['shows'] as String).trim(), isNotEmpty);
    }
    for (final e in content.entries) {
      final row = e.value as Map<String, dynamic>;
      if (row['keep'] == false) {
        expect(adhanVideoCatalog.any((v) => v.id == e.key), isFalse,
            reason: '${e.key} is offered again: ${row['why']}');
      }
    }
  });

  test('every entry carries measured numbers, none of them zero', () {
    expect(adhanVideoCatalog, isNotEmpty);
    final ids = <String>{};
    for (final v in adhanVideoCatalog) {
      expect(ids.add(v.id), isTrue, reason: 'duplicate id ${v.id}');
      expect(v.approxSizeBytes, greaterThan(0), reason: v.id);
      expect(v.width, greaterThan(0), reason: v.id);
      expect(v.height, greaterThan(0), reason: v.id);
      expect(v.seconds, greaterThan(0), reason: v.id);
      expect(v.url, contains('/adhan/video/${v.id}.mp4'));
    }
  });

  test('the catalogue matches what ffmpeg read off the bucket', () {
    // `adhan_video_probe.json` is the measurement; the catalogue is a copy of
    // it. If someone edits one and not the other, the picker starts lying
    // about what a clip costs and how big it is — which is §1.1's «الحجم:
    // 1.0 MB» all over again.
    final file = File('../adhan_video_probe.json');
    if (!file.existsSync()) return;
    final probe = {
      for (final r in jsonDecode(file.readAsStringSync()) as List<dynamic>)
        (r as Map<String, dynamic>)['id'] as String: r
    };
    for (final v in adhanVideoCatalog) {
      final r = probe[v.id];
      expect(r, isNotNull, reason: '${v.id} was never probed');
      expect(v.width, r!['width'], reason: v.id);
      expect(v.height, r['height'], reason: v.id);
      expect(v.approxSizeBytes, r['bytes'], reason: v.id);
    }
  });
}
