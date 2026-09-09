import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/rafeeq_app.dart' show sharedPrefsProvider;

/// A decorative border drawn around the text mushaf's page.
///
/// Ten styles, all **painted** rather than fetched or bundled as images, for
/// the same three reasons the rest of the app's ornament is painted: it costs
/// no bytes and no network, it is sharp at any page size and any screen
/// density, and — the one that matters most here — it takes its colour from
/// the active mushaf theme instead of being a fixed picture that only looks
/// right on one paper.
enum MushafFrameStyle {
  /// No border. The default, and the way back to a plain page.
  none,

  /// A chain of eight-point khātim stars along the band.
  khatim,

  /// Two rules with a woven arabesque running between them.
  arabesque,

  /// Interlocking hexagons — the girih family.
  geometric,

  /// A mihrab arch at the head of the page, plain rules elsewhere.
  mihrab,

  /// A zellij band of alternating squares set on point.
  zellij,

  /// Stepped muqarnas corners over a thin rule.
  muqarnas,

  /// A double gold rule with a rosette at each corner — the plainest of the
  /// ten, and the one that stays out of the way of long reading.
  doubleRule,

  /// Corner florets only, no band; the lightest possible framing.
  cornerFloret,

  /// An interlaced rope/chain band.
  chain;

  String get labelKey => 'mushaf_frame.$name';
}

/// A colour for the frame, independent of the theme's own gold.
///
/// «follow» is the default and the one that guarantees the coherence the
/// owner asked for: the border is drawn in the active theme's own accent, so
/// no combination can clash. The named accents are there for when he wants a
/// deliberate contrast, and each was picked to sit on both a light paper and
/// a dark one.
enum MushafFrameAccent {
  follow,
  gold,
  emerald,
  turquoise,
  sapphire,
  ruby,
  amethyst,
  copper,
  ivory,
  ink,
  rose;

  String get labelKey => 'mushaf_frame_accent.$name';

  /// Null for [follow] — the caller substitutes the theme's own accent.
  Color? get color => switch (this) {
        MushafFrameAccent.follow => null,
        MushafFrameAccent.gold => const Color(0xFFC8A951),
        MushafFrameAccent.emerald => const Color(0xFF1F8A5F),
        MushafFrameAccent.turquoise => const Color(0xFF17A2A2),
        MushafFrameAccent.sapphire => const Color(0xFF2F6FBF),
        MushafFrameAccent.ruby => const Color(0xFFB33A48),
        MushafFrameAccent.amethyst => const Color(0xFF7B5EA7),
        MushafFrameAccent.copper => const Color(0xFFB4703A),
        MushafFrameAccent.ivory => const Color(0xFFCFC3A4),
        MushafFrameAccent.ink => const Color(0xFF4A5568),
        MushafFrameAccent.rose => const Color(0xFFC2707C),
      };
}

const _kStyleKey = 'mushaf_frame_style_v1';
const _kAccentKey = 'mushaf_frame_accent_v1';

/// The frame the text mushaf draws, persisted.
class MushafFrameSettings {
  final MushafFrameStyle style;
  final MushafFrameAccent accent;

  const MushafFrameSettings({
    this.style = MushafFrameStyle.none,
    this.accent = MushafFrameAccent.follow,
  });

  MushafFrameSettings copyWith({
    MushafFrameStyle? style,
    MushafFrameAccent? accent,
  }) =>
      MushafFrameSettings(
        style: style ?? this.style,
        accent: accent ?? this.accent,
      );
}

class MushafFrameController extends StateNotifier<MushafFrameSettings> {
  MushafFrameController(this._prefs)
      : super(MushafFrameSettings(
          style: _readStyle(_prefs),
          accent: _readAccent(_prefs),
        ));

  final SharedPreferences _prefs;

  static MushafFrameStyle _readStyle(SharedPreferences p) {
    final v = p.getString(_kStyleKey);
    return MushafFrameStyle.values.firstWhere(
      (s) => s.name == v,
      orElse: () => MushafFrameStyle.none,
    );
  }

  static MushafFrameAccent _readAccent(SharedPreferences p) {
    final v = p.getString(_kAccentKey);
    return MushafFrameAccent.values.firstWhere(
      (a) => a.name == v,
      orElse: () => MushafFrameAccent.follow,
    );
  }

  Future<void> setStyle(MushafFrameStyle s) async {
    state = state.copyWith(style: s);
    await _prefs.setString(_kStyleKey, s.name);
  }

  Future<void> setAccent(MushafFrameAccent a) async {
    state = state.copyWith(accent: a);
    await _prefs.setString(_kAccentKey, a.name);
  }
}

final mushafFrameProvider =
    StateNotifierProvider<MushafFrameController, MushafFrameSettings>(
  (ref) => MushafFrameController(ref.watch(sharedPrefsProvider)),
);
