/// «مكتبتي» - the reader's own shelves.
///
/// Owner, 2026-10-07: «اعمل لي تاب جديد سميه مكتبتي … اقدر … اعمل جروبات
/// جواهم باسماء انا عايزها كل مجموعة كتب عايزة تتلم … عايز اعمل تذكيرات بان
/// انا اقدر اقرأ كتاب في الميعاد الفلاني … او يتعامل مع الكالندر بتاعت
/// جوجل».
///
/// A shelf is a name, a colour, an icon, an ordered list of book ids and an
/// optional weekly reading reminder. Books are referenced by id only: the
/// catalogue stays the single source of a book's title, author and files,
/// and a shelf never copies them. Stored as one JSON list in
/// SharedPreferences; nothing leaves the device.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shelf_reminder_service.dart';

/// When a shelf asks to be read: these weekdays (Dart's 1 = Monday ..
/// 7 = Sunday) at this time.
class ShelfReminder {
  final Set<int> weekdays;
  final int hour;
  final int minute;

  const ShelfReminder({
    required this.weekdays,
    required this.hour,
    required this.minute,
  });

  Map<String, dynamic> toJson() => {
    'days': weekdays.toList()..sort(),
    'h': hour,
    'm': minute,
  };

  factory ShelfReminder.fromJson(Map<String, dynamic> j) => ShelfReminder(
    weekdays: {for (final d in j['days'] as List) (d as num).toInt()},
    hour: (j['h'] as num).toInt(),
    minute: (j['m'] as num).toInt(),
  );
}

class Shelf {
  /// Stable small number: it also names the shelf's notification ids.
  final int id;
  final String name;
  final int colorIndex;
  final int iconIndex;
  final List<String> bookIds;
  final ShelfReminder? reminder;

  const Shelf({
    required this.id,
    required this.name,
    required this.colorIndex,
    required this.iconIndex,
    this.bookIds = const [],
    this.reminder,
  });

  Shelf copyWith({
    String? name,
    int? colorIndex,
    int? iconIndex,
    List<String>? bookIds,
    ShelfReminder? reminder,
    bool clearReminder = false,
  }) => Shelf(
    id: id,
    name: name ?? this.name,
    colorIndex: colorIndex ?? this.colorIndex,
    iconIndex: iconIndex ?? this.iconIndex,
    bookIds: bookIds ?? this.bookIds,
    reminder: clearReminder ? null : (reminder ?? this.reminder),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'color': colorIndex,
    'icon': iconIndex,
    'books': bookIds,
    if (reminder != null) 'reminder': reminder!.toJson(),
  };

  factory Shelf.fromJson(Map<String, dynamic> j) => Shelf(
    id: (j['id'] as num).toInt(),
    name: j['name'] as String,
    colorIndex: (j['color'] as num?)?.toInt() ?? 0,
    iconIndex: (j['icon'] as num?)?.toInt() ?? 0,
    bookIds: [for (final b in (j['books'] as List? ?? const [])) b as String],
    reminder: j['reminder'] == null
        ? null
        : ShelfReminder.fromJson(j['reminder'] as Map<String, dynamic>),
  );
}

class ShelvesNotifier extends StateNotifier<List<Shelf>> {
  ShelvesNotifier() : super(const []) {
    loaded = _restore();
  }

  static const _key = 'library.my_shelves_v1';
  late final Future<void> loaded;

  /// Startup/locale re-arming must wait for the asynchronous saved shelves.
  Future<void> rearmReminders() async {
    await loaded;
    if (!mounted) return;
    for (final shelf in state) {
      await ShelfReminderService.instance.apply(shelf);
    }
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || !mounted) return;
    try {
      state = [
        for (final j in jsonDecode(raw) as List)
          Shelf.fromJson(j as Map<String, dynamic>),
      ];
    } catch (_) {
      // A stored list this build cannot read is left alone, not overwritten
      // until the reader changes something.
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode([for (final s in state) s.toJson()]),
    );
  }

  Shelf? byId(int id) {
    for (final s in state) {
      if (s.id == id) return s;
    }
    return null;
  }

  Future<Shelf> create({
    required String name,
    required int colorIndex,
    required int iconIndex,
  }) async {
    final next = state.isEmpty
        ? 1
        : state.map((s) => s.id).reduce((a, b) => a > b ? a : b) + 1;
    final shelf = Shelf(
      id: next,
      name: name.trim(),
      colorIndex: colorIndex,
      iconIndex: iconIndex,
    );
    state = [...state, shelf];
    await _save();
    return shelf;
  }

  Future<void> update(Shelf shelf) async {
    state = [for (final s in state) s.id == shelf.id ? shelf : s];
    await _save();
    await ShelfReminderService.instance.apply(shelf);
  }

  Future<void> delete(int id) async {
    final gone = byId(id);
    state = [
      for (final s in state)
        if (s.id != id) s,
    ];
    await _save();
    if (gone != null) await ShelfReminderService.instance.cancelAll(gone.id);
  }

  Future<void> reorder(int from, int to) async {
    final list = [...state];
    final s = list.removeAt(from);
    list.insert(to > from ? to - 1 : to, s);
    state = list;
    await _save();
  }

  Future<void> setBooks(int id, List<String> bookIds) async {
    final s = byId(id);
    if (s == null) return;
    await update(s.copyWith(bookIds: bookIds));
  }

  Future<void> removeBook(int id, String bookId) async {
    final s = byId(id);
    if (s == null) return;
    await update(s.copyWith(bookIds: [...s.bookIds]..remove(bookId)));
  }

  Future<void> setReminder(int id, ShelfReminder? reminder) async {
    final s = byId(id);
    if (s == null) return;
    await update(
      reminder == null || reminder.weekdays.isEmpty
          ? s.copyWith(clearReminder: true)
          : s.copyWith(reminder: reminder),
    );
  }
}

final shelvesProvider = StateNotifierProvider<ShelvesNotifier, List<Shelf>>(
  (ref) => ShelvesNotifier(),
);
