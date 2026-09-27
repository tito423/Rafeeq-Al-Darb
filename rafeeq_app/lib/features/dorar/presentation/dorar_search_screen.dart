import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/byte_formatter.dart' show ratio;
import '../../../core/utils/digits.dart';
import '../data/dorar_encyclopedia.dart';
import '../data/dorar_search.dart';
import 'dorar_hub_screen.dart' show DorarSectionScreen;

/// One search over the contents of all nine tree encyclopaedias
/// ([searchDorarSections]). The contents pages are the ones each
/// encyclopaedia's own screen already caches for a week, fetched here side
/// by side; after the first time the search is offline and instant.
class DorarSearchScreen extends StatefulWidget {
  const DorarSearchScreen({super.key, this.initialQuery});
  final String? initialQuery;

  @override
  State<DorarSearchScreen> createState() => _DorarSearchScreenState();
}

class _DorarSearchScreenState extends State<DorarSearchScreen> {
  final _controller = TextEditingController();
  final List<(DorarSectionHit, String)> _all = [];
  List<DorarSectionHit> _results = const [];
  Timer? _debounce;
  int _loaded = 0;
  int _failed = 0;

  bool get _done => _loaded + _failed == dorarEncyclopedias.length;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialQuery ?? '';
    for (final e in dorarEncyclopedias) {
      unawaited(_load(e));
    }
  }

  Future<void> _load(DorarEncyclopedia e) async {
    try {
      final toc = await DorarEncyclopediaService.instance.toc(e.slug);
      _all.addAll(flattenDorarToc(e, toc));
      _loaded++;
    } catch (_) {
      _failed++;
    }
    if (mounted) setState(() => _results = _search(_controller.text));
  }

  List<DorarSectionHit> _search(String q) => searchDorarSections(_all, q);

  void _onQuery(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _results = _search(q));
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final scheme = Theme.of(context).colorScheme;
    final query = _controller.text.trim();
    return Scaffold(
      appBar: AppBar(title: Text('dorar.search_all'.tr())),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: TextField(
              controller: _controller,
              autofocus: widget.initialQuery == null,
              textInputAction: TextInputAction.search,
              onChanged: _onQuery,
              decoration: InputDecoration(
                hintText: 'dorar.search_all_hint'.tr(),
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          if (!_done)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(children: [
                LinearProgressIndicator(
                    value: (_loaded + _failed) / dorarEncyclopedias.length),
                const SizedBox(height: 6),
                Text(localizeDigits(
                    'dorar.search_all_loading'.tr(args: [
                      ratio(_loaded + _failed, dorarEncyclopedias.length),
                    ]),
                    lang)),
              ]),
            ),
          if (_done && _failed > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                  localizeDigits(
                      'dorar.search_all_failed'.tr(args: ['$_failed']), lang),
                  style: TextStyle(color: scheme.error)),
            ),
          if (_done && query.isNotEmpty && _results.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('dorar.search_all_none'.tr()),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
              itemCount: _results.length,
              itemBuilder: (context, i) {
                final h = _results[i];
                final where = [h.encyclopedia.titleKey.tr(), h.path]
                    .where((s) => s.isNotEmpty)
                    .join(' › ');
                return Card(
                  child: ListTile(
                    title: Text(h.title),
                    subtitle: Text(where,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => DorarSectionScreen(
                            slug: h.encyclopedia.slug,
                            id: h.id,
                            title: h.title),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
