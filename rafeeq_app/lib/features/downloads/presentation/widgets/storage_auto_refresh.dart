import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/download_manager.dart';
import '../../../../core/services/mushaf_page_service.dart';
import '../../../quran_audio/data/quran_audio_library.dart';
import '../../data/downloads_controller.dart';

/// Re-reads the totals while downloads move, so the overview is never a
/// snapshot of when the screen opened — «الـ UI بتاع التنزيلات يتحدث تلقائيًا
/// لكل تحميل». At most every two seconds: the totals walk six page folders.
class StorageAutoRefresh extends ConsumerStatefulWidget {
  const StorageAutoRefresh({super.key});

  @override
  ConsumerState<StorageAutoRefresh> createState() => StorageAutoRefreshState();
}

class StorageAutoRefreshState extends ConsumerState<StorageAutoRefresh> {
  StreamSubscription<List<DownloadTask>>? _sub;
  Timer? _timer;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _sub = DownloadManager.instance.stream.listen((_) => _poke());
    QuranAudioLibrary.instance.addListener(_poke);
    MushafPageService.instance.changes.addListener(_poke);
  }

  void _poke() {
    if (_timer != null) return;
    final wait = const Duration(seconds: 2) - DateTime.now().difference(_last);
    _timer = Timer(wait.isNegative ? Duration.zero : wait, () {
      _timer = null;
      _last = DateTime.now();
      if (mounted) ref.invalidate(storageSummaryProvider);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    QuranAudioLibrary.instance.removeListener(_poke);
    MushafPageService.instance.changes.removeListener(_poke);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
