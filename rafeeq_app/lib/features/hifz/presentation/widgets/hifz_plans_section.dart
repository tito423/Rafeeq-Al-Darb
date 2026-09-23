/// «حفظي» on the memorization screen: the stretches the reader chose, and
/// «حفظ جديد» to choose another — from any ayah of any surah to any later
/// one. See `hifz_plans.dart` for why a plan is only a range.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/models.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/arabic_normalize.dart'
    show surahNamePlain, surahNameShort;
import '../../../../core/utils/digits.dart';
import '../../data/hifz_plans.dart';
import '../../data/hifz_store.dart';
import '../hifz_session_screen.dart';

/// «مريم» out of «سورة مريم» — a plan's default name is short.
String _bareName(Surah s) => surahNameShort(s.nameAr);

/// What a plan is called when the reader gave it no name: «مريم ١٢–٤٠», or
/// «مريم ١٢ – طه ٥» when it crosses into another surah.
String hifzPlanTitle(HifzPlan plan, Map<int, Surah> surahs) {
  if (plan.name.isNotEmpty) return plan.name;
  final a = surahs[plan.from.surah], b = surahs[plan.to.surah];
  if (a == null || b == null) return '';
  final text = plan.from.surah == plan.to.surah
      ? '${_bareName(a)} ${plan.from.ayah}–${plan.to.ayah}'
      : '${_bareName(a)} ${plan.from.ayah} – ${_bareName(b)} ${plan.to.ayah}';
  return localizeDigits(text, uiLanguageCode);
}

class HifzPlansSection extends ConsumerWidget {
  final List<Surah> surahs;
  const HifzPlansSection({super.key, required this.surahs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(hifzPlansProvider);
    final state = ref.watch(hifzStoreProvider);
    final byId = {for (final s in surahs) s.id: s};

    int total(HifzPlan p) {
      var n = 0;
      for (var s = p.from.surah; s <= p.to.surah; s++) {
        final count = byId[s]?.ayahsCount ?? 0;
        final first = s == p.from.surah ? p.from.ayah : 1;
        final last = s == p.to.surah ? p.to.ayah : count;
        if (last >= first) n += last - first + 1;
      }
      return n;
    }

    int due(HifzPlan p) {
      var n = 0;
      for (var s = p.from.surah; s <= p.to.surah; s++) {
        final count = byId[s]?.ayahsCount ?? 0;
        final first = s == p.from.surah ? p.from.ayah : 1;
        final last = s == p.to.surah ? p.to.ayah : count;
        for (var a = first; a <= last; a++) {
          if (state.isDue(s, a)) n++;
        }
      }
      return n;
    }

    void open(HifzPlan p) => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HifzSessionScreen(
          from: p.from,
          to: p.to,
          title: hifzPlanTitle(p, byId),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'hifz.my_plans'.tr(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: () async {
                  final plan = await showModalBottomSheet<HifzPlan>(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    builder: (_) => _NewPlanSheet(surahs: surahs),
                  );
                  if (plan != null && context.mounted) open(plan);
                },
                icon: const Icon(Icons.add_rounded),
                label: Text('hifz.new_plan'.tr()),
              ),
            ],
          ),
        ),
        for (final p in plans)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: AppColors.gold.withValues(alpha: 0.08),
            child: ListTile(
              leading: const Icon(
                Icons.bookmark_rounded,
                color: AppColors.gold,
              ),
              title: Text(hifzPlanTitle(p, byId)),
              subtitle: Text(
                trn('hifz.due_count', args: ['${due(p)}', '${total(p)}']),
              ),
              trailing: IconButton(
                tooltip: 'hifz.plan_delete'.tr(),
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () =>
                    ref.read(hifzPlansProvider.notifier).remove(p.id),
              ),
              onTap: () => open(p),
            ),
          ),
        const Divider(height: 20),
      ],
    );
  }
}

class _NewPlanSheet extends ConsumerStatefulWidget {
  final List<Surah> surahs;
  const _NewPlanSheet({required this.surahs});

  @override
  ConsumerState<_NewPlanSheet> createState() => _NewPlanSheetState();
}

class _NewPlanSheetState extends ConsumerState<_NewPlanSheet> {
  late int _fromSurah = widget.surahs.first.id;
  int _fromAyah = 1;
  late int _toSurah = _fromSurah;
  late int _toAyah = _count(_fromSurah);
  final _name = TextEditingController();

  int _count(int surah) =>
      widget.surahs.firstWhere((s) => s.id == surah).ayahsCount;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// Keeps the end at or after the start: moving the start past it takes the
  /// end to the close of the start's surah.
  void _clampEnd() {
    if (AyahRef(_toSurah, _toAyah).compareTo(AyahRef(_fromSurah, _fromAyah)) <
        0) {
      _toSurah = _fromSurah;
      _toAyah = _count(_fromSurah);
    }
  }

  Widget _surahField(
    String label,
    int value,
    ValueChanged<int> onChanged, {
    int minSurah = 1,
  }) {
    final lang = context.locale.languageCode;
    // Keyed on what it shows: `initialValue` is read once, so a field whose
    // value is changed from outside (the end, when the start moves) must be
    // rebuilt to show it.
    return DropdownButtonFormField<int>(
      key: ValueKey('$label:$value:$minSurah'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, isDense: true),
      items: [
        for (final s in widget.surahs)
          if (s.id >= minSurah)
            DropdownMenuItem(
              value: s.id,
              child: Text(
                '${localizeDigits('${s.id}', lang)}. ${surahNamePlain(s.nameAr)}',
              ),
            ),
      ],
      onChanged: (v) => v == null ? null : onChanged(v),
    );
  }

  Widget _ayahField(
    int surah,
    int value,
    ValueChanged<int> onChanged, {
    int minAyah = 1,
  }) {
    final lang = context.locale.languageCode;
    return DropdownButtonFormField<int>(
      key: ValueKey('$surah:$minAyah:$value'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'hifz.plan_ayah'.tr(),
        isDense: true,
      ),
      items: [
        for (var a = minAyah; a <= _count(surah); a++)
          DropdownMenuItem(value: a, child: Text(localizeDigits('$a', lang))),
      ],
      onChanged: (v) => v == null ? null : onChanged(v),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sameSurah = _toSurah == _fromSurah;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'hifz.new_plan'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          Text(
            'hifz.plan_from'.tr(),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _surahField('hifz.plan_surah'.tr(), _fromSurah, (v) {
                  setState(() {
                    _fromSurah = v;
                    _fromAyah = 1;
                    _toSurah = v;
                    _toAyah = _count(v);
                  });
                }),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: _ayahField(_fromSurah, _fromAyah, (v) {
                  setState(() {
                    _fromAyah = v;
                    _clampEnd();
                  });
                }),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'hifz.plan_to'.tr(),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _surahField(
                  'hifz.plan_surah'.tr(),
                  _toSurah,
                  (v) => setState(() {
                    _toSurah = v;
                    _toAyah = _count(v);
                    _clampEnd();
                  }),
                  minSurah: _fromSurah,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: _ayahField(
                  _toSurah,
                  _toAyah,
                  (v) => setState(() => _toAyah = v),
                  minAyah: sameSurah ? _fromAyah : 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _name,
            decoration: InputDecoration(
              labelText: 'hifz.plan_name'.tr(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () async {
              final plan = await ref
                  .read(hifzPlansProvider.notifier)
                  .add(
                    name: _name.text,
                    from: AyahRef(_fromSurah, _fromAyah),
                    to: AyahRef(_toSurah, _toAyah),
                  );
              if (context.mounted) Navigator.of(context).pop(plan);
            },
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text('hifz.plan_start'.tr()),
          ),
        ],
      ),
    );
  }
}

/// «في الشاشة دي اديني اختيار تغيير الاية … اقدر اغير السورة والايه اللي
/// ابتدي منها» (the owner, 2026-09-23): from inside a session, pick any
/// surah and ayah and carry on from there. Returns the chosen start.
Future<AyahRef?> showAyahJumpSheet(
  BuildContext context,
  List<Surah> surahs,
  AyahRef initial,
) => showModalBottomSheet<AyahRef>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _JumpSheet(surahs: surahs, initial: initial),
);

class _JumpSheet extends StatefulWidget {
  final List<Surah> surahs;
  final AyahRef initial;
  const _JumpSheet({required this.surahs, required this.initial});

  @override
  State<_JumpSheet> createState() => _JumpSheetState();
}

class _JumpSheetState extends State<_JumpSheet> {
  late int _surah = widget.initial.surah;
  late int _ayah = widget.initial.ayah;

  int get _count => widget.surahs.firstWhere((s) => s.id == _surah).ayahsCount;

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'hifz.jump'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<int>(
                  key: ValueKey('s$_surah'),
                  initialValue: _surah,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'hifz.plan_surah'.tr(),
                    isDense: true,
                  ),
                  items: [
                    for (final s in widget.surahs)
                      DropdownMenuItem(
                        value: s.id,
                        child: Text(
                          '${localizeDigits('${s.id}', lang)}. ${surahNamePlain(s.nameAr)}',
                        ),
                      ),
                  ],
                  onChanged: (v) => v == null
                      ? null
                      : setState(() {
                          _surah = v;
                          _ayah = 1;
                        }),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<int>(
                  key: ValueKey('a$_surah:$_ayah'),
                  initialValue: _ayah,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'hifz.plan_ayah'.tr(),
                    isDense: true,
                  ),
                  items: [
                    for (var a = 1; a <= _count; a++)
                      DropdownMenuItem(
                        value: a,
                        child: Text(localizeDigits('$a', lang)),
                      ),
                  ],
                  onChanged: (v) =>
                      v == null ? null : setState(() => _ayah = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(AyahRef(_surah, _ayah)),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text('hifz.jump_start'.tr()),
          ),
        ],
      ),
    );
  }
}
