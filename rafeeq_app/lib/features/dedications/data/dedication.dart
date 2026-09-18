import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// «إهداء قراءة القرآن أو الاستغفار للأحباء مع ذكر اسم الشخص المدعو له
/// ونبذة عن الدعاء له يكتبها المستخدم نفسه».
///
/// A dedication is the reader's own: a name, what they are doing for that
/// person, and their own words. The app writes nothing on their behalf — no
/// template dua, no ruling on what reaches whom — it keeps the record and
/// counts what they do.
enum DedicationKind {
  quran,
  istighfar,
  tasbih,
  dua;

  static DedicationKind fromName(String? n) => DedicationKind.values
      .firstWhere((k) => k.name == n, orElse: () => DedicationKind.dua);

  String get titleKey => 'dedication.kind_$name';

  /// What the counter counts, as a translation key: pages for the Qur'an,
  /// repetitions for dhikr. A dua has no counter.
  String? get unitKey => switch (this) {
        DedicationKind.quran => 'dedication.unit_pages',
        DedicationKind.istighfar || DedicationKind.tasbih =>
          'dedication.unit_times',
        DedicationKind.dua => null,
      };
}

class Dedication {
  final String id;
  final String name;
  final DedicationKind kind;
  final String note;
  final int count;
  final DateTime created;

  const Dedication({
    required this.id,
    required this.name,
    required this.kind,
    required this.note,
    required this.count,
    required this.created,
  });

  Dedication copyWith({String? name, DedicationKind? kind, String? note, int? count}) =>
      Dedication(
        id: id,
        name: name ?? this.name,
        kind: kind ?? this.kind,
        note: note ?? this.note,
        count: count ?? this.count,
        created: created,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'note': note,
        'count': count,
        'created': created.toIso8601String(),
      };

  factory Dedication.fromJson(Map<String, dynamic> j) => Dedication(
        id: j['id'] as String,
        name: j['name'] as String,
        kind: DedicationKind.fromName(j['kind'] as String?),
        note: j['note'] as String? ?? '',
        count: (j['count'] as num?)?.toInt() ?? 0,
        created: DateTime.tryParse(j['created'] as String? ?? '') ?? DateTime(2026),
      );
}

class DedicationsNotifier extends StateNotifier<List<Dedication>> {
  DedicationsNotifier() : super(const []) {
    loaded = _restore();
  }

  late final Future<void> loaded;
  static const _key = 'dedications_v1';

  Future<void> _restore() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => Dedication.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) state = list;
    } catch (_) {
      // A corrupt record is not a reason to crash the screen; it is shown
      // empty and the next save writes a clean list.
    }
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(state.map((d) => d.toJson()).toList()));
  }

  Future<void> add(Dedication d) async {
    state = [d, ...state];
    await _save();
  }

  Future<void> update(Dedication d) async {
    state = [for (final x in state) x.id == d.id ? d : x];
    await _save();
  }

  Future<void> remove(String id) async {
    state = state.where((d) => d.id != id).toList();
    await _save();
  }

  Future<void> bump(String id, int by) async {
    state = [
      for (final x in state)
        x.id == id ? x.copyWith(count: (x.count + by).clamp(0, 1 << 30)) : x,
    ];
    await _save();
  }
}

final dedicationsProvider =
    StateNotifierProvider<DedicationsNotifier, List<Dedication>>(
        (ref) => DedicationsNotifier());
