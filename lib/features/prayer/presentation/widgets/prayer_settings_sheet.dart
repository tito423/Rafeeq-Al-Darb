import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';

import '../providers/prayer_settings_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../services/download_manager.dart';

class PrayerSettingsSheet extends ConsumerWidget {
  const PrayerSettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(prayerSettingsProvider);
    final notifier = ref.read(prayerSettingsProvider.notifier);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCardBackground : Colors.white;
    final textColor = isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface;

    final prayers = ['الفجر', 'الشروق', 'الظهر', 'العصر', 'المغرب', 'العشاء'];

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.accentGold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.access_time_filled_rounded,
                          color: AppColors.accentGold,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'إعدادات الأذان والمواقيت',
                        style: GoogleFonts.scheherazadeNew(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Muezzin Selection ──────────────────────────────────────────
              Text(
                'صوت الأذان والمؤذن',
                style: GoogleFonts.amiri(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentGold,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                color: cardBg,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: const Icon(Icons.record_voice_over_rounded, color: AppColors.accentGold),
                  title: Text(
                    settings.selectedMuezzin,
                    style: GoogleFonts.scheherazadeNew(fontSize: 18, fontWeight: FontWeight.w700, color: textColor),
                  ),
                  subtitle: Text(
                    'اضغط لمعاينة وتغيير صوت الأذان',
                    style: GoogleFonts.amiri(fontSize: 12, color: AppColors.lightSubtext),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.accentGold),
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
              
              // Adhan Display Mode Toggle
              Text(
                'طريقة عرض الأذان',
                style: GoogleFonts.amiri(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentGold,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                color: cardBg,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    RadioListTile<String>(
                      value: 'animated',
                      groupValue: settings.adhanDisplayMode,
                      activeColor: AppColors.accentGold,
                      title: Text(
                        'صوت وفيديو تفاعلي',
                        style: GoogleFonts.amiri(fontSize: 16, fontWeight: FontWeight.w600, color: textColor),
                      ),
                      subtitle: Text('عرض فيديو تفاعلي متزامن مع صوت المؤذن', style: GoogleFonts.amiri(fontSize: 12, color: AppColors.lightSubtext)),
                      onChanged: (val) => notifier.setAdhanDisplayMode(val!),
                    ),
                    const Divider(height: 1, indent: 56),
                    RadioListTile<String>(
                      value: 'audio_only',
                      groupValue: settings.adhanDisplayMode,
                      activeColor: AppColors.accentGold,
                      title: Text(
                        'صوت فقط (في الخلفية)',
                        style: GoogleFonts.amiri(fontSize: 16, fontWeight: FontWeight.w600, color: textColor),
                      ),
                      subtitle: Text('تشغيل الأذان صوتياً فقط دون إظهار الشاشة الكاملة', style: GoogleFonts.amiri(fontSize: 12, color: AppColors.lightSubtext)),
                      onChanged: (val) => notifier.setAdhanDisplayMode(val!),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Athkar & Wird Alarms (Sakanty-Style) ────────────────────────
              Text(
                'تنبيهات الأذكار والورد القرآني (سكينتي)',
                style: GoogleFonts.amiri(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentGold,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                color: cardBg,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.wb_sunny_rounded, color: Color(0xFFE17055)),
                      title: Text(
                        'أذكار الصباح (05:00 ص)',
                        style: GoogleFonts.amiri(fontSize: 16, fontWeight: FontWeight.w600, color: textColor),
                      ),
                      subtitle: Text('تذكير يومي في بداية الصباح', style: GoogleFonts.amiri(fontSize: 12, color: AppColors.lightSubtext)),
                      value: settings.morningAthkarEnabled,
                      activeThumbColor: AppColors.accentGold,
                      onChanged: (val) => notifier.setMorningAthkarEnabled(val),
                    ),
                    const Divider(height: 1, indent: 56),
                    SwitchListTile(
                      secondary: const Icon(Icons.nights_stay_rounded, color: Color(0xFF6C5CE7)),
                      title: Text(
                        'أذكار المساء (16:30 م)',
                        style: GoogleFonts.amiri(fontSize: 16, fontWeight: FontWeight.w600, color: textColor),
                      ),
                      subtitle: Text('تذكير يومي في وقت العصر', style: GoogleFonts.amiri(fontSize: 12, color: AppColors.lightSubtext)),
                      value: settings.eveningAthkarEnabled,
                      activeThumbColor: AppColors.accentGold,
                      onChanged: (val) => notifier.setEveningAthkarEnabled(val),
                    ),
                    const Divider(height: 1, indent: 56),
                    SwitchListTile(
                      secondary: const Icon(Icons.menu_book_rounded, color: Color(0xFF00B894)),
                      title: Text(
                        'الورد القرآني الصباحي (05:00 ص)',
                        style: GoogleFonts.amiri(fontSize: 16, fontWeight: FontWeight.w600, color: textColor),
                      ),
                      subtitle: Text('تذكير بقراءة الورد اليومي', style: GoogleFonts.amiri(fontSize: 12, color: AppColors.lightSubtext)),
                      value: settings.morningQuranWirdEnabled,
                      activeThumbColor: AppColors.accentGold,
                      onChanged: (val) => notifier.setMorningQuranWirdEnabled(val),
                    ),
                    const Divider(height: 1, indent: 56),
                    SwitchListTile(
                      secondary: const Icon(Icons.auto_stories_rounded, color: Color(0xFF0984E3)),
                      title: Text(
                        'الورد القرآني المسائي (16:30 م)',
                        style: GoogleFonts.amiri(fontSize: 16, fontWeight: FontWeight.w600, color: textColor),
                      ),
                      subtitle: Text('تذكير بختام اليوم مع كتاب الله', style: GoogleFonts.amiri(fontSize: 12, color: AppColors.lightSubtext)),
                      value: settings.eveningQuranWirdEnabled,
                      activeThumbColor: AppColors.accentGold,
                      onChanged: (val) => notifier.setEveningQuranWirdEnabled(val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Calculation Method ─────────────────────────────────────────
              Text(
                'طريقة الحساب الفلكي',
                style: GoogleFonts.amiri(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentGold,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                color: cardBg,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: const Icon(Icons.calculate_rounded, color: AppColors.primaryBlue),
                  title: Text(
                    settings.calculationMethod,
                    style: GoogleFonts.scheherazadeNew(fontSize: 16, fontWeight: FontWeight.w700, color: textColor),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.accentGold),
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

              // ── Prayer Adjustments ─────────────────────────────────────────
              Text(
                'تعديل المواقيت وتنبيهات الإقامة (بالدقائق)',
                style: GoogleFonts.amiri(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentGold,
                ),
              ),
              const SizedBox(height: 8),
              
              ...prayers.map((prayer) {
                final offset = settings.prayerOffsets[prayer] ?? 0;
                final preAdhan = settings.preAdhanAlarms[prayer] ?? 0;
                final iqamah = settings.iqamahAlarms[prayer] ?? 0;
                final isEnabled = settings.prayerToggles[prayer] ?? true;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Card(
                    color: cardBg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.hardEdge,
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      leading: Switch(
                        value: isEnabled,
                        activeThumbColor: AppColors.accentGold,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onChanged: (val) => notifier.setPrayerToggle(prayer, val),
                      ),
                      title: Text(
                        prayer,
                        style: GoogleFonts.scheherazadeNew(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: isEnabled ? AppColors.accentGold : (isDark ? AppColors.darkSubtext : AppColors.lightSubtext),
                        ),
                      ),
                      trailing: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.accentGold),
                      children: [
                        // Offset dropdown
                        _buildDropdownRow(
                          label: 'تعديل الوقت',
                          icon: Icons.tune_rounded,
                          value: offset,
                          items: List.generate(61, (i) => i - 30), // -30 to +30
                          labelFn: (v) => v > 0 ? '+$v دق' : (v < 0 ? '$v دق' : 'بدون تعديل'),
                          onChanged: (v) => notifier.setPrayerOffset(prayer, v),
                          textColor: textColor,
                          isDark: isDark,
                        ),
                        const Divider(height: 1),
                        // Pre-adhan alert dropdown
                        _buildDropdownRow(
                          label: 'تنبيه قبل الأذان',
                          icon: Icons.notifications_active_rounded,
                          value: preAdhan,
                          items: [0, 5, 10, 15, 20, 30, 45, 60],
                          labelFn: (v) => v == 0 ? 'لا يوجد' : 'قبل $v دق',
                          onChanged: (v) => notifier.setPreAdhanAlarm(prayer, v),
                          textColor: textColor,
                          isDark: isDark,
                        ),
                        if (prayer != 'الشروق') ...[
                          const Divider(height: 1),
                          // Iqama alert dropdown
                          _buildDropdownRow(
                            label: 'تنبيه الإقامة',
                            icon: Icons.alarm_rounded,
                            value: iqamah,
                            items: [0, 5, 10, 15, 20, 25, 30, 45],
                            labelFn: (v) => v == 0 ? 'لا يوجد' : 'بعد $v دق',
                            onChanged: (v) => notifier.setIqamahAlarm(prayer, v),
                            textColor: textColor,
                            isDark: isDark,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownRow({
    required String label,
    required IconData icon,
    required int value,
    required List<int> items,
    required String Function(int) labelFn,
    required ValueChanged<int> onChanged,
    required Color textColor,
    required bool isDark,
  }) {
    // Clamp value to available items to avoid assertion errors
    final safeValue = items.contains(value) ? value : items.first;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.accentGold, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.amiri(fontSize: 15, color: textColor),
              ),
            ],
          ),
          DropdownButton<int>(
            value: safeValue,
            underline: const SizedBox(),
            dropdownColor: isDark ? AppColors.darkCardBackground : Colors.white,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.accentGold),
            style: GoogleFonts.amiri(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.accentGold,
            ),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
            items: items.map((v) => DropdownMenuItem(
              value: v,
              child: Text(
                labelFn(v),
                style: GoogleFonts.amiri(
                  fontSize: 14,
                  color: v == safeValue ? AppColors.accentGold : textColor,
                  fontWeight: v == safeValue ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Muezzin Selection Sheet with Instant Live Audio Preview ──────────────────
class MuezzinSelectionSheet extends ConsumerStatefulWidget {
  const MuezzinSelectionSheet({super.key});

  @override
  ConsumerState<MuezzinSelectionSheet> createState() => _MuezzinSelectionSheetState();
}

class _MuezzinSelectionSheetState extends ConsumerState<MuezzinSelectionSheet> {
  final AudioPlayer _player = AudioPlayer();
  String? _currentlyPlayingId;
  bool _isLoadingAudio = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _previewAudio(Muezzin muezzin) async {
    if (_currentlyPlayingId == muezzin.id) {
      if (_player.playing) {
        await _player.pause();
      } else {
        await _player.play();
      }
      setState(() {});
      return;
    }

    setState(() {
      _currentlyPlayingId = muezzin.id;
      _isLoadingAudio = true;
    });

    try {
      await _player.stop();
      final manager = ref.read(downloadManagerProvider.notifier);
      final path = await manager.getAdhanPath(muezzin.id);
      if (path != null) {
        await _player.setFilePath(path);
      } else {
        await _player.setUrl(muezzin.url);
      }
      await _player.play();
    } catch (e) {
      debugPrint('Error previewing adhan: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingAudio = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(prayerSettingsProvider);
    final notifier = ref.read(prayerSettingsProvider.notifier);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCardBackground : Colors.white;
    final textColor = isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface;
    final muezzinsAsync = ref.watch(muezzinsProvider);
    final downloadState = ref.watch(downloadManagerProvider);


    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'اختر المؤذن',
                    style: GoogleFonts.scheherazadeNew(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      _player.stop();
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            muezzinsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accentGold)),
              error: (err, _) => Center(child: Text('خطأ في التحميل', style: GoogleFonts.amiri(color: Colors.red))),
              data: (muezzins) {
                return Column(
                  children: muezzins.map((m) {
                    final isSelected = settings.selectedMuezzin == m.name;
                    final isPlayingThis = _currentlyPlayingId == m.id && _player.playing;
                    final isLoadingThis = _currentlyPlayingId == m.id && _isLoadingAudio;
                    
                    final taskId = 'adhan_${m.id}';
                    final task = downloadState.tasks[taskId];
                    final isDownloading = task?.isDownloading == true;

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.accentGold.withValues(alpha: 0.12) : cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AppColors.accentGold : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: IconButton(
                          icon: isLoadingThis
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentGold),
                                )
                              : Icon(
                                  isPlayingThis ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                                  color: AppColors.accentGold,
                                  size: 36,
                                ),
                          onPressed: () => _previewAudio(m),
                        ),
                        title: Text(
                          m.name,
                          style: GoogleFonts.scheherazadeNew(
                            fontSize: 20,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? AppColors.accentGold : textColor,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FutureBuilder<bool>(
                              future: ref.read(downloadManagerProvider.notifier).isAdhanDownloaded(m.id),
                              builder: (context, snapshot) {
                                final isDownloaded = snapshot.data ?? false;
                                if (isDownloaded) return const SizedBox();
                                
                                if (isDownloading) {
                                  return SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      value: task?.progress,
                                      strokeWidth: 2,
                                      color: AppColors.accentGold,
                                    ),
                                  );
                                }
                                
                                return IconButton(
                                  icon: const Icon(Icons.download_rounded, color: AppColors.accentGold),
                                  onPressed: () {
                                    ref.read(downloadManagerProvider.notifier).downloadAdhan(m.id, m.url);
                                  },
                                );
                              },
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle_rounded, color: AppColors.accentGold, size: 24)
                            else
                              TextButton(
                                onPressed: () {
                                  notifier.setSelectedMuezzin(m.name);
                                  _player.stop();
                                  Navigator.pop(context);
                                },
                                child: Text(
                                  'اختيار',
                                  style: GoogleFonts.amiri(color: AppColors.accentGold, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                        onTap: () {
                          notifier.setSelectedMuezzin(m.name);
                          _previewAudio(m);
                        },
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Calculation Method Sheet ──────────────────────────────────────────────────
const kCalculationMethods = [
  'Umm Al-Qura Univ., Makkah',
  'Egyptian General Authority of Survey',
  'Univ. of Islamic Sciences, Karachi',
  'Islamic Society of North America (ISNA)',
  'Muslim World League (MWL)',
  'Kuwait',
  'Qatar',
];

class CalculationMethodSheet extends ConsumerWidget {
  const CalculationMethodSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(prayerSettingsProvider);
    final notifier = ref.read(prayerSettingsProvider.notifier);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'طريقة الحساب الفلكي',
                  style: GoogleFonts.scheherazadeNew(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ...kCalculationMethods.map((m) {
                final isSelected = settings.calculationMethod == m;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  title: Text(
                    m,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? AppColors.accentGold : textColor,
                    ),
                    textDirection: TextDirection.ltr,
                  ),
                  trailing: isSelected 
                    ? const Icon(Icons.check_circle_rounded, color: AppColors.accentGold)
                    : null,
                  onTap: () {
                    notifier.setCalculationMethod(m);
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Single Prayer Config Sheet ───────────────────────────────────────────────
class SinglePrayerConfigSheet extends ConsumerWidget {
  final String prayer;
  const SinglePrayerConfigSheet({super.key, required this.prayer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(prayerSettingsProvider);
    final notifier = ref.read(prayerSettingsProvider.notifier);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface;

    final offset = settings.prayerOffsets[prayer] ?? 0;
    final preAdhan = settings.preAdhanAlarms[prayer] ?? 0;
    final iqamah = settings.iqamahAlarms[prayer] ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'تعديل تنبيهات $prayer',
              style: GoogleFonts.scheherazadeNew(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 24),
            _buildNumberRow('تعديل الوقت (دقائق):', offset, (val) => notifier.setPrayerOffset(prayer, val)),
            const SizedBox(height: 12),
            _buildNumberRow('تنبيه قبل الأذان:', preAdhan, (val) => notifier.setPreAdhanAlarm(prayer, val), allowNegative: false),
            if (prayer != 'الشروق') ...[
              const SizedBox(height: 12),
              _buildNumberRow('تنبيه الإقامة:', iqamah, (val) => notifier.setIqamahAlarm(prayer, val), allowNegative: false),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNumberRow(String label, int value, ValueChanged<int> onChanged, {bool allowNegative = true}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.amiri(fontSize: 15),
        ),
        Row(
          children: [
            IconButton(
              onPressed: () {
                if (!allowNegative && value <= 0) return;
                onChanged(value - 1);
              },
              icon: const Icon(Icons.remove_circle_outline_rounded),
              color: Colors.redAccent,
              iconSize: 22,
            ),
            SizedBox(
              width: 36,
              child: Text(
                value > 0 && allowNegative ? '+$value' : '$value',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              onPressed: () {
                onChanged(value + 1);
              },
              icon: const Icon(Icons.add_circle_outline_rounded),
              color: Colors.green,
              iconSize: 22,
            ),
          ],
        ),
      ],
    );
  }
}
