import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/models.dart';
import '../../../../core/db/quran_repository.dart';
import '../../../../core/db/sciences_repository.dart';
import '../../../../core/services/ayah_audio_service.dart';

/// "علوم الآية" — real tafsir, i'rab (grammar) and word meanings for an ayah,
/// served straight from the bundled quran_sciences.db.
class AyahSciencesSheet extends ConsumerStatefulWidget {
  final Ayah ayah;
  final String surahNameAr;
  final QuranRepository quranRepo;

  const AyahSciencesSheet({
    super.key,
    required this.ayah,
    required this.surahNameAr,
    required this.quranRepo,
  });

  static Future<void> show(
    BuildContext context, {
    required Ayah ayah,
    required String surahNameAr,
    required QuranRepository quranRepo,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => AyahSciencesSheet(
        ayah: ayah,
        surahNameAr: surahNameAr,
        quranRepo: quranRepo,
      ),
    );
  }

  @override
  ConsumerState<AyahSciencesSheet> createState() => _AyahSciencesSheetState();
}

class _AyahSciencesSheetState extends ConsumerState<AyahSciencesSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  Future<Map<String, String>>? _tafseer;
  Future<List<WordGrammar>>? _grammar;
  Future<List<WordMeaning>>? _meanings;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(sciencesRepositoryProvider.future);
    _tafseer = repo.then(
        (r) => r.tafseerForAyah(widget.ayah.surahId, widget.ayah.ayahNumber));
    _grammar = repo.then(
        (r) => r.wordGrammar(widget.ayah.surahId, widget.ayah.ayahNumber));
    _meanings = repo.then(
        (r) => r.wordMeanings(widget.ayah.surahId, widget.ayah.ayahNumber));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ayah = widget.ayah;

    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.82,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Icon(Icons.auto_stories, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${widget.surahNameAr} — ${'quran.ayah'.tr()} '
                      '${ayah.ayahNumber} (${'quran.page'.tr()} '
                      '${ayah.pageNumber})',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'quran.play'.tr(),
                    icon: const Icon(Icons.play_circle_outline),
                    onPressed: () => AyahAudioService.instance.play(
                      ayah,
                      widget.quranRepo,
                    ),
                  ),
                  IconButton(
                    tooltip: 'quran.stop'.tr(),
                    icon: const Icon(Icons.stop_circle_outlined),
                    onPressed: AyahAudioService.instance.stop,
                  ),
                  IconButton(
                    tooltip: 'quran.copy'.tr(),
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: ayah.textUthmani));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('quran.copy'.tr()),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text(
                ayah.textUthmani,
                textAlign: TextAlign.right,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontFamily: 'AmiriQuran',
                  height: 1.9,
                ),
              ),
            ),
            const Divider(height: 1),
            TabBar(
              controller: _tabs,
              tabs: [
                Tab(text: 'quran.tafseer'.tr()),
                Tab(text: 'quran.irab'.tr()),
                Tab(text: 'quran.meanings'.tr()),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _TafseerTab(future: _tafseer!),
                  _IrabTab(future: _grammar!),
                  _MeaningsTab(future: _meanings!),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}