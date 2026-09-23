import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rafeeq_app/core/services/ayah_audio_service.dart';
import 'package:rafeeq_app/core/config/app_config.dart';
import 'package:rafeeq_app/core/services/recitation_source.dart';
import 'package:rafeeq_app/features/quran_audio/data/mp3quran_api.dart';
import 'package:rafeeq_app/features/downloads/data/reciters_provider.dart';

/// The reciter list the app shows IS `RecitationSource.verifiedMirrors`
/// (`recitersProvider` filters by it), because a reciter with no reachable
/// file plays nothing and says nothing — which is exactly what the owner hit
/// on 2026-09-23: 157 of the 175 catalogued Arabic editions answer 403 on the
/// audio CDN and exist nowhere else the app looks.
///
/// So a typo in a key here does not fail loudly — it removes a shaykh from
/// the picker. That is what this file is for. It cannot check the network;
/// each folder was range-checked by hand at its first and last ayah when it
/// was added, and `_reciter_cdn_check.txt` / the commit message record it.
void main() {
  final raw = File('assets/data/catalogs/audio_editions.json').readAsStringSync();
  final editions = (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();

  Map<String, dynamic>? byId(String id) {
    for (final e in editions) {
      if (e['identifier'] == id) return e;
    }
    return null;
  }

  test('every mapped edition is a real, named Arabic audio edition', () {
    for (final id in RecitationSource.verifiedMirrors.keys) {
      final e = byId(id);
      expect(e, isNotNull, reason: '$id is not in the editions catalogue');
      expect(e!['language'], 'ar', reason: '$id is not an Arabic edition');
      expect(e['format'], 'audio', reason: '$id is not an audio edition');
      // `recitersProvider` drops an entry whose name is just its own id.
      expect(e['name'], isNot(id), reason: '$id has no real name');
      expect(e['englishName'], isNot(id), reason: '$id has no real name');
    }
  });

  test('no two reciters are pointed at the same folder', () {
    final folders = RecitationSource.verifiedMirrors.values.toList();
    expect(folders.toSet().length, folders.length,
        reason: 'a copy-paste would give one recitation two shaykhs');
  });

  test('a folder name is a plausible everyayah folder', () {
    for (final entry in RecitationSource.verifiedMirrors.entries) {
      expect(entry.value.trim(), isNotEmpty, reason: entry.key);
      expect(entry.value, isNot(contains('/')), reason: entry.key);
      expect(entry.value, isNot(contains(' ')),
          reason: '${entry.key}: a space would have to be percent-encoded');
    }
  });

  test('the list is the 35 that were verified, not the whole catalogue', () {
    // 37 folders matched by name; two were dropped after their directory
    // index was checked against the Hafs ayah counts — see the map's own
    // note. A reciter here must have ALL 6,236.
    expect(RecitationSource.verifiedMirrors.length, 35);
    final named = editions.where((e) =>
        e['language'] == 'ar' &&
        e['format'] == 'audio' &&
        e['name'] != e['identifier'] &&
        e['englishName'] != e['identifier']);
    expect(named.length, greaterThan(35),
        reason: 'the catalogue is meant to be bigger than what is playable');
  });

  group('a reciter saved before the fix', () {
    setUp(() => TestWidgetsFlutterBinding.ensureInitialized());

    Future<String> restored(Map<String, Object> prefs) async {
      SharedPreferences.setMockInitialValues(prefs);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(selectedReciterProvider);
      // `_restore` is a future the notifier starts in its constructor.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      return container.read(selectedReciterProvider);
    }

    test('is dropped when it has no reachable file', () async {
      // ar.ahmedalhammad is one of the 157: 403 on the CDN, no everyayah
      // folder. A phone holding it would stay silent for ever otherwise.
      expect(RecitationSource.hasVerifiedMirror('ar.ahmedalhammad'), isFalse);
      expect(
        await restored({'recitation.selected_edition': 'ar.ahmedalhammad'}),
        AyahAudioService.defaultEdition,
      );
    });

    test('is kept when it does have one', () async {
      expect(
        await restored({'recitation.selected_edition': 'ar.alafasy'}),
        'ar.alafasy',
      );
    });
  });

  group('mirror first, and the public origin right behind it', () {
    // `urlsFor` asks the download library for a local copy first, and that
    // library looks for its folder through path_provider — a plugin with no
    // implementation in a unit test. Point it at an empty temp folder: no
    // reciter is downloaded there, which is exactly the case under test.
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => Directory.systemTemp.createTempSync('rafeeq_ps').path,
      );
    });

    final script =
        File('../scripts/r2_mirror_recitations.py').readAsStringSync();

    Set<String> dictKeys(String name) {
      final body = RegExp(name + r' = \{(.*?)\n\}', dotAll: true)
          .firstMatch(script)!
          .group(1)!;
      return {
        for (final m in RegExp(r'"([^"]+)":').allMatches(body)) m.group(1)!,
      };
    }

    test('the app mirrors exactly the per-ayah folders the script uploads',
        () {
      final uploaded = dictKeys('AYAH_SETS');
      expect(uploaded, isNotEmpty);
      expect(RecitationSource.mirroredOnR2Folders, uploaded);
      for (final f in uploaded) {
        expect(RecitationSource.verifiedMirrors.values, contains(f),
            reason: '$f is mirrored but no listed reciter plays it');
      }
    });

    test('and exactly the whole-surah sets', () {
      expect(Mp3Moshaf.r2Mirrors.values.toSet(), dictKeys('SURAH_SETS'));
    });

    test('a mirrored reciter asks the bucket first, then everyayah, then the CDN',
        () {
      final urls = RecitationSource.urlsFor(
          edition: 'ar.alafasy', surah: 2, ayah: 255, globalAyah: 262);
      expect(urls.first,
          '${AppConfig.contentBaseUrl}/recitations/ayah/Alafasy_128kbps/002255.mp3');
      expect(urls[1], contains('everyayah.com/data/Alafasy_128kbps/002255.mp3'));
      expect(urls.length, greaterThanOrEqualTo(3));
      expect(AppConfig.isOwnMirror(urls.first), isTrue);
      expect(AppConfig.isOwnMirror(urls[1]), isFalse);
    });

    test('an unmirrored reciter is untouched: everyayah first', () {
      final urls = RecitationSource.urlsFor(
          edition: 'ar.husary', surah: 2, ayah: 255, globalAyah: 262);
      expect(urls.first, contains('everyayah.com/data/Husary_128kbps/'));
      expect(urls.any(AppConfig.isOwnMirror), isFalse);
    });

    test('a mirrored surah recitation keeps mp3quran as its origin', () {
      const basit = Mp3Moshaf(
          id: 53,
          name: 'حفص عن عاصم - مرتل',
          server: 'https://server7.mp3quran.net/basit/',
          surahs: [114]);
      expect(basit.urlFor(114),
          '${AppConfig.contentBaseUrl}/recitations/surah/basit_murattal/114.mp3');
      expect(basit.originUrlFor(114), 'https://server7.mp3quran.net/basit/114.mp3');
      const other = Mp3Moshaf(
          id: 999999, name: 'x', server: 'https://example.invalid/', surahs: [1]);
      expect(other.urlFor(1), other.originUrlFor(1));
    });
  });
}
