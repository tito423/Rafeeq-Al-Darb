import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/digits.dart';
import '../../quran/data/mushaf_data_provider.dart';
import '../data/khatma_store.dart';

/// Opens «ختمة جديدة».
///
/// «زر ابدأ الختمة نصه تحت ومش فعال أصلًا»: the sheet was a plain Column
/// taller than the screen. It could not scroll, its last row sat under the
/// gesture bar, and a button laid out past its parent's bounds is painted
/// but never hit-tested — so «إنشاء الختمة» showed and did nothing. It
/// scrolls now, inside the safe area, and the keyboard inset is honoured.
Future<void> showCreateKhatmaSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _CreateKhatmaSheet(),
  );
}

enum _AmountUnit { pages, juz, quarters }

/// The reference's own fine-grained pre-juz steps
/// (`design_refs/khatma_app_ref/4_new_khatma_juz_units.jpg`): quarters of
/// a hizb, 1 through 7 (8 quarters = 1 juz, already covered by
/// [_AmountUnit.juz]'s own 1-30 range — no need to duplicate that as
/// "quarters" too).
String _quarterLabel(int n) {
  switch (n) {
    case 1:
      return 'khatma.quarter_1'.tr();
    case 2:
      return 'khatma.quarter_2'.tr();
    case 3:
      return 'khatma.quarter_3'.tr();
    case 4:
      return 'khatma.quarter_4_hizb'.tr();
    default:
      return trn('khatma.quarter_n', args: ['$n']);
  }
}

/// P3‑6 redesign: a real two-step wizard, matching the owner's actual
/// reference app's own "ختمة جديدة" flow (`design_refs/khatma_app_ref/
/// 2_new_khatma_start.jpg` + `3_new_khatma_duration.jpg`) — step 1 picks
/// *where* the khatma starts (the reference's own "الرجاء تحديد المكان أو
/// الجزء الذي تريد أن تبدء منه الختمة"), step 2 links the khatma's
/// duration and its daily portion size so editing either one recomputes
/// the other (the reference's "حدد المدة ... أو كمية الورد اليومي" — two
/// views of the same rate).
///
/// P3‑43 #9: the reference's own quarter-hizb precision for the daily
/// amount (ربع/ربعان/٣ أرباع/حزب...) was missed in the original P3‑6
/// build — this app's mushaf DB has no hizb/quarter column, only juz, so
/// building it honestly needed real boundary data first. Now sourced from
/// `assets/data/mushaf/rub_el_hizb_pages.json` (real `rub_el_hizb_number`
/// metadata fetched from api.quran.com, the same trusted source already
/// used for tafsir/translations) — see `MushafData.rubElHizbPages`'s own
/// doc.
class _CreateKhatmaSheet extends ConsumerStatefulWidget {
  const _CreateKhatmaSheet();

  @override
  ConsumerState<_CreateKhatmaSheet> createState() => _CreateKhatmaSheetState();
}

class _CreateKhatmaSheetState extends ConsumerState<_CreateKhatmaSheet> {
  // Where to start. Both null = بداية المصحف (page 1); at most one is set.
  //
  // «ولية بدء ختمة جديدة في نص الصفحة ادمجه مع اختيار من اول المصحف ولا من اي
  // جزء وزود من اي سورة» — so the two steps this sheet used to have are one
  // now, and the list it offers is: the beginning, any of the thirty juz, or
  // any of the hundred and fourteen surahs.
  int? _startJuz;
  int? _startSurah;

  // Step 2 — linked duration/amount. _dailyAmount starts consistent with
  // _durationDays (recomputed once real mushaf data is available in
  // didChangeDependencies below) rather than an arbitrary pair of numbers
  // that wouldn't actually multiply out to 604 pages.
  _AmountUnit _unit = _AmountUnit.pages;
  int _durationDays = 30;
  int _dailyAmount = 21;
  bool _amountInitialized = false;

  TimeOfDay? _reminder;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_amountInitialized) return;
    final mushaf = ref.read(mushafDataProvider).valueOrNull;
    if (mushaf == null) return;
    _amountInitialized = true;
    final plan = _totalPlan(mushaf, _startPage(mushaf));
    _dailyAmount = (plan / _durationDays).ceil().clamp(1, plan);
  }

  int _startPage(MushafData? mushaf) {
    if (mushaf == null) return 1;
    final surah = _startSurah;
    if (surah != null) return mushaf.surahStartPages[surah] ?? 1;
    final juz = _startJuz;
    if (juz == null) return 1;
    return mushaf.juzStartPages[juz] ?? 1;
  }

  /// The dropdown's value: null for the beginning, `j5` for a juz, `s36` for
  /// a surah. A single key keeps one list showing all three kinds of choice,
  /// which is what he asked for.
  String? get _startKey {
    if (_startSurah != null) return 's$_startSurah';
    if (_startJuz != null) return 'j$_startJuz';
    return null;
  }

  void _setStart(String? key) {
    setState(() {
      if (key == null) {
        _startJuz = null;
        _startSurah = null;
      } else if (key.startsWith('j')) {
        _startJuz = int.tryParse(key.substring(1));
        _startSurah = null;
      } else {
        _startSurah = int.tryParse(key.substring(1));
        _startJuz = null;
      }
      // The daily amount is derived from how much is left to read, and that
      // changes the moment the starting point does.
      _amountInitialized = false;
    });
    final mushaf = ref.read(mushafDataProvider).valueOrNull;
    if (mushaf != null) {
      final plan = _totalPlan(mushaf, _startPage(mushaf));
      setState(() {
        _amountInitialized = true;
        _dailyAmount = (plan / _durationDays).ceil().clamp(1, plan);
      });
    }
  }

  int _startJuzNumber(MushafData? mushaf, int startPage) {
    if (mushaf == null) return 1;
    var juz = 1;
    for (final entry in mushaf.juzStartPages.entries) {
      if (entry.value <= startPage) juz = juz < entry.key ? entry.key : juz;
    }
    return juz;
  }

  int _startQuarterNumber(MushafData? mushaf, int startPage) {
    final rubPages = mushaf?.rubElHizbPages;
    if (rubPages == null || rubPages.isEmpty) return 1;
    var rub = 1;
    for (var i = 0; i < rubPages.length; i++) {
      if (rubPages[i] <= startPage) rub = i + 1;
    }
    return rub;
  }

  int _totalPlan(MushafData? mushaf, int startPage) {
    switch (_unit) {
      case _AmountUnit.pages:
        return Khatma.totalPages - startPage + 1;
      case _AmountUnit.juz:
        final startJuz = _startJuzNumber(mushaf, startPage);
        return 30 - startJuz + 1;
      case _AmountUnit.quarters:
        final total = mushaf?.rubElHizbPages.length ?? 240;
        final startRub = _startQuarterNumber(mushaf, startPage);
        return total - startRub + 1;
    }
  }

  /// Caps how big a single day's amount can be for the *current* unit —
  /// quarters are deliberately bounded to 1-7 (8 quarters = a full juz,
  /// already the [_AmountUnit.juz] option's own job), unlike pages/juz
  /// which can validly span the whole plan in one day.
  int _maxAmount(_AmountUnit unit, int plan) =>
      unit == _AmountUnit.quarters ? math.min(7, plan) : plan;

  void _onDurationChanged(int v, MushafData? mushaf) {
    setState(() {
      _durationDays = v;
      final plan = _totalPlan(mushaf, _startPage(mushaf));
      _dailyAmount = (plan / v).ceil().clamp(1, _maxAmount(_unit, plan));
    });
  }

  void _onAmountChanged(int v, MushafData? mushaf) {
    setState(() {
      _dailyAmount = v;
      final plan = _totalPlan(mushaf, _startPage(mushaf));
      _durationDays = (plan / v).ceil().clamp(1, 3650);
    });
  }

  void _onUnitChanged(_AmountUnit u, MushafData? mushaf) {
    setState(() {
      _unit = u;
      final plan = _totalPlan(mushaf, _startPage(mushaf));
      _dailyAmount = (plan / _durationDays).ceil().clamp(
        1,
        _maxAmount(u, plan),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final mushaf = ref.watch(mushafDataProvider).valueOrNull;
    final media = MediaQuery.of(context);
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 4,
        bottom: media.viewInsets.bottom + media.viewPadding.bottom + 18,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'khatma.new'.tr(),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          _StartStep(mushaf: mushaf, startKey: _startKey, onChanged: _setStart),
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 18),
          _DurationStep(
            unit: _unit,
            durationDays: _durationDays,
            dailyAmount: _dailyAmount,
            reminder: _reminder,
            onUnitChanged: (u) => _onUnitChanged(u, mushaf),
            onDurationChanged: (v) => _onDurationChanged(v, mushaf),
            onAmountChanged: (v) => _onAmountChanged(v, mushaf),
            onReminderChanged: (t) => setState(() => _reminder = t),
            onCreate: () async {
              final startPage = _startPage(mushaf);
              final mode = switch (_unit) {
                _AmountUnit.pages => KhatmaMode.dailyPages,
                _AmountUnit.juz => KhatmaMode.dailyJuz,
                _AmountUnit.quarters => KhatmaMode.dailyQuarters,
              };
              await ref
                  .read(khatmaStoreProvider.notifier)
                  .create(
                    mode: mode,
                    dailyAmount: _dailyAmount,
                    startPage: startPage,
                    reminderTime: _reminder,
                  );
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}

class _StartStep extends StatelessWidget {
  final MushafData? mushaf;
  final String? startKey;
  final ValueChanged<String?> onChanged;

  const _StartStep({
    required this.mushaf,
    required this.startKey,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final surahs = mushaf?.surahs ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'khatma.start_prompt'.tr(),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String?>(
          initialValue: startKey,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'khatma.start_from'.tr(),
            border: const OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem(
              value: null,
              child: Text('khatma.start_beginning'.tr()),
            ),
            for (var j = 1; j <= 30; j++)
              DropdownMenuItem(
                value: 'j$j',
                child: Text(trn('khatma.juz_label', args: ['$j'])),
              ),
            // «وزود من اي سورة». The names come from the mushaf data, so
            // they are the same ones the reader sees everywhere else.
            for (final s in surahs)
              DropdownMenuItem(
                value: 's${s.id}',
                child: Text(
                  s.nameAr,
                  style: const TextStyle(fontFamily: 'AmiriQuran'),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _DurationStep extends StatelessWidget {
  final _AmountUnit unit;
  final int durationDays;
  final int dailyAmount;
  final TimeOfDay? reminder;
  final ValueChanged<_AmountUnit> onUnitChanged;
  final ValueChanged<int> onDurationChanged;
  final ValueChanged<int> onAmountChanged;
  final ValueChanged<TimeOfDay?> onReminderChanged;
  final VoidCallback onCreate;

  const _DurationStep({
    required this.unit,
    required this.durationDays,
    required this.dailyAmount,
    required this.reminder,
    required this.onUnitChanged,
    required this.onDurationChanged,
    required this.onAmountChanged,
    required this.onReminderChanged,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final gold = AppColors.gold;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'khatma.duration_prompt'.tr(),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 18),
        _Stepper(
          label: 'khatma.duration_days'.tr(),
          value: durationDays,
          min: 1,
          max: 3650,
          onChanged: onDurationChanged,
        ),
        const Divider(height: 28),
        // Label above, picker full width below. Side by side, the three
        // segments took the whole row, the label's Expanded was squeezed to
        // a few pixels and wrapped one letter per line — that was the big
        // empty gap in the sheet — and «أرباع» ran off the screen's edge.
        Text('khatma.daily_portion'.tr()),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SegmentedButton<_AmountUnit>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: _AmountUnit.quarters,
                  label: Text('khatma.unit_quarters'.tr()),
                ),
                ButtonSegment(
                  value: _AmountUnit.pages,
                  label: Text('khatma.unit_pages'.tr()),
                ),
                ButtonSegment(
                  value: _AmountUnit.juz,
                  label: Text('khatma.unit_juz'.tr()),
                ),
              ],
              selected: {unit},
              onSelectionChanged: (s) => onUnitChanged(s.first),
            ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // P3‑43 #9: quarters are a bounded, named 1-7 choice (ربع..٧ أرباع
        // — 8 quarters is a full juz, already the juz option's own job),
        // not an open-ended stepper like pages/juz.
        if (unit == _AmountUnit.quarters)
          DropdownButtonFormField<int>(
            initialValue: dailyAmount.clamp(1, 7),
            decoration: InputDecoration(
              labelText: 'khatma.quarters_per_day'.tr(),
              border: const OutlineInputBorder(),
            ),
            items: [
              for (var n = 1; n <= 7; n++)
                DropdownMenuItem(value: n, child: Text(_quarterLabel(n))),
            ],
            onChanged: (v) {
              if (v != null) onAmountChanged(v);
            },
          )
        else
          _Stepper(
            label: unit == _AmountUnit.pages
                ? 'khatma.pages_per_day'.tr()
                : 'khatma.juz_per_day'.tr(),
            value: dailyAmount,
            min: 1,
            max: unit == _AmountUnit.pages ? 60 : 30,
            onChanged: onAmountChanged,
          ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                reminder == null
                    ? 'khatma.no_reminder'.tr()
                    : 'khatma.reminder_at'.tr(
                        args: [
                          '${reminder!.hour.toString().padLeft(2, '0')}:${reminder!.minute.toString().padLeft(2, '0')}',
                        ],
                      ),
                style: TextStyle(color: gold),
              ),
            ),
            TextButton(
              onPressed: () async {
                final t = await showTimePicker(
                  context: context,
                  initialTime: reminder ?? const TimeOfDay(hour: 20, minute: 0),
                );
                if (t != null) onReminderChanged(t);
              },
              child: Text('khatma.set_reminder'.tr()),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onCreate,
            child: Text('khatma.create'.tr()),
          ),
        ),
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _Stepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Text(
          localizeDigits('$value', uiLanguageCode),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        IconButton(
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}
