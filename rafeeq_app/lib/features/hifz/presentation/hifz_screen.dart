/// «التحفيظ والتسميع» — pick a surah and a range, then work through it.
///
/// The owner asked for this on 2026-09-22, remembering an app that «بيعمل
/// طريقة لفظ القرآن الكريم». This is the first half of it, which needs no
/// speech recognition: listen to the ayah as many times as you choose, hide
/// its words one by one, say it, then tell the app whether it is memorized.
/// What the app keeps is a review date per ayah (`hifz_store.dart`).
///
/// The ayah text and the recitation are the app's existing ones — the local
/// mushaf database and the per-ayah recitation the reader already uses — so
/// nothing new is downloaded and nothing is written by the app itself.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/user_error.dart';
import '../../../core/db/models.dart';
import '../../../core/db/quran_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/arabic_normalize.dart' show surahNamePlain;
import '../../../core/utils/digits.dart';
import '../data/hifz_store.dart';
import 'hifz_session_screen.dart';
import 'widgets/hifz_plans_section.dart';
import '../../tutorial/data/tutorial_anchors.dart';

final _surahsProvider = FutureProvider<List<Surah>>((ref) async {
  final repo = await ref.watch(quranRepositoryProvider.future);
  return repo.surahs();
});

class HifzScreen extends ConsumerWidget {
  const HifzScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surahs = ref.watch(_surahsProvider);
    final state = ref.watch(hifzStoreProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text('hifz.title'.tr())),
      body: surahs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(userErrorText(e))),
        data: (list) => ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
          itemCount: list.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _intro(context, state, scheme),
                  TutorialAnchor(
                    id: TourAnchor.hifzPlans,
                    child: HifzPlansSection(surahs: list),
                  ),
                ],
              );
            }
            final s = list[i - 1];
            final due = state.dueIn(s.id, s.ayahsCount).length;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.gold.withValues(alpha: 0.15),
                  child: Text(
                    localizeDigits('${s.id}', context.locale.languageCode),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                title: Text(surahNamePlain(s.nameAr)),
                subtitle: Text(
                  trn('hifz.due_count', args: ['$due', '${s.ayahsCount}']),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => HifzSessionScreen.surah(s),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _intro(BuildContext context, HifzState state, ColorScheme scheme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'hifz.intro'.tr(),
              style: TextStyle(height: 1.7, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 18,
                  color: goldText(context),
                ),
                const SizedBox(width: 6),
                Text(
                  trn('hifz.progress', args: ['${state.started}']),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
