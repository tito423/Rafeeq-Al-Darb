import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../app/app_locale_provider.dart';
import '../../../../app/shell/tab_request_provider.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/manual_location.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/hero_surface.dart';
import '../../../../core/utils/digits.dart';
import '../../../../core/widgets/two_pane_scroll.dart';
import '../../../adhan/presentation/screens/adhan_settings_screen.dart';
import '../../../adhan/presentation/screens/prayer_adjustments_screen.dart';
import '../../../tutorial/data/tutorial_anchors.dart';

/// P3‑16 — a real Qibla compass, the star feature of the new "الصلاة" tab.
/// "روعه بصريا... باحترافية شديدة جدا" (owner: should look genuinely
/// professional, not a placeholder arrow) — built as one clear needle
/// (never rotates the whole dial face, which is harder to read at a
/// glance) pointing at the real great-circle bearing to the Kaaba, offset
/// live by the device's own compass heading, with an honest state for
/// every real-world failure mode (no location permission, no magnetometer
/// on this device) instead of ever faking a direction.
class QiblaScreen extends ConsumerStatefulWidget {
  const QiblaScreen({super.key});

  @override
  ConsumerState<QiblaScreen> createState() => _QiblaScreenState();
}

enum _LocationState { loading, denied, ready }

class _QiblaScreenState extends ConsumerState<QiblaScreen>
    with WidgetsBindingObserver {
  StreamSubscription<CompassEvent>? _compassSub;

  /// P3‑47: only true while the Prayer tab is actually on screen and the app
  /// is in the foreground. The compass alignment haptic + `setState` loop is
  /// gated on this so the kept-alive Prayer tab never buzzes/spins in the
  /// background — the "random haptic" the owner couldn't source.
  bool _screenActive = true;

  /// The route this screen is on. When another screen is pushed over it -
  /// adhan settings, prayer adjustments, any sheet - it is no longer the
  /// current route and the compass must stop buzzing, even though the tab
  /// and the app are both still "active" (owner, 2026-09-29: «لما بكون فاتح
  /// اعدادات … بتفضل البوصلة تعمل هزة في الخلفية»).
  ModalRoute<dynamic>? _route;

  _LocationState _locationState = _LocationState.loading;
  double? _qiblaBearing; // great-circle bearing from the user to the Kaaba
  double? _heading; // device compass heading, 0-360, 0 = true north
  bool _compassChecked = false;
  bool _hasCompass = true;
  bool _wasAligned = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ManualLocationStore.instance.changes.addListener(_resolveLocation);
    _resolveLocation();
    _listenCompass();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ManualLocationStore.instance.changes.removeListener(_resolveLocation);
    _compassSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause the compass work (and its haptic) whenever the app leaves the
    // foreground — the sensor stream would otherwise keep firing while the
    // app is backgrounded.
    _screenActive = state == AppLifecycleState.resumed && _isPrayerTabActive();
  }

  bool _isPrayerTabActive() => ref.read(activeTabProvider) == AppTab.prayer;

  Future<void> _resolveLocation() async {
    if (!mounted) return;
    setState(() => _locationState = _LocationState.loading);
    // The Qibla shows no city name, but it shares the location cache with
    // the prayer card - so it must ask in the same language, or it
    // rewrites the cached city in a language nobody picked.
    final pos = await LocationService.instance.getCurrentPosition(
      localeCode: ref.read(appLocaleProvider),
    );
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
    // P3‑47: skip everything (haptic + rebuild) unless the Prayer tab is
    // actually on screen and the app is foregrounded — the compass stream
    // keeps emitting from the kept-alive tab otherwise.
    if (!_screenActive) return;
    // Covered by another screen: no haptic, no rebuild.
    if (!(_route?.isCurrent ?? true)) return;
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
    const phi2 = kaabaLat * math.pi / 180;
    final deltaLambda = (kaabaLon - lon) * math.pi / 180;
    final y = math.sin(deltaLambda) * math.cos(phi2);
    final x =
        math.cos(phi1) * math.sin(phi2) -
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
    // Track whether this tab is the one on screen; combined with the app
    // being foregrounded, this drives whether the compass does any work.
    final tabActive = ref.watch(activeTabProvider) == AppTab.prayer;
    _screenActive =
        tabActive &&
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    return Scaffold(
      appBar: AppBar(title: Text('nav.prayer'.tr())),
      body: SafeArea(
        // Sideways: the compass on one side, its settings on the other.
        child: TwoPaneScroll(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          gap: 14,
          start: [
            TutorialAnchor(
              id: TourAnchor.qiblaCompass,
              child: _buildCompassCard(context),
            ),
          ],
          end: [
            const TutorialAnchor(
              id: TourAnchor.adhanSettings,
              child: _AdhanSettingsLink(),
            ),
            const TutorialAnchor(
              id: TourAnchor.prayerAdjustments,
              child: _PrayerAdjustmentsLink(),
            ),
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
        // LocationService never prompts on its own any more, so the tap
        // asks (and opens the location switch when it is off).
        onAction: () async {
          if (await LocationService.instance.askToEnable()) {
            await _resolveLocation();
          }
        },
        secondaryLabel: 'qibla.open_settings'.tr(),
        onSecondary: Geolocator.openAppSettings,
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
        border: Border.all(color: goldOn(scheme).withValues(alpha: 0.35)),
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
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
          ),
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

    // «خلي كارت القبلة مطابق لثيم التطبيق مع اختيار الألوان المناسبة». The
    // card was a fixed near-black gradient on every theme, so on the light
    // theme it sat as a dark slab on a pale page. It takes the app's hero
    // surface now — the same ground the home cards and the card screens use —
    // with the compass accent adjusted for it.
    final surface = HeroSurface.of(context);
    // Sideways the dial is sized to the screen's height, so the whole card -
    // dial, the aligned mark and the bearing - is on screen without scrolling.
    final sideways = TwoPaneScroll.isSideways(context);
    final dial = sideways
        ? math.min(280.0, MediaQuery.sizeOf(context).height * 0.5)
        : 280.0;
    return Container(
      padding: EdgeInsets.symmetric(vertical: sideways ? 14 : 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: surface.gradient,
        ),
        border: Border.all(
          color:
              (aligned
                      ? AppColors.success
                      : surface.accent(const Color(0xFF15C7B0)))
                  .withValues(alpha: aligned ? 0.7 : 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: (aligned ? AppColors.success : AppColors.gold).withValues(
              alpha: aligned ? 0.28 : 0.12,
            ),
            blurRadius: aligned ? 32 : 22,
            spreadRadius: aligned ? 2 : 1,
          ),
        ],
      ),
      child: Column(
        children: [
          // Scaled down, never clipped: the dial is drawn for 280 and a
          // narrow phone at a large display size has less than that inside
          // this card.
          SizedBox(
            height: dial,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: 280,
                height: 280,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(280, 280),
                      painter: _DialPainter(goldOn(scheme)),
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
                                ? goldOn(scheme)
                                : scheme.onSurfaceVariant,
                            fontSize: 13,
                            fontWeight: e.$1 == 0
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    AnimatedRotation(
                      turns: needleAngle / (2 * math.pi),
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      child: _Needle(aligned: aligned, angle: needleAngle),
                    ),
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: goldOn(scheme),
                        boxShadow: [
                          BoxShadow(
                            color: goldOn(scheme).withValues(alpha: 0.6),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: sideways ? 10 : 20),
          AnimatedOpacity(
            opacity: aligned ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  'qibla.aligned'.tr(),
                  style: const TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            localizeDigits(
              '${'qibla.bearing_info'.tr()} ${qiblaBearing.round()}°',
              context.locale.languageCode,
            ),
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

class _Needle extends StatelessWidget {
  final bool aligned;

  /// The needle's own rotation, so the Kaaba at its tip can be turned back
  /// by the same amount and always stand upright.
  final double angle;
  const _Needle({required this.aligned, required this.angle});

  @override
  Widget build(BuildContext context) {
    final color = aligned ? AppColors.success : AppColors.gold;
    return SizedBox(
      width: 48,
      height: 220,
      child: Column(
        children: [
          // «العلامة اللي تودي لها ابره البوصله … تبقى الكعبه الشريفه وتبقى
          // انيميتد» (owner, 2026-10-07). Drawn here, not a photograph -
          // original art only. Counter-rotated: the needle turns, the Kaaba
          // stays upright the way it stands.
          AnimatedRotation(
            turns: -angle / (2 * math.pi),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: _KaabaMark(aligned: aligned),
          ),
          Expanded(
            child: CustomPaint(
              size: const Size(16, 180),
              painter: _NeedleShaftPainter(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// The Kaaba at the needle's tip: a black cube seen a little from above
/// and to the side, the kiswa's gold band round it and the gold door on
/// its face. Alive in two slow ways - a glint that travels along the band
/// and a halo that breathes behind it, green once the phone faces the
/// Qibla.
class _KaabaMark extends StatefulWidget {
  final bool aligned;
  const _KaabaMark({required this.aligned});

  @override
  State<_KaabaMark> createState() => _KaabaMarkState();
}

class _KaabaMarkState extends State<_KaabaMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => CustomPaint(
            painter: _KaabaPainter(t: _c.value, aligned: widget.aligned),
          ),
        ),
      ),
    );
  }
}

class _KaabaPainter extends CustomPainter {
  final double t;
  final bool aligned;
  const _KaabaPainter({required this.t, required this.aligned});

  static const _gold = Color(0xFFD4AF37);
  static const _goldDeep = Color(0xFF9C7A1E);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 40;
    canvas.save();
    canvas.scale(s);

    // Halo: breathes in and out once per cycle.
    final breath = 0.5 - 0.5 * math.cos(t * 2 * math.pi);
    final halo = aligned ? AppColors.success : _gold;
    canvas.drawCircle(
      const Offset(20, 21),
      15 + 3 * breath,
      Paint()
        ..color = halo.withValues(alpha: 0.18 + 0.22 * breath)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );

    // The cube: front face, side face, roof.
    const fl = 6.0, fr = 26.0, ft = 12.0, fb = 34.0; // front face
    const dx = 8.0, dy = -5.0; // depth of the side and roof
    const front = Rect.fromLTRB(fl, ft, fr, fb);
    final side = Path()
      ..moveTo(fr, ft)
      ..lineTo(fr + dx, ft + dy)
      ..lineTo(fr + dx, fb + dy)
      ..lineTo(fr, fb)
      ..close();
    final roof = Path()
      ..moveTo(fl, ft)
      ..lineTo(fl + dx, ft + dy)
      ..lineTo(fr + dx, ft + dy)
      ..lineTo(fr, ft)
      ..close();
    canvas.drawRect(front, Paint()..color = const Color(0xFF111111));
    canvas.drawPath(side, Paint()..color = const Color(0xFF242424));
    canvas.drawPath(roof, Paint()..color = const Color(0xFF3A3A3A));

    // The kiswa's band, a third of the way down, round both faces.
    const by = 17.0, bh = 3.2;
    final glint = (t * 1.6) - 0.3; // sweeps left to right, then rests
    final band = LinearGradient(
      colors: const [_goldDeep, _gold, Color(0xFFFFF2B8), _gold, _goldDeep],
      stops: [
        0,
        (glint - 0.18).clamp(0.0, 1.0),
        glint.clamp(0.0, 1.0),
        (glint + 0.18).clamp(0.0, 1.0),
        1,
      ],
    ).createShader(const Rect.fromLTRB(fl, 0, fr + dx, 1));
    final bandPaint = Paint()..shader = band;
    canvas.drawRect(const Rect.fromLTRB(fl, by, fr, by + bh), bandPaint);
    final sideBand = Path()
      ..moveTo(fr, by)
      ..lineTo(fr + dx, by + dy)
      ..lineTo(fr + dx, by + dy + bh)
      ..lineTo(fr, by + bh)
      ..close();
    canvas.drawPath(sideBand, bandPaint);

    // The door: raised off the ground, near the corner of the face.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(17.5, 23, 22.5, 31),
        const Radius.circular(0.8),
      ),
      Paint()..color = _gold,
    );
    canvas.drawLine(
      const Offset(20, 23.6),
      const Offset(20, 30.4),
      Paint()
        ..color = _goldDeep
        ..strokeWidth = 0.6,
    );

    // A fine gold edge on the near corner so the cube reads on a dark dial.
    canvas.drawLine(
      const Offset(fr, ft),
      const Offset(fr, fb),
      Paint()
        ..color = _gold.withValues(alpha: 0.55)
        ..strokeWidth = 0.7,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_KaabaPainter old) => old.t != t || old.aligned != aligned;
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
  /// The dial is drawn on a card that follows the theme, so its gold has to
  /// as well — flat gold measures ~2 : 1 on the light ground.
  final Color accent;

  const _DialPainter(this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = accent.withValues(alpha: 0.45);
    canvas.drawCircle(center, radius - 4, ring);

    for (var deg = 0; deg < 360; deg += 15) {
      final major = deg % 90 == 0;
      final rad = deg * math.pi / 180;
      final outer = radius - 6;
      final inner = outer - (major ? 14 : 7);
      final p1 = Offset(
        center.dx + outer * math.sin(rad),
        center.dy - outer * math.cos(rad),
      );
      final p2 = Offset(
        center.dx + inner * math.sin(rad),
        center.dy - inner * math.cos(rad),
      );
      final tick = Paint()
        ..strokeWidth = major ? 2 : 1
        ..color = accent.withValues(alpha: major ? 0.85 : 0.45);
      canvas.drawLine(p1, p2, tick);
    }
  }

  @override
  bool shouldRepaint(covariant _DialPainter oldDelegate) =>
      oldDelegate.accent != accent;
}

/// Sits directly under the Adhan-settings card: everything that decides *when*
/// a prayer is, as opposed to how it is announced.
class _PrayerAdjustmentsLink extends StatelessWidget {
  const _PrayerAdjustmentsLink();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: Icon(Icons.tune_rounded, color: goldText(context)),
        title: Text('prayer.adjustments'.tr()),
        subtitle: Text(
          'prayer.adjustments_hint'.tr(),
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const PrayerAdjustmentsScreen(),
          ),
        ),
      ),
    );
  }
}

class _AdhanSettingsLink extends StatelessWidget {
  const _AdhanSettingsLink();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: Icon(Icons.campaign_outlined, color: goldText(context)),
        title: Text('prayer.adhan_settings'.tr()),
        subtitle: Text(
          'qibla.adhan_settings_hint'.tr(),
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AdhanSettingsScreen()),
        ),
      ),
    );
  }
}
