import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/digits.dart';
import '../../../core/widgets/paired_list_view.dart';
import '../data/dedication.dart';
import 'dedication_counter_screen.dart';
import 'dedication_look.dart';

/// «الإهداءات» — the reader's list of people they read or make dhikr for.
class DedicationsScreen extends ConsumerWidget {
  const DedicationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(dedicationsProvider);
    return Scaffold(
      appBar: AppBar(title: Text('dedication.title'.tr())),
      // «بلاش كل حاجة في نص الشاشة … خلي كارت كبير يظهر في نص الشاشة مليان
      // بالاختيارات» (owner, 2026-09-30): with nothing yet, one large card
      // holding the four kinds of gift; with some, the same four as a strip
      // on top and the gifts under it.
      body: list.isEmpty
          ? Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: _StartCard(
                    onPick: (k) => _edit(context, ref, null, kind: k),
                  ),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
              children: [
                _StartCard(
                  compact: true,
                  onPick: (k) => _edit(context, ref, null, kind: k),
                ),
                const SizedBox(height: 12),
                _Summary(list: list),
                const SizedBox(height: 12),
                // Sideways two a row (`PairedColumn`).
                PairedColumn(
                  gap: 10,
                  children: [for (final d in list) _DedicationCard(d: d)],
                ),
              ],
            ),
    );
  }
}

Future<void> _edit(
  BuildContext context,
  WidgetRef ref,
  Dedication? existing, {
  DedicationKind? kind,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _EditSheet(existing: existing, kind: kind),
  );
}

/// «أهدِ عملًا لمن تحب» and the four kinds, each a big tile.
class _StartCard extends StatelessWidget {
  final bool compact;
  final ValueChanged<DedicationKind> onPick;
  const _StartCard({required this.onPick, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(compact ? 14 : 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              const Color(0xFFE0A800).withValues(alpha: 0.16),
              scheme.surfaceContainerHighest,
            ),
            scheme.surfaceContainerHighest,
          ],
        ),
        border: Border.all(
          color: const Color(0xFFE0A800).withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!compact) ...[
            const Icon(
              Icons.card_giftcard_rounded,
              size: 56,
              color: Color(0xFFE0A800),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            'dedication.start_title'.tr(),
            textAlign: compact ? TextAlign.start : TextAlign.center,
            style: TextStyle(
              fontSize: compact ? 17 : 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 6),
            Text(
              'dedication.start_sub'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5),
            ),
          ],
          SizedBox(height: compact ? 10 : 18),
          GridView.count(
            crossAxisCount: compact ? 4 : 2,
            shrinkWrap: true,
            // A scroll view with no padding of its own takes the screen's
            // bottom inset as padding — the empty band that sat under the
            // four tiles on the owner's phone.
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: compact ? 0.95 : 1.05,
            children: [
              for (final k in DedicationKind.values)
                _KindTile(kind: k, compact: compact, onTap: () => onPick(k)),
            ],
          ),
        ],
      ),
    );
  }
}

class _KindTile extends StatelessWidget {
  final DedicationKind kind;
  final bool compact;
  final VoidCallback onTap;
  const _KindTile({
    required this.kind,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, color) = dedicationLook(kind);
    return Material(
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          padding: EdgeInsets.all(compact ? 6 : 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color, Color.lerp(color, Colors.black, 0.3)!],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: compact ? 26 : 38),
              SizedBox(height: compact ? 4 : 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  kind.titleKey.tr(),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: compact ? 12 : 16,
                  ),
                ),
              ),
              if (!compact) ...[
                const SizedBox(height: 4),
                Text(
                  '${kind.titleKey}_desc'.tr(),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 11.5,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One person and what is given to them.
///
/// A header in the kind's colour carries the name; the reader's own words
/// sit under it as a quote; and the count is a ring with one clear action
/// beside it that opens the counting screen — «ابدأ الاستغفار», not a bare
/// «+» (owner, 2026-10-02: «شكلها وحش قوي إن أنا أضغط على علامة الزائد»).
class _DedicationCard extends ConsumerWidget {
  final Dedication d;
  const _DedicationCard({required this.d});

  String _shareText() {
    final b = StringBuffer()
      ..writeln(
        'dedication.share_line'.tr(
          namedArgs: {'kind': d.kind.titleKey.tr(), 'name': d.name},
        ),
      );
    if (d.note.trim().isNotEmpty) b.writeln(d.note.trim());
    return b.toString().trim();
  }

  Future<void> _onMenu(BuildContext context, WidgetRef ref, String v) async {
    final n = ref.read(dedicationsProvider.notifier);
    if (v == 'edit') await _edit(context, ref, d);
    if (v == 'share') {
      await SharePlus.instance.share(ShareParams(text: _shareText()));
    }
    if (v == 'reset') await n.update(d.copyWith(count: 0));
    if (v == 'delete' && context.mounted) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          content: Text(
            'dedication.delete_confirm'.tr(namedArgs: {'name': d.name}),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text('common.cancel'.tr()),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text('dedication.delete'.tr()),
            ),
          ],
        ),
      );
      if (ok == true) await n.remove(d.id);
    }
  }

  void _openCounter(BuildContext context) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DedicationCounterScreen(id: d.id),
      ),
    );
  }

  /// «اليوم» / «أمس» / the date.
  String _when(BuildContext context, DateTime t) {
    final now = DateTime.now();
    final days = DateTime(now.year, now.month, now.day)
        .difference(DateTime(t.year, t.month, t.day))
        .inDays;
    if (days == 0) return 'dedication.today'.tr();
    if (days == 1) return 'dedication.yesterday'.tr();
    return localizeDigits(
      DateFormat.yMMMd(context.locale.toString()).format(t),
      context.locale.languageCode,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unit = d.kind.unitKey;
    final lang = context.locale.languageCode;
    final (kindIcon, kindColor) = dedicationLook(d.kind);
    final last = d.lastAt;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: kindColor.withValues(alpha: 0.45)),
      ),
      color: Color.alphaBlend(
        kindColor.withValues(alpha: 0.06),
        scheme.surfaceContainerHighest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── the name, on the kind's colour ──
          Container(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 4, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: AlignmentDirectional.centerStart,
                end: AlignmentDirectional.centerEnd,
                colors: [
                  kindColor,
                  Color.lerp(kindColor, Colors.black, 0.35)!,
                ],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(kindIcon, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        d.kind.titleKey.tr(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  iconColor: Colors.white,
                  onSelected: (v) => _onMenu(context, ref, v),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text('dedication.edit'.tr()),
                    ),
                    PopupMenuItem(
                      value: 'share',
                      child: Text('dedication.share'.tr()),
                    ),
                    if (unit != null)
                      PopupMenuItem(
                        value: 'reset',
                        child: Text('dedication.reset'.tr()),
                      ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('dedication.delete'.tr()),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // ── their own words ──
          if (d.note.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.format_quote_rounded,
                    color: kindColor,
                    size: 22,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      d.note.trim(),
                      style: theme.textTheme.bodyLarge?.copyWith(height: 1.7),
                    ),
                  ),
                ],
              ),
            ),
          // ── the count, and the way to add to it ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: unit == null
                ? Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: OutlinedButton.icon(
                      onPressed: () => SharePlus.instance
                          .share(ShareParams(text: _shareText())),
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: Text('dedication.share'.tr()),
                    ),
                  )
                : Row(
                    children: [
                      _MiniRing(
                        color: kindColor,
                        progress: d.hasGoal
                            ? (d.count / d.goal).clamp(0.0, 1.0).toDouble()
                            : null,
                        label: localizeDigits('${d.count}', lang),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d.hasGoal
                                  ? 'dedication.of_goal'.tr(namedArgs: {
                                      'goal': localizeDigits('${d.goal}', lang),
                                    })
                                  : unit.tr(),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (last != null)
                              Text(
                                'dedication.last_time'.tr(namedArgs: {
                                  'when': _when(context, last),
                                }),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: kindColor,
                          foregroundColor: Colors.white,
                          shape: const StadiumBorder(),
                        ),
                        onPressed: () => _openCounter(context),
                        icon: Icon(
                          d.goalReached
                              ? Icons.verified_rounded
                              : Icons.touch_app_rounded,
                          size: 18,
                        ),
                        label: Text('dedication.action_${d.kind.name}'.tr()),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// The card's count: a small ring, filled toward the goal when there is one.
class _MiniRing extends StatelessWidget {
  const _MiniRing({
    required this.color,
    required this.progress,
    required this.label,
  });

  final Color color;
  final double? progress;
  final String label;

  @override
  Widget build(BuildContext context) {
    final done = (progress ?? 0) >= 1;
    return SizedBox(
      width: 58,
      height: 58,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: progress ?? 1,
            strokeWidth: 5,
            strokeCap: StrokeCap.round,
            color: done ? const Color(0xFFE0A800) : color,
            backgroundColor: color.withValues(alpha: 0.15),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: FittedBox(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What all the gifts add up to — people, dhikr counted, pages read —
/// summed from the reader's own records.
class _Summary extends StatelessWidget {
  const _Summary({required this.list});

  final List<Dedication> list;

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    var times = 0;
    var pages = 0;
    for (final d in list) {
      if (d.kind == DedicationKind.quran) {
        pages += d.count;
      } else if (d.kind.unitKey != null) {
        times += d.count;
      }
    }
    final names = {for (final d in list) d.name.trim()}.length;
    final items = <(IconData, String, String)>[
      (
        Icons.favorite_rounded,
        localizeDigits('$names', lang),
        'dedication.summary_people'.tr(),
      ),
      if (times > 0)
        (
          Icons.all_inclusive_rounded,
          localizeDigits('$times', lang),
          'dedication.summary_times'.tr(),
        ),
      if (pages > 0)
        (
          Icons.auto_stories_rounded,
          localizeDigits('$pages', lang),
          'dedication.summary_pages'.tr(),
        ),
    ];
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(items[i].$1, size: 18, color: const Color(0xFFE0A800)),
                  const SizedBox(height: 2),
                  Text(
                    items[i].$2,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    items[i].$3,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _EditSheet extends ConsumerStatefulWidget {
  final Dedication? existing;

  /// The kind picked on the start card, for a new gift.
  final DedicationKind? kind;
  const _EditSheet({this.existing, this.kind});

  @override
  ConsumerState<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends ConsumerState<_EditSheet> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _note = TextEditingController(text: widget.existing?.note ?? '');
  late DedicationKind _kind =
      widget.existing?.kind ?? widget.kind ?? DedicationKind.quran;
  late int _goal = widget.existing?.goal ?? 0;

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final n = ref.read(dedicationsProvider.notifier);
    final e = widget.existing;
    if (e == null) {
      await n.add(
        Dedication(
          id: const Uuid().v4(),
          name: name,
          kind: _kind,
          note: _note.text.trim(),
          count: 0,
          created: DateTime.now(),
          goal: _kind.unitKey == null ? 0 : _goal,
        ),
      );
    } else {
      await n.update(
        e.copyWith(
          name: name,
          kind: _kind,
          note: _note.text.trim(),
          goal: _kind.unitKey == null ? 0 : _goal,
        ),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.existing == null
                  ? 'dedication.add'.tr()
                  : 'dedication.edit'.tr(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'dedication.name_label'.tr(),
                hintText: 'dedication.name_hint'.tr(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final k in DedicationKind.values)
                  ChoiceChip(
                    label: Text(k.titleKey.tr()),
                    selected: _kind == k,
                    onSelected: (_) => setState(() => _kind = k),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: 'dedication.note_label'.tr(),
                hintText: 'dedication.note_hint'.tr(),
                alignLabelWithHint: true,
              ),
            ),
            if (_kind.unitKey != null) ...[
              const SizedBox(height: 14),
              Text(
                'dedication.goal_label'.tr(),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              _GoalPicker(
                kind: _kind,
                value: _goal,
                onChanged: (g) => setState(() => _goal = g),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _name.text.trim().isEmpty ? null : _save,
              child: Text('dedication.save'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

/// The reader's own goal: none, a few common round numbers, or a whole
/// khatma for the Qur'an (604 pages — the Madinah mushaf's real count).
class _GoalPicker extends StatelessWidget {
  const _GoalPicker({
    required this.kind,
    required this.value,
    required this.onChanged,
  });

  final DedicationKind kind;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final options = kind == DedicationKind.quran
        ? const [0, 10, 20, 100, 604]
        : const [0, 33, 100, 1000];
    // A goal saved before that is none of the chips still shows, selected.
    final all = [...options, if (!options.contains(value)) value];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final g in all)
          ChoiceChip(
            label: Text(
              g == 0
                  ? 'dedication.goal_none'.tr()
                  : kind == DedicationKind.quran && g == 604
                      ? 'dedication.goal_khatma'.tr()
                      : localizeDigits('$g', lang),
            ),
            selected: value == g,
            onSelected: (_) => onChanged(g),
          ),
      ],
    );
  }
}
