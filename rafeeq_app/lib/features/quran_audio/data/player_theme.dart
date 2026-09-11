import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One look for the player: its ground, from top to bottom, and the accent
/// the disc, the seek bar and the controls are drawn in.
///
/// «حط في بلاير مشغّل القرآن زرار ثيمات بعشر ثيمات جميلة». Each accent was
/// picked against its own darkest ground, which the controls sit on.
class PlayerTheme {
  final String id;
  final List<Color> ground;
  final Color accent;
  final Color accentSoft;

  const PlayerTheme({
    required this.id,
    required this.ground,
    required this.accent,
    required this.accentSoft,
  });

  String get nameKey => 'quran_audio.theme_$id';

  /// What sits on the accent (the play button's icon).
  Color get onAccent => ground.last;
}

const playerThemes = <PlayerTheme>[
  PlayerTheme(
    id: 'night',
    ground: [Color(0xFF1B2F24), Color(0xFF0C2135), Color(0xFF071625)],
    accent: Color(0xFFD4AF37),
    accentSoft: Color(0xFFE8C96A),
  ),
  PlayerTheme(
    id: 'emerald',
    ground: [Color(0xFF0E4D3A), Color(0xFF06281F), Color(0xFF021510)],
    accent: Color(0xFF34D399),
    accentSoft: Color(0xFFA7F3D0),
  ),
  PlayerTheme(
    id: 'dawn',
    ground: [Color(0xFF4A2340), Color(0xFF2A1633), Color(0xFF120A1F)],
    accent: Color(0xFFF9A8D4),
    accentSoft: Color(0xFFFBCFE8),
  ),
  PlayerTheme(
    id: 'sand',
    ground: [Color(0xFF5A4127), Color(0xFF34261A), Color(0xFF18110B)],
    accent: Color(0xFFF4C27A),
    accentSoft: Color(0xFFFDE3B5),
  ),
  PlayerTheme(
    id: 'sea',
    ground: [Color(0xFF0E4A5C), Color(0xFF072C3A), Color(0xFF03161E)],
    accent: Color(0xFF38BDF8),
    accentSoft: Color(0xFFBAE6FD),
  ),
  PlayerTheme(
    id: 'ruby',
    ground: [Color(0xFF5C1A2A), Color(0xFF360F1A), Color(0xFF17060B)],
    accent: Color(0xFFFB7185),
    accentSoft: Color(0xFFFECDD3),
  ),
  PlayerTheme(
    id: 'violet',
    ground: [Color(0xFF3B2A6B), Color(0xFF221845), Color(0xFF0E0A22)],
    accent: Color(0xFFA78BFA),
    accentSoft: Color(0xFFDDD6FE),
  ),
  PlayerTheme(
    id: 'silver',
    ground: [Color(0xFF3A4452), Color(0xFF222831), Color(0xFF0F1216)],
    accent: Color(0xFFCBD5E1),
    accentSoft: Color(0xFFF1F5F9),
  ),
  PlayerTheme(
    id: 'cedar',
    ground: [Color(0xFF2F4A1E), Color(0xFF1B2C12), Color(0xFF0B1307)],
    accent: Color(0xFFA3E635),
    accentSoft: Color(0xFFD9F99D),
  ),
  PlayerTheme(
    id: 'amber',
    ground: [Color(0xFF5B3A0A), Color(0xFF352206), Color(0xFF170E02)],
    accent: Color(0xFFF59E0B),
    accentSoft: Color(0xFFFDE68A),
  ),
];

class PlayerThemeNotifier extends StateNotifier<PlayerTheme> {
  PlayerThemeNotifier() : super(playerThemes.first) {
    _restore();
  }

  static const _key = 'quran_audio.player_theme_v1';

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_key);
    final match = playerThemes.where((t) => t.id == id);
    if (match.isNotEmpty) state = match.first;
  }

  Future<void> select(PlayerTheme theme) async {
    state = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, theme.id);
  }
}

final playerThemeProvider =
    StateNotifierProvider<PlayerThemeNotifier, PlayerTheme>(
        (ref) => PlayerThemeNotifier());
