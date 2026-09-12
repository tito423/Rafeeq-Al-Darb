import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/arabic_text.dart';
import '../../data/sources_catalog.dart';

/// Where every piece of content in the app actually comes from.
///
/// This used to be a single run-on subtitle of dot-separated hostnames, which
/// credited nobody legibly. Each source now gets its own row saying what it
/// provides, and opens its site — the point of a credits page is that a reader
/// can go and check the source for themselves.
class SourcesScreen extends StatelessWidget {
  const SourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text('settings.credits'.tr())),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
            child: Text(
              'about.sources_intro'.tr(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.7,
              ),
            ),
          ),
          for (final group in sourceGroups) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
              child: Text(
                group.$1.tr(),
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: scheme.primary),
              ),
            ),
            ...group.$2.map((s) => _SourceRow(source: s)),
          ],
        ],
      ),
    );
  }
}

/// A host name written in Arabic script is laid out right to left; a
/// Latin one is not. Rendering detail, so it stays with the screen.
final _hasArabic = RegExp(r'[\u0600-\u06FF]');


class _SourceRow extends StatelessWidget {
  final SourceEntry source;
  const _SourceRow({required this.source});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => launchUrl(
            Uri.parse(source.url),
            mode: LaunchMode.externalApplication,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.gold,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // A source's identity is its own name: `sunnah.com`
                      // is Latin, and «مسند أحمد — ط الرسالة» is Arabic and
                      // carries an em dash and an editor's name. On a French
                      // UI that line inherits an LTR paragraph and its parts
                      // migrate to the wrong end. The name itself is never
                      // translated - a credit that renames its source stops
                      // being a credit (CLAUDE.md §1.2) - so what is fixed
                      // here is direction, not words.
                      if (_hasArabic.hasMatch(source.host))
                        ArabicText(
                          source.host,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      else
                        Text(
                          source.host,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      const SizedBox(height: 2),
                      Text(
                        source.roleKey.tr(),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.open_in_new_rounded,
                    size: 16, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
