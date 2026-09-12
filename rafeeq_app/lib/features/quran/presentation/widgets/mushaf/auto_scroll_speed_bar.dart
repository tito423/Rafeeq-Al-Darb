/// The speed slider that appears while auto-scroll is running.
library;


import 'package:flutter/material.dart';


/// Quran tab — a real mushaf browser.
///  • Text mode: real Uthmani ayahs laid out by their real Madani page
///    boundaries from the bundled database (works fully offline).
///  • Image mode: the authentic KFQC mushaf pages as vector art, cached on
///    device, with the real ayah polygons layered on top for tap/highlight.

/// P3‑39: the auto-scroll speed control — a plain labelled `Slider` over a
/// real pixels/second range (15–120) rather than an opaque "slow/medium/
/// fast" enum, so a reader can actually tune it to their own reading pace.
/// Only ever built while auto-scroll is on (see the call site).
class AutoScrollSpeedBar extends StatelessWidget {
  final double speed;
  final ValueChanged<double> onChanged;
  const AutoScrollSpeedBar({super.key, required this.speed, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.speed, size: 18),
          Expanded(
            child: Slider(
              value: speed.clamp(15, 120),
              min: 15,
              max: 120,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '${speed.round()}',
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// P3‑43 #4/#5: replaces the old surah-name strip (P3‑8) *and* the ‹ ›
/// page-arrow buttons with one real drag-to-scrub scrollbar — the owner's
/// actual, twice-repeated ask ("my request was only fast scroll bar not
/// putting suras names", P3‑41; "delete the arrows, make scroll bar, when
/// I move it scroll quickly", this round). Dragging anywhere jumps
/// immediately (no animation — a scrub should feel instant, not
/// throttled by a 320ms page-turn tween), and the thumb tracks the real
/// current page live while dragging, not just on release.
///
/// **Direction: follows the app's own text direction.** P3‑43 originally
/// shipped this as a plain always-left-to-right value (matching every
/// other slider in the app) since there was no confirmed signal either
/// way. P3‑44's real-device round gave a direct one: real feedback asked
/// for RTL specifically "in arabic locale selection state" — so in an
/// RTL locale, page 1 now sits at the physical right (like a printed
/// Arabic mushaf's spine) and dragging left increases the page number;
/// in an LTR locale it stays the original plain left-to-right mapping.
