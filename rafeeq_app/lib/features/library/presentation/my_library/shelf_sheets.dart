/// The forms of «مكتبتي»: make or edit a shelf, set its reading time, and
/// choose its books.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/proper_name.dart';
import '../../../../core/services/alarm_permissions_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/arabic_normalize.dart';
import '../../../../core/utils/digits.dart';
import '../../../../core/widgets/fitted_sheet.dart';
import '../../data/book_catalog.dart';
import '../../data/my_shelves.dart';
import '../widgets/hidden_books_sheet.dart';
import 'shelf_style.dart';

/// New shelf when [shelf] is null, else edits it. Returns the saved shelf,
/// or null if the reader backed out.
Future<Shelf?> showShelfEditor(BuildContext context, {Shelf? shelf}) =>
    showFittedSheet<Shelf>(
      context: context,
      showDragHandle: true,
      builder: (_) => _ShelfEditor(shelf: shelf),
    );

class _ShelfEditor extends ConsumerStatefulWidget {
  final Shelf? shelf;
  const _ShelfEditor({this.shelf});

  @override
  ConsumerState<_ShelfEditor> createState() => _ShelfEditorState();
}

class _ShelfEditorState extends ConsumerState<_ShelfEditor> {
  late final _name = TextEditingController(text: widget.shelf?.name ?? '');
  late int _color =
      widget.shelf?.colorIndex ??
      ref.read(shelvesProvider).length % shelfPalettes.length;
  late int _icon = widget.shelf?.iconIndex ?? 0;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final n = _name.text.trim();
    if (n.isEmpty) return;
    final notifier = ref.read(shelvesProvider.notifier);
    final s = widget.shelf;
    final Shelf saved;
    if (s == null) {
      saved = await notifier.create(
        name: n,
        colorIndex: _color,
        iconIndex: _icon,
      );
    } else {
      saved = s.copyWith(name: n, colorIndex: _color, iconIndex: _icon);
      await notifier.update(saved);
    }
    if (mounted) Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = shelfPalettes[_color];
    final name = _name.text.trim();
    return Padding(
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 18,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            (widget.shelf == null ? 'shelves.new' : 'shelves.edit').tr(),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          // Live preview: the card as it will look.
          AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            height: 86,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: colors,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.last.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (c, a) =>
                      ScaleTransition(scale: a, child: c),
                  child: Icon(
                    shelfIcons[_icon],
                    key: ValueKey(_icon),
                    color: Colors.white,
                    size: 34,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    name.isEmpty ? 'shelves.name_hint'.tr() : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(
                        alpha: name.isEmpty ? 0.6 : 1,
                      ),
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _name,
            autofocus: widget.shelf == null,
            maxLength: 30,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: 'shelves.name'.tr(),
              hintText: 'shelves.name_hint'.tr(),
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('shelves.color'.tr(), style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < shelfPalettes.length; i++)
                _Swatch(
                  colors: shelfPalettes[i],
                  selected: i == _color,
                  onTap: () => setState(() => _color = i),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text('shelves.icon'.tr(), style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < shelfIcons.length; i++)
                _IconChoice(
                  icon: shelfIcons[i],
                  color: colors.last,
                  selected: i == _icon,
                  onTap: () => setState(() => _icon = i),
                ),
            ],
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: name.isEmpty ? null : _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            child: Text('common.save'.tr()),
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final List<Color> colors;
  final bool selected;
  final VoidCallback onTap;
  const _Swatch({
    required this.colors,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: colors),
        border: Border.all(
          color: selected ? AppColors.gold : Colors.transparent,
          width: 3,
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
          : null,
    ),
  );
}

class _IconChoice extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _IconChoice({
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? color.withValues(alpha: 0.16)
              : scheme.surfaceContainerHighest,
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Icon(icon, color: selected ? color : scheme.onSurfaceVariant),
      ),
    );
  }
}

/// The weekday's short name in the reader's language (1 = Monday).
String weekdayShort(int weekday, String lang) {
  // 2024-01-01 was a Monday.
  final d = DateTime(2024, 1, weekday);
  return DateFormat.E(lang).format(d);
}

/// Sets or clears [shelf]'s weekly reading time.
Future<void> showShelfReminderSheet(BuildContext context, Shelf shelf) =>
    showFittedSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _ReminderSheet(shelf: shelf),
    );

class _ReminderSheet extends ConsumerStatefulWidget {
  final Shelf shelf;
  const _ReminderSheet({required this.shelf});

  @override
  ConsumerState<_ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends ConsumerState<_ReminderSheet> {
  late final Set<int> _days = {...?widget.shelf.reminder?.weekdays};
  late TimeOfDay _time = widget.shelf.reminder == null
      ? const TimeOfDay(hour: 21, minute: 0)
      : TimeOfDay(
          hour: widget.shelf.reminder!.hour,
          minute: widget.shelf.reminder!.minute,
        );

  Future<void> _save() async {
    // Asked only when a reminder is actually being set, never on opening.
    await AlarmPermissionsService.instance.requestStartupPermissions();
    await ref
        .read(shelvesProvider.notifier)
        .setReminder(
          widget.shelf.id,
          ShelfReminder(
            weekdays: _days,
            hour: _time.hour,
            minute: _time.minute,
          ),
        );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _clear() async {
    await ref.read(shelvesProvider.notifier).setReminder(widget.shelf.id, null);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = context.locale.languageCode;
    final accent = paletteOf(widget.shelf).last;
    // Week laid out from Saturday, as an Arabic calendar starts it.
    const order = [6, 7, 1, 2, 3, 4, 5];
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'shelves.reminder_title'.tr(),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'shelves.reminder_hint'.tr(),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final d in order)
                FilterChip(
                  label: Text(weekdayShort(d, lang)),
                  selected: _days.contains(d),
                  showCheckmark: false,
                  selectedColor: accent.withValues(alpha: 0.22),
                  onSelected: (on) => setState(() {
                    on ? _days.add(d) : _days.remove(d);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Center(
            child: TextButton(
              onPressed: () => setState(() {
                _days.length == 7
                    ? _days.clear()
                    : _days.addAll(const [1, 2, 3, 4, 5, 6, 7]);
              }),
              child: Text('shelves.every_day'.tr()),
            ),
          ),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            icon: const Icon(Icons.schedule_rounded),
            label: Text(
              localizeDigits(_time.format(context), lang),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: () async {
              final t = await showTimePicker(
                context: context,
                initialTime: _time,
              );
              if (t != null) setState(() => _time = t);
            },
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _days.isEmpty ? null : _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            child: Text('common.save'.tr()),
          ),
          if (widget.shelf.reminder != null) ...[
            const SizedBox(height: 6),
            TextButton(
              onPressed: _clear,
              child: Text('shelves.reminder_off'.tr()),
            ),
          ],
        ],
      ),
    );
  }
}

/// Every catalogue book a reader can see, with a tick on the ones already on
/// [shelf]. Returns the new list, in shelf order (kept books first, in their
/// old order, then the newly ticked ones), or null if he backed out.
class ShelfBookPicker extends StatefulWidget {
  final Shelf shelf;
  const ShelfBookPicker({super.key, required this.shelf});

  @override
  State<ShelfBookPicker> createState() => _ShelfBookPickerState();
}

class _ShelfBookPickerState extends State<ShelfBookPicker> {
  late final Set<String> _picked = {...widget.shelf.bookIds};
  final _query = TextEditingController();
  late final List<LibraryBook> _all = visibleBookCatalog();

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<LibraryBook> get _shown {
    final q = normalizeArabicLoose(_query.text.trim()).toLowerCase();
    if (q.isEmpty) return _all;
    return [
      for (final b in _all)
        if (normalizeArabicLoose(
          '${b.titleAr} ${b.authorAr} ${b.titleEn} ${b.authorEn}',
        ).toLowerCase().contains(q))
          b,
    ];
  }

  void _done() {
    final kept = [
      for (final id in widget.shelf.bookIds)
        if (_picked.contains(id)) id,
    ];
    final added = [
      for (final b in _all)
        if (_picked.contains(b.id) && !kept.contains(b.id)) b.id,
    ];
    Navigator.of(context).pop([...kept, ...added]);
  }

  @override
  Widget build(BuildContext context) {
    final accent = paletteOf(widget.shelf).last;
    final shown = _shown;
    final lang = context.locale.languageCode;
    return Scaffold(
      appBar: AppBar(
        title: Text('shelves.pick_title'.tr(args: [widget.shelf.name])),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _query,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: 'shelves.pick_search'.tr(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: shown.length,
              itemBuilder: (context, i) {
                final b = shown[i];
                final on = _picked.contains(b.id);
                return CheckboxListTile(
                  value: on,
                  activeColor: accent,
                  title: Text(properName(b.titleAr, b.titleEn)),
                  subtitle: Text(
                    properName(b.authorAr, b.authorEn),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onChanged: (v) => setState(() {
                    v == true ? _picked.add(b.id) : _picked.remove(b.id);
                  }),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _done,
        backgroundColor: paletteOf(widget.shelf).first,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.check_rounded),
        label: Text(
          localizeDigits(
            'shelves.pick_done'.tr(args: ['${_picked.length}']),
            lang,
          ),
        ),
      ),
    );
  }
}
