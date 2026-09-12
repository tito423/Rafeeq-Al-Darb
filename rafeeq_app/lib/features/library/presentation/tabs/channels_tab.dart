/// «قنوات دعوية» — the verified channel list, with each channel's mirrored
/// avatar or, where YouTube has only a generated letter tile for it, the
/// app's own mark.
library;

import '../../../../core/widgets/arabic_text.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/i18n/proper_name.dart';
import '../../../channels/data/islamic_channels.dart';
import '../../../../core/utils/external_link.dart';

// ── Islamic Channels ──────────────────────────────────────────────────────

/// The channel's picture, or its mark when YouTube has only a letter tile
/// for it. `CachedNetworkImage` keeps the mirrored avatar on the device, so
/// the grid is not a page of grey circles with the network off — and its
/// placeholder and error states both fall back to the same mark, so a slow or
/// failed fetch looks deliberate rather than broken.
class _ChannelAvatar extends StatelessWidget {
  final IslamicChannel channel;
  const _ChannelAvatar({required this.channel});

  @override
  Widget build(BuildContext context) {
    final mark = Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: channel.color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(channel.icon, color: channel.color, size: 28),
    );
    if (!channel.hasPhoto) return mark;
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: channel.avatarUrl,
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        placeholder: (_, _) => mark,
        errorWidget: (_, _, _) => mark,
      ),
    );
  }
}

class ChannelsTab extends StatelessWidget {
  const ChannelsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: islamicChannels.length,
      itemBuilder: (context, i) {
        final ch = islamicChannels[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          clipBehavior: Clip.antiAlias,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            onTap: () => openExternalLink(ch.url),
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
                            properName(ch.nameAr, ch.nameEn),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ch.descriptionKey.tr(),
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
