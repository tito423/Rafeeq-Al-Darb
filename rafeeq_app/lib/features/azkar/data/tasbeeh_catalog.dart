/// What the tasbeeh screen counts: the seven short phrases, the five long
/// ma'thur adhkar, the selectable targets and the celebration milestone.
///
/// Moved out of `tasbeeh_screen.dart`. These are the app's religious content,
/// not layout - and the doc comment on the long adhkar explains why none of
/// them carries a reward line, which is a §1.2 decision that belongs where
/// the content is, not inside a widget file.
library;

import 'package:flutter/material.dart';

/// One of the standard tasbeeh phrases + the pill/accent colour the owner's
/// reference image (`design_refs/ref_tasbeeh.jpg`) used for it.
class DhikrOption {
  final String textKey;
  final Color color;
  const DhikrOption(this.textKey, this.color);
}

const tasbeehShortAdhkar = [
  DhikrOption('azkar.tasbeeh_subhanallah', Color(0xFF2E9FE8)), // blue
  DhikrOption('azkar.tasbeeh_alhamdulillah', Color(0xFF2E9D6F)), // green
  DhikrOption('azkar.tasbeeh_allahuakbar', Color(0xFF6C5FBC)), // purple
  DhikrOption('azkar.tasbeeh_lailahaillallah', Color(0xFFC9A227)), // gold
  DhikrOption('azkar.tasbeeh_allahumma_salli', Color(0xFFD4785A)), // amber
  DhikrOption('azkar.tasbeeh_lahawla', Color(0xFF5C8A6E)), // sage
  DhikrOption('azkar.tasbeeh_astaghfirullah', Color(0xFF3F7A8C)), // teal
];

/// The five the owner asked for by name. They are kept apart from the seven
/// above for a plain layout reason: each is a full sentence — «لا إله إلا الله
/// وحده لا شريك له، له الملك وله الحمد يحيي ويميت وهو على كل شيء قدير» is 88
/// characters — and none of them fits either a pill or the 250-pixel counting
/// circle. «حطهم في كارت بحيث لما أضغط عليه يفتح كارت فيهم الذكر وأختار اللي
/// عاوز أبدأ فيه، ويطلع لوحده المختار في شكل كارت جميل وعدّاد زي اللي موجود في
/// الأذكار»: so a card opens a picker, and the one picked takes over the
/// counting area as a card of its own.
///
/// No fadl / reward line is attached to any of them. Several do have one in
/// the Sunna, but §1.2 of CLAUDE.md is that a claim about a text needs a named
/// source in the app, and the tasbeeh screen has nowhere to show one — so the
/// screen counts, and says nothing it cannot attribute.
const tasbeehLongAdhkar = [
  DhikrOption('azkar.tasbeeh_tawhid_full', Color(0xFFC9A227)), // gold
  DhikrOption('azkar.tasbeeh_baqiyat_full', Color(0xFF2E9D6F)), // green
  DhikrOption('azkar.tasbeeh_yunus', Color(0xFF2E9FE8)), // blue
  DhikrOption('azkar.tasbeeh_subhanallah_wabihamdih', Color(0xFF3F7A8C)), // teal
  DhikrOption('azkar.tasbeeh_astaghfirullah_full', Color(0xFF6C5FBC)), // purple
];

/// The selectable per-round targets. `null` = no limit (count climbs freely,
/// celebrating every 1000). P3‑47: real-device feedback — the fixed 33 was
/// the only option and the counter visibly stopped at 32 (it reset the
/// instant it hit the target, so the target number itself was never shown).
const List<int?> tasbeehTargets = [33, 100, 1000, null];

/// Milestone every N counts triggers the full-screen celebration — the
/// owner asked specifically for 1000 / 1000n.
const tasbeehCelebrateEvery = 1000;
