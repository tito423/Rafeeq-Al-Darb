import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/notification_service.dart';
import '../providers/prayer_settings_provider.dart';
import 'full_screen_adhan_screen.dart';

class PrayerSettingsScreen extends ConsumerWidget {
  const PrayerSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = ref.watch(prayerSettingsProvider);
    final notifier = ref.read(prayerSettingsProvider.notifier);
    final muezzins = ref.watch(muezzinsProvider);

    final prayers = [
      ('الفجر', true),
      ('الشروق', false), // Sunrise has offset adjustment only
      ('الظهر', true),
      ('العصر', true),
      ('المغرب', true),
      ('العشاء', true),
    ];

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFFAF7F0),
      appBar: AppBar(
        title: Text('إعدادات الصلاة والأذان', style: GoogleFonts.amiri(fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle('المؤذن الافتراضي', isDark),
          _buildMuezzinSelector(settings.selectedMuezzin, muezzins, notifier, isDark),
          const SizedBox(height: 24),
          
          _buildSectionTitle('الأذان المخصص', isDark),
          _buildCustomAdhanCard(context, settings, notifier, isDark),
          const SizedBox(height: 24),
          
          _buildSectionTitle('تعديل أوقات الصلاة ونوع التنبيه', isDark),
          for (final p in prayers)
            _buildPrayerCard(context, p.$1, p.$2, settings, notifier, isDark),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.amiri(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: isDark ? AppColors.accentGold : AppColors.primaryBlue,
        ),
      ),
    );
  }

  Widget _buildMuezzinSelector(
    String current,
    List<Muezzin> muezzins,
    PrayerSettingsNotifier notifier,
    bool isDark,
  ) {
    // Find matching muezzin or default to first
    final exists = muezzins.any((m) => m.name == current || m.id == current);
    final selectedValue = exists ? current : (muezzins.isNotEmpty ? muezzins.first.name : '');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            spreadRadius: 1,
          )
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedValue,
          isExpanded: true,
          dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
          items: muezzins.map((m) {
            return DropdownMenuItem(
              value: m.name,
              child: Text(m.name, style: GoogleFonts.amiri(fontSize: 16)),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) notifier.setSelectedMuezzin(val);
          },
        ),
      ),
    );
  }
Widget _buildCustomAdhanCard(
    BuildContext context,
    PrayerSettings settings,
    PrayerSettingsNotifier notifier,
    bool isDark,
  ) {
    final customPath = settings.customAdhanPath;
    final usesVisualizer = settings.customAdhanUsesVisualizer;
    final displayMode = settings.customAdhanDisplayMode;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'أذان مخصص',
                style: GoogleFonts.amiri(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.play_circle_fill, color: AppColors.accentGold),
                onPressed: customPath.isNotEmpty
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FullScreenAdhanScreen(
                              prayerName: 'مخصص',
                              muezzinName: 'أذان مخصص',
                            ),
                          ),
                        );
                      }
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (customPath.isNotEmpty) ...[
            Text(
              'الملف: ${customPath.split('/').last}',
              style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.upload_file),
                  label: Text(customPath.isEmpty ? 'اختر ملف صوتي' : 'تغيير الملف'),
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.audio,
                      allowMultiple: false,
                    );
                    if (result != null && result.files.single.path != null) {
                      notifier.setCustomAdhanPath(result.files.single.path!);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              if (customPath.isNotEmpty) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => notifier.setCustomAdhanPath(''),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('استخدام الشاشة التفاعلية:', style: GoogleFonts.cairo(fontSize: 14)),
              const Spacer(),
              Switch(
                value: usesVisualizer,
                onChanged: (val) => notifier.setCustomAdhanUsesVisualizer(val),
                activeColor: AppColors.accentGold,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('نوع العرض:', style: GoogleFonts.cairo(fontSize: 14)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text('شاشة كاملة مع تأثيرات', style: GoogleFonts.cairo(fontSize: 12)),
                selected: displayMode == 'animated',
                onSelected: (selected) {
                  if (selected) notifier.setCustomAdhanDisplayMode('animated');
                },
                selectedColor: AppColors.primaryBlue,
                labelStyle: TextStyle(color: displayMode == 'animated' ? Colors.white : (isDark ? Colors.white70 : Colors.black87)),
                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
              ),
              ChoiceChip(
                label: Text('شاشة صوت فقط', style: GoogleFonts.cairo(fontSize: 12)),
                selected: displayMode == 'audio_only',
                onSelected: (selected) {
                  if (selected) notifier.setCustomAdhanDisplayMode('audio_only');
                },
                selectedColor: AppColors.primaryBlue,
                labelStyle: TextStyle(color: displayMode == 'audio_only' ? Colors.white : (isDark ? Colors.white70 : Colors.black87)),
                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildPrayerCard(
    BuildContext context,
    String nameAr,
    bool hasAdhan,
    PrayerSettings settings,
    PrayerSettingsNotifier notifier,
    bool isDark,
  ) {
    final offset = settings.prayerOffsets[nameAr] ?? 0;
    final mode = settings.prayerAdhanModes[nameAr] ?? 'animated';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            spreadRadius: 1,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                nameAr,
                style: GoogleFonts.amiri(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              if (hasAdhan)
                TextButton.icon(
                  onPressed: () {
                    // Adhan Preview
                    if (mode == 'audio_only' || mode == 'vibrate_only' || mode == 'silent') {
                      NotificationService().showImmediate(
                        title: 'معاينة أذان $nameAr',
                        body: 'تم ضبط التنبيه على: ${_modeName(mode)}',
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FullScreenAdhanScreen(
                            prayerName: nameAr,
                            muezzinName: settings.selectedMuezzin,
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.play_circle_fill, color: AppColors.accentGold),
                  label: Text('معاينة', style: GoogleFonts.cairo(color: AppColors.accentGold, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const Divider(),
          // Offset control
          Row(
            children: [
              Text('تعديل الوقت (دقائق):', style: GoogleFonts.cairo(fontSize: 14)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: AppColors.primaryBlue),
                onPressed: () => notifier.setPrayerOffset(nameAr, offset - 1),
              ),
              Text(
                '${offset > 0 ? '+' : ''}$offset د',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: AppColors.primaryBlue),
                onPressed: () => notifier.setPrayerOffset(nameAr, offset + 1),
              ),
            ],
          ),
          // Adhan mode control
          if (hasAdhan) ...[
            const SizedBox(height: 12),
            Text('نوع التنبيه:', style: GoogleFonts.cairo(fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildModeChip('animated', 'شاشة كاملة وصوت', mode, nameAr, notifier, isDark),
                _buildModeChip('audio_only', 'صوت فقط بالخلفية', mode, nameAr, notifier, isDark),
                _buildModeChip('vibrate_only', 'اهتزاز فقط', mode, nameAr, notifier, isDark),
                _buildModeChip('silent', 'صامت', mode, nameAr, notifier, isDark),
              ],
            ),
          ]
        ],
      ),
    );
  }
  
  String _modeName(String mode) {
    switch (mode) {
      case 'animated': return 'شاشة كاملة وصوت';
      case 'audio_only': return 'صوت فقط بالخلفية';
      case 'vibrate_only': return 'اهتزاز فقط';
      case 'silent': return 'صامت';
      default: return '';
    }
  }

  Widget _buildModeChip(
    String val,
    String label,
    String current,
    String prayer,
    PrayerSettingsNotifier notifier,
    bool isDark,
  ) {
    final isSelected = val == current;
    return ChoiceChip(
      label: Text(label, style: GoogleFonts.cairo(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) notifier.setPrayerAdhanMode(prayer, val);
      },
      selectedColor: AppColors.primaryBlue,
      labelStyle: TextStyle(color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87)),
      backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
    );
  }
}
