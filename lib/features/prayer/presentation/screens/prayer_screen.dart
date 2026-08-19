import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/prayer_times_service.dart';
import '../providers/prayer_settings_provider.dart';

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
          'إعدادات الصلاة',
          style: GoogleFonts.amiri(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.arrow_forward_ios_rounded, color: textColor, size: 20),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        children: [
          // Main Toggles
          _buildSwitchTile(
            title: 'إشعارات الصلاة',
            subtitle: 'تنبيه عند دخول وقت كل صلاة',
            value: settings.globalNotifications,
            onChanged: (v) => notifier.setGlobalNotifications(v),
            icon: Icons.notifications_active_outlined,
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildSwitchTile(
            title: 'أوقات حسب موقعي الجغرافي',
            subtitle: 'تلقائي',
            value: settings.locationEnabled,
            onChanged: (v) => notifier.setLocationEnabled(v),
            icon: Icons.location_on_outlined,
            isDark: isDark,
          ),
          const SizedBox(height: 24),

          // Muezzin Selection
          Text(
            'اختر المؤذن',
            style: GoogleFonts.amiri(fontSize: 14, color: AppColors.lightSubtext),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF132B25) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primaryBlue.withOpacity(0.1)),
            ),
            child: ListTile(
              title: Text(settings.selectedMuezzin, style: GoogleFonts.amiri(color: textColor, fontWeight: FontWeight.bold)),
              subtitle: Text('Adhan', style: GoogleFonts.outfit(color: AppColors.lightSubtext, fontSize: 12)),
              trailing: const Icon(Icons.mosque, color: AppColors.accentGold),
              onTap: () {
                // Future: show bottom sheet to select muezzin
              },
            ),
          ),
          const SizedBox(height: 24),

          // Prayer Times list
          ...['الفجر', 'الشروق', 'الظهر', 'العصر', 'المغرب', 'العشاء'].map((p) {
            bool isNext = false; // Mock next prayer or calculate it later
            bool isEnabled = settings.prayerToggles[p] ?? true;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isNext ? AppColors.primaryBlue.withOpacity(0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isNext ? AppColors.primaryBlue : Colors.transparent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      p,
                      style: GoogleFonts.amiri(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isNext ? AppColors.primaryBlue : textColor,
                      ),
                    ),
                  ),
                  Text(
                    isEnabled ? 'مفعل' : 'معطل',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppColors.lightSubtext,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Switch(
                    value: isEnabled,
                    onChanged: settings.globalNotifications
                        ? (v) => notifier.setPrayerToggle(p, v)
                        : null,
                    activeColor: AppColors.primaryBlue,
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 24),
          // Sections placeholders
          _buildSectionTitle('تذكيرات الأذكار'),
          _buildReminderTile('أذكار الصباح', 'يومياً عند 05:00', Icons.wb_sunny_outlined, isDark),
          _buildReminderTile('أذكار المساء', 'يومياً عند 16:30', Icons.nights_stay_outlined, isDark),
          
          const SizedBox(height: 24),
          _buildSectionTitle('تذكيرات الورد اليومي'),
          _buildReminderTile('ورد القرآن اليومي - الصبح', 'يومياً عند 05:00', Icons.menu_book, isDark),
          _buildReminderTile('ورد القرآن اليومي - المغرب', 'يومياً عند 16:30', Icons.menu_book, isDark),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: GoogleFonts.amiri(fontSize: 14, color: AppColors.lightSubtext, fontWeight: FontWeight.bold),
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
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.1)),
      ),
      child: SwitchListTile(
        title: Text(title, style: GoogleFonts.amiri(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: GoogleFonts.amiri(fontSize: 12, color: AppColors.lightSubtext)),
        value: value,
        onChanged: onChanged,
        secondary: Icon(icon, color: AppColors.primaryBlue),
        activeColor: AppColors.primaryBlue,
      ),
    );
  }

  Widget _buildReminderTile(String title, String subtitle, IconData icon, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.1)),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primaryBlue),
        title: Text(title, style: GoogleFonts.amiri(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.lightSubtext)),
        trailing: Switch(
          value: true,
          onChanged: (v) {},
          activeColor: AppColors.primaryBlue,
        ),
      ),
    );
  }
}
