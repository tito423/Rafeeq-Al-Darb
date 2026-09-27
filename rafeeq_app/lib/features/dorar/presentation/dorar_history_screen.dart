import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/digits.dart';
import '../data/dorar_encyclopedia.dart';
import 'dorar_hub_screen.dart' show DorarReadOnSite;

/// «الموسوعة التاريخية» - its seven eras, then each era's events, twenty a
/// page as the site pages them, each opening to its whole text. The site
/// has no contents tree for it (measured 2026-09-27), hence its own reader.
class DorarHistoryScreen extends StatefulWidget {
  const DorarHistoryScreen({super.key});

  @override
  State<DorarHistoryScreen> createState() => _DorarHistoryScreenState();
}

class _DorarHistoryScreenState extends State<DorarHistoryScreen> {
  late final Future<List<DorarSurahRef>> _eras =
      DorarEncyclopediaService.instance.historyEras();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('dorar.enc_history'.tr())),
      body: FutureBuilder<List<DorarSurahRef>>(
        future: _eras,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final eras = snap.data ?? const [];
          if (snap.hasError || eras.isEmpty) {
            return DorarReadOnSite(
              url: DorarEncyclopediaService.instance.url('history'),
              offline: snap.hasError,
            );
          }
          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              for (final e in eras)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: Icon(Icons.history_edu, color: goldText(context)),
                    title: Text(e.title,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => _EraScreen(era: e),
                    )),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _EraScreen extends StatefulWidget {
  const _EraScreen({required this.era});
  final DorarSurahRef era;

  @override
  State<_EraScreen> createState() => _EraScreenState();
}

class _EraScreenState extends State<_EraScreen> {
  final List<DorarHistoryEvent> _events = [];
  int _page = 0;
  int _last = 1;
  bool _busy = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _more();
  }

  Future<void> _more() async {
    if (_busy || (_page >= _last && _page > 0)) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final p = await DorarEncyclopediaService.instance
          .historyPage(widget.era.number, _page + 1);
      if (!mounted) return;
      setState(() {
        _page++;
        _last = p.lastPage;
        _events.addAll(p.events);
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final scheme = Theme.of(context).colorScheme;
    final url =
        'https://dorar.net/history?era=${widget.era.number}';
    return Scaffold(
      appBar: AppBar(title: Text(widget.era.title)),
      body: _events.isEmpty && !_busy
          ? DorarReadOnSite(url: url, offline: _failed)
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              children: [
                for (final e in _events)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    clipBehavior: Clip.antiAlias,
                    child: ExpansionTile(
                      shape: const Border(),
                      title: Text(e.title,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        localizeDigits(
                            '${'dorar.hijri_year'.tr()}: ${e.hijri}   '
                            '${'dorar.gregorian_year'.tr()}: ${e.gregorian}',
                            lang),
                        style: TextStyle(color: goldText(context), fontSize: 12.5),
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final d in e.details)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: SelectableText(d,
                                style: const TextStyle(fontSize: 16, height: 1.85)),
                          ),
                        Text('https://dorar.net/history/event/${e.id}',
                            style: TextStyle(
                                fontSize: 11, color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_page < _last)
                  Center(
                    child: TextButton.icon(
                      onPressed: _more,
                      icon: const Icon(Icons.expand_more),
                      label: Text('dorar.more'.tr()),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${'dorar.section_credit'.tr()}\n$url',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11.5, color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
    );
  }
}
