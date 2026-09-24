/// «قنوات دعوية» — the verified channel list, with each channel's mirrored
/// avatar or, where YouTube has only a generated letter tile for it, the
/// app's own mark. The reader can reorder, hide, edit and delete entries and
/// choose where they open (`link_list_manage_screen.dart`).
library;

import '../../../../core/widgets/mirrored_network_image.dart';
import '../../../../core/widgets/arabic_text.dart';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/proper_name.dart';
import '../../../channels/data/islamic_channels.dart';
import '../../data/link_list_customization.dart';
import '../widgets/link_list_manage_screen.dart';

// ── Islamic Channels ──────────────────────────────────────────────────────

/// The channel's picture, or its mark when YouTube has only a letter tile
/// for it. `CachedNetworkImage` keeps the mirrored avatar on the device, so
/// the grid is not a page of grey circles with the network off — and its
/// placeholder and error states both fall back to the same mark, so a slow or
/// failed fetch looks deliberate rather than broken.
class _ChannelAvatar extends StatelessWidget {
  final IslamicChannel channel;
  final double size;
  const _ChannelAvatar({required this.channel, this.size = 52});

  @override
  Widget build(BuildContext context) {
    final mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: channel.color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(channel.icon, color: channel.color, size: size * 0.54),
    );
    if (!channel.hasPhoto) return mark;
    return ClipOval(
      child: MirroredNetworkImage(
        url: channel.avatarUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, _) => mark,
        errorWidget: (_, _, _) => mark,
      ),
    );
  }
}

const _listId = 'channels';

/// The catalogue as the reader has edited it, in catalogue order.
List<(IslamicChannel, ManagedLink)> _channelLinks(
    BuildContext context, LinkListState state,
    {double avatar = 40}) {
  return [
    for (final ch in islamicChannels)
      (
        ch,
        ManagedLink(
          id: ch.id,
          name: state.edits[ch.id]?.$1 ?? properName(ch.nameAr, ch.nameEn),
          subtitle: ch.descriptionKey.tr(),
          url: state.edits[ch.id]?.$2 ?? ch.url,
          leading: _ChannelAvatar(channel: ch, size: avatar),
        ),
      ),
  ];
}

class ChannelsTab extends ConsumerWidget {
  const ChannelsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(linkListProvider(_listId));
    final entries = {
      for (final e in _channelLinks(context, state)) e.$2.id: e,
    };
    final visible = [
      for (final id in state.arrange(entries.keys.toList()))
        if (!state.hidden.contains(id)) entries[id]!,
    ];

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: visible.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return ManageLinksButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => LinkListManageScreen(
                  listId: _listId,
                  title: 'library.tab_channels'.tr(),
                  catalogue: (s) => [
                    for (final e in _channelLinks(context, s)) e.$2,
                  ],
                ),
              ),
            ),
          );
        }
        final (ch, link) = visible[i - 1];
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
                    ch.color.withValues(alpha: 0.12),
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
                    _ChannelAvatar(channel: ch),
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
                            style: TextStyle(
                              fontSize: 13,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.play_circle_fill_rounded,
                      color: Colors.red.shade600,
                      size: 32,
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
