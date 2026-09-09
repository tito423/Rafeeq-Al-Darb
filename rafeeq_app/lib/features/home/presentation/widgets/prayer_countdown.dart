import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

import '../../../../core/theme/hero_surface.dart';

/// The live countdown to the next prayer, on the Home clock card.
///
/// It used to be a static line rebuilt only when the card happened to rebuild:
/// «المتبقي: 8س 16د». The owner asked for a real counter — «غيّر صيغة عرض
/// الزمن ده لعداد تنازلي بالساعات والدقايق والثواني وخليه أنيميتد برضه
/// وألوانه متناسقة مع الثيم المختار».
///
/// So: one `Timer` on the second, three units, and each unit's digits swap
/// through an `AnimatedSwitcher` that slides the old value up and the new one
/// in behind it — the seconds visibly tick, the minutes roll over once a
/// minute, and nothing jumps. Colours come from [HeroSurface] and the prayer's
/// own accent, both of which follow the selected theme.
///
/// The hours box disappears once there is less than an hour left rather than
/// showing a dead «0س», and the whole row is laid out left-to-right in every
/// locale: h:m:s is a clock reading, and mirroring it in Arabic would put the
/// seconds where the reader looks for hours.
class PrayerCountdown extends StatefulWidget {
  /// When the next prayer starts.
  final DateTime target;

  /// That prayer's colour, before [HeroSurface.accent] tones it for the
  /// current ground.
  final Color accent;

  /// Arabic-Indic digits, matching the clock face above it.
  final bool arabicDigits;

  const PrayerCountdown({
    super.key,
    required this.target,
    required this.accent,
    required this.arabicDigits,
  });

  @override
  State<PrayerCountdown> createState() => _PrayerCountdownState();
}

class _PrayerCountdownState extends State<PrayerCountdown> {
  Timer? _timer;
  late Duration _left;

  @override
  void initState() {
    super.initState();
    _left = _remaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _left = _remaining());
    });
  }

  @override
  void didUpdateWidget(PrayerCountdown old) {
    super.didUpdateWidget(old);
    if (widget.target != old.target) _left = _remaining();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Duration _remaining() {
    final diff = widget.target.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  @override
  Widget build(BuildContext context) {
    final hero = HeroSurface.of(context);
    final accent = hero.accent(widget.accent);
    final hours = _left.inHours;
    final minutes = _left.inMinutes % 60;
    final seconds = _left.inSeconds % 60;

    return Directionality(
      // A clock reading, not a sentence: hours on the left in every language.
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (hours > 0) ...[
            _Unit(
              value: hours,
              unit: 'home.hours_short'.tr(),
              accent: accent,
              hero: hero,
              arabicDigits: widget.arabicDigits,
              // Only the seconds need to be two digits at all times; an hour
              // count of 8 should not read «08».
              pad: false,
            ),
            _Separator(hero: hero),
          ],
          _Unit(
            value: minutes,
            unit: 'home.minutes_short'.tr(),
            accent: accent,
            hero: hero,
            arabicDigits: widget.arabicDigits,
            pad: hours > 0,
          ),
          _Separator(hero: hero),
          _Unit(
            value: seconds,
            unit: 'home.seconds_short'.tr(),
            accent: accent,
            hero: hero,
            arabicDigits: widget.arabicDigits,
            pad: true,
          ),
        ],
      ),
    );
  }
}

/// One number-and-unit box. The number is the animated part.
class _Unit extends StatelessWidget {
  final int value;
  final String unit;
  final Color accent;
  final HeroSurface hero;
  final bool arabicDigits;
  final bool pad;

  const _Unit({
    required this.value,
    required this.unit,
    required this.accent,
    required this.hero,
    required this.arabicDigits,
    required this.pad,
  });

  static const _arabicIndic = '٠١٢٣٤٥٦٧٨٩';

  String get _text {
    final raw = pad ? value.toString().padLeft(2, '0') : value.toString();
    if (!arabicDigits) return raw;
    return raw.split('').map((c) => _arabicIndic[int.parse(c)]).join();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          // The outgoing value rises and fades while the incoming one comes
          // up from below: a roll, not a blink.
          transitionBuilder: (child, animation) {
            final incoming = child.key == ValueKey<String>(_text);
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: Offset(0, incoming ? 0.45 : -0.45),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.center,
            children: [...previous, ?current],
          ),
          child: Text(
            _text,
            key: ValueKey<String>(_text),
            style: TextStyle(
              color: accent,
              fontSize: 19,
              height: 1.05,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        Text(
          unit,
          style: TextStyle(
            color: hero.onSurfaceFaint,
            fontSize: 9,
            height: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// The colon between two units, sitting on the digits' baseline rather than
/// the box's centre so it does not float above the unit labels.
class _Separator extends StatelessWidget {
  final HeroSurface hero;
  const _Separator({required this.hero});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11, left: 5, right: 5),
      child: Text(
        ':',
        style: TextStyle(
          color: hero.onSurfaceFaint,
          fontSize: 17,
          height: 1.05,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
