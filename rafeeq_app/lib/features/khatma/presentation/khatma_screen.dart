import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/tab_request_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../quran/data/mushaf_data_provider.dart';
import '../../quran/data/quran_jump_provider.dart';
import '../data/khatma_store.dart';
import 'khatma_card.dart' show showKhatmaUndoSnackBar;

/// The full khatma manager (P2‑11) — every active khatma with its own
/// progress/read-today/reminder controls, a "+" to start a new one, and a
/// history section for finished ones. Pushed from `KhatmaCard`.
class KhatmaScreen extends ConsumerWidget {
  const KhatmaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeKhatmasProvider);
    final done = ref.watch(completedKhatmasProvider);
    final mushaf = ref.watch(mushafDataProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: Text('khatma.title'.tr())),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateSheet(context, ref),
        icon: const Icon(Icons.add),
        label: Text('khatma.new'.tr()),
      ),
      body: (active.isEmpty && done.isEmpty)
          ? const _EmptyBody()
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
              children: [
                for (final k in active)
                  _KhatmaTile(
                    khatma: k,
                    mushaf: mushaf,
                    onReadToday: mushaf == null
                        ? null
                        : () async {
                            final before = k;
                            final updated = await ref
                                .read(khatmaStoreProvider.notifier)
                                .readToday(k, mushaf.juzStartPages);
                            if (!context.mounted) return;
                            ref.read(quranJumpRequestProvider.notifier).state =
                                updated.currentPage;
                            ref.read(requestedTabProvider.notifier).state =
                                AppTab.quran;
                            // Shown via the root ScaffoldMessenger (this
                            // Scaffold doesn't nest its own), so it survives
                            // the pop below and appears over Home.
                            showKhatmaUndoSnackBar(context, ref, before);
                            Navigator.of(context).pop();
                          },
                    onOpenReader: () {
                      ref.read(quranJumpRequestProvider.notifier).state =
                          k.currentPage;
                      ref.read(requestedTabProvider.notifier).state =
                          AppTab.quran;
                      Navigator.of(context).pop();
                    },
                    onSetReminder: () => _pickReminder(context, ref, k),
                    onDelete: () => _confirmDelete(context, ref, k),
                  ),
                if (done.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('khatma.history'.tr(),
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(color: AppColors.gold)),
                  const SizedBox(height: 8),
                  for (final k in done) _CompletedTile(khatma: k),
                ],
              ],
            ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Khatma k) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('khatma.delete_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('khatma.delete'.tr()),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(khatmaStoreProvider.notifier).delete(k);
  }

  Future<void> _pickReminder(
      BuildContext context, WidgetRef ref, Khatma k) async {
    final time = await showTimePicker(
      context: context,
      initialTime: k.reminderTime ?? const TimeOfDay(hour: 20, minute: 0),
    );
    if (time == null) return;
    await ref.read(khatmaStoreProvider.notifier).setReminder(k, time);
  }

  Future<void> _openCreateSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CreateKhatmaSheet(),
    );
  }
}

/// P3‑6: this used to carry its own "+ ختمة جديدة" button, duplicating the
/// Scaffold's own `FloatingActionButton.extended` (same label, same action)
/// — both visible on screen at once whenever the list was empty. The FAB
/// alone is enough; [onCreate] is kept unused-by-this-widget on purpose
/// (nothing here needs it now), tapping the illustration area does nothing
/// special, the FAB is the one and only "create" affordance.
class _EmptyBody extends StatelessWidget {
  const _EmptyBody();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_stories_outlined,
                size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 14),
            Text('khatma.start_invite'.tr(), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _KhatmaTile extends StatelessWidget {
  final Khatma khatma;
  final MushafData? mushaf;
  final VoidCallback? onReadToday;
  final VoidCallback onOpenReader;
  final VoidCallback onSetReminder;
  final VoidCallback onDelete;

  const _KhatmaTile({
    required this.khatma,
    required this.mushaf,
    required this.onReadToday,
    required this.onOpenReader,
    required this.onSetReminder,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = AppColors.gold;
    final due = mushaf == null ? 0 : khatma.duePages(mushaf!.juzStartPages);
    final daysLeft = khatma.daysLeft;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 46,
                  height: 46,
                  child: Stack(alignment: Alignment.center, children: [
                    CircularProgressIndicator(
                      value: khatma.progress,
                      strokeWidth: 4,
                      backgroundColor: gold.withValues(alpha: 0.15),
                      color: gold,
                    ),
                    Text('${(khatma.progress * 100).round()}%',
                        style: theme.textTheme.labelSmall),
                  ]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'khatma.pages_read_of'
                            .tr(args: ['${khatma.pagesRead}', '${khatma.totalPagesInPlan}']),
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        daysLeft != null
                            ? 'khatma.days_left'.tr(args: ['$daysLeft'])
                            : 'khatma.daily_amount'.tr(args: ['${khatma.dailyAmount ?? 1}']),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'reminder') onSetReminder();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'reminder',
                      child: ListTile(
                        leading: const Icon(Icons.notifications_outlined),
                        title: Text(khatma.reminderTime == null
                            ? 'khatma.set_reminder'.tr()
                            : 'khatma.reminder_at'
                                .tr(args: [_fmtTime(khatma.reminderTime!)])),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: const Icon(Icons.delete_outline, color: AppColors.error),
                        title: Text('khatma.delete'.tr(),
                            style: const TextStyle(color: AppColors.error)),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onOpenReader,
                    child: Text('khatma.open_reader'.tr()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: khatma.readToday
                      ? FilledButton.tonalIcon(
                          onPressed: null,
                          icon: const Icon(Icons.check),
                          label: Text('khatma.read_today_done'.tr()),
                        )
                      : FilledButton(
                          onPressed: onReadToday,
                          child: Text('khatma.read_today'.tr(args: ['$due'])),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class _CompletedTile extends StatelessWidget {
  final Khatma khatma;
  const _CompletedTile({required this.khatma});

  @override
  Widget build(BuildContext context) {
    final date = khatma.completedAt;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.emoji_events_outlined, color: AppColors.gold),
        title: Text('khatma.completed_on'.tr(
          args: [date != null ? DateFormat.yMMMd(context.locale.toString()).format(date) : ''],
        )),
        subtitle: Text('khatma.started_on'.tr(
          args: [DateFormat.yMMMd(context.locale.toString()).format(khatma.startDate)],
        )),
      ),
    );
  }
}

enum _AmountUnit { pages, juz }

/// P3‑6 redesign: a real two-step wizard, matching the owner's actual
/// reference app's own "ختمة جديدة" flow (`design_refs/khatma_app_ref/
/// 2_new_khatma_start.jpg` + `3_new_khatma_duration.jpg`) — step 1 picks
/// *where* the khatma starts (the reference's own "الرجاء تحديد المكان أو
/// الجزء الذي تريد أن تبدء منه الختمة"), step 2 links the khatma's
/// duration and its daily portion size so editing either one recomputes
/// the other (the reference's "حدد المدة ... أو كمية الورد اليومي" — two
/// views of the same rate). The reference also offers quarter-hizb
/// precision for the daily amount; this app has no hizb/quarter boundary
/// data in its mushaf DB (only juz boundaries), so the unit choice here is
/// honestly limited to صفحات/جزء rather than faking finer precision it
/// can't actually back with real page numbers.
class _CreateKhatmaSheet extends ConsumerStatefulWidget {
  const _CreateKhatmaSheet();

  @override
  ConsumerState<_CreateKhatmaSheet> createState() => _CreateKhatmaSheetState();
}

class _CreateKhatmaSheetState extends ConsumerState<_CreateKhatmaSheet> {
  int _step = 0;

  // Step 1 — where to start.
  int? _startJuz; // null = بداية المصحف (page 1)

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
    final juz = _startJuz;
    if (juz == null || mushaf == null) return 1;
    return mushaf.juzStartPages[juz] ?? 1;
  }

  int _startJuzNumber(MushafData? mushaf, int startPage) {
    if (mushaf == null) return 1;
    var juz = 1;
    for (final entry in mushaf.juzStartPages.entries) {
      if (entry.value <= startPage) juz = juz < entry.key ? entry.key : juz;
    }
    return juz;
  }

  int _totalPlan(MushafData? mushaf, int startPage) {
    if (_unit == _AmountUnit.pages) return Khatma.totalPages - startPage + 1;
    final startJuz = _startJuzNumber(mushaf, startPage);
    return 30 - startJuz + 1;
  }

  void _onDurationChanged(int v, MushafData? mushaf) {
    setState(() {
      _durationDays = v;
      final plan = _totalPlan(mushaf, _startPage(mushaf));
      _dailyAmount = (plan / v).ceil().clamp(1, plan);
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
      _dailyAmount = (plan / _durationDays).ceil().clamp(1, plan);
    });
  }

  @override
  Widget build(BuildContext context) {
    final mushaf = ref.watch(mushafDataProvider).valueOrNull;
    return Padding(
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 18,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_step == 1)
                IconButton(
                  onPressed: () => setState(() => _step = 0),
                  icon: const Icon(Icons.arrow_back),
                  visualDensity: VisualDensity.compact,
                ),
              Text('khatma.new'.tr(), style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 16),
          if (_step == 0)
            _StartStep(
              mushaf: mushaf,
              startJuz: _startJuz,
              onChanged: (v) => setState(() => _startJuz = v),
              onContinue: () => setState(() => _step = 1),
            )
          else
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
                await ref.read(khatmaStoreProvider.notifier).create(
                      mode: _unit == _AmountUnit.pages
                          ? KhatmaMode.dailyPages
                          : KhatmaMode.dailyJuz,
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
  final int? startJuz;
  final ValueChanged<int?> onChanged;
  final VoidCallback onContinue;

  const _StartStep({
    required this.mushaf,
    required this.startJuz,
    required this.onChanged,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('khatma.start_prompt'.tr(),
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 20),
        DropdownButtonFormField<int?>(
          initialValue: startJuz,
          decoration: InputDecoration(
            labelText: 'khatma.start_from'.tr(),
            border: const OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem(value: null, child: Text('khatma.start_beginning'.tr())),
            for (var j = 1; j <= 30; j++)
              DropdownMenuItem(value: j, child: Text('khatma.juz_label'.tr(args: ['$j']))),
          ],
          onChanged: onChanged,
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: mushaf == null ? null : onContinue,
            child: Text('khatma.continue_button'.tr()),
          ),
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
        Text('khatma.duration_prompt'.tr(),
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 18),
        _Stepper(
          label: 'khatma.duration_days'.tr(),
          value: durationDays,
          min: 1,
          max: 3650,
          onChanged: onDurationChanged,
        ),
        const Divider(height: 28),
        Row(
          children: [
            Expanded(child: Text('khatma.daily_portion'.tr())),
            SegmentedButton<_AmountUnit>(
              segments: [
                ButtonSegment(
                    value: _AmountUnit.pages, label: Text('khatma.unit_pages'.tr())),
                ButtonSegment(
                    value: _AmountUnit.juz, label: Text('khatma.unit_juz'.tr())),
              ],
              selected: {unit},
              onSelectionChanged: (s) => onUnitChanged(s.first),
            ),
          ],
        ),
        const SizedBox(height: 8),
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
                    : 'khatma.reminder_at'.tr(args: [
                        '${reminder!.hour.toString().padLeft(2, '0')}:${reminder!.minute.toString().padLeft(2, '0')}'
                      ]),
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
        Text('$value', style: Theme.of(context).textTheme.titleMedium),
        IconButton(
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}
