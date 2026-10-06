import 'package:flutter/material.dart';

/// Each prayer's place in the day, as an icon and a tint.
const prayerLook = <String, (IconData, Color)>{
  'fajr': (Icons.wb_twilight_rounded, Color(0xFF5C7CFA)),
  'dhuhr': (Icons.wb_sunny_rounded, Color(0xFFF2A93B)),
  'asr': (Icons.light_mode_outlined, Color(0xFFE67E22)),
  'maghrib': (Icons.wb_twilight_rounded, Color(0xFFD9534F)),
  'isha': (Icons.nightlight_round, Color(0xFF7E57C2)),
};
