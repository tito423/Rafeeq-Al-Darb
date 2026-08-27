import 'dart:math' as math;
import 'package:flutter/material.dart';

class AdhanAnimatedBackground extends StatefulWidget {
  final bool isDaytime; // Switch between day and night themes based on prayer
  
  const AdhanAnimatedBackground({super.key, this.isDaytime = true});

  @override
  State<AdhanAnimatedBackground> createState() => _AdhanAnimatedBackgroundState();
}

class _AdhanAnimatedBackgroundState extends State<AdhanAnimatedBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _AdhanBackgroundPainter(
            animationValue: _controller.value,
            isDaytime: widget.isDaytime,
          ),
          child: Container(),
        );
      },
    );
  }
}

class _AdhanBackgroundPainter extends CustomPainter {
  final double animationValue;
  final bool isDaytime;

  _AdhanBackgroundPainter({
    required this.animationValue,
    required this.isDaytime,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Background Gradient
    final Rect rect = Offset.zero & size;
    final Paint bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDaytime
            ? [
                const Color(0xFF1E3C72), // Deep Blue
                const Color(0xFF2A5298), // Lighter Blue
                const Color(0xFFE8CBC0), // Dawn/Dusk tint at bottom
              ]
            : [
                const Color(0xFF0F2027), // Very dark blue/black
                const Color(0xFF203A43), // Dark teal
                const Color(0xFF2C5364), // Muted dark blue
              ],
      ).createShader(rect);
    
    canvas.drawRect(rect, bgPaint);

    // 2. Draw Stars (if night) or Sun Rays (if day)
    final Offset center = Offset(size.width / 2, size.height * 0.35);
    
    if (!isDaytime) {
      _drawStars(canvas, size);
    } else {
      _drawRays(canvas, center, size.width * 1.5);
    }

    // 3. Draw pulsating glowing aura in center
    final double pulse = math.sin(animationValue * math.pi * 8) * 0.1 + 0.9;
    final Paint auraPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          (isDaytime ? Colors.orange.shade200 : Colors.teal.shade200).withOpacity(0.4 * pulse),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.8));
    
    canvas.drawCircle(center, size.width * 0.8, auraPaint);
    
    // 4. Draw Mosque Silhouette at bottom
    _drawMosqueSilhouette(canvas, size);
  }

  void _drawRays(Canvas canvas, Offset center, double radius) {
    final Paint rayPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.fill;

    final int numRays = 12;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(animationValue * math.pi * 2); // Slow rotation

    for (int i = 0; i < numRays; i++) {
      final Path path = Path();
      path.moveTo(0, 0);
      path.lineTo(math.cos(-0.1) * radius, math.sin(-0.1) * radius);
      path.lineTo(math.cos(0.1) * radius, math.sin(0.1) * radius);
      path.close();
      canvas.drawPath(path, rayPaint);
      canvas.rotate((math.pi * 2) / numRays);
    }
    canvas.restore();
  }

  void _drawStars(Canvas canvas, Size size) {
    final Paint starPaint = Paint()..color = Colors.white.withOpacity(0.6);
    final math.Random random = math.Random(42); // Fixed seed for consistent stars

    for (int i = 0; i < 50; i++) {
      final double dx = random.nextDouble() * size.width;
      final double dy = random.nextDouble() * (size.height * 0.6); // Stars only in top 60%
      final double radius = random.nextDouble() * 1.5 + 0.5;
      
      // Add twinkling effect based on animation value
      final double twinkleOffset = random.nextDouble() * math.pi * 2;
      final double opacity = (math.sin(animationValue * math.pi * 10 + twinkleOffset) + 1) / 2;
      
      starPaint.color = Colors.white.withOpacity(0.2 + (0.8 * opacity));
      canvas.drawCircle(Offset(dx, dy), radius, starPaint);
    }
  }

  void _drawMosqueSilhouette(Canvas canvas, Size size) {
    final Paint silhouettePaint = Paint()
      ..color = isDaytime ? const Color(0xFF1A2A4A) : const Color(0xFF0A1118)
      ..style = PaintingStyle.fill;

    final Path path = Path();
    final double baseHeight = size.height * 0.85;
    
    path.moveTo(0, size.height);
    path.lineTo(0, baseHeight);
    
    // Left Dome
    path.quadraticBezierTo(size.width * 0.15, baseHeight - 40, size.width * 0.3, baseHeight);
    
    // Left Minaret
    path.lineTo(size.width * 0.35, baseHeight);
    path.lineTo(size.width * 0.38, baseHeight - 120);
    path.lineTo(size.width * 0.42, baseHeight - 120);
    path.lineTo(size.width * 0.45, baseHeight);
    
    // Main Dome
    path.quadraticBezierTo(size.width * 0.6, baseHeight - 90, size.width * 0.75, baseHeight);
    
    // Right Minaret
    path.lineTo(size.width * 0.8, baseHeight);
    path.lineTo(size.width * 0.83, baseHeight - 100);
    path.lineTo(size.width * 0.87, baseHeight - 100);
    path.lineTo(size.width * 0.9, baseHeight);

    // Right Edge
    path.lineTo(size.width, baseHeight);
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, silhouettePaint);
  }

  @override
  bool shouldRepaint(covariant _AdhanBackgroundPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || 
           oldDelegate.isDaytime != isDaytime;
  }
}
