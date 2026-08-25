import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/qibla_provider.dart';

class QiblaCompassScreen extends ConsumerStatefulWidget {
  const QiblaCompassScreen({super.key});

  @override
  ConsumerState<QiblaCompassScreen> createState() => _QiblaCompassScreenState();
}

class _QiblaCompassScreenState extends ConsumerState<QiblaCompassScreen> with SingleTickerProviderStateMixin {
  bool _wasAccurate = false;
  
  // Parallax variables
  double _pitch = 0.0;
  double _roll = 0.0;
  
  // Animation for smooth compass rotation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // Listen to accelerometer for parallax
    accelerometerEvents.listen((AccelerometerEvent event) {
      if (mounted) {
        setState(() {
          // Normalize the values to create a smooth tilt
          _pitch = event.y * 0.05;
          _roll = event.x * 0.05;
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
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _checkHaptics(bool isAccurate) {
    if (isAccurate && !_wasAccurate) {
      HapticFeedback.heavyImpact();
      _wasAccurate = true;
    } else if (!isAccurate && _wasAccurate) {
      _wasAccurate = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final qiblaAsync = ref.watch(qiblaStreamProvider);

    return Scaffold(
      backgroundColor: Colors.black, // Deep black for space effect
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
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
          // 1. Animated Gradient Background (Mystic Deep Space)
          _buildBackground(),
          
          // 2. Main Content
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
                    const Icon(Icons.location_off_rounded, color: Colors.redAccent, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      'تعذر الحصول على الموقع',
                      style: GoogleFonts.amiri(fontSize: 22, color: Colors.white),
                    ),
                    Text(
                      error.toString(),
                      style: GoogleFonts.amiri(fontSize: 14, color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            data: (qiblaData) {
              // Only trigger haptics after initial build to avoid spam
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _checkHaptics(qiblaData.isAccurate);
                }
              });
              
              // Smooth rotation angle using AnimatedRotation
              // Heading gives degrees from North. QiblaDirection gives degrees from North to Mecca.
              // To point to Mecca, we must rotate the needle by (qiblaDirection - heading)
              final diff = qiblaData.qiblaDiff;
              
              // Convert to turns for AnimatedRotation (1 turn = 360 degrees)
              final turns = diff / 360.0;

              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Status text
                    AnimatedOpacity(
                      opacity: qiblaData.isAccurate ? 1.0 : 0.6,
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        qiblaData.isAccurate ? 'أنت في اتجاه القبلة' : 'وجه الهاتف نحو القبلة',
                        style: GoogleFonts.amiri(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: qiblaData.isAccurate ? AppColors.accentGold : Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 60),
                    
                    // Parallax Compass Container
                    Transform(
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001) // perspective
                        ..rotateX(_pitch)
                        ..rotateY(_roll),
                      alignment: Alignment.center,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer glow when accurate
                          if (qiblaData.isAccurate)
                            ScaleTransition(
                              scale: _pulseAnimation,
                              child: Container(
                                width: 320,
                                height: 320,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.accentGold.withValues(alpha: 0.5),
                                      blurRadius: 60,
                                      spreadRadius: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          
                          // Compass Dial Background (Fixed to North)
                          AnimatedRotation(
                            turns: -qiblaData.heading / 360.0,
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutCubic,
                            child: Container(
                              width: 280,
                              height: 280,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF14251D).withValues(alpha: 0.8),
                                border: Border.all(
                                  color: AppColors.accentGold.withValues(alpha: 0.3),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  )
                                ],
                              ),
                              child: CustomPaint(
                                painter: _CompassDialPainter(),
                              ),
                            ),
                          ),
                          
                          // Qibla Indicator (Needle pointing to Mecca)
                          AnimatedRotation(
                            turns: turns,
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutCubic,
                            child: SizedBox(
                              width: 280,
                              height: 280,
                              child: Column(
                                children: [
                                  const SizedBox(height: 20),
                                  // The Arrow / Kaaba Indicator
                                  Icon(
                                    Icons.keyboard_double_arrow_up_rounded,
                                    size: 60,
                                    color: qiblaData.isAccurate ? AppColors.accentGold : Colors.white70,
                                  ),
                                  if (qiblaData.isAccurate)
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.black,
                                        border: Border.all(color: AppColors.accentGold, width: 2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Center(
                                        child: Icon(Icons.mosque_rounded, color: AppColors.accentGold, size: 20),
                                      ),
                                    )
                                ],
                              ),
                            ),
                          ),
                          
                          // Center Hub
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.accentGold,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                )
                              ],
                            ),
                            child: Center(
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
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
          center: Alignment.center,
          radius: 1.5,
          colors: [
            Color(0xFF1B382B), // Deep Islamic Green
            Color(0xFF0F1714),
            Colors.black,
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}

// Custom Painter for intricate Compass Dial
class _CompassDialPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    final paint = Paint()
      ..color = AppColors.accentGold.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
      
    final thickPaint = Paint()
      ..color = AppColors.accentGold.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Draw inner rings
    canvas.drawCircle(center, radius * 0.9, paint);
    canvas.drawCircle(center, radius * 0.7, paint);
    
    // Draw tick marks
    for (int i = 0; i < 360; i += 15) {
      final isMajor = i % 90 == 0;
      final angle = i * math.pi / 180;
      
      final innerRadius = isMajor ? radius * 0.75 : radius * 0.82;
      final outerRadius = radius * 0.9;
      
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
        text: 'N',
        style: GoogleFonts.outfit(
          color: Colors.redAccent,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - radius * 0.65),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
