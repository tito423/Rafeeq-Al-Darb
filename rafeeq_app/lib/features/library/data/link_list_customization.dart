import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/rafeeq_app.dart';

/// The reader's own arrangement of a link list — «قنوات دعوية» or «مواقع
/// إسلامية».
///
/// «حط امكانية اخفاء تعديل و حذف واعادة ترتيب في القنوات الدعوية والمواقع
/// الاسلامية». The catalogues themselves stay what they are — verified
/// constants in `data/` — and this records only what the reader changed on
/// top of them, keyed by each entry's stable id. So a catalogue that gains an
/// entry in a later release still shows it (appended after the reader's
/// order), and «استعادة القائمة الأصلية» is simply forgetting this record.
class LinkListState {
  /// Ids in the reader's order. Ids missing from it keep catalogue order,
  /// after these.
  final List<String> order;
  final Set<String> hidden;
  final Set<String> deleted;

  /// id -> (name, url) the reader typed over the catalogue's.
  final Map<String, (String, String)> edits;

  const LinkListState({
    this.order = const [],
    this.hidden = const {},
    this.deleted = const {},
    this.edits = const {},
  });

  bool get isCustomised =>
      order.isNotEmpty ||
      hidden.isNotEmpty ||
      deleted.isNotEmpty ||
      edits.isNotEmpty;

  /// [ids] (catalogue order) arranged by the reader, deleted ones removed.
  List<String> arrange(List<String> ids) {
    final present = ids.where((id) => !deleted.contains(id)).toList();
    final ranked = <String>[
      for (final id in order)
        if (present.contains(id)) id,
    ];
    return [
      ...ranked,
      for (final id in present)
        if (!ranked.contains(id)) id,
    ];
  }

  Map<String, dynamic> toJson() => {
        'order': order,
        'hidden': hidden.toList(),
        'deleted': deleted.toList(),
        'edits': {
          for (final e in edits.entries)
            e.key: {'name': e.value.$1, 'url': e.value.$2},
        },
      };

  factory LinkListState.fromJson(Map<String, dynamic> j) => LinkListState(
        order: [for (final v in (j['order'] as List? ?? const [])) '$v'],
        hidden: {for (final v in (j['hidden'] as List? ?? const [])) '$v'},
        deleted: {for (final v in (j['deleted'] as List? ?? const [])) '$v'},
        edits: {
          for (final e
              in ((j['edits'] as Map?) ?? const {}).entries)
            '${e.key}': (
              '${(e.value as Map)['name'] ?? ''}',
              '${(e.value as Map)['url'] ?? ''}',
            ),
        },
      );
}

class LinkListNotifier extends StateNotifier<LinkListState> {
  LinkListNotifier(this._prefs, this.listId) : super(_read(_prefs, listId));

  final SharedPreferences _prefs;
  final String listId;

  static String _key(String listId) => 'links.$listId.v1';

  static LinkListState _read(SharedPreferences prefs, String listId) {
    final raw = prefs.getString(_key(listId));
    if (raw == null) return const LinkListState();
    try {
      return LinkListState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // A record that cannot be read must not hide the whole list.
      return const LinkListState();
    }
  }

  Future<void> _save(LinkListState next) async {
    state = next;
    if (!next.isCustomised) {
      await _prefs.remove(_key(listId));
      return;
    }
    await _prefs.setString(_key(listId), jsonEncode(next.toJson()));
  }

  Future<void> reorder(List<String> idsInNewOrder) => _save(LinkListState(
        order: idsInNewOrder,
        hidden: state.hidden,
        deleted: state.deleted,
        edits: state.edits,
      ));

  Future<void> setHidden(String id, bool hidden) => _save(LinkListState(
        order: state.order,
        hidden: hidden
            ? {...state.hidden, id}
            : ({...state.hidden}..remove(id)),
        deleted: state.deleted,
        edits: state.edits,
      ));

  Future<void> delete(String id) => _save(LinkListState(
        order: [...state.order]..remove(id),
        hidden: {...state.hidden}..remove(id),
        deleted: {...state.deleted, id},
        edits: {...state.edits}..remove(id),
      ));

  Future<void> edit(String id, String name, String url) => _save(LinkListState(
        order: state.order,
        hidden: state.hidden,
        deleted: state.deleted,
        edits: {...state.edits, id: (name.trim(), url.trim())},
      ));

  Future<void> restoreDefaults() => _save(const LinkListState());
}

/// One record per list: `'channels'` and `'websites'`.
final linkListProvider = StateNotifierProvider.family<LinkListNotifier,
    LinkListState, String>((ref, listId) {
  return LinkListNotifier(ref.watch(sharedPrefsProvider), listId);
});

/// «خلي امكانية اختيار فتحه داخل التطبيق او ببرنامج خارجي». One choice for
/// both lists. Defaults to external, which is how every link has opened so
/// far — turning the setting up for the first time must not change it.
class LinkOpenInAppNotifier extends StateNotifier<bool> {
  LinkOpenInAppNotifier(this._prefs) : super(_prefs.getBool(_key) ?? false);

  final SharedPreferences _prefs;
  static const _key = 'links.open_in_app_v1';

  Future<void> set(bool inApp) async {
    state = inApp;
    await _prefs.setBool(_key, inApp);
  }
}

final linkOpenInAppProvider =
    StateNotifierProvider<LinkOpenInAppNotifier, bool>((ref) {
  return LinkOpenInAppNotifier(ref.watch(sharedPrefsProvider));
});
