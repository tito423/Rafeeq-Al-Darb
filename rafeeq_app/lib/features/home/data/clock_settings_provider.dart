import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Digital face or analogue face for the Home card's hero clock.
///
/// The enum *value names* are the SharedPreferences payload, so they are kept
/// exactly as they were when there was only one analogue face — renaming
/// `analogRgb` would silently reset every existing user to the digital clock.
enum ClockStyle {
  /// Digits — one of [DigitalClockFace].
  digital,

  /// An analogue face — one of [AnalogClockFace].
  analogRgb;

  static ClockStyle fromName(String? n) => ClockStyle.values.firstWhere(
        (v) => v.name == n,
        orElse: () => ClockStyle.digital,
      );
}

/// The ten digital faces. Each one is drawn by `digital_clock_faces.dart`
/// from the *same* live `DateTime`, so switching face never changes what the
/// clock says, only how it says it.
enum DigitalClockFace {
  /// Thin, wide-tracked digits — the calmest of the set.
  minimal,

  /// Teal/violet glow behind the digits.
  neon,

  /// A seven-segment LCD, drawn segment by segment.
  segment,

  /// Each digit on its own card, flipping when it changes.
  flip,

  /// Digits filled with the app's teal→gold gradient.
  gradient,

  /// Arabic-Indic digits in the Amiri calligraphy face.
  arabic,

  /// Digits inside a ring that fills with the current minute.
  ring,

  /// Digits over three bars for hour / minute / second progress.
  bars,

  /// A frosted-glass slab behind tabular digits.
  glass,

  /// A dot-matrix rendering — every digit built from a 5x7 grid of dots.
  dots;

  static DigitalClockFace fromName(String? n) =>
      DigitalClockFace.values.firstWhere(
        (v) => v.name == n,
        orElse: () => DigitalClockFace.minimal,
      );

  /// `home.face_<name>` in the translation files.
  String get labelKey => 'home.face_$name';
}

/// The ten analogue faces, drawn by `analog_clock_faces.dart`.
enum AnalogClockFace {
  /// The original: rim and hands travelling through the RGB spectrum.
  rgb,

  /// Cream dial, gold bezel, slim gold hands.
  classicGold,

  /// A hairline circle, four ticks, white hands.
  minimalDark,

  /// A glowing neon ring with matching hands.
  neonRing,

  /// Arabic-Indic numerals (١٢ ٣ ٦ ٩) on a dark dial.
  arabicNumerals,

  /// An eight-point Islamic star as the dial.
  islamicStar,

  /// Three concentric arcs — hour, minute, second — instead of hands.
  skeleton,

  /// A day/night arc with a sun and a moon marker.
  sunMoon,

  /// A soft halo that breathes with the seconds.
  halo,

  /// Sixty ticks tinted along a teal→gold ramp by the current second.
  mosaic;

  static AnalogClockFace fromName(String? n) =>
      AnalogClockFace.values.firstWhere(
        (v) => v.name == n,
        orElse: () => AnalogClockFace.rgb,
      );

  String get labelKey => 'home.face_$name';
}

/// Everything the Home clock needs: which family, which face inside it, and
/// the 12/24-hour and seconds choices that apply across both.
class ClockSettings {
  final ClockStyle style;
  final DigitalClockFace digitalFace;
  final AnalogClockFace analogFace;

  /// True = 1:30 PM, false = 13:30. Independent of [style]: the analogue
  /// faces use it for their own AM/PM marker.
  final bool use12Hour;

  /// Whether the digital clock shows seconds. Off makes for a calmer card;
  /// on is what a "live" clock usually means.
  final bool showSeconds;

  const ClockSettings({
    required this.style,
    required this.digitalFace,
    required this.analogFace,
    required this.use12Hour,
    required this.showSeconds,
  });

  ClockSettings copyWith({
    ClockStyle? style,
    DigitalClockFace? digitalFace,
    AnalogClockFace? analogFace,
    bool? use12Hour,
    bool? showSeconds,
  }) =>
      ClockSettings(
        style: style ?? this.style,
        digitalFace: digitalFace ?? this.digitalFace,
        analogFace: analogFace ?? this.analogFace,
        use12Hour: use12Hour ?? this.use12Hour,
        showSeconds: showSeconds ?? this.showSeconds,
      );
}

class ClockSettingsNotifier extends StateNotifier<ClockSettings> {
  ClockSettingsNotifier()
      : super(const ClockSettings(
          style: ClockStyle.digital,
          digitalFace: DigitalClockFace.minimal,
          analogFace: AnalogClockFace.rgb,
          // 12-hour by default: the prayer chips on the same card already
          // read as "5:12 PM", so a 24-hour clock directly above them was
          // the odd one out.
          use12Hour: true,
          showSeconds: true,
        )) {
    _restore();
  }

  static const _kStyle = 'home_clock_style_v1';
  static const _kDigitalFace = 'home_clock_digital_face_v1';
  static const _kAnalogFace = 'home_clock_analog_face_v1';
  static const _k12h = 'home_clock_12h_v1';
  static const _kSeconds = 'home_clock_seconds_v1';

  Future<void> _restore() async {
    final p = await SharedPreferences.getInstance();
    state = ClockSettings(
      style: ClockStyle.fromName(p.getString(_kStyle)),
      digitalFace: DigitalClockFace.fromName(p.getString(_kDigitalFace)),
      analogFace: AnalogClockFace.fromName(p.getString(_kAnalogFace)),
      use12Hour: p.getBool(_k12h) ?? true,
      showSeconds: p.getBool(_kSeconds) ?? true,
    );
  }

  Future<void> setStyle(ClockStyle s) async {
    state = state.copyWith(style: s);
    (await SharedPreferences.getInstance()).setString(_kStyle, s.name);
  }

  /// Picking a digital face also switches the card to the digital family —
  /// otherwise tapping a face in the gallery would appear to do nothing.
  Future<void> setDigitalFace(DigitalClockFace f) async {
    state = state.copyWith(style: ClockStyle.digital, digitalFace: f);
    final p = await SharedPreferences.getInstance();
    await p.setString(_kDigitalFace, f.name);
    await p.setString(_kStyle, ClockStyle.digital.name);
  }

  Future<void> setAnalogFace(AnalogClockFace f) async {
    state = state.copyWith(style: ClockStyle.analogRgb, analogFace: f);
    final p = await SharedPreferences.getInstance();
    await p.setString(_kAnalogFace, f.name);
    await p.setString(_kStyle, ClockStyle.analogRgb.name);
  }

  Future<void> set12Hour(bool v) async {
    state = state.copyWith(use12Hour: v);
    (await SharedPreferences.getInstance()).setBool(_k12h, v);
  }

  Future<void> setShowSeconds(bool v) async {
    state = state.copyWith(showSeconds: v);
    (await SharedPreferences.getInstance()).setBool(_kSeconds, v);
  }
}

final clockSettingsProvider =
    StateNotifierProvider<ClockSettingsNotifier, ClockSettings>(
        (ref) => ClockSettingsNotifier());
