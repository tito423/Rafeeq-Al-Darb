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
  int _currentStep = 0; // 0: Permissions, 1: Mushaf Selection & Download
  
  // Permissions status
  bool _locationGranted = false;
  bool _notificationGranted = false;

  // Selected mushaf style
  MushafStyle _selectedStyle = MushafStyle.medina1;
  bool _isDownloadingMushaf = false;
  double _downloadProgress = 0.0;
  String _downloadStatusText = '';

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    // Auto request on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestAllPermissions();
    });
  }

  Future<void> _checkPermissions() async {
    final loc = await Permission.location.isGranted;
    final notif = await Permission.notification.isGranted;
    if (mounted) {
      setState(() {
        _locationGranted = loc;
        _notificationGranted = notif;
      });
    }
  }

  Future<void> _requestLocation() async {
    final res = await Permission.location.request();
    if (mounted) {
      setState(() => _locationGranted = res.isGranted);
    }
  }

  Future<void> _requestNotifications() async {
    final res = await Permission.notification.request();
    if (mounted) {
      setState(() => _notificationGranted = res.isGranted);
    }
  }

  Future<void> _requestAllPermissions() async {
    await _requestLocation();
    await _requestNotifications();
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
            // Top Step Indicator
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
              child: Row(
                children: [
                  _buildStepCircle(0, 'صلاحيات', _currentStep >= 0),
                  _buildStepLine(_currentStep >= 1),
                  _buildStepCircle(1, 'المصحف', _currentStep >= 1),
                ],
              ),
            ),

            // Content Area
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildCurrentStep(isDark, primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCircle(int step, String title, bool active) {
    final isCurrent = _currentStep == step;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? AppColors.accentGold : Colors.grey.withValues(alpha: 0.3),
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: AppColors.accentGold.withValues(alpha: 0.4),
                      blurRadius: 10,
                      spreadRadius: 2,
                    )
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              '${step + 1}',
              style: GoogleFonts.outfit(
                color: active ? AppColors.primaryBlue : Colors.grey,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: GoogleFonts.amiri(
            fontSize: 12,
            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
            color: active ? AppColors.accentGold : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(bool active) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 18),
        color: active ? AppColors.accentGold : Colors.grey.withValues(alpha: 0.2),
      ),
    );
  }

  Widget _buildCurrentStep(bool isDark, Color primary) {
    switch (_currentStep) {
      case 0:
        return _buildPermissionsStep(isDark, primary);
      case 1:
      default:
        return _buildMushafStep(isDark, primary);
    }
  }

  // ── Step 0: Permissions ───────────────────────────────────────────────────
  Widget _buildPermissionsStep(bool isDark, Color primary) {
    return Padding(
      key: const ValueKey(0),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentGold.withValues(alpha: 0.15),
              ),
              child: const Icon(
                Icons.security_rounded,
                size: 48,
                color: AppColors.accentGold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'أهلاً بك في رفيق الدرب 🌟',
            textAlign: TextAlign.center,
            style: GoogleFonts.amiri(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'لتقديم تجربة إسلامية متكاملة ودقيقة، يحتاج التطبيق إلى الأذونات التالية:',
            textAlign: TextAlign.center,
            style: GoogleFonts.amiri(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 28),

          // Location Permission Tile
          _buildPermissionTile(
            icon: Icons.location_on_rounded,
            title: 'إذن الموقع الجغرافي',
            desc: 'لحساب مواقيت الصلاة واتجاه القبلة بدقة متناهية حسب موقعك.',
            isGranted: _locationGranted,
            onRequest: _requestLocation,
            isDark: isDark,
          ),
          const SizedBox(height: 12),

          // Notification Permission Tile
          _buildPermissionTile(
            icon: Icons.notifications_active_rounded,
            title: 'إذن الإشعارات وتنبيهات الأذان',
            desc: 'لإرسال تنبيهات الأذان، أذكار الصباح والمساء، وسور الكهف والملك.',
            isGranted: _notificationGranted,
            onRequest: _requestNotifications,
            isDark: isDark,
          ),

          const Spacer(),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
            onPressed: _requestAllPermissions,
            child: Text(
              'متابعة الخطوة التالية',
              style: GoogleFonts.amiri(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildPermissionTile({
    required IconData icon,
    required String title,
    required String desc,
    required bool isGranted,
    required VoidCallback onRequest,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGranted ? Colors.green.withValues(alpha: 0.5) : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isGranted ? Colors.green : AppColors.primaryBlue).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isGranted ? Icons.check_circle_rounded : icon,
              color: isGranted ? Colors.green : AppColors.primaryBlue,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.amiri(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: GoogleFonts.amiri(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!isGranted)
            TextButton(
              onPressed: onRequest,
              child: Text(
                'سماح',
                style: GoogleFonts.amiri(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentGold,
                ),
              ),
            )
          else
            const Icon(Icons.check_rounded, color: Colors.green, size: 24),
        ],
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

  // ── Step 2: Theme Selection ───────────────────────────────────────────────
  Widget _buildThemeStep(bool isDark, Color primary) {
    final themeState = ref.watch(themeProvider);
    final currentTheme = themeState.appThemeType;

    return Padding(
      key: const ValueKey(2),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Text(
            'اختيار مظهر التطبيق 🎨',
            textAlign: TextAlign.center,
            style: GoogleFonts.amiri(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'اختر النمط اللوني الذي يناسب ذوقك (يمكنك تغييره في أي وقت من الإعدادات):',
            textAlign: TextAlign.center,
            style: GoogleFonts.amiri(
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 24),

          // Palette options
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.3,
              ),
              itemCount: kAppThemes.length,
              itemBuilder: (context, idx) {
                final themeConfig = kAppThemes[idx];
                final isSelected = currentTheme == themeConfig.type;

                return GestureDetector(
                  onTap: () {
                    ref.read(themeProvider.notifier).setAppThemeType(themeConfig.type);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected ? AppColors.accentGold : Colors.transparent,
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isSelected
                              ? AppColors.accentGold.withValues(alpha: 0.25)
                              : Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: themeConfig.primaryColor,
                              ),
                              const SizedBox(width: 8),
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: themeConfig.accentColor,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            themeConfig.name,
                            style: GoogleFonts.amiri(
                              fontSize: 15,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                              color: isSelected
                                  ? AppColors.accentGold
                                  : (isDark ? Colors.white : Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          Row(
            children: [
              TextButton(
                onPressed: () => setState(() => _currentStep = 0),
                child: Text(
                  'السابق',
                  style: GoogleFonts.amiri(fontSize: 16, color: Colors.grey),
                ),
              ),
              const Spacer(),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentGold,
                  foregroundColor: AppColors.primaryBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 6,
                ),
                onPressed: _finishOnboarding,
                child: Text(
                  'ابدأ رحلتك الإيمانية 🚀',
                  style: GoogleFonts.amiri(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryBlue,
                  ),
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
