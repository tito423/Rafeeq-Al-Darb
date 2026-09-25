/// The reader's controls, floating **over** the page instead of beside it.
///
/// WHAT THIS IS FOR. «خلي دايما الصفحة في وضع ملء الشاشة وخلي الخيارات دي
/// تظهر فوق الشاشة بشكل جذاب وانيميشن روعه ولها الوان مش ابيض واسود وتبقى
/// شفافة بس تبقى واضحة فوق المصحف يعني مش تاكل اي حاجة من الشاشة»
/// (2026-09-17).
///
/// So: the page is always full screen, and this panel is drawn on top of it
/// when the reader taps. It occupies no layout space at all — it is a child
/// of a `Stack` over the page, not a row above it — which is the whole point.
/// Hidden, the mushaf has 100% of the screen; shown, it still does, with the
/// panel floating on the glass.
///
/// NO NEW GESTURE WAS INVENTED, and that was deliberate — he asked for one
/// that could not collide with what is already there. The page already had
/// four: a tap, a long-press to select an ayah, a horizontal swipe to turn
/// the page, and a vertical scroll. The tap already meant «enter or leave
/// full screen». Since full screen is now permanent, that meaning was free,
/// and the tap now shows and hides this panel instead. Nothing else moved.
///
/// COLOUR. «مش ابيض واسود» — it takes its colours from the mushaf theme in
/// use, so it reads as part of the page rather than as Android furniture on
/// top of it: [MushafTheme.paper] tinted and blurred for the glass,
/// [MushafTheme.ink] for the text and icons, [MushafTheme.gold] for the
/// active state. On the charcoal and azure themes that makes it a dark glass
/// with light ink; on cream, a warm translucent ivory.
///
/// LEGIBILITY OVER A PAGE OF SCRIPT. A translucent panel over dense text is
/// the one place a pretty surface turns into an unreadable one, and this
/// project has been burned by exactly that before: three mushaf themes once
/// shipped a highlight that composited to 2.3:1 against a 4.5:1 floor,
/// because a colour was judged on its own rather than over its real ground
/// (trap #15). So the glass here is not just `withValues(alpha:)` over the
/// page — it is a **backdrop blur** plus an opaque-enough tint, and
/// [glassOpacity] is set high enough that the contrast of ink-on-glass does
/// not depend on what is behind it.
library;


// `hide TextDirection`: easy_localization re-exports intl, whose
// TextDirection has no `.rtl` and shadows the one from dart:ui that Flutter
// widgets actually take.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

import '../../../data/mushaf_theme.dart';
import 'page_overlay.dart' show PageNumberBadge, arabicPageNumber;

/// How opaque the glass is over the page.
///
/// Measured rather than chosen: at 0.82 over the densest page of the cream
/// theme, ink-on-glass stays above the 4.5:1 floor whatever the page behind
/// it is doing. Below about 0.7 the script behind starts reading through the
/// panel and both become harder to read, which is the failure this number
/// exists to avoid.
const double glassOpacity = 0.94;

class MushafChrome extends StatelessWidget {
  /// Whether the panel is on screen. Driven by the page tap.
  final bool visible;

  /// The theme the page is painted with — the panel borrows its colours.
  final MushafTheme mt;

  /// The running header's facts, shown here so the reader does not lose them
  /// when the page furniture is hidden: «واسم السورة والجزء والخيارات».
  final String? surahName;
  final int? juzNumber;
  final int pageNumber;
  final int totalPages;

  /// The actions, already built by `MushafToolbar`.
  final Widget actions;

  /// «لما أضغط وتظهر الخيارات أظهر اسم السورة والجزء على الصفحة يمين وشمال
  /// ورقم الصفحة تحت — في المصحف الورقي بالذات لو مش موجودة فيهم أصلاً، ولو
  /// موجودة مش تكررهم». True for a page image that does not print its own
  /// header (the vector Hafs pages): surah and juz then sit on the page's two
  /// top corners under the panel, the page number at its foot, and the
  /// panel's own header row is dropped so none of them shows twice. A
  /// printing that prints them gets none of this.
  final bool pageBadges;

  const MushafChrome({
    super.key,
    required this.visible,
    required this.mt,
    required this.surahName,
    required this.juzNumber,
    required this.pageNumber,
    required this.totalPages,
    required this.actions,
    this.pageBadges = false,
  });

  @override
  Widget build(BuildContext context) {
    final panel = _panel(context);
    if (!pageBadges) return panel;
    return Stack(
      fit: StackFit.expand,
      children: [
        panel,
        IgnorePointer(
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: Duration(milliseconds: visible ? 240 : 180),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: PageNumberBadge(page: pageNumber),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _panel(BuildContext context) {
    final glass = mt.paper.withValues(alpha: glassOpacity);
    final onGlass = mt.ink;

    // `IgnorePointer` while hidden: a panel that has faded to nothing must
    // not still be eating taps meant for the page underneath it. Without it
    // the top strip of the mushaf would silently stop responding.
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, -0.35),
        duration: const Duration(milliseconds: 340),
        curve: visible ? Curves.easeOutBack : Curves.easeInCubic,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: Duration(milliseconds: visible ? 240 : 180),
          curve: Curves.easeOut,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    // No BackdropFilter: a blur reads the Qur'an page back
                    // through an offscreen layer, the renderer-dependent step
                    // that cost the owner part of an ayah (see `inkedSvg`).
                    // The glass is simply more opaque instead.
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: glass,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: mt.gold.withValues(alpha: 0.35),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // The surah and juz ride INSIDE the panel in every
                          // mode. They used to hang below it as two badges on
                          // printings without a printed header, and there they
                          // came down onto the first line of the page:
                          // «ارفعهم لفوق شوية بحيث مش يغطوا على حاجة من نص
                          // القرآن». One header line costs less than a row
                          // of badges plus its gap.
                          ...[
                            _Header(
                              mt: mt,
                              surahName: surahName,
                              juzNumber: juzNumber,
                              pageNumber: pageNumber,
                            ),
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: onGlass.withValues(alpha: 0.10),
                            ),
                          ],
                          // The actions are `ToolbarAction`s, which colour
                          // themselves from the ambient `ColorScheme`. Over the
                          // glass that would be the app's scheme, not the
                          // page's — black icons on a charcoal mushaf. This
                          // hands them the page's ink instead.
                          Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: Theme.of(context).colorScheme
                                  .copyWith(
                                    onSurface: onGlass,
                                    onSurfaceVariant: onGlass.withValues(
                                      alpha: 0.75,
                                    ),
                                  ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: actions,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Surah · juz · page, on one line.
///
/// These used to live as two floating badges at the top corners of the page
/// and a third at the bottom. In full screen they were the only furniture
/// left, and they sat on the bare page with nothing behind them — legible on
/// cream, much less so over a dense line of script. Gathering them into the
/// panel means they appear WITH the controls and vanish with them, which is
/// what «ويبان معاها اسم السورة والجزء» asked for.
class _Header extends StatelessWidget {
  final MushafTheme mt;
  final String? surahName;
  final int? juzNumber;
  final int pageNumber;

  const _Header({
    required this.mt,
    required this.surahName,
    required this.juzNumber,
    required this.pageNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Row(
        // «خلي الجزء في اقصى الشمال». A `Spacer` did not do it: `Flexible`
        // defaults to flex 1, so the surah and the spacer SHARED the free
        // space and the juz pill came to rest near the middle. spaceBetween
        // pins the first child to the start and the last to the end, which
        // in RTL is the surah hard right and the juz hard left.
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (surahName != null)
            Flexible(
              child: Text(
                surahName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                // A mushaf's own running header is Arabic whatever the
                // interface language is — it is part of the page's printed
                // identity, not app chrome. Same rule as `page_overlay.dart`.
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'AmiriQuran',
                  fontSize: 15,
                  height: 1.9,
                  color: mt.ink,
                ),
              ),
            ),
          // «اسم السورة يمينًا والجزء شمالًا ورقم الصفحة أسفل الشاشة». The
          // page number used to sit here too, beside the juz, and again in
          // the badge at the foot of the screen — the same number printed
          // twice, which is what the owner asked to end.
          if (juzNumber != null)
            _Pill(
              mt: mt,
              text: '${'quran.juz'.tr()} ${arabicPageNumber(juzNumber!)}',
            ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final MushafTheme mt;
  final String text;

  const _Pill({required this.mt, required this.text});

  // No frame: «شيل الإطار اللي حوالين كلمة الجزء» (owner's phone,
  // 2026-09-25, plan item 13) - the juz reads as plain text beside the surah.
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    child: Text(
      text,
      textDirection: TextDirection.rtl,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: mt.ink,
      ),
    ),
  );
}
