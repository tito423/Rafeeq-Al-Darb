import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Is the mushaf page pinched in right now?
///
/// WHY THIS EXISTS. The image mushaf is an `InteractiveViewer` living inside
/// a horizontally-swiping `PageView`, and both of them want the same
/// horizontal drag. Flutter settles that in the gesture arena, and the result
/// was what the owner described as «الزووم … مش بتشتغل باحترافية تحسها
/// تقيلة»:
///
///  * at rest, every drag went to the arena before the `PageView` could take
///    it, so the page turn began late — the "heavy" feeling;
///  * zoomed in, a horizontal pan to look at the right-hand side of the page
///    turned the page instead of moving it, because the `PageView` is the
///    parent and wins.
///
/// The fix is to stop them competing at all rather than to tune thresholds:
/// the viewer only takes pans while it is actually zoomed, and the `PageView`
/// stops scrolling while it is. This provider is the seam between the two —
/// the page widget writes it, `QuranScreen` reads it — because the two are
/// far apart in the tree and threading a callback through would have meant a
/// parameter on every widget between them.
final quranPageZoomedProvider = StateProvider<bool>((ref) => false);
