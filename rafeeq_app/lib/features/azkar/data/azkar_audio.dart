import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which dhikr has a recording, and where (owner, 2026-09-29: «حط زرار
/// استماع في الاذكار كلها»).
///
/// The recordings are hisnmuslim.com's - the site of the book the adhkar
/// come from - one per dhikr, streamed from there. A dhikr is paired with a
/// recording only when the recording says the SAME words
/// (`scripts/hisnmuslim_audio_map.py`: 213 of the 302; e.g. a text with
/// «بالماء والثلج» is not given a recording that says «بالثلج والماء»).
/// The rest show no listen button rather than a near miss.
final azkarAudioProvider = FutureProvider<Map<int, String>>((ref) async {
  final raw = jsonDecode(
      await rootBundle.loadString('assets/data/azkar_audio.json'))
      as Map<String, dynamic>;
  return {
    for (final e in (raw['audio'] as Map<String, dynamic>).entries)
      int.parse(e.key): e.value as String,
  };
});
