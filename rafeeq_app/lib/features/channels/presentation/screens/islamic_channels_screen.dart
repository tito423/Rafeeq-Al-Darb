import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/islamic_pattern.dart';
import '../../data/islamic_channels.dart';

/// Islamic channels, as a thumbnail grid or a list — the owner asked for both
/// («سواء لسيت او جريد»), and the choice is remembered.
///
/// This screen links out; it never embeds or re-hosts anyone's video. Only the
/// avatars are mirrored, so the page is not blank without a network.
class IslamicChannelsScreen extends StatefulWidget {
  const IslamicChannelsScreen({super.key});

  @override
  State<IslamicChannelsScreen> createState() => _IslamicChannelsScreenState();
}

class _IslamicChannelsScreenState extends State<IslamicChannelsScreen> {
  static const _prefsKey = 'channels_view_grid_v1';

  bool _grid = true;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getBool(_prefsKey);
    if (v != null && mounted) setState(() => _grid = v);
  }

  Future<void> _setGrid(bool grid) async {
    setState(() => _grid = grid);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, grid);
  }

  Future<void> _open(IslamicChannel c) async {
    final uri = Uri.parse(c.url);
    // externalApplication so it lands in the YouTube app when it is installed,
    // rather than a cut-down in-app web view of a video page.
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('errors.generic'.tr())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final arabic = context.locale.languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text('channels.title'.tr()),
        actions: [
          IconButton(
            tooltip: _grid
                ? 'channels.view_list'.tr()
                : 'channels.view_grid'.tr(),
            onPressed: () => _setGrid(!_grid),
            icon: Icon(_grid
                ? Icons.view_list_rounded
                : Icons.grid_view_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: IslamicPatternPanel(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  const Icon(Icons.ondemand_video_rounded,
                      color: AppColors.goldSoft, size: 26),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'channels.intro'.tr(),
                      style: const TextStyle(
                        color: AppColors.textHigh,
                        fontSize: 12.5,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOutCubic,
              child: _grid
                  ? _ChannelGrid(
                      key: const ValueKey('grid'),
                      arabic: arabic,
                      onOpen: _open,
                    )
                  : _ChannelList(
                      key: const ValueKey('list'),
                      arabic: arabic,
                      onOpen: _open,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelGrid extends StatelessWidget {
  final bool arabic;
  final void Function(IslamicChannel) onOpen;

  const _ChannelGrid({super.key, required this.arabic, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.82,
      ),
      itemCount: islamicChannels.length,
      itemBuilder: (context, i) {
        final c = islamicChannels[i];
        return _ChannelCard(
          channel: c,
          arabic: arabic,
          onTap: () => onOpen(c),
        );
      },
    );
  }
}

class _ChannelList extends StatelessWidget {
  final bool arabic;
  final void Function(IslamicChannel) onOpen;

  const _ChannelList({super.key, required this.arabic, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      itemCount: islamicChannels.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final c = islamicChannels[i];
        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => onOpen(c),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: AppColors.nightSurface,
              border:
                  Border.all(color: AppColors.gold.withValues(alpha: 0.22)),
            ),
            child: Row(
              children: [
                _Avatar(channel: c, size: 62),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        arabic ? c.nameAr : c.nameEn,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textHigh,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        arabic ? c.descriptionAr : c.descriptionEn,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textLow,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.open_in_new_rounded,
                    size: 18, color: AppColors.textMedium),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ChannelCard extends StatelessWidget {
  final IslamicChannel channel;
  final bool arabic;
  final VoidCallback onTap;

  const _ChannelCard({
    required this.channel,
    required this.arabic,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [AppColors.nightSurface, AppColors.nightElevated],
            ),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.24)),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: IslamicPatternPainter(
                        tile: 44,
                        color: AppColors.gold.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Avatar(channel: channel, size: 84),
                      const SizedBox(height: 10),
                      Text(
                        arabic ? channel.nameAr : channel.nameEn,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textHigh,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        arabic
                            ? channel.descriptionAr
                            : channel.descriptionEn,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textLow,
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                    ],
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

class _Avatar extends StatelessWidget {
  final IslamicChannel channel;
  final double size;

  const _Avatar({required this.channel, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5), width: 1.5),
      ),
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: channel.avatarUrl,
          fit: BoxFit.cover,
          // An honest placeholder rather than a blank hole: the initial on the
          // app's own gold, so a card with no picture yet still reads as that
          // channel.
          placeholder: (_, _) => const ColoredBox(
            color: AppColors.nightElevated,
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          errorWidget: (_, _, _) => const ColoredBox(
            color: AppColors.goldContainer,
            child: Icon(Icons.ondemand_video_rounded,
                color: AppColors.goldSoft),
          ),
        ),
      ),
    );
  }
}
