import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/external_link.dart';
import '../../../core/utils/screen_class.dart';
import '../data/dorar_encyclopedia.dart';
import 'dorar_history_screen.dart';
import 'dorar_screen.dart';
import 'dorar_search_screen.dart';
import 'dorar_tafseer_screen.dart';

/// «الدرر السنية» inside the app: hadith grading and every encyclopaedia of
/// dorar.net, read live with its own table of contents (owner, 2026-09-26:
/// «الموقع ده قيم جدا … يبقى فيه واجهة محترمة»).
class DorarHubScreen extends StatelessWidget {
  const DorarHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tiles = <Widget>[
      // «بحث عام في الدرر كلها» (owner, 2026-09-27): first, above the
      // encyclopaedias it searches.
      _Tile(
        icon: Icons.manage_search,
        title: 'dorar.search_all'.tr(),
        subtitle: 'dorar.search_all_sub'.tr(),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const DorarSearchScreen())),
      ),
      _Tile(
        icon: Icons.fact_check_outlined,
        title: 'dorar.title'.tr(),
        subtitle: 'dorar.grading_sub'.tr(),
        onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const DorarScreen())),
      ),
      // The Tafseer encyclopaedia has its own reader (surah list + the
      // site's previous/next chain), not the contents tree of the others.
      _Tile(
        icon: Icons.menu_book_outlined,
        title: 'dorar.enc_tafseer'.tr(),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const DorarTafseerScreen())),
      ),
      _Tile(
        icon: Icons.history_edu,
        title: 'dorar.enc_history'.tr(),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const DorarHistoryScreen())),
      ),
      for (final e in dorarEncyclopedias)
        _Tile(
          icon: Icons.menu_book_outlined,
          title: e.titleKey.tr(),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => DorarTocScreen(encyclopedia: e))),
        ),
    ];
    return Scaffold(
      appBar: AppBar(title: Text('dorar.hub_title'.tr())),
      body: GridView.count(
        padding: const EdgeInsets.all(14),
        crossAxisCount: ScreenClass.twoColumns(context) ? 3 : 1,
        childAspectRatio: ScreenClass.twoColumns(context) ? 2.6 : 4.2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        children: [
          ...tiles,
          Center(
            child: Text('dorar.hub_credit'.tr(),
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(
      {required this.icon, required this.title, this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(children: [
              CircleAvatar(
                backgroundColor: AppColors.gold.withValues(alpha: 0.15),
                child: Icon(icon, color: goldText(context)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (subtitle != null)
                      Text(subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ]),
          ),
        ),
      );
}

/// An encyclopaedia's table of contents as a tree (folders open in place).
class DorarTocScreen extends StatefulWidget {
  const DorarTocScreen({super.key, required this.encyclopedia});
  final DorarEncyclopedia encyclopedia;

  @override
  State<DorarTocScreen> createState() => _DorarTocScreenState();
}

class _DorarTocScreenState extends State<DorarTocScreen> {
  late Future<List<DorarTocNode>> _toc =
      DorarEncyclopediaService.instance.toc(widget.encyclopedia.slug);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.encyclopedia.titleKey.tr())),
      body: FutureBuilder<List<DorarTocNode>>(
        future: _toc,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('dorar.failed'.tr(), textAlign: TextAlign.center),
                const SizedBox(height: 10),
                FilledButton.tonal(
                  onPressed: () => setState(() => _toc = DorarEncyclopediaService
                      .instance
                      .toc(widget.encyclopedia.slug)),
                  child: Text('common.retry'.tr()),
                ),
              ]),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          // Read but nothing parsed: the page changed (or never had the
          // tree - /tafseer and /history, seen EMPTY on the owner's Xiaomi,
          // 2026-09-27). Never a blank screen: say so, offer the site.
          if (snap.data!.isEmpty) {
            return DorarReadOnSite(
              url: DorarEncyclopediaService.instance
                  .url(widget.encyclopedia.slug),
            );
          }
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              for (final n in snap.data!)
                _TocNodeView(node: n, slug: widget.encyclopedia.slug, depth: 0),
            ],
          );
        },
      ),
    );
  }
}

class _TocNodeView extends StatelessWidget {
  const _TocNodeView(
      {required this.node, required this.slug, required this.depth});
  final DorarTocNode node;
  final String slug;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final indent = EdgeInsetsDirectional.only(start: 12.0 + depth * 14);
    if (node.isSection) {
      return ListTile(
        contentPadding: indent,
        dense: true,
        leading: Icon(Icons.article_outlined, color: goldText(context), size: 20),
        title: Text(node.title),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) =>
              DorarSectionScreen(slug: slug, id: node.id!, title: node.title),
        )),
      );
    }
    return ExpansionTile(
      tilePadding: indent,
      leading: Icon(Icons.folder_outlined, color: goldText(context), size: 20),
      title: Text(node.title,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      shape: const Border(),
      collapsedShape: const Border(),
      children: [
        for (final c in node.children)
          _TocNodeView(node: c, slug: slug, depth: depth + 1),
      ],
    );
  }
}

/// One section, read in the app: headings, text, footnotes, and where it
/// came from.
class DorarSectionScreen extends StatelessWidget {
  const DorarSectionScreen(
      {super.key, required this.slug, required this.id, required this.title});
  final String slug;
  final int id;
  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: FutureBuilder<DorarSection?>(
        future: DorarEncyclopediaService.instance.section(slug, id),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final s = snap.data;
          if (snap.hasError || s == null) {
            return DorarReadOnSite(
              url: DorarEncyclopediaService.instance.url(slug, id),
              offline: snap.hasError,
            );
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
                children: [
                  Text(s.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: goldText(context))),
                  const SizedBox(height: 10),
                  for (final p in s.paras)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SelectableText(
                        p.text,
                        style: TextStyle(
                          fontSize: p.heading ? 17 : 16.5,
                          height: 1.9,
                          fontWeight:
                              p.heading ? FontWeight.w800 : FontWeight.normal,
                          color: p.heading ? goldText(context) : null,
                        ),
                      ),
                    ),
                  if (s.footnotes.isNotEmpty) ...[
                    const Divider(height: 28),
                    for (var i = 0; i < s.footnotes.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: SelectableText('(${i + 1}) ${s.footnotes[i]}',
                            style: TextStyle(
                                fontSize: 13.5,
                                height: 1.7,
                                color: scheme.onSurfaceVariant)),
                      ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    '${'dorar.section_credit'.tr()}\n${DorarEncyclopediaService.instance.url(slug, id)}',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}


/// Shown when a Dorar page could not be read here: offline, or the site's
/// layout no longer matches the rules (SourceRules) - the reader is sent to
/// the page itself instead of being left on an empty screen.
class DorarReadOnSite extends StatelessWidget {
  const DorarReadOnSite({super.key, required this.url, this.offline = false});
  final String url;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(offline ? Icons.wifi_off_rounded : Icons.travel_explore,
              size: 44, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 14),
          Text(
            (offline ? 'dorar.failed' : 'dorar.read_on_site_msg').tr(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => openExternalLink(url),
            icon: const Icon(Icons.open_in_new),
            label: Text('dorar.read_on_site'.tr()),
          ),
        ]),
      ),
    );
  }
}
