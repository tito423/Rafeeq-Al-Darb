import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/db/hadeethenc_repository.dart';
import '../../../../core/widgets/error_retry.dart';
import '../../../../app/app_locale_provider.dart';
import '../../data/hadeethenc_providers.dart';
import 'hadeethenc_category_screen.dart';

/// موسوعة الأحاديث النبوية — a collection **beside** the nine books, not
/// inside them.
///
/// The nine collections in `hadith.db` are 67,153 Arabic hadiths that nothing
/// translates. This one is 3,574 curated records where every single row
/// carries a takhrij and a grading **in the reader's own language** — which is
/// the whole reason the owner asked for it: «اهم حاجة ترجمات المواد العلمية
/// خاصة الحديث من مصادرها الموثوقة».
///
/// One pack per language, all seven bundled in the app; the one matching the
/// app's language is unpacked the first time it is opened, so switching the
/// app to French switches this tab to the French pack with no download.
class HadeethEncTab extends ConsumerStatefulWidget {
  const HadeethEncTab({super.key});

  @override
  ConsumerState<HadeethEncTab> createState() => _HadeethEncTabState();
}

class _HadeethEncTabState extends ConsumerState<HadeethEncTab> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300),
        () => mounted ? setState(() => _query = v.trim()) : null);
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(hadeethEncCatalogProvider);
    final repoAsync = ref.watch(hadeethEncRepositoryProvider);

    return catalogAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => ErrorRetry(
          onRetry: () => ref.invalidate(hadeethEncCatalogProvider)),
      data: (catalog) {
        final pack = catalog.forLocale(ref.watch(appLocaleProvider));
        if (pack == null) {
          return _Message(text: 'hadeethenc.no_pack_for_language'.tr());
        }
        return repoAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => ErrorRetry(
              onRetry: () => ref.invalidate(hadeethEncRepositoryProvider)),
          data: (repo) {
            if (repo == null) {
              return _Message(text: 'errors.generic'.tr());
            }
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'hadeethenc.search_hint'.tr(),
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
                Expanded(
                  child: _query.length < 2
                      ? _Categories(
                          repo: repo, catalog: catalog, pack: pack)
                      : _Results(
                          repo: repo,
                          catalog: catalog,
                          pack: pack,
                          query: _query),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _Categories extends StatelessWidget {
  final HadeethEncRepository repo;
  final HadeethEncCatalog catalog;
  final HadeethEncPack pack;

  const _Categories(
      {required this.repo, required this.catalog, required this.pack});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<HadeethCategory>>(
      future: repo.categories(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final cats = snap.data!;
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: cats.length + 1,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            if (i == cats.length) return _Credit(catalog: catalog);
            final c = cats[i];
            return ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(c.title),
              // `library.hadiths_count`, not a second counting key of its
              // own: that one already carries the six CLDR plural cases in
              // all seven locales, and Russian and Arabic both need them.
              subtitle: Text('library.hadiths_count'.plural(c.count)),
              // `chevron_right`, not `chevron_left`: trap #7 — the left one
              // auto-mirrors in RTL and ten of them pointed the wrong way.
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => HadeethEncCategoryScreen(
                    repo: repo,
                    category: c,
                    sourceName: catalog.nameFor(pack.lang),
                    sourceUrl: catalog.sourceUrl,
                    rtl: pack.isRtl,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _Results extends StatelessWidget {
  final HadeethEncRepository repo;
  final HadeethEncCatalog catalog;
  final HadeethEncPack pack;
  final String query;

  const _Results({
    required this.repo,
    required this.catalog,
    required this.pack,
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<HadeethItem>>(
      future: repo.search(query),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final hits = snap.data!;
        if (hits.isEmpty) {
          return _Message(text: 'hadeethenc.no_results'.tr());
        }
        return ListView.separated(
          itemCount: hits.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) => HadeethEncTile(
            item: hits[i],
            sourceName: catalog.nameFor(pack.lang),
            sourceUrl: catalog.sourceUrl,
            rtl: pack.isRtl,
          ),
        );
      },
    );
  }
}

/// The publisher credit the source's own terms require, wherever the
/// collection is shown.
class _Credit extends ConsumerWidget {
  final HadeethEncCatalog catalog;
  const _Credit({required this.catalog});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final locale = ref.watch(appLocaleProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: InkWell(
        onTap: () => launchUrl(Uri.parse(catalog.sourceUrl),
            mode: LaunchMode.externalApplication),
        child: Text(
          'hadeethenc.credit'
              .tr(namedArgs: {'source': catalog.nameFor(locale)}),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  const _Message({required this.text});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
      );
}
