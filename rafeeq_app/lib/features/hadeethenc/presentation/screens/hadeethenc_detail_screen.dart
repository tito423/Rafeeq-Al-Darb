import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/db/hadeethenc_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/arabic_normalize.dart';
import '../../../../core/widgets/arabic_text.dart';

/// One record of موسوعة الأحاديث النبوية, in full.
///
/// WHAT THIS SCREEN IS OBLIGED TO SHOW, AND WHY.
/// CLAUDE.md §1.2: a grading must come from a named source and the app must
/// say whose it is. HadeethEnc grades every record but names no individual
/// scholar per hadith — the verdict is the encyclopedia's own, taken from the
/// works it lists in `reference`. So the grading is never shown bare: it is
/// always «الدرجة: … — the encyclopedia», with the reference list under it
/// when the record carries one. A reader always knows whose ruling they are
/// reading.
///
/// The source's own republication terms (see `AppConfig.hadeethEncUrl`)
/// require clear credit to the publisher, which is the footer at the bottom
/// of every one of these, not only the Sources screen.
class HadeethEncDetailScreen extends StatelessWidget {
  final HadeethItem item;
  final String sourceName;
  final String sourceUrl;
  final bool rtl;

  const HadeethEncDetailScreen({
    super.key,
    required this.item,
    required this.sourceName,
    required this.sourceUrl,
    required this.rtl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text('hadeethenc.title'.tr())),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (item.title.isNotEmpty)
            _Body(
              text: item.title,
              rtl: rtl,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          const SizedBox(height: 16),

          // The Arabic original always, in its own direction, whatever the
          // app's chrome direction is.
          if (item.hadeethAr.isNotEmpty)
            _Panel(
              child: ArabicText(
                stripBidiControls(item.hadeethAr),
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.9),
              ),
            ),

          // …and the translation under it, unless this pack IS the Arabic
          // one, in which case the two are the same paragraph.
          if (!item.isArabicOriginal && item.hadeeth.isNotEmpty) ...[
            const SizedBox(height: 12),
            _Body(
              text: item.hadeeth,
              rtl: rtl,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.7),
            ),
          ],

          const SizedBox(height: 20),

          if (item.attribution.isNotEmpty)
            _Field(
              label: 'hadeethenc.takhrij'.tr(),
              value: item.attribution,
              rtl: rtl,
              icon: Icons.account_balance_outlined,
            ),

          // §1.2 again: no grade is *shown* without saying whose it is, and a
          // record with no grade says so rather than showing nothing at all.
          _Field(
            label: 'hadeethenc.grade'.tr(),
            value: item.grade.isEmpty
                ? 'hadeethenc.grade_missing'.tr()
                : item.grade,
            note: item.grade.isEmpty
                ? null
                : 'hadeethenc.grade_by'.tr(namedArgs: {'source': sourceName}),
            rtl: rtl,
            icon: Icons.verified_outlined,
            emphasis: item.grade.isNotEmpty,
          ),

          if (item.explanation.isNotEmpty) ...[
            const SizedBox(height: 18),
            _SectionLabel('hadeethenc.explanation'.tr()),
            const SizedBox(height: 6),
            _Body(
              text: item.explanation,
              rtl: rtl,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.7),
            ),
          ],

          if (item.hints.isNotEmpty) ...[
            const SizedBox(height: 18),
            _SectionLabel('hadeethenc.hints'.tr()),
            const SizedBox(height: 6),
            for (final h in item.hints)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Icon(Icons.circle,
                          size: 6, color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Body(
                        text: h,
                        rtl: rtl,
                        style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                      ),
                    ),
                  ],
                ),
              ),
          ],

          if (item.reference.isNotEmpty) ...[
            const SizedBox(height: 18),
            _SectionLabel('hadeethenc.reference'.tr()),
            const SizedBox(height: 6),
            _Body(
              text: item.reference,
              rtl: rtl,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant, height: 1.6),
            ),
          ],

          const SizedBox(height: 26),
          const Divider(),
          const SizedBox(height: 10),
          // Condition 2 of the publisher's terms: clear credit to the
          // publisher and the source, on the content itself.
          InkWell(
            onTap: () => launchUrl(Uri.parse(sourceUrl),
                mode: LaunchMode.externalApplication),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.link, size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'hadeethenc.credit'.tr(namedArgs: {'source': sourceName}),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A block of the pack's own language, laid out in that language's direction.
///
/// An Arabic or Urdu pack read on a French UI would otherwise inherit the
/// chrome's left-to-right paragraph and throw its edge punctuation to the
/// wrong end — the defect `test/arabic_direction_test.dart` measures.
class _Body extends StatelessWidget {
  final String text;
  final bool rtl;
  final TextStyle? style;
  const _Body({required this.text, required this.rtl, this.style});

  @override
  Widget build(BuildContext context) {
    final clean = stripBidiControls(text);
    if (rtl) return ArabicText(clean, style: style);
    return Text(clean, style: style);
  }
}

class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: child,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: AppColors.gold, fontWeight: FontWeight.w700),
      );
}

class _Field extends StatelessWidget {
  final String label;
  final String value;
  final String? note;
  final IconData icon;
  final bool rtl;
  final bool emphasis;

  const _Field({
    required this.label,
    required this.value,
    required this.icon,
    required this.rtl,
    this.note,
    this.emphasis = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 2),
                _Body(
                  text: value,
                  rtl: rtl,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: emphasis ? FontWeight.w700 : null,
                    color: emphasis ? AppColors.gold : null,
                  ),
                ),
                if (note != null) ...[
                  const SizedBox(height: 2),
                  Text(note!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
