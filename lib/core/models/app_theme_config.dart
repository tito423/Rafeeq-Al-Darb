import 'package:flutter/material.dart';

enum AppThemeType {
  sakanati,
  oud,
  rose,
  desert,
  river,
  dawn,
  purple,
  night,
}

class AppThemeConfig {
  final AppThemeType type;
  final String name;
  final String subtitle;
  final IconData icon;
  final Color backgroundColor;
  final Color cardColor;
  final Color primaryColor; // ذهبي
  final Color accentColor; // أساسي
  final Color borderColor; // حدود
  
  const AppThemeConfig({
    required this.type,
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.backgroundColor,
    required this.cardColor,
    required this.primaryColor,
    required this.accentColor,
    required this.borderColor,
  });
}

const List<AppThemeConfig> kAppThemes = [
  AppThemeConfig(
    type: AppThemeType.desert,
    name: 'الصحراء',
    subtitle: 'منقط',
    icon: Icons.landscape_rounded,
    backgroundColor: Color(0xFF1C1A17),
    cardColor: Color(0xFF2B251E),
    primaryColor: Color(0xFFD49A4C),
    accentColor: Color(0xFFE8B671),
    borderColor: Color(0xFF453B31),
  ),
  AppThemeConfig(
    type: AppThemeType.rose,
    name: 'الورد',
    subtitle: 'مزدوج',
    icon: Icons.local_florist_rounded,
    backgroundColor: Color(0xFF1D1719),
    cardColor: Color(0xFF2E2226),
    primaryColor: Color(0xFFD46B80),
    accentColor: Color(0xFFE88A9C),
    borderColor: Color(0xFF4A343A),
  ),
  AppThemeConfig(
    type: AppThemeType.oud,
    name: 'العود',
    subtitle: 'إطار كامل',
    icon: Icons.park_rounded,
    backgroundColor: Color(0xFF1F1C18),
    cardColor: Color(0xFF332A22),
    primaryColor: Color(0xFFC79860),
    accentColor: Color(0xFFE3BC8D),
    borderColor: Color(0xFF54463A),
  ),
  AppThemeConfig(
    type: AppThemeType.sakanati,
    name: 'سكينتي',
    subtitle: 'أخضر وذهبي',
    icon: Icons.mosque_rounded,
    backgroundColor: Color(0xFF0A1D1C), // Deep Forest Green
    cardColor: Color(0xFF142C2A), // Lighter Green
    primaryColor: Color(0xFFD4AF37), // Gold
    accentColor: Color(0xFFF1C40F),
    borderColor: Color(0xFF1E4340),
  ),
  AppThemeConfig(
    type: AppThemeType.river,
    name: 'النهر',
    subtitle: 'بسيط',
    icon: Icons.water_rounded,
    backgroundColor: Color(0xFF141C1E),
    cardColor: Color(0xFF1E2E31),
    primaryColor: Color(0xFF4DD0E1),
    accentColor: Color(0xFF80DEEA),
    borderColor: Color(0xFF314C51),
  ),
  AppThemeConfig(
    type: AppThemeType.dawn,
    name: 'الفجر',
    subtitle: 'ظل',
    icon: Icons.wb_twilight_rounded,
    backgroundColor: Color(0xFF1D1A1E),
    cardColor: Color(0xFF2B252E),
    primaryColor: Color(0xFFFFB74D),
    accentColor: Color(0xFFFFCC80),
    borderColor: Color(0xFF453B4A),
  ),
  AppThemeConfig(
    type: AppThemeType.purple,
    name: 'البنفسج',
    subtitle: 'زخرفي',
    icon: Icons.favorite_rounded,
    backgroundColor: Color(0xFF1A1721),
    cardColor: Color(0xFF272136),
    primaryColor: Color(0xFFBA68C8),
    accentColor: Color(0xFFCE93D8),
    borderColor: Color(0xFF413759),
  ),
  AppThemeConfig(
    type: AppThemeType.night,
    name: 'الليل',
    subtitle: 'ليلي حالك ✦',
    icon: Icons.nightlight_round,
    backgroundColor: Color(0xFF050505),
    cardColor: Color(0xFF111111),
    primaryColor: Color(0xFFD4AF37),
    accentColor: Color(0xFFE5C158),
    borderColor: Color(0xFF222222),
  ),
];
