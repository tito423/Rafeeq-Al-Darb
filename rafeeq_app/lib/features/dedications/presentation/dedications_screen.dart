import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/digits.dart';
import '../../../core/widgets/paired_list_view.dart';
import '../data/dedication.dart';

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

/// Each kind's look: an icon and a colour, the same on the start card and
/// on every gift of that kind.
(IconData, Color) _look(DedicationKind k) => switch (k) {
  DedicationKind.quran => (Icons.menu_book_rounded, const Color(0xFF10AC84)),
  DedicationKind.istighfar => (
    Icons.self_improvement_rounded,
    const Color(0xFF2E86DE),
  ),
  DedicationKind.tasbih => (
    Icons.radio_button_checked_rounded,
    const Color(0xFF8854D0),
  ),
  DedicationKind.dua => (
    Icons.volunteer_activism_rounded,
    const Color(0xFFF79F1F),
  ),
};

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
    final (icon, color) = _look(kind);
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final unit = d.kind.unitKey;
    final n = ref.read(dedicationsProvider.notifier);
    final (kindIcon, kindColor) = _look(d.kind);
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: kindColor.withValues(alpha: 0.6)),
      ),
      color: Color.alphaBlend(
        kindColor.withValues(alpha: 0.08),
        theme.colorScheme.surfaceContainerHighest,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: kindColor,
                  child: Icon(kindIcon, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        d.kind.titleKey.tr(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'edit') await _edit(context, ref, d);
                    if (v == 'share') {
                      await SharePlus.instance.share(
                        ShareParams(text: _shareText()),
                      );
                    }
                    if (v == 'reset') await n.update(d.copyWith(count: 0));
                    if (v == 'delete' && context.mounted) {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          content: Text(
                            'dedication.delete_confirm'.tr(
                              namedArgs: {'name': d.name},
                            ),
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
                  },
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
            if (d.note.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                d.note,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
              ),
            ],
            if (unit != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  // «عدد المرات: ٥», not «٥ مرة»: a label and a number need
                  // no plural agreement in any of the seven languages.
                  Text(
                    '${unit.tr()}: ${localizeDigits('${d.count}', uiLanguageCode)}',
                    style: theme.textTheme.titleMedium,
                  ),
                  const Spacer(),
                  if (d.kind == DedicationKind.quran)
                    OutlinedButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        n.bump(d.id, 1);
                      },
                      child: Text('dedication.add_page'.tr()),
                    )
                  else
                    IconButton.filledTonal(
                      iconSize: 28,
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        n.bump(d.id, 1);
                      },
                      icon: const Icon(Icons.add),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
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
        ),
      );
    } else {
      await n.update(
        e.copyWith(name: name, kind: _kind, note: _note.text.trim()),
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
