import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/models.dart';
import '../../../../core/db/quran_repository.dart';
import '../../../../core/services/ayah_audio_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/arabic_text.dart';
import '../../data/tajweed_example.dart';

/// «اسمع الحكم في آية» — the card that plays the ayah a rule lives in.
///
/// Lifted whole out of `tajweed_course_screen.dart`, which was retired
/// with the copyrighted book it read. Not one line of it came from that book:
/// it fetches the ayah from the app's own mushaf database and plays it from
/// the recitation the reader has chosen.

class ListenCard extends ConsumerStatefulWidget {
  final TajweedExample example;

  const ListenCard({super.key, required this.example});

  @override
  ConsumerState<ListenCard> createState() => ListenCardState();
}

class ListenCardState extends ConsumerState<ListenCard>
    with SingleTickerProviderStateMixin {
  /// «قسم التجويد خليه تفاعلي وانيمشن». While this card's recitation plays,
  /// the bars move and the words the rule lives in glow — the eye is on the
  /// place in the ayah while the ear hears it.
  late final AnimationController _beat = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  Ayah? _ayah;

  /// Whether the player is running *for this card*. The service is a
  /// singleton shared by the whole app, so its «is something playing» stream
  /// alone would turn every lesson's button into a stop button at once;
  /// `_mine` is what narrows it to the card that started the recitation.
  bool _mine = false;
  bool _audioOn = false;
  StreamSubscription<bool>? _sub;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = AyahAudioService.instance.isPlayingStream.listen((on) {
      if (!mounted) return;
      setState(() {
        _audioOn = on;
        if (!on) _mine = false;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _beat.dispose();
    super.dispose();
  }

  /// Runs the beat only while this card is the one playing.
  void _syncBeat() {
    if (_playing && !_beat.isAnimating) {
      _beat.repeat(reverse: true);
    } else if (!_playing && _beat.isAnimating) {
      _beat.animateTo(0, duration: const Duration(milliseconds: 200));
    }
  }

  Future<void> _load() async {
    final repo = await ref.read(quranRepositoryProvider.future);
    final a = await repo.ayah(widget.example.surah, widget.example.ayah);
    if (mounted) setState(() => _ayah = a);
  }

  bool get _playing => _mine && _audioOn;

  Future<void> _toggle() async {
    final ayah = _ayah;
    if (ayah == null) return;
    if (_playing) {
      await AyahAudioService.instance.stop();
      return;
    }
    setState(() => _mine = true);
    final repo = await ref.read(quranRepositoryProvider.future);
    // The mujawwad reading on purpose: a murattal one is correct but does
    // not let you hear a ghunnah being held.
    await AyahAudioService.instance.play(
      ayah,
      repo,
      edition: AyahAudioService.defaultEdition,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ayah = _ayah;
    _syncBeat();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          AppColors.gold.withValues(alpha: _playing ? 0.18 : 0.10),
          scheme.surfaceContainerHighest,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppColors.gold.withValues(alpha: _playing ? 0.8 : 0.35),
            width: _playing ? 1.6 : 1),
        boxShadow: _playing
            ? [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.25),
                  blurRadius: 16,
                ),
              ]
            : const [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _EqualizerBars(beat: _beat, active: _playing),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  widget.example.listenKey.tr(),
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (ayah != null)
            ArabicText(
              ayah.textUthmani,
              style: const TextStyle(
                fontFamily: 'KFGQPCHafs',
                fontSize: 18,
                height: 2.0,
              ),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              // The words the rule happens in, glowing in time while heard.
              AnimatedBuilder(
                animation: _beat,
                builder: (context, child) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: AppColors.gold
                        .withValues(alpha: _playing ? 0.08 + 0.14 * _beat.value : 0),
                    boxShadow: _playing
                        ? [
                            BoxShadow(
                              color: AppColors.gold
                                  .withValues(alpha: 0.35 * _beat.value),
                              blurRadius: 12,
                            ),
                          ]
                        : const [],
                  ),
                  child: Transform.scale(
                    scale: _playing ? 1 + 0.06 * _beat.value : 1,
                    child: child,
                  ),
                ),
                child: Text(
                  '﴿${widget.example.phrase}﴾',
                  style: TextStyle(
                    fontFamily: 'AmiriQuran',
                    fontSize: 15,
                    color: goldText(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: ayah == null ? null : _toggle,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.black,
                  visualDensity: VisualDensity.compact,
                ),
                icon: Icon(
                    _playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                    size: 18),
                label: Text(_playing
                    ? 'tajweed.stop'.tr()
                    : 'tajweed.listen'.tr()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EqualizerBars extends StatelessWidget {
  final Animation<double> beat;
  final bool active;

  const _EqualizerBars({required this.beat, required this.active});

  @override
  Widget build(BuildContext context) {
    const phases = [0.0, 0.55, 0.2, 0.8, 0.35];
    return SizedBox(
      width: 22,
      height: 18,
      child: AnimatedBuilder(
        animation: beat,
        builder: (context, _) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (final p in phases)
              Container(
                width: 3,
                height: active
                    ? 4 + 14 * (((beat.value + p) % 1.0 - 0.5).abs() * 2)
                    : 6 + 6 * p,
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
