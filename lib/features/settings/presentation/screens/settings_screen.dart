import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/alerts_customization_sheet.dart';
import '../widgets/theme_customization_sheet.dart';
import '../../../prayer/presentation/widgets/prayer_settings_sheet.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeState = ref.watch(themeProvider);
    final notifier = ref.read(themeProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        children: [
          // ── Section Header ────────────────────────────────────────────────
          Text(
            'المظهر',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),

          // ── Quick Day/Night Toggle ──────────────────────────────────────
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
                style: GoogleFonts.amiri(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
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
              // Theme Customization
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
              // Alerts Customization
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
                          Text('التنبيهات والأذكار', style: theme.textTheme.titleSmall),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Prayer Settings ───────────────────────────────────────
          Text(
            'مواقيت الصلاة',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),

          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.access_time_filled_rounded, color: AppColors.accentGold),
              ),
              title: Text(
                'إعدادات المؤذن والمواقيت',
                style: GoogleFonts.amiri(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                'تخصيص المؤذن وتعديل أوقات الصلاة',
                style: GoogleFonts.amiri(fontSize: 13, color: AppColors.accentGold, fontWeight: FontWeight.w600),
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const PrayerSettingsSheet(),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // ── Cloud Backup & Sync ───────────────────────────────────────
          Text(
            'النسخ الاحتياطي السحابي',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),

          Consumer(
            builder: (context, ref, _) {
              final authState = ref.watch(authControllerProvider);
              final authNotifier = ref.read(authControllerProvider.notifier);
              
              return Card(
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
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
                                  authState.value != null
                                      ? 'تم تسجيل الدخول (${authState.value?.displayName ?? authState.value?.email})'
                                      : 'قم بتسجيل الدخول لحفظ إعداداتك ومزامنتها عبر أجهزتك',
                                  style: GoogleFonts.amiri(fontSize: 13, color: AppColors.primaryBlue, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (authState.isLoading)
                        const Center(child: CircularProgressIndicator())
                      else if (authState.value == null)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => authNotifier.signIn(),
                            icon: const Icon(Icons.login_rounded),
                            label: Text('تسجيل الدخول', style: GoogleFonts.amiri(fontSize: 16, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  authNotifier.manualSyncUp();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('تمت مزامنة الإعدادات بنجاح', style: GoogleFonts.amiri(fontSize: 16)),
                                      backgroundColor: AppColors.accentGold,
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.sync_rounded),
                                label: Text('مزامنة الآن', style: GoogleFonts.amiri(fontSize: 15, fontWeight: FontWeight.bold)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primaryBlue,
                                  side: const BorderSide(color: AppColors.primaryBlue),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => authNotifier.signOut(),
                                icon: const Icon(Icons.logout_rounded),
                                label: Text('تسجيل الخروج', style: GoogleFonts.amiri(fontSize: 15, fontWeight: FontWeight.bold)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.error,
                                  side: const BorderSide(color: AppColors.error),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
