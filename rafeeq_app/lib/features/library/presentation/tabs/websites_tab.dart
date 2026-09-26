/// «مواقع إسلامية» — the link list. The catalogue itself lives in
/// `data/islamic_websites.dart`; a screen file is no place for content. The
/// reader can reorder, hide, edit and delete entries and choose where they
/// open (`link_list_manage_screen.dart`).
library;

import '../../../../core/widgets/paired_list_view.dart';
import '../../../../core/widgets/arabic_text.dart';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/islamic_websites.dart';
import '../../data/link_list_customization.dart';
import '../widgets/link_list_manage_screen.dart';

const _listId = 'websites';

Widget _siteIcon(WebsiteInfo site, double size) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: site.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(size * 0.27),
      ),
      child: Icon(site.icon, color: site.color, size: size * 0.54),
    );

/// A site has no id field; its description key is unique and never edited,
/// so it identifies the entry even after the reader changes its name or link.
List<(WebsiteInfo, ManagedLink)> _siteLinks(LinkListState state,
    {double icon = 40}) {
  return [
    for (final site in islamicWebsites)
      (
        site,
        ManagedLink(
          id: site.descriptionKey,
          name: state.edits[site.descriptionKey]?.$1 ?? site.name,
          subtitle: site.descriptionKey.tr(),
          url: state.edits[site.descriptionKey]?.$2 ?? site.url,
          leading: _siteIcon(site, icon),
        ),
      ),
  ];
}

class WebsitesTab extends ConsumerWidget {
  const WebsitesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(linkListProvider(_listId));
    final entries = {for (final e in _siteLinks(state)) e.$2.id: e};
    final visible = [
      for (final id in state.arrange(entries.keys.toList()))
        if (!state.hidden.contains(id)) entries[id]!,
    ];

    // Sideways two a row (`PairedListView`); the manage button stays
    // full width above them.
    return PairedListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      header: ManageLinksButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => LinkListManageScreen(
                  listId: _listId,
                  title: 'library.tab_websites'.tr(),
                  catalogue: (s) => [for (final e in _siteLinks(s)) e.$2],
                ),
              ),
            ),
          ),
      itemCount: visible.length,
      itemBuilder: (context, i) {
        final (site, link) = visible[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          clipBehavior: Clip.antiAlias,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            onTap: () => openManagedLink(context, ref, link.url),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    site.color.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                  begin: AlignmentDirectional.centerStart,
                  end: AlignmentDirectional.centerEnd,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _siteIcon(site, 52),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ArabicText(
                            link.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            link.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.open_in_new_rounded,
                      color: site.color,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
