part of 'mushaf_text_page.dart';

// Split out of mushaf_text_page.dart to keep it under its length ceiling.

// ─── Ayah row widget ───────────────────────────────────────────────────────

/// One ayah rendered as a card-like row: Uthmani text (right-aligned, RTL) with
/// a rosette marker on the side, an `InkWell` for long-press → sciences sheet,
/// and an optional highlight when this is the verse being recited.
class _AyahRow extends StatelessWidget {
  final Ayah ayah;
  final bool isPlaying;
  final TextStyle textStyle;
  final MushafTheme mt;
  final VoidCallback onLongPress;
  final VoidCallback? onTap;
  final VoidCallback? onPlayTap;

  const _AyahRow({
    super.key,
    required this.ayah,
    required this.isPlaying,
    required this.textStyle,
    required this.mt,
    required this.onLongPress,
    this.onTap,
    this.onPlayTap,
  });

  @override
  Widget build(BuildContext context) {
    // The row's resting tint comes from the *theme's* own lightness, not the
    // app's: a light mushaf theme can be selected while the app is in dark
    // mode, and a white wash on cream paper is invisible.
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isPlaying
            ? mt.highlightPlaying
            : (mt.isLight
                  ? Colors.black.withValues(alpha: 0.015)
                  : Colors.white.withValues(alpha: 0.03)),
        borderRadius: BorderRadius.circular(14),
        border: isPlaying
            ? Border.all(color: mt.gold.withValues(alpha: 0.5), width: 1.2)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onLongPress: onLongPress,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              textDirection: TextDirection.rtl,
              children: [
                // ── Ayah text ──
                Expanded(
                  child: InkWell(
                    onTap: onTap,
                    onLongPress: onLongPress,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text(
                        ayah.textUthmani,
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
                        style: textStyle,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // ── Rosette marker ──
                InkWell(
                  onTap: onPlayTap,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: 6,
                      left: 4,
                      right: 4,
                      bottom: 4,
                    ),
                    child: _AyahMarker(
                      number: ayah.ayahNumber,
                      playing: isPlaying,
                      mt: mt,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
