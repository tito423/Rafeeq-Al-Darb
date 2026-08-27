import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart' as import_flutter_native_splash;

import '../../../../app/shell/app_shell.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/notification_service.dart' as import_notification_service;
import '../../../onboarding/presentation/screens/first_launch_screen.dart';
import '../../../../services/assets_extractor_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _rotationCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _fadeCtrl;

  late Animation<double> _scaleAnim;
  late Animation<double> _glowAnim;
  late Animation<double> _fadeAnim;
  
  String _extractionProgress = '';
  bool _isExtracting = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      import_flutter_native_splash.FlutterNativeSplash.remove();
    });

    // Continuous rotation for Islamic arabesque pattern
    _rotationCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();

    // Pulse & glow animation for icon
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _scaleAnim = Tween<double>(begin: 0.92, end: 1.06).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _glowAnim = Tween<double>(begin: 0.3, end: 0.85).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Initial entrance fade animation
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();

    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);

    // Removed _checkInitialNotification() from initState, handled in _initializeApp

    // Start initialization sequence
    _initializeApp();
  }
  
  Future<void> _initializeApp() async {
    final launchedByNotif = await import_notification_service.NotificationService().checkInitialNotification();

    if (!launchedByNotif) {
      // Show splash for at least 2.5 seconds before checking assets
      await Future.delayed(const Duration(milliseconds: 2500));
    }

    
    if (!mounted) return;
    setState(() {
      _isExtracting = true;
    });
    
    await AssetsExtractorService.extractInitialAssetsIfNeeded((progressMsg) {
      if (mounted) {
        setState(() {
          _extractionProgress = progressMsg;
        });
      }
    });
    
    if (mounted) {
      setState(() {
        _isExtracting = false;
      });
    }
    
    // Proceed
    _navigateNext();
  }

  Future<bool> _checkInitialNotification() async {
    // Deprecated wrapper
    return false;
  }

  Future<void> _navigateNext() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstLaunch = prefs.getBool('is_first_launch') ?? true;

    if (!mounted) return;

    if (isFirstLaunch) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const FirstLaunchScreen(),
          transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const AppShell(),
          transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    }
  }

  @override
  void dispose() {
    _rotationCtrl.dispose();
    _pulseCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Deep Celestial Radial Gradient Background
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: isDark
                    ? [const Color(0xFF1E293B), const Color(0xFF07101E), const Color(0xFF030712)]
                    : [const Color(0xFF1B4965), const Color(0xFF0B2545), const Color(0xFF031024)],
              ),
            ),
          ),

          // 2. Animated Islamic Geometric Mandalas (GIF-like motion graphic effect)
          AnimatedBuilder(
            animation: _rotationCtrl,
            builder: (context, _) {
              return Transform.rotate(
                angle: _rotationCtrl.value * 2 * pi,
                child: CustomPaint(
                  painter: _IslamicGeometricMandalaPainter(
                    color: AppColors.accentGold.withValues(alpha: 0.12),
                  ),
                  size: Size.infinite,
                ),
              );
            },
          ),

          AnimatedBuilder(
            animation: _rotationCtrl,
            builder: (context, _) {
              return Transform.rotate(
                angle: -_rotationCtrl.value * 2 * pi * 0.7,
                child: CustomPaint(
                  painter: _IslamicGeometricMandalaPainter(
                    color: Colors.white.withValues(alpha: 0.05),
                    spokes: 16,
                    radiusFactor: 0.75,
                  ),
                  size: Size.infinite,
                ),
              );
            },
          ),

          // 3. Central Content: Glowing App Icon & Calligraphy
          FadeTransition(
            opacity: _fadeAnim,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Glowing Icon with pulse
                  AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _scaleAnim.value,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE5C07B), Color(0xFFC99700), Color(0xFF996515)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accentGold.withValues(alpha: _glowAnim.value * 0.6),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.2),
                                blurRadius: 15,
                                offset: const Offset(-4, -4),
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const Icon(Icons.mosque_rounded, size: 68, color: Colors.white),
                              Icon(Icons.mosque_outlined, size: 68, color: Colors.black.withValues(alpha: 0.1)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 36),

                  // Calligraphy Title
                  Text(
                    'رَفِيقُ الدَّرْبِ',
                    style: GoogleFonts.scheherazadeNew(
                      fontSize: 44,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 1.5,
                      shadows: [
                        Shadow(
                          color: AppColors.accentGold.withValues(alpha: 0.6),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Subtitle
                  Text(
                    'زَادُ المُسْلِمِ اليَوْمِي وَمُصْحَفُ القُلُوبِ',
                    style: GoogleFonts.amiri(
                      fontSize: 17,
                      color: AppColors.accentGold,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  
                  // Extraction Progress Indicator
                  if (_isExtracting && _extractionProgress.isNotEmpty) ...[
                    const SizedBox(height: 48),
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: AppColors.accentGold,
                        strokeWidth: 2.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _extractionProgress,
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Custom Painter for Islamic Mandala Geometric Animation ──────────────────

class _IslamicGeometricMandalaPainter extends CustomPainter {
  final Color color;
  final int spokes;
  final double radiusFactor;

  _IslamicGeometricMandalaPainter({
    required this.color,
    this.spokes = 12,
    this.radiusFactor = 0.95,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = (min(size.width, size.height) / 2) * radiusFactor;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    // Draw concentric decorative rings
    for (int r = 1; r <= 4; r++) {
      canvas.drawCircle(center, maxRadius * (r / 4), paint);
    }

    // Draw interlocking 8-point / 12-point star polygons
    for (int i = 0; i < spokes; i++) {
      final angle = (i * 2 * pi) / spokes;
      final p1 = Offset(
        center.dx + maxRadius * cos(angle),
        center.dy + maxRadius * sin(angle),
      );
      canvas.drawLine(center, p1, paint);

      // Star cross diagonals
      final p2 = Offset(
        center.dx + (maxRadius * 0.7) * cos(angle + pi / spokes),
        center.dy + (maxRadius * 0.7) * sin(angle + pi / spokes),
      );
      canvas.drawLine(p1, p2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _IslamicGeometricMandalaPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.spokes != spokes;
}
