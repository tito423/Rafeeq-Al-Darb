import 'dart:ui' show Color;

/// The page's SVG with the ink written INTO it, instead of a colour filter
/// laid over the picture.
///
/// «جزء من نص القرآن ممسوح». On the owner's phone, in landscape, the first
/// words of page 316 were simply not drawn - the background pattern showed
/// through a clean rectangle where «قالوا يموسى إما أن» should be. The page
/// used to go through `colorFilter: srcIn`, which renders the whole picture
/// into an offscreen layer and composites it; a layer whose bounds come out
/// wrong clips everything outside them, and that is exactly the shape seen.
/// It did not reproduce on the emulator (Impeller on OpenGL; the phone is
/// Vulkan), so rather than trust any renderer's layer bounds the colour now
/// lives in the drawing itself and there is no layer at all.
///
/// The quranpedia pages are monochrome: every glyph path is either unfilled
/// (default black, inherited from the root) or `fill="#231f20"`. Both
/// become the ink. `test/mushaf_inked_svg_test.dart` checks a real page.
String inkedSvg(String svg, Color ink) {
  final cached = _inkedMemo[svg.hashCode ^ ink.toARGB32()];
  if (cached != null) return cached;
  final hex = '#${(ink.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  var out = svg.replaceAll('fill="#231f20"', 'fill="$hex"');
  final open = out.indexOf('<svg');
  if (open >= 0) {
    out = '${out.substring(0, open + 4)} fill="$hex"${out.substring(open + 4)}';
  }
  if (_inkedMemo.length > 12) _inkedMemo.remove(_inkedMemo.keys.first);
  return _inkedMemo[svg.hashCode ^ ink.toARGB32()] = out;
}

final _inkedMemo = <int, String>{};
