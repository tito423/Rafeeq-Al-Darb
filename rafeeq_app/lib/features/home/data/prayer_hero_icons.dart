import 'package:flutter/material.dart';

/// The icon that says which prayer is next: a crescent moon for Fajr, the
/// rising sun for sunrise, the full sun at noon, and so on (owner, 2026-09-29).
const prayerHeroIcons = <String, IconData>{
  'fajr': Icons.nightlight_round,
  'sunrise': Icons.wb_twilight,
  'dhuhr': Icons.light_mode,
  'asr': Icons.wb_sunny_outlined,
  'maghrib': Icons.wb_twilight_outlined,
  'isha': Icons.dark_mode,
};
