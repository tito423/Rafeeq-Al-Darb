import 'dart:math';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class QiblaParticles extends StatefulWidget {
  const QiblaParticles({super.key});

  @override
  State<QiblaParticles> createState() => _QiblaParticlesState();
}

class _QiblaParticlesState extends State<QiblaParticles> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..addListener(() {
        _updateParticles();
        setState(() {});
      })
      ..repeat();

    // Initialize 60 particles
    for (int i = 0; i < 60; i++) {
      _particles.add(_generateParticle());
    }
  }

  _Particle _generateParticle() {
    return _Particle(
      x: _random.nextDouble(),
      y: _random.nextDouble(),
      speed: _random.nextDouble() * 0.002 + 0.0005,
      size: _random.nextDouble() * 3 + 1,
      opacity: _random.nextDouble() * 0.5 + 0.1,
      angle: _random.nextDouble() * 2 * pi,
      angleSpeed: (_random.nextDouble() - 0.5) * 0.02,
    );
  }

  void _updateParticles() {
    for (int i = 0; i < _particles.length; i++) {
      var p = _particles[i];
      // Drift upward and drift horizontally based on angle
      p.y -= p.speed;
      p.x += sin(p.angle) * (p.speed * 0.5);
      p.angle += p.angleSpeed;
      
      // Pulse opacity
      p.opacity += (sin(_controller.value * 2 * pi * 10 + i) * 0.01);
      p.opacity = p.opacity.clamp(0.1, 0.8);

      // Reset if out of bounds
      if (p.y < -0.1 || p.x < -0.1 || p.x > 1.1) {
        _particles[i] = _generateParticle()..y = 1.1; // reset to bottom
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _ParticlePainter(_particles),
    );
  }
}

class _Particle {
  double x;
  double y;
  double speed;
  double size;
  double opacity;
  double angle;
  double angleSpeed;

  _Particle({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.opacity,
    required this.angle,
    required this.angleSpeed,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;

  _ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    for (var p in particles) {
      paint.color = AppColors.accentGold.withValues(alpha: p.opacity);
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
