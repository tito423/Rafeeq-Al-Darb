import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/localization/app_localizations.dart';

import '../widgets/alerts_customization_sheet.dart';
import '../widgets/theme_customization_sheet.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../downloads/presentation/screens/downloads_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeState = ref.watch(themeProvider);
    final notifier = ref.read(themeProvider.notifier);
    // Use Firebase stream directly — always reflects real signed-in state
    final authUserAsync = ref.watch(authStateProvider);
    final authNotifier = ref.read(authControllerProvider.notifier);

    Widget sectionHeader(String title) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
              letterSpacing: 0.8,
            ),
          ),
        );
String _getLanguageName(String code) {
      const names = {
        'ar': 'العربية',
        'en': 'English',
        'fr': 'Français',
        'id': 'Bahasa Indonesia',
        'ms': 'Bahasa Melayu',
        'tr': 'Türkçe',
        'ur': 'اردو',
        'hi': 'हिन्दी',
        'bn': 'বাংলা',
        'fa': 'فارسی',
        'es': 'Español',
        'ru': 'Русский',
        'zh': '中文',
        'de': 'Deutsch',
        'it': 'Italiano',
        'pt': 'Português',
        'ha': 'Hausa',
      };
      return names[code] ?? code;
    }

    void _showLanguageSelectionSheet(BuildContext context) {
      final supported = ['ar', 'en', 'fr', 'id', 'ms', 'tr', 'ur', 'hi', 'bn', 'fa', 'es', 'ru', 'zh', 'de', 'it', 'pt', 'ha'];
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.language, color: AppColors.accentGold),
                    const SizedBox(width: 12),
                    Text(
                      'اختر لغة التطبيق',
                      style: GoogleFonts.amiri(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ...supported.map((code) => RadioListTile(
                value: code,
                groupValue: ref.read(localeProvider).languageCode,
                onChanged: (value) {
                  if (value != null) {
                    ref.read(localeProvider.notifier).setLocale(value);
                    Navigator.pop(context);
                  }
                },
                title: Text(_getLanguageName(code)),
                secondary: Text(code.toUpperCase()),
              )).toList(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('المزيد')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        children: [
          // ── المظهر ──────────────────────────────────────────────────────
          sectionHeader('المظهر'),

          Card(
            clipBehavior: Clip.antiAlias,
            child: SwitchListTile(
              secondary: Icon(
                themeState.themeMode == ThemeMode.dark
                    ? Icons.dark_mode_rounded
                    : Icons.light_mode_rounded,
                color: theme.colorScheme.primary,
                size: 26,
              ),
              title: Text(
                'الوضع الليلي (Dark Mode)',
                style: GoogleFonts.amiri(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                themeState.themeMode == ThemeMode.dark
                    ? 'المظهر الليلي مفعَّل لراحة العين'
                    : 'المظهر النهاري مفعَّل',
                style: GoogleFonts.amiri(fontSize: 13),
              ),
              value: themeState.themeMode == ThemeMode.dark,
              activeColor: AppColors.accentGold,
              onChanged: (val) {
                notifier.setThemeMode(val ? ThemeMode.dark : ThemeMode.light);
              },
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => const ThemeCustomizationSheet(),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.palette, color: theme.colorScheme.primary, size: 28),
                          const SizedBox(height: 8),
                          Text('تخصيص الألوان', style: theme.textTheme.titleSmall),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => const AlertsCustomizationSheet(),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.notifications_active, color: theme.colorScheme.primary, size: 28),
                          const SizedBox(height: 8),
                          Text('التنبيهات', style: theme.textTheme.titleSmall),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

// ── اللغة ────────────────────────────────────────────────────────
          sectionHeader('اللغة'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _showLanguageSelectionSheet(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accentGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.language, color: AppColors.accentGold),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'اختر لغة التطبيق',
                            style: GoogleFonts.amiri(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          Consumer(
                            builder: (context, ref, child) {
                              final locale = ref.watch(localeProvider);
                              return Text(
                                _getLanguageName(locale.languageCode),
                                style: GoogleFonts.amiri(
                                  fontSize: 13,
                                  color: themeState.themeMode == ThemeMode.dark ? AppColors.darkSubtext : AppColors.lightSubtext,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // ── النسخ الاحتياطي السحابي ──────────────────────────────────
          sectionHeader('النسخ الاحتياطي السحابي'),

          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: authUserAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => Text(
                  'خطأ في تحميل حالة الدخول',
                  style: GoogleFonts.amiri(fontSize: 14, color: Colors.red),
                ),
                data: (User? user) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.cloud_sync_rounded, color: AppColors.primaryBlue),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'المزامنة مع جوجل',
                                style: GoogleFonts.amiri(fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                              Text(
                                user != null
                                    ? 'تم الدخول ✅ - ${user.displayName?.isNotEmpty == true ? user.displayName! : user.email ?? "مسجّل الدخول"}'
                                    : 'سجّل دخولك لحفظ إعداداتك ومزامنتها',
                                style: GoogleFonts.amiri(
                                  fontSize: 13,
                                  color: user != null
                                      ? Colors.green
                                      : AppColors.primaryBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (user == null)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await authNotifier.signIn();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'تم تسجيل الدخول واستعادة بياناتك. يرجى إعادة تشغيل التطبيق لتطبيق الإعدادات بالكامل.',
                                    style: GoogleFonts.amiri(fontSize: 15),
                                  ),
                                  backgroundColor: AppColors.primaryBlue,
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.login_rounded),
                          label: Text(
                            'تسجيل الدخول بجوجل',
                            style: GoogleFonts.amiri(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                await authNotifier.manualSyncUp();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('تمت المزامنة السحابية بنجاح',
                                          style: GoogleFonts.amiri(fontSize: 16)),
                                      backgroundColor: AppColors.accentGold,
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.sync_rounded),
                              label: Text('مزامنة الآن',
                                  style: GoogleFonts.amiri(
                                      fontSize: 15, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primaryBlue,
                                side: const BorderSide(color: AppColors.primaryBlue),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => authNotifier.signOut(),
                              icon: const Icon(Icons.logout_rounded),
                              label: Text('تسجيل الخروج',
                                  style: GoogleFonts.amiri(
                                      fontSize: 15, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                                side: const BorderSide(color: AppColors.error),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // ── مدير التحميلات ───────────────────────────────────────────────────
          sectionHeader('إدارة الملفات'),
          
          Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DownloadsScreen()),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accentGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.download_rounded, color: AppColors.accentGold),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'مدير التحميلات',
                            style: GoogleFonts.amiri(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'إدارة الملفات المحملة والمصاحف المصورة والتفاسير',
                            style: GoogleFonts.amiri(
                              fontSize: 13,
                              color: themeState.themeMode == ThemeMode.dark ? AppColors.darkSubtext : AppColors.lightSubtext,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
