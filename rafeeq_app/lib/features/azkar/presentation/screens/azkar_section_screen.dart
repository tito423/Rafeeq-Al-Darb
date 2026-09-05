// easy_localization re-exports package:intl, whose `TextDirection` (LTR/RTL)
// collides with the `dart:ui` enum (rtl/ltr) this file uses for swipe
// direction — see the identical fix in ayah_sciences_sheet.dart.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/models.dart';
import '../../../../core/db/sciences_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/azkar_repeat.dart';
import '../../data/azkar_settings_provider.dart';

/// One section's adhkar, one at a time — a real tap-to-count counter per
/// dhikr (counts on the very first tap, not only after a reset — WORK_QUEUE
/// Stage 3 flags that as a real bug from an older build), auto-advancing to
/// the next dhikr once its real repeat count (parsed from the actual text,
/// see `azkar_repeat.dart`) is reached.
class AzkarSectionScreen extends ConsumerStatefulWidget {
  final AzkarSection section;

  const AzkarSectionScreen({super.key, required this.section});

  @override
  ConsumerState<AzkarSectionScreen> createState() => _AzkarSectionScreenState();
}

class _AzkarSectionScreenState extends ConsumerState<AzkarSectionScreen> {
  List<AzkarItem>? _items;
  int _index = 0;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    ref.read(sciencesRepositoryProvider.future).then((repo) async {
      final items = await repo.azkarItems(widget.section.id);
      if (mounted) setState(() => _items = items);
    });
  }

  int get _target =>
      _items == null ? 1 : parseAzkarRepeatCount(_items![_index].body);

  void _tap() {
    final haptics = ref.read(azkarSettingsProvider).haptics;
    setState(() => _count++);
    if (_count >= _target) {
      if (haptics) HapticFeedback.mediumImpact();
      Future.delayed(const Duration(milliseconds: 350), _advance);
    } else if (haptics) {
      HapticFeedback.lightImpact();
    }
  }

  void _advance() {
    if (!mounted || _items == null) return;
    if (_index < _items!.length - 1) {
      setState(() {
        _index++;
        _count = 0;
      });
    } else {
      setState(() => _index++); // past the end -> "section done" view
    }
  }

  void _goTo(int i) {
    setState(() {
      _index = i.clamp(0, _items!.length);
      _count = 0;
    });
  }

  /// P3‑11: the previous/next controls used to be two arrow buttons at the
  /// bottom of the screen; the owner asked for them gone in favour of a
  /// swipe, in the direction that matches the app's current reading
  /// direction rather than a fixed "swipe left = next" assumption — for
  /// Arabic (RTL) a rightward swipe (`primaryVelocity > 0`) is "forward"
  /// (matches how the mushaf pager already turns pages under RTL), for an
  /// LTR locale it's the mirror image.
  void _onSwipe(DragEndDetails details, TextDirection direction) {
    final v = details.primaryVelocity ?? 0;
    if (v.abs() < 200) return; // ignore a slow drag/near-tap
    final isNext = direction == TextDirection.rtl ? v > 0 : v < 0;
    if (isNext) {
      _goTo(_index + 1);
    } else if (_index > 0) {
      _goTo(_index - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final items = _items;

    return Scaffold(
      appBar: AppBar(title: Text(widget.section.title)),
      body: items == null
          ? const Center(child: CircularProgressIndicator())
          : (_index >= items.length
              ? _SectionDone(onBack: () => Navigator.of(context).pop())
              : SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                        child: Row(
                          children: [
                            Text(
                              '${'azkar.progress'.tr()}: ${_index + 1} / '
                              '${items.length}',
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                            const Spacer(),
                            if (_target > 1)
                              Chip(
                                label: Text('$_count / $_target'),
                                backgroundColor: scheme.primaryContainer,
                              ),
                          ],
                        ),
                      ),
                      LinearProgressIndicator(
                        value: (_index + 1) / items.length,
                        color: AppColors.gold,
                      ),
                      Expanded(
                        child: GestureDetector(
                          // P3‑11: previous/next used to be two arrow
                          // buttons; now a swipe, direction-aware (see
                          // `_onSwipe`'s doc).
                          onHorizontalDragEnd: (d) =>
                              _onSwipe(d, Directionality.of(context)),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  items[_index].body,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: 'AmiriQuran',
                                    fontSize: 22,
                                    height: 1.9,
                                  ),
                                ),
                                if (items[_index].footnote.isNotEmpty) ...[
                                  const SizedBox(height: 20),
                                  const Divider(),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${'azkar.source'.tr()}: ${items[_index].footnote}',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(color: scheme.onSurfaceVariant),
                                  ),
                                ],
                                // P3‑44: real-device feedback — repeated on
                                // every single dhikr, reads as stuck rather
                                // than a one-time gesture hint. First dhikr
                                // in the section only.
                                if (_index == 0) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    'azkar.swipe_hint'.tr(),
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.labelSmall
                                        ?.copyWith(color: scheme.outline),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                        child: FilledButton(
                          onPressed: _tap,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 64),
                            backgroundColor: AppColors.primary,
                          ),
                          child: Text(
                            _target > 1
                                ? '${'azkar.count'.tr()}: $_count'
                                : 'azkar.done'.tr(),
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
    );
  }
}

class _SectionDone extends StatelessWidget {
  final VoidCallback onBack;
  const _SectionDone({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 72, color: AppColors.success),
            const SizedBox(height: 16),
            Text('azkar.section_done'.tr(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onBack,
              child: Text('azkar.back_to_sections'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
