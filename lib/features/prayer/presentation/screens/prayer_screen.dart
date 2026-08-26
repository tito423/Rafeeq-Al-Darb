import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/prayer_settings_provider.dart';
import '../widgets/prayer_settings_sheet.dart';
import 'qibla_compass_screen.dart';

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
          // ── Qibla Card ──────────────────────────────────────────────────
          _buildQiblaCard(context, isDark),
          const SizedBox(height: 24),

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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Consumer(
              builder: (context, ref, child) {
                final muezzinsAsync = ref.watch(muezzinsProvider);
                return muezzinsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accentGold)),
                  error: (err, _) => Text('خطأ في التحميل', style: GoogleFonts.amiri(color: Colors.red)),
                  data: (muezzins) {
                    final selected = muezzins.any((m) => m.name == settings.selectedMuezzin)
                        ? settings.selectedMuezzin
                        : muezzins.first.name;

                    return DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selected,
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.accentGold),
                        dropdownColor: cardBg,
                        style: GoogleFonts.scheherazadeNew(color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            notifier.setSelectedMuezzin(newValue);
                          }
                        },
                        items: muezzins.map<DropdownMenuItem<String>>((m) {
                          return DropdownMenuItem<String>(
                            value: m.name,
                            child: Text(m.name),
                          );
                        }).toList(),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Adhan Display Mode
          Text(
            'نوع تنبيه الأذان',
            style: GoogleFonts.amiri(fontSize: 14, color: AppColors.accentGold, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.2)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Consumer(
              builder: (context, ref, child) {
                // Read directly from SharedPreferences since it's used directly in notification_service
                return FutureBuilder<SharedPreferences>(
                  future: SharedPreferences.getInstance(),
                  builder: (context, snapshot) {
                    final prefs = snapshot.data;
                    final mode = prefs?.getString('adhanDisplayMode') ?? 'animated';

                    return DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: mode,
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.accentGold),
                        dropdownColor: cardBg,
                        style: GoogleFonts.amiri(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                        onChanged: (String? newValue) {
                          if (newValue != null && prefs != null) {
                            prefs.setString('adhanDisplayMode', newValue);
                            // Force rebuild
                            (context as Element).markNeedsBuild();
                          }
                        },
                        items: const [
                          DropdownMenuItem(value: 'animated', child: Text('شاشة أذان متحركة')),
                          DropdownMenuItem(value: 'audio_only', child: Text('صوت في الخلفية فقط')),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 24),

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

  Widget _buildQiblaCard(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const QiblaCompassScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  colors: [Color(0xFF0F1714), Color(0xFF14251D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : const LinearGradient(
                  colors: [Color(0xFF102118), Color(0xFF163225)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: AppColors.accentGold.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.accentGold.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.4)),
              ),
              child: const Icon(Icons.explore_rounded, color: AppColors.accentGold, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تحديد القبلة',
                    style: GoogleFonts.scheherazadeNew(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'بوصلة ذكية نحو الكعبة المشرفة',
                    style: GoogleFonts.amiri(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.accentGold, size: 18),
          ],
        ),
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
