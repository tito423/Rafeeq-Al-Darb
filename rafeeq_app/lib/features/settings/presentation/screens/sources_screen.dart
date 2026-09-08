import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';

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
          for (final group in _groups) ...[
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

class _Source {
  final String host;
  final String url;

  /// What this source actually provides — an i18n key.
  final String roleKey;

  const _Source(this.host, this.url, this.roleKey);
}

/// (section title key, sources) — grouped by what part of the app they feed.
const _groups = <(String, List<_Source>)>[
  (
    'about.src_quran',
    [
      _Source('quran.com', 'https://quran.com', 'about.src_qurancom'),
      _Source('api.alquran.cloud', 'https://alquran.cloud',
          'about.src_alquran'),
      _Source('quranpedia/quran-svg',
          'https://github.com/quranpedia/quran-svg', 'about.src_svg'),
      _Source('archive.org', 'https://archive.org', 'about.src_archive'),
    ]
  ),
  (
    'about.src_audio',
    [
      _Source('everyayah.com', 'https://everyayah.com', 'about.src_everyayah'),
      _Source('cdn.islamic.network', 'https://islamic.network',
          'about.src_islamicnetwork'),
      _Source('mp3quran.net', 'https://mp3quran.net', 'about.src_mp3quran'),
    ]
  ),
  (
    'about.src_hadith',
    [
      _Source('sunnah.com', 'https://sunnah.com', 'about.src_sunnah'),
      _Source('المكتبة الشاملة', 'https://shamela.ws', 'about.src_shamela'),
    ]
  ),
  (
    'about.src_prayer',
    [
      _Source('api.aladhan.com', 'https://aladhan.com', 'about.src_aladhan'),
    ]
  ),
];

class _SourceRow extends StatelessWidget {
  final _Source source;
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
