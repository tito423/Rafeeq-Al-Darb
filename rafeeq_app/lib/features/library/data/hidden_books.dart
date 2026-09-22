import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Books the reader took off his own shelves.
///
/// «اديني إمكانية إني أمسح أي كتاب من التصنيف نفسه قبل تحميله أصلًا»
/// (2026-09-22). A book not on the phone has nothing to delete, so this is
/// the catalogue's side of it: the book leaves the authors and categories
/// lists on this device. Nothing is removed from the catalogue itself or
/// from the bucket, and «الكتب المخفية» brings any of them back.
class HiddenBooks extends ChangeNotifier {
  HiddenBooks._();
  static final HiddenBooks instance = HiddenBooks._();

  static const _key = 'library_hidden_books_v1';

  final Set<String> _ids = {};
  Future<void>? _ready;

  Future<void> ensureReady() => _ready ??= _load();

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _ids.addAll(prefs.getStringList(_key) ?? const []);
    notifyListeners();
  }

  bool isHidden(String bookId) => _ids.contains(bookId);
  Set<String> get ids => Set.unmodifiable(_ids);
  int get count => _ids.length;

  Future<void> hide(String bookId) => _set(bookId, true);
  Future<void> restore(String bookId) => _set(bookId, false);

  Future<void> _set(String bookId, bool hidden) async {
    await ensureReady();
    final changed = hidden ? _ids.add(bookId) : _ids.remove(bookId);
    if (!changed) return;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _ids.toList()..sort());
  }
}
