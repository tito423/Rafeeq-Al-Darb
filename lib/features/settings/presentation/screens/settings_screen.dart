import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/theme/app_colors.dart';

import '../widgets/alerts_customization_sheet.dart';
import '../widgets/theme_customization_sheet.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

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
                                    ? '✅ ${user.displayName?.isNotEmpty == true ? user.displayName! : user.email ?? "مسجّل الدخول"}'
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
                          onPressed: () => authNotifier.signIn(),
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
                              onPressed: () {
                                authNotifier.manualSyncUp();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('تمت المزامنة بنجاح',
                                        style: GoogleFonts.amiri(fontSize: 16)),
                                    backgroundColor: AppColors.accentGold,
                                  ),
                                );
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
        ],
      ),
    );
  }
}
