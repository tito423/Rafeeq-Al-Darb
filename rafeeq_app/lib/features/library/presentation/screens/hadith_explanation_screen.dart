import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/hadeethenc_repository.dart';
import '../../../../core/widgets/arabic_text.dart';
import '../../../hadeethenc/data/hadeethenc_providers.dart';
import '../../../hadeethenc/presentation/screens/hadeethenc_detail_screen.dart';

/// Candidate explanations for a hadith, from the Hadeeth Encyclopaedia.
///
/// The nine books the app ships carry no published explanation — the app is
/// not going to invent one, and «لا يوجد شرح» is a truthful answer (§1.2).
/// The Encyclopaedia **does** carry one per hadith, with its own grading and
/// source, and its packs are already in the app.
///
/// So this connects the two without the app asserting anything it cannot
/// verify. It searches the Encyclopaedia for the opening of this hadith's
/// matn and shows **whatever it finds, as candidates**. The reader decides
/// which is the same hadith; the app never picks one and calls it a match.
/// Matching a hadith across two collections by text is not reliable enough to
/// do silently — the cost of getting it wrong is an explanation attached to
/// the wrong words of the Prophet ﷺ.
class HadithExplanationScreen extends ConsumerWidget {
  /// The distinctive opening of the matn, from `matnQuery`.
  final String query;

  const HadithExplanationScreen({super.key, required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repoAsync = ref.watch(hadeethEncRepositoryProvider);
    final catalog = ref.watch(hadeethEncCatalogProvider).valueOrNull;
    final pack = ref.watch(hadeethEncPackProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: Text('hadith_daily.explain_title'.tr())),
      body: repoAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text('errors.generic'.tr())),
        data: (repo) {
          if (repo == null) {
            // Every pack ships inside the app, so this is only reachable if
            // the bundled zip would not unpack — a real failure, said as one.
            return Center(child: Text('errors.generic'.tr()));
          }
          return FutureBuilder<List<HadeethItem>>(
            // searchArabic, not search: the query is an Arabic matn and a
            // non-Arabic pack's `search` column holds the translation.
            future: repo.searchArabic(query, limit: 20),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = snap.data ?? const <HadeethItem>[];
              if (items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(28),
                  child: Center(
                    child: Text(
                      'hadith_daily.explain_none'.tr(),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: items.length + 1,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  if (i == 0) {
                    // The honest header: these are candidates, not a verdict.
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 14),
                      child: Text(
                        'hadith_daily.explain_candidates'.tr(),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    );
                  }
                  final h = items[i - 1];
                  return ListTile(
                    title: ArabicText(h.title),
                    subtitle: h.grade.isEmpty ? null : Text(h.grade),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => HadeethEncDetailScreen(
                          item: h,
                          // Same attribution the Encyclopaedia's own tab
                          // shows - the explanation is credited where it
                          // comes from, wherever it is reached from.
                          sourceName: catalog?.nameFor(pack?.lang ?? 'ar') ?? '',
                          sourceUrl: catalog?.sourceUrl ?? '',
                          rtl: pack?.isRtl ?? true,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
