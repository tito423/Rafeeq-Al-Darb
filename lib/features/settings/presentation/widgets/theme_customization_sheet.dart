import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/theme_provider.dart';
import '../../../../core/models/app_theme_config.dart';

class ThemeCustomizationSheet extends ConsumerWidget {
  const ThemeCustomizationSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final isDark = themeState.themeMode == ThemeMode.dark ||
        (themeState.themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
            
    final currentTheme = themeState.currentConfig;
    final bgColor = isDark ? const Color(0xFF141922) : Colors.white;
    final cardBgColor = isDark ? const Color(0xFF1B2330) : const Color(0xFFF3F5F7);
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 40), // Balance the close button
                Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.palette_outlined, color: textColor, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'تخصيص المظهر',
                          style: GoogleFonts.cairo(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'اختر ثيماً يناسبك',
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        color: textColor.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close, size: 18, color: textColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Dark Mode Toggle
          GestureDetector(
            onTap: () {
              final newMode = isDark ? ThemeMode.light : ThemeMode.dark;
              ref.read(themeProvider.notifier).setThemeMode(newMode);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isDark ? const Color(0xFF334055) : Colors.black12,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isDark ? 'الليل — مفعّل' : 'الليل — معطّل',
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF64B5F6) : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.nightlight_round,
                    color: isDark ? const Color(0xFFFFD54F) : Colors.black54,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Themes Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 16,
              runSpacing: 24,
              alignment: WrapAlignment.center,
              children: kAppThemes.map((theme) {
                final isSelected = themeState.appThemeType == theme.type;
                return GestureDetector(
                  onTap: () {
                    ref.read(themeProvider.notifier).setAppThemeType(theme.type);
                  },
                  child: SizedBox(
                    width: 70,
                    child: Column(
                      children: [
                        // Theme Card Icon
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 80,
                          width: 70,
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? theme.primaryColor : theme.borderColor,
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: theme.primaryColor.withValues(alpha: 0.3),
                                      blurRadius: 12,
                                    )
                                  ]
                                : [],
                          ),
                          child: Stack(
                            children: [
                              // Top colored bar
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: theme.accentColor,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(14),
                                    ),
                                  ),
                                ),
                              ),
                              // Content lines placeholder
                              Positioned(
                                top: 26,
                                left: 12,
                                right: 12,
                                child: Column(
                                  children: [
                                    Container(
                                      height: 4,
                                      width: double.infinity,
                                      color: Colors.white24,
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      height: 4,
                                      width: 30,
                                      color: Colors.white24,
                                    ),
                                  ],
                                ),
                              ),
                              // Bottom colored circle (Primary)
                              Positioned(
                                bottom: 12,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: theme.primaryColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: isSelected
                                        ? const Icon(Icons.check, size: 10, color: Colors.white)
                                        : null,
                                  ),
                                ),
                              ),
                              // Top-left small icon (from the image)
                              if (theme.type == AppThemeType.night)
                                const Positioned(
                                  top: 18,
                                  left: 6,
                                  child: Icon(Icons.nightlight_round, size: 10, color: Colors.white70),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Icon(theme.icon, size: 16, color: isSelected ? theme.primaryColor : textColor),
                        const SizedBox(height: 4),
                        Text(
                          theme.name,
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: textColor,
                          ),
                        ),
                        Text(
                          theme.subtitle,
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            color: isSelected ? theme.primaryColor : textColor.withValues(alpha: 0.5),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          
          const SizedBox(height: 32),

          // Current Theme Colors Indicator
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text(
                  'ألوان الثيم الحالي',
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    color: textColor.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ColorBlob(color: currentTheme.backgroundColor, label: 'خلفية', textColor: textColor),
                    _ColorBlob(color: currentTheme.cardColor, label: 'كارت', textColor: textColor),
                    _ColorBlob(color: currentTheme.primaryColor, label: 'ذهبي', textColor: textColor),
                    _ColorBlob(color: currentTheme.accentColor, label: 'أساسي', textColor: textColor),
                    _ColorBlob(color: currentTheme.borderColor, label: 'حدود', textColor: textColor),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ColorBlob extends StatelessWidget {
  final Color color;
  final String label;
  final Color textColor;

  const _ColorBlob({
    required this.color,
    required this.label,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 12,
            color: textColor.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}
