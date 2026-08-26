import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/qibla_provider.dart';
import '../widgets/qibla_particles.dart';

class QiblaCompassScreen extends ConsumerStatefulWidget {
  const QiblaCompassScreen({super.key});

  @override
  ConsumerState<QiblaCompassScreen> createState() => _QiblaCompassScreenState();
}

class _QiblaCompassScreenState extends ConsumerState<QiblaCompassScreen>
    with TickerProviderStateMixin {
  bool _wasAccurate = false;

  // Advanced Parallax variables
  double _pitch = 0.0;
  double _roll = 0.0;

  // Animations
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  late AnimationController _beamController;
  late Animation<double> _beamAnimation;

  @override
  void initState() {
    super.initState();

    // Smooth lerp for accelerometer
    accelerometerEvents.listen((AccelerometerEvent event) {
      if (mounted) {
        setState(() {
          // Add some dampening for smoother physics
          _pitch = ui.lerpDouble(_pitch, event.y * 0.05, 0.2) ?? _pitch;
          _roll = ui.lerpDouble(_roll, event.x * 0.05, 0.2) ?? _roll;
        });
      }
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _glowController, curve: Curves.linear));

    _beamController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _beamAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _beamController, curve: Curves.easeOutCirc),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _glowController.dispose();
    _beamController.dispose();
    super.dispose();
  }

  void _checkHaptics(bool isAccurate) {
    if (isAccurate && !_wasAccurate) {
      HapticFeedback.heavyImpact();
      _beamController.forward(from: 0);
      _wasAccurate = true;
    } else if (!isAccurate && _wasAccurate) {
      _beamController.reverse();
      _wasAccurate = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final qiblaAsync = ref.watch(qiblaStreamProvider);

    return Scaffold(
      backgroundColor: Colors.black, // Deep space black
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'القبلة',
          style: GoogleFonts.scheherazadeNew(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // 1. Animated Deep Space Background
          _buildBackground(),

          // 2. Floating Particles Layer
          const QiblaParticles(),

          // 3. Main Content
          qiblaAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.accentGold),
            ),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.location_off_rounded,
                      color: Colors.redAccent,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'تعذر الحصول على الموقع',
                      style: GoogleFonts.amiri(
                        fontSize: 22,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      error.toString(),
                      style: GoogleFonts.amiri(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            data: (qiblaData) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _checkHaptics(qiblaData.isAccurate);
                }
              });

              final diff = qiblaData.qiblaDiff;
              final turns = diff / 360.0;

              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Status text with glowing aura when accurate
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: qiblaData.isAccurate
                            ? AppColors.accentGold.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: qiblaData.isAccurate
                              ? AppColors.accentGold.withValues(alpha: 0.5)
                              : Colors.transparent,
                        ),
                        boxShadow: qiblaData.isAccurate
                            ? [
                                BoxShadow(
                                  color: AppColors.accentGold.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ]
                            : [],
                      ),
                      child: Text(
                        qiblaData.isAccurate
                            ? 'أنت في اتجاه القبلة'
                            : 'وجه الهاتف نحو القبلة',
                        style: GoogleFonts.amiri(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: qiblaData.isAccurate
                              ? AppColors.accentGold
                              : Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 60),

                    // Epic 3D Parallax Compass Container
                    Transform(
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0015) // Deep perspective
                        ..rotateX(_pitch)
                        ..rotateY(_roll),
                      alignment: Alignment.center,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          // Epic Outer glow when accurate
                          if (qiblaData.isAccurate)
                            ScaleTransition(
                              scale: _pulseAnimation,
                              child: Container(
                                width: 340,
                                height: 340,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.accentGold.withValues(
                                        alpha: 0.4,
                                      ),
                                      blurRadius: 80,
                                      spreadRadius: 30,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // Golden Beam of Light pointing up when accurate
                          Positioned(
                            top: -150,
                            child: AnimatedBuilder(
                              animation: _beamAnimation,
                              builder: (context, child) {
                                return Opacity(
                                  opacity: _beamAnimation.value,
                                  child: Container(
                                    width: 40,
                                    height: 200,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          AppColors.accentGold.withValues(
                                            alpha: 0.8,
                                          ),
                                          AppColors.accentGold.withValues(
                                            alpha: 0.0,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          // Compass Dial Background (Fixed to North)
                          AnimatedRotation(
                            turns: -qiblaData.heading / 360.0,
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutCubic,
                            child: AnimatedBuilder(
                              animation: _glowAnimation,
                              builder: (context, child) {
                                return Container(
                                  width: 300,
                                  height: 300,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(
                                      0xFF0F1A15,
                                    ).withValues(alpha: 0.85),
                                    border: Border.all(
                                      color: AppColors.accentGold.withValues(
                                        alpha: 0.4,
                                      ),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.7,
                                        ),
                                        blurRadius: 30,
                                        offset: const Offset(0, 15),
                                      ),
                                    ],
                                  ),
                                  child: CustomPaint(
                                    painter: _EpicCompassDialPainter(
                                      glowPhase: _glowAnimation.value,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          // Qibla Indicator (Needle pointing to Mecca)
                          AnimatedRotation(
                            turns: turns,
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutBack,
                            child: SizedBox(
                              width: 300,
                              height: 300,
                              child: Column(
                                children: [
                                  const SizedBox(height: 10),
                                  // The Golden Arrow
                                  Icon(
                                    Icons.keyboard_arrow_up_rounded,
                                    size: 60,
                                    color: qiblaData.isAccurate
                                        ? AppColors.accentGold
                                        : Colors.white70,
                                  ),
                                  if (qiblaData.isAccurate)
                                    ScaleTransition(
                                      scale: _beamAnimation,
                                      child: Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: Colors.black,
                                          border: Border.all(
                                            color: AppColors.accentGold,
                                            width: 2.5,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.accentGold
                                                  .withValues(alpha: 0.6),
                                              blurRadius: 15,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            Icons.mosque_rounded,
                                            color: AppColors.accentGold,
                                            size: 28,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),

                          // Center Hub Jewel
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const RadialGradient(
                                colors: [Colors.white, AppColors.accentGold],
                                stops: [0.2, 1.0],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.8),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.0, -0.2),
          radius: 1.2,
          colors: [
            Color(0xFF1B382B), // Deep Islamic Green
            Color(0xFF0F1714),
            Colors.black,
          ],
          stops: [0.0, 0.6, 1.0],
        ),
      ),
    );
  }
}

// Epic Custom Painter for Intricate Islamic Compass Dial
class _EpicCompassDialPainter extends CustomPainter {
  final double glowPhase;

  _EpicCompassDialPainter({required this.glowPhase});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint = Paint()
      ..color = AppColors.accentGold.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final thickPaint = Paint()
      ..color = AppColors.accentGold.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Outer intricate ring
    canvas.drawCircle(center, radius * 0.95, thickPaint);
    canvas.drawCircle(center, radius * 0.92, paint);

    // Inner intricate ring
    canvas.drawCircle(center, radius * 0.65, thickPaint);
    canvas.drawCircle(center, radius * 0.62, paint);

    // Draw sweeping glow on the outer edge
    final rect = Rect.fromCircle(center: center, radius: radius * 0.95);
    final sweepGradient = SweepGradient(
      colors: [
        Colors.transparent,
        AppColors.accentGold.withValues(alpha: 0.8),
        Colors.transparent,
      ],
      stops: const [0.0, 0.5, 1.0],
      transform: GradientRotation(glowPhase * 2 * math.pi),
    );

    final sweepPaint = Paint()
      ..shader = sweepGradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    canvas.drawCircle(center, radius * 0.95, sweepPaint);

    // Draw Islamic octagram (Rub el Hizb style) in the middle
    _drawOctagram(canvas, center, radius * 0.55, paint);

    // Draw tick marks (Degrees)
    for (int i = 0; i < 360; i += 5) {
      final isMajor = i % 90 == 0;
      final isMedium = i % 30 == 0;
      final angle = i * math.pi / 180;

      final innerRadius = isMajor
          ? radius * 0.72
          : (isMedium ? radius * 0.80 : radius * 0.85);
      final outerRadius = radius * 0.90;

      final p1 = Offset(
        center.dx + innerRadius * math.cos(angle),
        center.dy + innerRadius * math.sin(angle),
      );

      final p2 = Offset(
        center.dx + outerRadius * math.cos(angle),
        center.dy + outerRadius * math.sin(angle),
      );

      canvas.drawLine(p1, p2, isMajor ? thickPaint : paint);
    }

    // Draw North marker
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'ش',
        style: GoogleFonts.amiri(
          color: Colors.redAccent,
          fontSize: 26,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.rtl,
    );
    textPainter.layout();

    // Position North marker (شمال - N)
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - radius * 0.88 - textPainter.height / 2,
      ),
    );
  }

  void _drawOctagram(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    // Square 1
    for (int i = 0; i < 4; i++) {
      final angle = (i * math.pi / 2);
      final p = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      if (i == 0)
        path.moveTo(p.dx, p.dy);
      else
        path.lineTo(p.dx, p.dy);
    }
    path.close();

    // Square 2 (Rotated 45 deg)
    final path2 = Path();
    for (int i = 0; i < 4; i++) {
      final angle = (i * math.pi / 2) + (math.pi / 4);
      final p = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      if (i == 0)
        path2.moveTo(p.dx, p.dy);
      else
        path2.lineTo(p.dx, p.dy);
    }
    path2.close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(covariant _EpicCompassDialPainter oldDelegate) {
    return oldDelegate.glowPhase != glowPhase;
  }
}
