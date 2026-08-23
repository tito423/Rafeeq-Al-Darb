import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/prayer_settings_provider.dart';
import '../widgets/prayer_settings_sheet.dart';

class PrayerScreen extends ConsumerStatefulWidget {
  const PrayerScreen({super.key});

  @override
  ConsumerState<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends ConsumerState<PrayerScreen> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(prayerSettingsProvider);
    final notifier = ref.read(prayerSettingsProvider.notifier);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : const Color(0xFFFAF7F0);
    final cardBg = isDark ? AppColors.darkCardBackground : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'إعدادات الصلاة والمواقيت',
          style: GoogleFonts.scheherazadeNew(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.accentGold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        children: [
          // Main Toggles
          _buildSwitchTile(
            title: 'إشعارات الصلاة',
            subtitle: 'تنبيه عند دخول وقت كل صلاة مع الأذان',
            value: settings.globalNotifications,
            onChanged: (v) => notifier.setGlobalNotifications(v),
            icon: Icons.notifications_active_outlined,
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildSwitchTile(
            title: 'المواقيت حسب الموقع الجغرافي',
            subtitle: 'حساب فلكي دقيق حسب إحداثيات موقعك',
            value: settings.locationEnabled,
            onChanged: (v) => notifier.setLocationEnabled(v),
            icon: Icons.location_on_outlined,
            isDark: isDark,
          ),
          const SizedBox(height: 24),

          // Muezzin Selection
          Text(
            'صوت المؤذن والأذان',
            style: GoogleFonts.amiri(fontSize: 14, color: AppColors.accentGold, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.2)),
            ),
            child: ListTile(
              title: Text(settings.selectedMuezzin, style: GoogleFonts.scheherazadeNew(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
              subtitle: Text('اضغط للمعاينة الفورية وتغيير المؤذن', style: GoogleFonts.amiri(color: AppColors.lightSubtext, fontSize: 12)),
              trailing: const Icon(Icons.record_voice_over_rounded, color: AppColors.accentGold),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const MuezzinSelectionSheet(),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Calculation Method Selection
          Text(
            'طريقة الحساب الفلكي',
            style: GoogleFonts.amiri(fontSize: 14, color: AppColors.accentGold, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.2)),
            ),
            child: ListTile(
              title: Text(settings.calculationMethod, style: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.bold), textDirection: TextDirection.ltr),
              subtitle: Text('Calculation Method', style: GoogleFonts.outfit(color: AppColors.lightSubtext, fontSize: 12)),
              trailing: const Icon(Icons.calculate_rounded, color: AppColors.accentGold),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const CalculationMethodSheet(),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // Prayer Times list
          Text(
            'تخصيص تنبيهات الصلوات المفردة',
            style: GoogleFonts.amiri(fontSize: 14, color: AppColors.accentGold, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          ...['الفجر', 'الشروق', 'الظهر', 'العصر', 'المغرب', 'العشاء'].map((p) {
            final isEnabled = settings.prayerToggles[p] ?? true;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.15)),
              ),
              child: ListTile(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => SinglePrayerConfigSheet(prayer: p),
                  );
                },
                title: Text(
                  p,
                  style: GoogleFonts.scheherazadeNew(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isEnabled ? textColor : Colors.grey,
                  ),
                ),
                subtitle: Text(
                  'اضغط لتعديل الوقت وتنبيه الإقامة',
                  style: GoogleFonts.amiri(fontSize: 12, color: AppColors.lightSubtext),
                ),
                trailing: Switch(
                  value: isEnabled,
                  onChanged: settings.globalNotifications
                      ? (v) => notifier.setPrayerToggle(p, v)
                      : null,
                  activeColor: AppColors.accentGold,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
    required bool isDark,
  }) {
    final cardBg = isDark ? AppColors.darkCardBackground : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.2)),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: GoogleFonts.scheherazadeNew(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.amiri(fontSize: 12, color: AppColors.lightSubtext),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.accentGold,
        secondary: Icon(icon, color: AppColors.accentGold),
      ),
    );
  }
}
