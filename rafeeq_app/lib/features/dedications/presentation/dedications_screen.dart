import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/digits.dart';
import '../data/dedication.dart';

/// «الإهداءات» — the reader's list of people they read or make dhikr for.
class DedicationsScreen extends ConsumerWidget {
  const DedicationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(dedicationsProvider);
    return Scaffold(
      appBar: AppBar(title: Text('dedication.title'.tr())),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref, null),
        icon: const Icon(Icons.add),
        label: Text('dedication.add'.tr()),
      ),
      body: list.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'dedication.empty'.tr(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              children: [
                for (final d in list) _DedicationCard(d: d),
              ],
            ),
    );
  }
}

Future<void> _edit(BuildContext context, WidgetRef ref, Dedication? existing) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _EditSheet(existing: existing),
  );
}

class _DedicationCard extends ConsumerWidget {
  final Dedication d;
  const _DedicationCard({required this.d});

  String _shareText() {
    final b = StringBuffer()
      ..writeln('dedication.share_line'.tr(namedArgs: {
        'kind': d.kind.titleKey.tr(),
        'name': d.name,
      }));
    if (d.note.trim().isNotEmpty) b.writeln(d.note.trim());
    return b.toString().trim();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final unit = d.kind.unitKey;
    final n = ref.read(dedicationsProvider.notifier);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.volunteer_activism, color: AppColors.gold),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.name,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      Text(d.kind.titleKey.tr(),
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'edit') await _edit(context, ref, d);
                    if (v == 'share') {
                      await SharePlus.instance
                          .share(ShareParams(text: _shareText()));
                    }
                    if (v == 'reset') await n.update(d.copyWith(count: 0));
                    if (v == 'delete' && context.mounted) {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          content: Text('dedication.delete_confirm'
                              .tr(namedArgs: {'name': d.name})),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: Text('common.cancel'.tr())),
                            FilledButton(
                                onPressed: () => Navigator.pop(c, true),
                                child: Text('dedication.delete'.tr())),
                          ],
                        ),
                      );
                      if (ok == true) await n.remove(d.id);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'edit', child: Text('dedication.edit'.tr())),
                    PopupMenuItem(value: 'share', child: Text('dedication.share'.tr())),
                    if (unit != null)
                      PopupMenuItem(value: 'reset', child: Text('dedication.reset'.tr())),
                    PopupMenuItem(value: 'delete', child: Text('dedication.delete'.tr())),
                  ],
                ),
              ],
            ),
            if (d.note.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(d.note, style: theme.textTheme.bodyMedium?.copyWith(height: 1.6)),
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
  const _EditSheet({this.existing});

  @override
  ConsumerState<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends ConsumerState<_EditSheet> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _note = TextEditingController(text: widget.existing?.note ?? '');
  late DedicationKind _kind = widget.existing?.kind ?? DedicationKind.quran;

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
      await n.add(Dedication(
        id: const Uuid().v4(),
        name: name,
        kind: _kind,
        note: _note.text.trim(),
        count: 0,
        created: DateTime.now(),
      ));
    } else {
      await n.update(e.copyWith(name: name, kind: _kind, note: _note.text.trim()));
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 8, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
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
