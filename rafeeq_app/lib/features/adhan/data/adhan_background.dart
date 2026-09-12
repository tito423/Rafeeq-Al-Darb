/// «خلفيات شاشة الأذان» — the ten painted grounds the adhan screen can wear.
///
/// Painted, not filmed. The clips this app used to ship were 640×360 upscaled
/// 6.7× on a 1080×2400 phone (trap #37), twenty seconds long under a
/// four-minute adhan so they visibly looped a dozen times, and somebody else's
/// licence. A painter has none of those problems: it is resolution
/// independent, weighs nothing, and its motion is driven by a clock that
/// counts thirty minutes, so no period is short enough to read as a repeat.
///
/// Each style is a BACKGROUND. The mosque silhouette and the rings that leave
/// its minaret on every phrase of the adhan stay on top of all ten, because
/// that synchronisation is the point of the screen and not a decoration.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AdhanBackground {
  /// The original: a plain graded sky with stars. The default, because it is
  /// the quietest thing to lay white text over.
  horizon,

  /// A girih lattice — the interlacing ten-point strapwork of Seljuk and
  /// Timurid tilework — drifting slowly across the sky.
  girih,

  /// Rub' al-hizb medallions, turning at different rates.
  medallions,

  /// Arabesque vines growing and receding.
  arabesque,

  /// Tiers of muqarnas niches with light travelling across them.
  muqarnas,

  /// Fanous lanterns rising through the dark.
  lanterns,

  /// A field of eight-point khatim stars, breathing.
  khatim,

  /// Layered crescents drifting past one another.
  crescents,

  /// Wide calligraphic ribbons crossing the sky.
  ribbons,

  /// Concentric dome outlines rippling outward from the horizon.
  domes;

  /// The i18n key for this style's name.
  String get nameKey => 'adhan.bg_$name';
}

/// Which ground the adhan screen wears. Persisted, because it is a choice
/// about how the app looks and those do not survive a restart by accident.
class AdhanBackgroundSetting extends StateNotifier<AdhanBackground> {
  AdhanBackgroundSetting() : super(AdhanBackground.horizon) {
    _restore();
  }

  static const _key = 'adhan.background_v1';

  /// Reads the stored choice WITHOUT Riverpod.
  ///
  /// The full-screen adhan alert runs in its own Flutter engine
  /// (`adhan_entry.dart`) with no `ProviderScope` above it, so the screen that
  /// most needs this setting is the one place a provider cannot be read. This
  /// is the seam both engines share.
  static Future<AdhanBackground> read() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    for (final b in AdhanBackground.values) {
      if (b.name == stored) return b;
    }
    return AdhanBackground.horizon;
  }

  Future<void> _restore() async {
    state = await read();
  }

  Future<void> set(AdhanBackground value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, value.name);
  }
}

final adhanBackgroundProvider =
    StateNotifierProvider<AdhanBackgroundSetting, AdhanBackground>(
        (ref) => AdhanBackgroundSetting());
