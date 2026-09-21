import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// «هل فيه إمكانية لجعل المصحف الورقي يناسب الوضع الليلي والوضع الورقي
/// الدافئ». The page of the paper (image) mushaf, as the reader wants it lit.
///
/// The vector Hafs pages are monochrome glyphs recoloured with one `srcIn`,
/// so night and warm paper are exact: an ink and a ground. A scanned printing
/// is a photograph, so it goes through a colour matrix instead — warm paper
/// multiplies the white towards cream and leaves black ink black; night
/// inverts the lightness and rotates the hue half a turn so the tajweed
/// colours come back as themselves rather than their complements.
enum MushafPaper {
  normal,
  warm,
  night;

  static MushafPaper fromName(String? n) => MushafPaper.values.firstWhere(
    (v) => v.name == n,
    orElse: () => MushafPaper.normal,
  );

  String get titleKey => 'quran.paper_$name';
}

/// Page ground for each mode. Warm is the colour the matrix below turns
/// white into, so a scan and the letterbox around it are one colour.
const warmPaper = Color(0xFFF4E8CF);
const warmInk = Color(0xFF3B2A1A);
const nightPaper = Color(0xFF0F1722);
const nightInk = Color(0xFFE8E0CC);

/// The ground for the whole Qur'an screen, so the strips above and below the
/// page (status bar, page-number band) are the page's colour too — a white
/// band under a night page glares. Null keeps the app's own background.
/// An opaque version of [surface], for a theme whose surfaces are not.
///
/// The RGB theme's scaffold is `Colors.transparent` and its surface is 94%
/// opaque, because `RgbScaffoldBackground` paints an animated gradient behind
/// every screen and the cards are meant to let a little of it through. A
/// Qur'an page is not a card. «لما وضع الار جي بي اشتغل المصحف الورقي الوانه
/// باظت» - the gradient was moving underneath the printed page, through the
/// transparent scaffold, and compositing with the printing's own ink.
Color opaqueMushafGround(Color surface, Brightness brightness) =>
    Color.alphaBlend(
      surface,
      brightness == Brightness.dark
          ? const Color(0xFF000000)
          : const Color(0xFFFFFFFF),
    );

Color? mushafGround(
  MushafPaper p, {
  required bool imageMode,
  required bool darkPage,
}) {
  if (!imageMode) return null;
  // A printing whose scans are black pages (Madinah night) sits on black:
  // the app's light ground showed as a pale band under the page in
  // landscape, where the page scrolls and the strip below it is visible.
  if (darkPage) return const Color(0xFF000000);
  return switch (p) {
    // The Madinah PNG is black ink on a transparent ground. Letting the app
    // theme show through therefore makes a normal page black-on-black in dark
    // mode, and lets the animated RGB gradient tint it. Normal paper owns a
    // real white sheet independently of the surrounding app theme.
    MushafPaper.normal => const Color(0xFFFFFFFF),
    MushafPaper.warm => warmPaper,
    MushafPaper.night => nightPaper,
  };
}

/// 4×5 colour matrices, row-major, as `ColorFilter.matrix` takes them.
List<double> _compose(List<double> a, List<double> b) {
  // (a ∘ b)(x) = a(b(x)); both are affine 4×5.
  final out = List<double>.filled(20, 0);
  for (var r = 0; r < 4; r++) {
    for (var c = 0; c < 5; c++) {
      var v = c == 4 ? a[r * 5 + 4] : 0.0;
      for (var k = 0; k < 4; k++) {
        v += a[r * 5 + k] * b[k * 5 + c];
      }
      out[r * 5 + c] = v;
    }
  }
  return out;
}

const List<double> _invert = [
  -1, 0, 0, 0, 255, //
  0, -1, 0, 0, 255, //
  0, 0, -1, 0, 255, //
  0, 0, 0, 1, 0, //
];

/// Hue rotation by 180°, the SVG `feColorMatrix` luminance-preserving form
/// with cos = −1, sin = 0.
const List<double> _hue180 = [
  -0.574, 1.430, 0.144, 0, 0, //
  0.426, 0.430, 0.144, 0, 0, //
  0.426, 1.430, -0.856, 0, 0, //
  0, 0, 0, 1, 0, //
];

/// Dims to 90% and lifts black to [nightPaper], so the inverted page sits on
/// the same navy as the letterbox instead of a hard black.
const List<double> _nightGround = [
  0.9, 0, 0, 0, 15, //
  0, 0.9, 0, 0, 23, //
  0, 0, 0.9, 0, 34, //
  0, 0, 0, 1, 0, //
];

/// White → [warmPaper] (244, 232, 207); black stays black.
const List<double> _warmMultiply = [
  244 / 255, 0, 0, 0, 0, //
  0, 232 / 255, 0, 0, 0, //
  0, 0, 207 / 255, 0, 0, //
  0, 0, 0, 1, 0, //
];

final List<double> nightScanMatrix = _compose(
  _nightGround,
  _compose(_hue180, _invert),
);

/// The filter a scanned page gets, or null to draw it untouched.
ColorFilter? scanFilter(MushafPaper p, {required bool darkPage}) {
  if (darkPage) return null;
  return switch (p) {
    MushafPaper.normal => null,
    MushafPaper.warm => const ColorFilter.matrix(_warmMultiply),
    MushafPaper.night => ColorFilter.matrix(nightScanMatrix),
  };
}

/// Where a colour lands under a 4×5 matrix — for the contrast test.
Color applyMatrix(List<double> m, Color c) {
  final v = [c.r * 255, c.g * 255, c.b * 255, c.a * 255];
  int ch(int r) =>
      (m[r * 5] * v[0] +
              m[r * 5 + 1] * v[1] +
              m[r * 5 + 2] * v[2] +
              m[r * 5 + 3] * v[3] +
              m[r * 5 + 4])
          .round()
          .clamp(0, 255);
  return Color.fromARGB(ch(3), ch(0), ch(1), ch(2));
}

List<double> get warmScanMatrix => _warmMultiply;

class MushafPaperNotifier extends StateNotifier<MushafPaper> {
  MushafPaperNotifier() : super(MushafPaper.normal) {
    _restore();
  }

  static const _key = 'mushaf_paper_mode_v1';

  Future<void> _restore() async {
    final p = await SharedPreferences.getInstance();
    final v = MushafPaper.fromName(p.getString(_key));
    if (mounted) state = v;
  }

  Future<void> set(MushafPaper v) async {
    state = v;
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, v.name);
  }
}

final mushafPaperProvider =
    StateNotifierProvider<MushafPaperNotifier, MushafPaper>(
      (ref) => MushafPaperNotifier(),
    );
