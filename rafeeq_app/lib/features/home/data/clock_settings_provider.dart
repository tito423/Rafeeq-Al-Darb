import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How the Home card shows the time.
enum ClockStyle {
  /// Digits — the original look.
  digital,

  /// An analogue face whose hands and rim cycle through the RGB spectrum.
  analogRgb;

  static ClockStyle fromName(String? n) => ClockStyle.values.firstWhere(
        (v) => v.name == n,
        orElse: () => ClockStyle.digital,
      );
}

/// Both the style and the 12/24-hour choice for the Home clock.
class ClockSettings {
  final ClockStyle style;

  /// True = 1:30 PM, false = 13:30. Independent of [style]: the analogue face
  /// uses it for its own AM/PM marker.
  final bool use12Hour;

  /// Whether the digital clock shows seconds. Off makes for a calmer card;
  /// on is what a "live" clock usually means.
  final bool showSeconds;

  const ClockSettings({
    required this.style,
    required this.use12Hour,
    required this.showSeconds,
  });

  ClockSettings copyWith({
    ClockStyle? style,
    bool? use12Hour,
    bool? showSeconds,
  }) =>
      ClockSettings(
        style: style ?? this.style,
        use12Hour: use12Hour ?? this.use12Hour,
        showSeconds: showSeconds ?? this.showSeconds,
      );
}

class ClockSettingsNotifier extends StateNotifier<ClockSettings> {
  ClockSettingsNotifier()
      : super(const ClockSettings(
          style: ClockStyle.digital,
          // 12-hour by default: the prayer chips on the same card already
          // read as "5:12 PM", so a 24-hour clock directly above them was
          // the odd one out.
          use12Hour: true,
          showSeconds: true,
        )) {
    _restore();
  }

  static const _kStyle = 'home_clock_style_v1';
  static const _k12h = 'home_clock_12h_v1';
  static const _kSeconds = 'home_clock_seconds_v1';

  Future<void> _restore() async {
    final p = await SharedPreferences.getInstance();
    state = ClockSettings(
      style: ClockStyle.fromName(p.getString(_kStyle)),
      use12Hour: p.getBool(_k12h) ?? true,
      showSeconds: p.getBool(_kSeconds) ?? true,
    );
  }

  Future<void> setStyle(ClockStyle s) async {
    state = state.copyWith(style: s);
    (await SharedPreferences.getInstance()).setString(_kStyle, s.name);
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
