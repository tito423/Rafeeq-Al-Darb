import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/models/app_theme_config.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../library/presentation/screens/library_screen.dart';
import '../../../prayer/presentation/widgets/prayer_settings_sheet.dart';
import '../widgets/alerts_customization_sheet.dart';
import '../../../downloads/presentation/screens/downloads_screen.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final themeConfig = themeState.currentConfig;
    final isDark = themeState.themeMode == ThemeMode.dark;
    final bgColor = themeConfig.backgroundColor;
    final cardColor = themeConfig.cardColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final currentLocale = ref.watch(localeProvider);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'الإعدادات والمزيد',
                  style: GoogleFonts.scheherazadeNew(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accentGold,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── Theme Section ─────────────────────────────────────────
                  _buildSectionHeader('المظهر والسمات'),
                  Card(
                    color: cardColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.palette_rounded, color: AppColors.accentGold),
                          title: Text(
                            'سمة التطبيق (Theme)',
                            style: GoogleFonts.scheherazadeNew(fontSize: 19, fontWeight: FontWeight.bold, color: textColor),
                          ),
                          subtitle: Text(
                            themeConfig.name,
                            style: GoogleFonts.amiri(fontSize: 13, color: AppColors.accentGold),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.accentGold),
                          onTap: () {
                            _showThemeSelector(context, ref, themeConfig);
                          },
                        ),
                        const Divider(height: 1, indent: 56),
                        ListTile(
                          leading: Icon(
                            isDark ? Icons.dark_mode_rounded : Icons.wb_sunny_rounded,
                            color: AppColors.accentGold,
                          ),
                          title: Text(
                            'الوضع الليلي (Dark Mode)',
                            style: GoogleFonts.scheherazadeNew(fontSize: 19, fontWeight: FontWeight.bold, color: textColor),
                          ),
                          trailing: Switch(
                            value: isDark,
                            activeColor: AppColors.accentGold,
                            onChanged: (val) {
                              ref.read(themeProvider.notifier).setThemeMode(
                                    val ? ThemeMode.dark : ThemeMode.light,
                                  );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Prayer & Notifications ─────────────────────────────────
                  _buildSectionHeader('الصلاة والتنبيهات'),
                  Card(
                    color: cardColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.access_time_filled_rounded, color: AppColors.accentGold),
                          title: Text(
                            'إعدادات الأذان والمواقيت',
                            style: GoogleFonts.scheherazadeNew(fontSize: 19, fontWeight: FontWeight.bold, color: textColor),
                          ),
                          subtitle: Text(
                            'اختيار المؤذن وضبط المواقيت والتنبيهات',
                            style: GoogleFonts.amiri(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.accentGold),
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => const PrayerSettingsSheet(),
                            );
                          },
                        ),
                        const Divider(height: 1, indent: 56),
                        ListTile(
                          leading: const Icon(Icons.notifications_active_rounded, color: AppColors.accentGold),
                          title: Text(
                            'تنبيهات الأذكار والورد (سكينتي)',
                            style: GoogleFonts.scheherazadeNew(fontSize: 19, fontWeight: FontWeight.bold, color: textColor),
                          ),
                          subtitle: Text(
                            'أذكار الصباح والمساء والورد القرآني',
                            style: GoogleFonts.amiri(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.accentGold),
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => const AlertsCustomizationSheet(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Content & Language ────────────────────────────────────
                  _buildSectionHeader('المحتوى واللغة'),
                  Card(
                    color: cardColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.local_library_rounded, color: AppColors.accentGold),
                          title: Text(
                            'المكتبة الإسلامية والكتب',
                            style: GoogleFonts.scheherazadeNew(fontSize: 19, fontWeight: FontWeight.bold, color: textColor),
                          ),
                          subtitle: Text(
                            'كتب الحديث الشريف والمراجع الإسلامية',
                            style: GoogleFonts.amiri(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.accentGold),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const LibraryScreen()),
                            );
                          },
                        ),
                        const Divider(height: 1, indent: 56),
                        ListTile(
                          leading: const Icon(Icons.download_for_offline_rounded, color: AppColors.accentGold),
                          title: Text(
                            'إدارة التحميلات والمصاحف',
                            style: GoogleFonts.scheherazadeNew(fontSize: 19, fontWeight: FontWeight.bold, color: textColor),
                          ),
                          subtitle: Text(
                            'المصاحف والتلاوات والكتب المحمَّلة بدون إنترنت',
                            style: GoogleFonts.amiri(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.accentGold),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const DownloadsScreen()),
                            );
                          },
                        ),
                        const Divider(height: 1, indent: 56),
                        ListTile(
                          leading: const Icon(Icons.language_rounded, color: AppColors.accentGold),
                          title: Text(
                            'لغة التطبيق (Language)',
                            style: GoogleFonts.scheherazadeNew(fontSize: 19, fontWeight: FontWeight.bold, color: textColor),
                          ),
                          subtitle: Text(
                            currentLocale.languageCode == 'ar'
                                ? 'العربية'
                                : (currentLocale.languageCode == 'en' ? 'English' : 'Français'),
                            style: GoogleFonts.amiri(fontSize: 13, color: AppColors.accentGold),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.accentGold),
                          onTap: () {
                            _showLanguageDialog(context, ref);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, right: 8.0),
      child: Text(
        title,
        style: GoogleFonts.amiri(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: AppColors.accentGold,
        ),
      ),
    );
  }

  void _showThemeSelector(BuildContext context, WidgetRef ref, AppThemeConfig currentConfig) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'اختر سمة التطبيق',
                  style: GoogleFonts.scheherazadeNew(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accentGold,
                  ),
                ),
                const SizedBox(height: 16),
                ...kAppThemes.map((theme) {
                  final isSelected = theme.type == currentConfig.type;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.accentGold.withValues(alpha: 0.15)
                          : (isDark ? AppColors.darkCardBackground : const Color(0xFFFAF7F0)),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppColors.accentGold : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: ListTile(
                      leading: Icon(theme.icon, color: AppColors.accentGold, size: 28),
                      title: Text(
                        theme.name,
                        style: GoogleFonts.scheherazadeNew(
                          fontSize: 20,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected ? AppColors.accentGold : (isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                      subtitle: Text(
                        theme.subtitle,
                        style: GoogleFonts.amiri(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                      ),
                      trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AppColors.accentGold) : null,
                      onTap: () {
                        ref.read(themeProvider.notifier).setAppThemeType(theme.type);
                        Navigator.pop(context);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLanguageDialog(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.read(localeProvider);
    final notifier = ref.read(localeProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'اختر لغة التطبيق / Select Language',
                  style: GoogleFonts.scheherazadeNew(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.accentGold),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Text('🇸🇦', style: TextStyle(fontSize: 24)),
                  title: Text('العربية (Arabic)', style: GoogleFonts.amiri(fontSize: 18, fontWeight: FontWeight.bold)),
                  trailing: currentLocale.languageCode == 'ar' ? const Icon(Icons.check_circle_rounded, color: AppColors.accentGold) : null,
                  onTap: () {
                    notifier.setLocale('ar');
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Text('🇬🇧', style: TextStyle(fontSize: 24)),
                  title: Text('English (الإنجليزية)', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600)),
                  trailing: currentLocale.languageCode == 'en' ? const Icon(Icons.check_circle_rounded, color: AppColors.accentGold) : null,
                  onTap: () {
                    notifier.setLocale('en');
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Text('🇫🇷', style: TextStyle(fontSize: 24)),
                  title: Text('Français (الفرنسية)', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600)),
                  trailing: currentLocale.languageCode == 'fr' ? const Icon(Icons.check_circle_rounded, color: AppColors.accentGold) : null,
                  onTap: () {
                    notifier.setLocale('fr');
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
