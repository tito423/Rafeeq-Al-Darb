/// «تلاوات آية بآية» — per-ayah recitation downloads, redesigned.
///
/// «تلاوة اية باية غير تصميمها لانها اصلا مش بتعرض هو بيحمل». The first
/// version was one card per reciter with a single «download all 6,236 ayahs»
/// button and a bar: it never showed WHAT was on the phone, a surah could not
/// be taken on its own, and nothing downloaded could be played from here. So:
///
///  * the reciters list shows, for each, a ring of how much is on the phone
///    and how many surahs are complete;
///  * a reciter opens onto his 114 surahs, each with its own ring, its own
///    download button, and a listen button that plays it ayah by ayah — from
///    the files on the phone when they are there (`RecitationSource.urlsFor`
///    prefers the local file), so a complete surah plays offline.
library;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/digits.dart';
import '../../downloads/data/reciters_provider.dart';
import '../data/ayah_recitation_library.dart';
import 'ayah_reciter_screen.dart';
import 'widgets/ayah_dl_ring.dart';

class AyahDownloadScreen extends StatefulWidget {
  const AyahDownloadScreen({super.key});

  @override
  State<AyahDownloadScreen> createState() => _AyahDownloadScreenState();
}

class _AyahDownloadScreenState extends State<AyahDownloadScreen> {
  @override
  void initState() {
    super.initState();
    AyahRecitationLibrary.instance.ensureReady();
    AyahRecitationLibrary.instance.addListener(_rebuild);
  }

  @override
  void dispose() {
    AyahRecitationLibrary.instance.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final lib = AyahRecitationLibrary.instance;
    final available = AyahRecitationLibrary.availableEditions.toSet();
    final locale = context.locale.languageCode;

    return Scaffold(
      appBar: AppBar(title: Text('ayah_dl.title'.tr())),
      body: Consumer(
        builder: (context, ref, _) {
          final recitersAsync = ref.watch(recitersProvider);
          return recitersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(child: Text('ayah_dl.error'.tr())),
            data: (all) {
              final reciters =
                  all.where((r) => available.contains(r.identifier)).toList()
                    // What is already on the phone first.
                    ..sort((a, b) => lib
                        .downloadedCount(b.identifier)
                        .compareTo(lib.downloadedCount(a.identifier)));
              if (reciters.isEmpty) {
                return Center(child: Text('ayah_dl.no_reciters'.tr()));
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
                itemCount: reciters.length + 1,
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        'ayah_dl.choose_reciter'.tr(),
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant),
                      ),
                    );
                  }
                  final r = reciters[i - 1];
                  return _ReciterTile(
                    reciter: r,
                    locale: locale,
                    onOpen: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AyahReciterScreen(reciter: r),
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

class _ReciterTile extends StatelessWidget {
  final Reciter reciter;
  final String locale;
  final VoidCallback onOpen;

  const _ReciterTile({
    required this.reciter,
    required this.locale,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final lib = AyahRecitationLibrary.instance;
    final scheme = Theme.of(context).colorScheme;
    final downloaded = lib.downloadedCount(reciter.identifier);
    var complete = 0;
    if (downloaded > 0) {
      for (var s = 1; s <= 114; s++) {
        if (lib.surahDownloadedCount(reciter.identifier, s) ==
            AyahRecitationLibrary.ayahCount(s)) {
          complete++;
        }
      }
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              AyahDlRing(
                value: downloaded / AyahRecitationLibrary.totalAyahs,
                locale: locale,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(reciter.displayName(locale),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      'ayah_dl.surahs_done'
                          .tr(args: [localizeDigits('$complete', locale)]),
                      style: TextStyle(
                          fontSize: 12.5, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
