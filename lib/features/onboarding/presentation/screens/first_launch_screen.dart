import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/shell/app_shell.dart';
import '../../../../core/models/mushaf_style.dart';
import '../../../../core/models/app_theme_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../services/download_manager.dart';
import '../../../quran/presentation/widgets/mushaf_selection_gallery.dart';

class FirstLaunchScreen extends ConsumerStatefulWidget {
  const FirstLaunchScreen({super.key});

  @override
  ConsumerState<FirstLaunchScreen> createState() => _FirstLaunchScreenState();
}

class _FirstLaunchScreenState extends ConsumerState<FirstLaunchScreen> {
  // Selected mushaf style
  MushafStyle _selectedStyle = MushafStyle.medina1;
  bool _isDownloadingMushaf = false;
  double _downloadProgress = 0.0;
  String _downloadStatusText = '';

  @override
  void initState() {
    super.initState();
    // Auto request on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestAllPermissions();
    });
  }

  Future<void> _requestAllPermissions() async {
    await Permission.location.request();
    await Permission.notification.request();
    await Permission.scheduleExactAlarm.request();
  }

  Future<void> _startMushafDownload() async {
    final styleInfo = getMushafStyleInfo(_selectedStyle);
    ref.read(mushafStyleProvider.notifier).setStyle(_selectedStyle);

    setState(() {
      _isDownloadingMushaf = true;
      _downloadProgress = 0.01;
      _downloadStatusText = 'جارٍ بدء تحميل المصحف الشريف...';
    });

    final totalPages = _selectedStyle == MushafStyle.shamarly ? 522 : 604;
    final downloadManager = ref.read(downloadManagerProvider.notifier);

    // Download sequentially in batches of 5
    int completed = 0;
    for (int page = 1; page <= totalPages; page++) {
      if (!mounted) return;
      try {
        await downloadManager.downloadMushaafPage(page, styleInfo: styleInfo);
        completed++;
        if (page % 5 == 0 || page == totalPages) {
          setState(() {
            _downloadProgress = completed / totalPages;
            _downloadStatusText = 'تم تحميل $completed من $totalPages صفحة (${(_downloadProgress * 100).toInt()}%)';
          });
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _isDownloadingMushaf = false;
        _downloadProgress = 1.0;
        _downloadStatusText = 'اكتمل تحميل المصحف الشريف بنجاح!';
      });
    }
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_first_launch', false);
    ref.read(mushafStyleProvider.notifier).setStyle(_selectedStyle);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AppShell()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.primaryBlue;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFFAF7F0),
      body: SafeArea(
        child: Column(
          children: [
            // Content Area
            Expanded(
              child: _buildMushafStep(isDark, primary),
            ),
          ],
        ),
      ),
    );
  }



  // ── Step 1: Mushaf Selection & Download ───────────────────────────────────
  Widget _buildMushafStep(bool isDark, Color primary) {
    final styleInfo = getMushafStyleInfo(_selectedStyle);

    return Padding(
      key: const ValueKey(1),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Text(
            'اختيار المصحف الشريف المصور 📖',
            textAlign: TextAlign.center,
            style: GoogleFonts.amiri(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'اختر الطبعة أو الرواية المفضلة لديك لقراءة صفحات المصحف بجودة فائقة:',
            textAlign: TextAlign.center,
            style: GoogleFonts.amiri(
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 20),


          // Selected Mushaf Description
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.primaryBlue, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    styleInfo.description,
                    style: GoogleFonts.amiri(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : AppColors.primaryBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Browse Full 17 Visual Mushafs Gallery
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accentGold,
              side: BorderSide(color: AppColors.accentGold.withValues(alpha: 0.6)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            icon: const Icon(Icons.auto_stories_rounded, size: 20),
            label: Text(
              'تصفح أغلفة ومعاينات الـ 17 مصحفاً بالصور 🌟',
              style: GoogleFonts.amiri(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            onPressed: () async {
              await MushafSelectionGallery.show(context);
              setState(() {
                _selectedStyle = ref.read(mushafStyleProvider);
              });
            },
          ),
          const SizedBox(height: 16),

          // Download Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                    : [Colors.white, const Color(0xFFF1F5F9)],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.cloud_download_rounded, color: AppColors.accentGold, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'تحميل المصحف للعمل بدون إنترنت',
                        style: GoogleFonts.amiri(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_isDownloadingMushaf || _downloadProgress > 0) ...[
                  LinearProgressIndicator(
                    value: _downloadProgress,
                    backgroundColor: Colors.grey.withValues(alpha: 0.2),
                    color: AppColors.accentGold,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _downloadStatusText,
                    style: GoogleFonts.amiri(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentGold,
                    ),
                  ),
                ] else ...[
                  Text(
                    'يمكنك تحميل جميع صفحات المصحف الآن لسرعة فائقة وتصفح بدون اتصال بالإنترنت.',
                    style: GoogleFonts.amiri(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accentGold,
                      side: const BorderSide(color: AppColors.accentGold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.download_rounded),
                    label: Text(
                      'تحميل المصحف كاملاً الآن',
                      style: GoogleFonts.amiri(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    onPressed: _startMushafDownload,
                  ),
                ],
              ],
            ),
          ),

          const Spacer(),

          Row(
            children: [
              const Spacer(),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentGold,
                  foregroundColor: AppColors.primaryBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _finishOnboarding,
                child: Text(
                  'ابدأ رحلتك الإيمانية 🚀',
                  style: GoogleFonts.amiri(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primaryBlue),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
