import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/digits.dart';
import '../data/dorar_encyclopedia.dart';
import 'dorar_hub_screen.dart' show DorarReadOnSite;

/// «موسوعة التفسير» - the 114 surahs, then each surah read part by part.
/// Unlike the other encyclopaedias it has no contents tree: its front page
/// is a grid of surah cards and every page links only to the page before
/// and after it (measured 2026-09-27), so the reader follows that chain.
class DorarTafseerScreen extends StatefulWidget {
  const DorarTafseerScreen({super.key});

  @override
  State<DorarTafseerScreen> createState() => _DorarTafseerScreenState();
}

class _DorarTafseerScreenState extends State<DorarTafseerScreen> {
  late Future<List<DorarSurahRef>> _surahs =
      DorarEncyclopediaService.instance.tafseerSurahs();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('dorar.enc_tafseer'.tr())),
      body: FutureBuilder<List<DorarSurahRef>>(
        future: _surahs,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data ?? const [];
          if (snap.hasError || list.isEmpty) {
            return Column(mainAxisSize: MainAxisSize.min, children: [
              Expanded(
                child: DorarReadOnSite(
                  url: DorarEncyclopediaService.instance.url('tafseer'),
                  offline: snap.hasError,
                ),
              ),
              if (snap.hasError)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: TextButton(
                    onPressed: () => setState(() => _surahs =
                        DorarEncyclopediaService.instance.tafseerSurahs()),
                    child: Text('common.retry'.tr()),
                  ),
                ),
            ]);
          }
          final lang = context.locale.languageCode;
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final s = list[i];
              return ListTile(
                leading: CircleAvatar(
                  radius: 17,
                  backgroundColor: AppColors.gold.withValues(alpha: 0.15),
                  child: Text(localizeDigits('${s.number}', lang),
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: goldText(context))),
                ),
                title: Text(s.title),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => DorarChainScreen(
                    slug: 'tafseer',
                    path: '/tafseer/${s.number}',
                  ),
                )),
              );
            },
          );
        },
      ),
    );
  }
}

/// One page of a chained encyclopaedia, with «السابق» / «التالي» taking the
/// reader along the site's own order (a surah's introduction, then its
/// ayah ranges, then the next surah).
class DorarChainScreen extends StatefulWidget {
  const DorarChainScreen({super.key, required this.slug, required this.path});
  final String slug;
  final String path;

  @override
  State<DorarChainScreen> createState() => _DorarChainScreenState();
}

class _DorarChainScreenState extends State<DorarChainScreen> {
  late String _path = widget.path;
  late Future<DorarChainPage?> _page = _load();
  final _scroll = ScrollController();

  Future<DorarChainPage?> _load() =>
      DorarEncyclopediaService.instance.chainPage(_path, widget.slug);

  void _go(String path) {
    setState(() {
      _path = path;
      _page = _load();
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<DorarChainPage?>(
      future: _page,
      builder: (context, snap) {
        final p = snap.data;
        return Scaffold(
          appBar: AppBar(
            title: Text(p?.title ?? 'dorar.enc_tafseer'.tr(),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          bottomNavigationBar: p == null
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                    child: Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: p.prev == null ? null : () => _go(p.prev!),
                          icon: const Icon(Icons.arrow_back, size: 18),
                          label: Text('library.previous'.tr()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: p.next == null ? null : () => _go(p.next!),
                          icon: const Icon(Icons.arrow_forward, size: 18),
                          label: Text('library.next'.tr()),
                        ),
                      ),
                    ]),
                  ),
                ),
          body: () {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError || p == null) {
              return DorarReadOnSite(
                url: 'https://dorar.net$_path',
                offline: snap.hasError,
              );
            }
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
                  children: [
                    for (final x in p.paras)
                      Padding(
                        padding: EdgeInsets.only(
                            top: x.heading ? 8 : 0, bottom: 10),
                        child: SelectableText(
                          x.text,
                          style: TextStyle(
                            fontSize: x.heading ? 17.5 : 16.5,
                            height: 1.9,
                            fontWeight: x.heading
                                ? FontWeight.w800
                                : FontWeight.normal,
                            color: x.heading ? goldText(context) : null,
                          ),
                        ),
                      ),
                    if (p.footnotes.isNotEmpty) ...[
                      const Divider(height: 28),
                      for (var i = 0; i < p.footnotes.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: SelectableText('(${i + 1}) ${p.footnotes[i]}',
                              style: TextStyle(
                                  fontSize: 13.5,
                                  height: 1.7,
                                  color: scheme.onSurfaceVariant)),
                        ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      '${'dorar.section_credit'.tr()}\nhttps://dorar.net$_path',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11.5, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            );
          }(),
        );
      },
    );
  }
}
