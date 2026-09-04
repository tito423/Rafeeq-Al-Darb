import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/services/ayah_audio_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../quran/data/mushaf_data_provider.dart';

/// P3‑27: "خليه في كارت صغير تحت القايمة المنسدلة مباشرة" (a small card
/// right under the reciter dropdown) offering to download the reciter's
/// **whole** recitation in one action — before this, downloading was only
/// possible one surah at a time from the list below. Downloads
/// sequentially (not all 114 at once — kinder to the device and the
/// network) and reuses `AyahAudioService.downloadSurah`'s own per-ayah
/// resume logic, so re-running it after a partial/cancelled run just picks
/// up where it left off instead of re-downloading anything already on disk.
///
/// Originally private to `downloads_screen.dart`; pulled out to a public
/// widget (P3‑21) so the first-run onboarding screen can offer the exact
/// same real "essential recitation download" (G5) instead of a second,
/// thinner copy.
class FullRecitationCard extends StatefulWidget {
  final String edition;
  final MushafData data;
  final VoidCallback onFinished;
  const FullRecitationCard({
    super.key,
    required this.edition,
    required this.data,
    required this.onFinished,
  });

  @override
  State<FullRecitationCard> createState() => _FullRecitationCardState();
}

class _FullRecitationCardState extends State<FullRecitationCard> {
  final _audio = AyahAudioService.instance;
  bool _checkingStatus = true;
  bool _running = false;
  bool _cancelled = false;
  int _doneSurahs = 0;
  int _totalSurahs = 0;
  int? _currentSurahId;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  @override
  void didUpdateWidget(covariant FullRecitationCard old) {
    super.didUpdateWidget(old);
    if (old.edition != widget.edition) {
      // Switched reciters mid-run: stop the old loop and, if a file for the
      // old edition was actually in flight, cancel it immediately rather
      // than letting it finish in the background.
      _cancelled = true;
      final id = _currentSurahId;
      if (id != null) _audio.cancelDownload(old.edition, id);
      _running = false;
      _currentSurahId = null;
      _refreshStatus();
    }
  }

  Future<void> _refreshStatus() async {
    setState(() => _checkingStatus = true);
    final surahs = widget.data.surahs;
    var done = 0;
    for (final s in surahs) {
      final p = await _audio.surahProgress(
          s.id, s.ayahsCount, widget.data.repo,
          edition: widget.edition);
      if (p.isComplete) done++;
    }
    if (!mounted) return;
    setState(() {
      _doneSurahs = done;
      _totalSurahs = surahs.length;
      _checkingStatus = false;
    });
  }

  Future<void> _downloadAll() async {
    setState(() {
      _running = true;
      _cancelled = false;
    });
    final surahs = widget.data.surahs;
    for (var i = 0; i < surahs.length; i++) {
      if (_cancelled) break;
      final s = surahs[i];
      if (!mounted) return;
      setState(() => _currentSurahId = s.id);
      await _audio.downloadSurah(
        surah: s.id,
        ayahCount: s.ayahsCount,
        repo: widget.data.repo,
        edition: widget.edition,
        title: '${s.id}. ${s.nameAr}',
      );
      if (!mounted) return;
      setState(() => _doneSurahs = i + 1);
    }
    if (!mounted) return;
    setState(() {
      _running = false;
      _currentSurahId = null;
    });
    widget.onFinished();
  }

  void _cancel() {
    setState(() => _cancelled = true);
    final id = _currentSurahId;
    if (id != null) _audio.cancelDownload(widget.edition, id);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_checkingStatus) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: LinearProgressIndicator(),
      );
    }

    final complete = _totalSurahs > 0 && _doneSurahs >= _totalSurahs;

    return Card(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              complete
                  ? Icons.offline_pin
                  : Icons.download_for_offline_outlined,
              color: complete ? AppColors.success : AppColors.gold,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('downloads.download_all_recitation'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  if (_running)
                    LinearProgressIndicator(
                      value: _totalSurahs == 0 ? null : _doneSurahs / _totalSurahs,
                      color: AppColors.gold,
                    )
                  else
                    Text(
                      complete
                          ? 'downloads.offline_ready'.tr()
                          : '$_doneSurahs / $_totalSurahs ${'quran.surah'.tr()}',
                      style: TextStyle(
                          color: scheme.onSurfaceVariant, fontSize: 12),
                    ),
                ],
              ),
            ),
            if (!complete)
              _running
                  ? IconButton(
                      tooltip: 'downloads.cancel'.tr(),
                      icon: const Icon(Icons.stop_circle_outlined),
                      onPressed: _cancel,
                    )
                  : FilledButton.tonal(
                      onPressed: _downloadAll,
                      child: Text('downloads.download'.tr()),
                    ),
          ],
        ),
      ),
    );
  }
}
