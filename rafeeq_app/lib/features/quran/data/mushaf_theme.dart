import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/rafeeq_app.dart' show sharedPrefsProvider;

/// A full colour scheme for the **text** mushaf.
///
/// Before this the text mushaf had exactly two looks — cream paper in light
/// mode, navy in dark — derived straight from `Theme.of(context).brightness`.
/// The owner asked for ten, «مع مراعاه تظليل الايات», and that second half is
/// the part that makes this a model rather than two colours: a highlight that
/// reads correctly on cream is invisible on charcoal, so every theme carries
/// **its own** highlight colours instead of one global tint applied over
/// whatever ground happens to be underneath.
@immutable
class MushafTheme {
  final String id;

  /// Translation key for the name shown in the picker.
  final String labelKey;

  /// The page itself.
  final Color paper;

  /// The Qur'an text.
  final Color ink;

  /// Ayah-number medallions, surah banners, ornament.
  final Color gold;

  /// The verse the reader selected.
  final Color highlight;

  /// The verse currently being recited. Deliberately distinct from
  /// [highlight]: during playback both can be on screen at once, and if they
  /// were the same colour the reader could not tell which verse the voice is
  /// on.
  final Color highlightPlaying;

  /// Text drawn *on* [highlightPlaying]. Some grounds need the ink to flip to
  /// stay legible under the highlight — which is exactly the case a single
  /// global highlight colour gets wrong.
  final Color inkOnHighlight;

  /// Whether this theme is a light one. Drives the status-bar icon
  /// brightness and the surah banner's contrast.
  final bool isLight;

  const MushafTheme({
    required this.id,
    required this.labelKey,
    required this.paper,
    required this.ink,
    required this.gold,
    required this.highlight,
    required this.highlightPlaying,
    required this.inkOnHighlight,
    required this.isLight,
  });
}

/// The ten themes.
///
/// Each pair was chosen for contrast on the actual page, not for the swatch:
/// the Qur'an text is fine-stroked naskh at ~24px, which needs more contrast
/// than UI text does, so none of these is a low-contrast "aesthetic" pairing.
///
/// **Every combination here is measured, not eyeballed.** The recited-verse
/// highlight is a translucent wash, so what the reader actually sees is the
/// wash composited over that theme's own paper — and on a dark paper the
/// result stays dark however bright the wash colour looks in isolation. Three
/// themes (charcoal, azure, emerald) first shipped with dark ink on that
/// composite and measured 2.6 : 1, 2.3 : 1 and 2.6 : 1 — well under the 4.5 : 1
/// floor. They carry light ink for that reason, not for taste. If you change
/// a colour here, recompute the composite and its contrast ratio before
/// trusting it.
const mushafThemes = <MushafTheme>[
  // 1 — the app's original light page.
  MushafTheme(
    id: 'classic',
    labelKey: 'mushaf_theme.classic',
    paper: Color(0xFFF8F4E9),
    ink: Color(0xFF241C0E),
    gold: Color(0xFFB08D2A),
    highlight: Color(0x3316A085),
    highlightPlaying: Color(0x59D4AF37),
    inkOnHighlight: Color(0xFF241C0E),
    isLight: true,
  ),
  // 2 — the app's original dark page.
  MushafTheme(
    id: 'night',
    labelKey: 'mushaf_theme.night',
    paper: Color(0xFF10293F),
    ink: Color(0xFFEFE6D0),
    gold: Color(0xFFD4AF37),
    highlight: Color(0x4D16A085),
    highlightPlaying: Color(0x66D4AF37),
    inkOnHighlight: Color(0xFFFFF8E7),
    isLight: false,
  ),
  // 3 — aged paper, the closest to a printed mushaf under a reading lamp.
  MushafTheme(
    id: 'sepia',
    labelKey: 'mushaf_theme.sepia',
    paper: Color(0xFFEFE0C4),
    ink: Color(0xFF3B2A15),
    gold: Color(0xFF97701C),
    highlight: Color(0x3D8A6A1C),
    highlightPlaying: Color(0x66C79A2E),
    inkOnHighlight: Color(0xFF2A1D0C),
    isLight: true,
  ),
  // 4 — the Madinah mushaf's own pale green stock.
  MushafTheme(
    id: 'madinah',
    labelKey: 'mushaf_theme.madinah',
    paper: Color(0xFFE7F0E4),
    ink: Color(0xFF13301F),
    gold: Color(0xFF1F7A4C),
    highlight: Color(0x331F7A4C),
    highlightPlaying: Color(0x5C2E9D6F),
    inkOnHighlight: Color(0xFF0C2415),
    isLight: true,
  ),
  // 5 — near-black, for reading in the dark without a blue cast.
  MushafTheme(
    id: 'charcoal',
    labelKey: 'mushaf_theme.charcoal',
    paper: Color(0xFF121212),
    ink: Color(0xFFEDE4D3),
    gold: Color(0xFFC8A951),
    highlight: Color(0x4DC8A951),
    highlightPlaying: Color(0x66E0BE5E),
    inkOnHighlight: Color(0xFFFFF3D6),
    isLight: false,
  ),
  // 6 — deep blue night.
  MushafTheme(
    id: 'azure',
    labelKey: 'mushaf_theme.azure',
    paper: Color(0xFF0B1A2E),
    ink: Color(0xFFD8E6F5),
    gold: Color(0xFF77B7E8),
    highlight: Color(0x4D2F80A9),
    highlightPlaying: Color(0x6653A6D8),
    inkOnHighlight: Color(0xFFEAF4FF),
    isLight: false,
  ),
  // 7 — emerald ground with gold text; the illuminated-manuscript look.
  MushafTheme(
    id: 'emerald',
    labelKey: 'mushaf_theme.emerald',
    paper: Color(0xFF07281C),
    ink: Color(0xFFF0E2BA),
    gold: Color(0xFFD9BA63),
    highlight: Color(0x4D14805A),
    highlightPlaying: Color(0x66D9BA63),
    inkOnHighlight: Color(0xFFFFF6DC),
    isLight: false,
  ),
  // 8 — parchment, warmer and lower-glare than `classic`.
  MushafTheme(
    id: 'parchment',
    labelKey: 'mushaf_theme.parchment',
    paper: Color(0xFFE8DCC0),
    ink: Color(0xFF463A20),
    gold: Color(0xFF8B6A22),
    highlight: Color(0x338B6A22),
    highlightPlaying: Color(0x66B98F2E),
    inkOnHighlight: Color(0xFF33240F),
    isLight: true,
  ),
  // 9 — a soft warm ground that is easier on tired eyes than pure white.
  MushafTheme(
    id: 'rose',
    labelKey: 'mushaf_theme.rose',
    paper: Color(0xFFF6E9E6),
    ink: Color(0xFF3A2226),
    gold: Color(0xFF9C5560),
    highlight: Color(0x339C5560),
    highlightPlaying: Color(0x5CC2707C),
    inkOnHighlight: Color(0xFF2C1417),
    isLight: true,
  ),
  // 10 — maximum contrast, for low vision. Not a style choice.
  MushafTheme(
    id: 'contrast',
    labelKey: 'mushaf_theme.contrast',
    paper: Color(0xFF000000),
    ink: Color(0xFFFFFFFF),
    gold: Color(0xFFFFD34D),
    highlight: Color(0x66FFD34D),
    highlightPlaying: Color(0xCCFFD34D),
    inkOnHighlight: Color(0xFF000000),
    isLight: false,
  ),
];

MushafTheme mushafThemeById(String id) => mushafThemes.firstWhere(
      (t) => t.id == id,
      orElse: () => mushafThemes.first,
    );

const _kKey = 'mushaf_text_theme_v1';

/// Which theme the text mushaf is using, persisted.
///
/// Defaults to `null` meaning **follow the app theme** — a fresh install keeps
/// behaving exactly as it did (cream in light, navy in dark) instead of being
/// moved to a look the reader never chose.
class MushafThemeController extends StateNotifier<String?> {
  MushafThemeController(this._prefs) : super(_prefs.getString(_kKey));

  final SharedPreferences _prefs;

  Future<void> select(String? id) async {
    state = id;
    if (id == null) {
      await _prefs.remove(_kKey);
    } else {
      await _prefs.setString(_kKey, id);
    }
  }
}

final mushafThemeProvider =
    StateNotifierProvider<MushafThemeController, String?>(
  (ref) => MushafThemeController(ref.watch(sharedPrefsProvider)),
);

/// The theme the mushaf should actually paint with right now.
///
/// Resolves the "follow the app theme" default against the ambient brightness,
/// so callers never have to handle the null case themselves.
MushafTheme resolveMushafTheme(String? selectedId, Brightness brightness) {
  if (selectedId != null) return mushafThemeById(selectedId);
  return brightness == Brightness.dark ? mushafThemes[1] : mushafThemes[0];
}
