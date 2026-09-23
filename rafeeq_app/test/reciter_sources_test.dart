import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rafeeq_app/core/services/ayah_audio_service.dart';
import 'package:rafeeq_app/core/services/recitation_source.dart';
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
}
