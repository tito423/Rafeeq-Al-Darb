import 'package:flutter/material.dart';

enum AppThemeType {
  light, // نهاري
  dark,  // ليلي
  rgb,   // متحرك RGB
}

class AppThemeConfig {
  final AppThemeType type;
  final String name;
  final String nameEn;
  final String nameFr;
  final String subtitle;
  final IconData icon;
  final Color backgroundColor;
  final Color cardColor;
  final Color primaryColor;
  final Color accentColor;
  final Color borderColor;
  final bool isAnimatedRgb;
  
  const AppThemeConfig({
    required this.type,
    required this.name,
    required this.nameEn,
    required this.nameFr,
    required this.subtitle,
    required this.icon,
    required this.backgroundColor,
    required this.cardColor,
    required this.primaryColor,
    required this.accentColor,
    required this.borderColor,
    this.isAnimatedRgb = false,
  });
}

const List<AppThemeConfig> kAppThemes = [
  AppThemeConfig(
    type: AppThemeType.light,
    name: 'نهاري (دافئ)',
    nameEn: 'Light Theme',
    nameFr: 'Thème Clair',
    subtitle: 'خلفية ورقية دافئة مع لمسات ذهبية وزمردية',
    icon: Icons.wb_sunny_rounded,
    backgroundColor: Color(0xFFFAF7F0), // Warm cream / parchment
    cardColor: Color(0xFFFFFFFF),
    primaryColor: Color(0xFF1B4D3E),     // Dark Emerald
    accentColor: Color(0xFFD4AF37),      // Dark Gold
    borderColor: Color(0xFFE5DEC9),
    isAnimatedRgb: false,
  ),
  AppThemeConfig(
    type: AppThemeType.dark,
    name: 'ليلي (سبجي)',
    nameEn: 'Dark Theme',
    nameFr: 'Thème Sombre',
    subtitle: 'خلفية سبجية داكنة مع إشراقات ذهبية هادئة',
    icon: Icons.nightlight_round,
    backgroundColor: Color(0xFF0A100E), // Deep Obsidian / Slate
    cardColor: Color(0xFF14251D),       // Card deep slate
    primaryColor: Color(0xFFD4AF37),     // Soft Gold
    accentColor: Color(0xFF10B981),      // Emerald Green
    borderColor: Color(0xFF1E3A2E),
    isAnimatedRgb: false,
  ),
  AppThemeConfig(
    type: AppThemeType.rgb,
    name: 'متحرك (RGB أثيري)',
    nameEn: 'Animated RGB',
    nameFr: 'RGB Animé',
    subtitle: 'تدرجات لونية محيطية متوهجة ومتحركة بسلاسة',
    icon: Icons.auto_awesome_rounded,
    backgroundColor: Color(0xFF090D16), // Dark Cosmic Blue
    cardColor: Color(0xFF131B2E),
    primaryColor: Color(0xFF6C5CE7),     // Electric Purple-Blue
    accentColor: Color(0xFF00CEC9),      // Neon Cyan / Gold
    borderColor: Color(0xFF81ECEC),
    isAnimatedRgb: true,
  ),
];
