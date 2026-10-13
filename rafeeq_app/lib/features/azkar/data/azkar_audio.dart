import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';

/// Which dhikr has a recording, and where (owner, 2026-09-29: «حط زرار
/// استماع في الاذكار كلها»).
///
/// Since 3.90.0 every one of the 302 adhkar has its own voicing, made in
/// this app from Hisn al-Muslim's text (owner, 2026-10-06: «فكنا من تسجيلات
/// حصن المسلم لو مش كاملة»; 2026-10-13: «ادمج اصوات جوجل»). It replaces
/// hisnmuslim.com's recordings, which covered 213 of the 302:
///
/// * every Qur'an passage is Mishary Alafasy's whole-ayah recording
///   (everyayah.com); dhikr 138 of the sleep adhkar, which tells the reader
///   to recite As-Sajdah and Al-Mulk, plays both surahs complete;
/// * every other line is Gemini TTS, read once and transcribed back with
///   faster-whisper (scripts/azkar_voice_all.py, scripts/azkar_voice_138.py).
///
/// The files are on R2 under `azkar/rafeeq_voice/items/v1/`; each was read
/// back from the public URL and matched by size and sha1 before
/// `assets/data/azkar_voice.json` was written
/// (scripts/upload_azkar_voice_items.py).
final azkarAudioProvider = FutureProvider<Map<int, String>>((ref) async {
  final raw =
      jsonDecode(await rootBundle.loadString('assets/data/azkar_voice.json'))
          as Map<String, dynamic>;
  final base = '${AppConfig.contentBaseUrl}/${raw['source'] as String}';
  return {
    for (final id in (raw['items'] as Map<String, dynamic>).keys)
      int.parse(id): '$base$id.mp3',
  };
});
