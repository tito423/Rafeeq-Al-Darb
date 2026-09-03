import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/services/location_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../adhan/presentation/screens/adhan_settings_screen.dart';

/// P3‑16 — a real Qibla compass, the star feature of the new "الصلاة" tab.
/// "روعه بصريا... باحترافية شديدة جدا" (owner: should look genuinely
/// professional, not a placeholder arrow) — built as one clear needle
/// (never rotates the whole dial face, which is harder to read at a
/// glance) pointing at the real great-circle bearing to the Kaaba, offset
/// live by the device's own compass heading, with an honest state for
/// every real-world failure mode (no location permission, no magnetometer
/// on this device) instead of ever faking a direction.
class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

enum _LocationState { loading, denied, ready }

class _QiblaScreenState extends State<QiblaScreen> {
  StreamSubscription<CompassEvent>? _compassSub;

  _LocationState _locationState = _LocationState.loading;
  double? _qiblaBearing; // great-circle bearing from the user to the Kaaba
  double? _heading; // device compass heading, 0-360, 0 = true north
  bool _compassChecked = false;
  bool _hasCompass = true;
  bool _wasAligned = false;

  @override
  void initState() {
    super.initState();
    _resolveLocation();
    _listenCompass();
  }

  @override
  void dispose() {
    _compassSub?.cancel();
    super.dispose();
  }

  Future<void> _resolveLocation() async {
    setState(() => _locationState = _LocationState.loading);
    final pos = await LocationService.instance.getCurrentPosition();
    if (!mounted) return;
    if (pos == null) {
      setState(() => _locationState = _LocationState.denied);
      return;
    }
    setState(() {
      _qiblaBearing = _bearingToKaaba(pos.latitude, pos.longitude);
      _locationState = _LocationState.ready;
    });
  }

  void _listenCompass() {
    final events = FlutterCompass.events;
    if (events == null) {
      setState(() {
        _hasCompass = false;
        _compassChecked = true;
      });
      return;
    }
    // Some devices/emulators register the sensor but never actually emit an
    // event (no real magnetometer) — a short timeout tells the two cases
    // apart instead of showing a spinner forever.
    Timer(const Duration(seconds: 3), () {
      if (mounted && !_compassChecked) {
        setState(() {
          _hasCompass = false;
          _compassChecked = true;
        });
      }
    });
    _compassSub = events.listen((event) {
      if (!mounted || event.heading == null) return;
      if (!_compassChecked) setState(() => _compassChecked = true);
      _hasCompass = true;
      _onHeading(event.heading!);
    });
  }

  void _onHeading(double heading) {
    final bearing = _qiblaBearing;
    var wasAligned = _wasAligned;
    if (bearing != null) {
      final diff = _angleDiff(heading, bearing);
      final aligned = diff.abs() <= 5;
      if (aligned && !_wasAligned) HapticFeedback.mediumImpact();
      wasAligned = aligned;
    }
    setState(() {
      _heading = heading;
      _wasAligned = wasAligned;
    });
  }

  /// Standard great-circle initial bearing formula, from (lat, lon) to the
  /// Kaaba's real published coordinates (21.4225°N, 39.8262°E).
  static double _bearingToKaaba(double lat, double lon) {
    const kaabaLat = 21.4225;
    const kaabaLon = 39.8262;
    final phi1 = lat * math.pi / 180;
    final phi2 = kaabaLat * math.pi / 180;
    final deltaLambda = (kaabaLon - lon) * math.pi / 180;
    final y = math.sin(deltaLambda) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(deltaLambda);
    final theta = math.atan2(y, x);
    return (theta * 180 / math.pi + 360) % 360;
  }

  /// Signed difference in [-180, 180] between two compass bearings.
  static double _angleDiff(double a, double b) {
    var d = (a - b) % 360;
    if (d > 180) d -= 360;
    if (d < -180) d += 360;
    return d;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('nav.prayer'.tr())),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            _buildCompassCard(context),
            const SizedBox(height: 16),
            _AdhanSettingsLink(),
          ],
        ),
      ),
    );
  }

  Widget _buildCompassCard(BuildContext context) {
    if (_locationState == _LocationState.loading) {
      return _StatusCard(
        icon: Icons.explore_outlined,
        message: 'qibla.locating'.tr(),
        showSpinner: true,
      );
    }
    if (_locationState == _LocationState.denied) {
      return _StatusCard(
        icon: Icons.location_off_outlined,
        message: 'qibla.location_needed'.tr(),
        actionLabel: 'qibla.enable_location'.tr(),
        onAction: _resolveLocation,
        secondaryLabel: 'qibla.open_settings'.tr(),
        onSecondary: () => Geolocator.openAppSettings(),
      );
    }
    if (_compassChecked && !_hasCompass) {
      return _StatusCard(
        icon: Icons.sensors_off_outlined,
        message: 'qibla.no_compass'.tr(),
      );
    }
    if (!_compassChecked || _heading == null) {
      return _StatusCard(
        icon: Icons.explore_outlined,
        message: 'qibla.reading_compass'.tr(),
        showSpinner: true,
      );
    }
    return _CompassDial(
      heading: _heading!,
      qiblaBearing: _qiblaBearing!,
      aligned: _wasAligned,
    );
  }
}

/// A single honest status state — loading, permission needed, or no
/// magnetometer — instead of ever showing a fake compass reading.
class _StatusCard extends StatelessWidget {
  final IconData icon;
  final String message;
  final bool showSpinner;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const _StatusCard({
    required this.icon,
    required this.message,
    this.showSpinner = false,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 48),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: scheme.surfaceContainerHighest,
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          if (showSpinner)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: CircularProgressIndicator(color: AppColors.gold),
            )
          else
            Icon(icon, size: 56, color: scheme.onSurfaceVariant),
          const SizedBox(height: 14),
          Text(message, textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14)),
          if (actionLabel != null) ...[
            const SizedBox(height: 18),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
          if (secondaryLabel != null) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: onSecondary, child: Text(secondaryLabel!)),
          ],
        ],
      ),
    );
  }
}

/// The compass itself: a fixed dial face (N/E/S/W never rotate — a single
/// rotating needle is far easier to read at a glance than a spinning
/// dial), a gold-gradient needle pointing at the live Qibla direction, and
/// a glowing "aligned" state once the user is actually facing it.
class _CompassDial extends StatelessWidget {
  final double heading;
  final double qiblaBearing;
  final bool aligned;

  const _CompassDial({
    required this.heading,
    required this.qiblaBearing,
    required this.aligned,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // The needle points at the Qibla relative to which way the device
    // itself is currently facing.
    final needleAngle = (qiblaBearing - heading) * math.pi / 180;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B0F1A), Color(0xFF102A3A), Color(0xFF1B1533)],
        ),
        border: Border.all(
          color: (aligned ? AppColors.success : const Color(0xFF15C7B0))
              .withValues(alpha: aligned ? 0.7 : 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: (aligned ? AppColors.success : AppColors.gold)
                .withValues(alpha: aligned ? 0.28 : 0.12),
            blurRadius: aligned ? 32 : 22,
            spreadRadius: aligned ? 2 : 1,
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: 280,
            height: 280,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(280, 280),
                  painter: _DialPainter(),
                ),
                for (final e in const [
                  (0.0, 'qibla.north'),
                  (90.0, 'qibla.east'),
                  (180.0, 'qibla.south'),
                  (270.0, 'qibla.west'),
                ])
                  Transform.translate(
                    offset: Offset(
                      116 * math.sin(e.$1 * math.pi / 180),
                      -116 * math.cos(e.$1 * math.pi / 180),
                    ),
                    child: Text(
                      e.$2.tr(),
                      style: TextStyle(
                        color: e.$1 == 0
                            ? AppColors.gold
                            : scheme.onSurfaceVariant,
                        fontSize: 13,
                        fontWeight: e.$1 == 0 ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                AnimatedRotation(
                  turns: needleAngle / (2 * math.pi),
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  child: _Needle(aligned: aligned),
                ),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.gold,
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.6),
                          blurRadius: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AnimatedOpacity(
            opacity: aligned ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: AppColors.success, size: 18),
                const SizedBox(width: 6),
                Text('qibla.aligned'.tr(),
                    style: const TextStyle(
                        color: AppColors.success, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${'qibla.bearing_info'.tr()} ${qiblaBearing.round()}°',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

class _Needle extends StatelessWidget {
  final bool aligned;
  const _Needle({required this.aligned});

  @override
  Widget build(BuildContext context) {
    final color = aligned ? AppColors.success : AppColors.gold;
    return SizedBox(
      width: 40,
      height: 220,
      child: Column(
        children: [
          // Kaaba mark at the needle's tip — a plain geometric cube, not a
          // photo/trademarked image, matching this project's "original art
          // only" rule.
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: color, width: 1.4),
            ),
            child: Center(
              child: Container(
                width: 10,
                height: 4,
                color: AppColors.gold,
              ),
            ),
          ),
          Expanded(
            child: CustomPaint(
              size: const Size(16, 190),
              painter: _NeedleShaftPainter(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _NeedleShaftPainter extends CustomPainter {
  final Color color;
  const _NeedleShaftPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [color, color.withValues(alpha: 0.15)],
    );
    final paint = Paint()
      ..shader = gradient.createShader(Rect.fromLTWH(0, 0, w, h));
    final path = Path()
      ..moveTo(w / 2, 0)
      ..lineTo(w, h * 0.14)
      ..lineTo(w * 0.62, h)
      ..lineTo(w * 0.38, h)
      ..lineTo(0, h * 0.14)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _NeedleShaftPainter old) => old.color != color;
}

/// Tick marks every 15°, a heavier mark every 90° — the dial face itself,
/// fixed in place (only the needle rotates).
class _DialPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = AppColors.gold.withValues(alpha: 0.3);
    canvas.drawCircle(center, radius - 4, ring);

    for (var deg = 0; deg < 360; deg += 15) {
      final major = deg % 90 == 0;
      final rad = deg * math.pi / 180;
      final outer = radius - 6;
      final inner = outer - (major ? 14 : 7);
      final p1 = Offset(center.dx + outer * math.sin(rad),
          center.dy - outer * math.cos(rad));
      final p2 = Offset(center.dx + inner * math.sin(rad),
          center.dy - inner * math.cos(rad));
      final tick = Paint()
        ..strokeWidth = major ? 2 : 1
        ..color = AppColors.gold.withValues(alpha: major ? 0.7 : 0.35);
      canvas.drawLine(p1, p2, tick);
    }
  }

  @override
  bool shouldRepaint(covariant _DialPainter oldDelegate) => false;
}

class _AdhanSettingsLink extends StatelessWidget {
  const _AdhanSettingsLink();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.campaign_outlined, color: AppColors.gold),
        title: Text('prayer.adhan_settings'.tr()),
        subtitle: Text('qibla.adhan_settings_hint'.tr(),
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
        trailing: const Icon(Icons.chevron_left),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const AdhanSettingsScreen(),
          ),
        ),
      ),
    );
  }
}
