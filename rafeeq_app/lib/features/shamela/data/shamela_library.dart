import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../library/data/book_catalog.dart';
import '../../library/data/book_category.dart';

/// Books the reader imported from Shamela, as library books.
///
/// The library's catalogue is a const list written by the pipeline; an
/// imported book is not in it. This keeps a small record per import (in
/// app support, `shamela/imported.json`) and turns each into a
/// [LibraryBook] under «من الشاملة», so the reader, the text search and
/// «مكتبتي» handle it like any other book. [bookById] consults it through
/// `extraBookLookup`, set once at start-up.
class ShamelaLibrary extends ChangeNotifier {
  ShamelaLibrary._();
  static final ShamelaLibrary instance = ShamelaLibrary._();

  final Map<String, LibraryBook> _books = {};
  final Map<String, Map<String, dynamic>> _records = {};
  bool _loaded = false;

  static String idFor(int shamelaId) => 'shamela_$shamelaId';

  List<LibraryBook> get books => _books.values.toList();
  LibraryBook? byId(String id) => _books[id];
  bool isImported(int shamelaId) => _books.containsKey(idFor(shamelaId));

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'shamela', 'imported.json'));
  }

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    extraBookLookup = byId;
    final f = await _file();
    if (!f.existsSync()) return;
    try {
      for (final r in jsonDecode(await f.readAsString()) as List) {
        final m = (r as Map).cast<String, dynamic>();
        _records['${m['id']}'] = m;
        _books['${m['id']}'] = _toBook(m);
      }
    } catch (_) {}
    notifyListeners();
  }

  static LibraryBook _toBook(Map<String, dynamic> m) => LibraryBook(
    id: '${m['id']}',
    titleAr: '${m['titleAr']}',
    titleEn: '${m['titleAr']}',
    authorAr: '${m['authorAr']}',
    authorEn: '${m['authorAr']}',
    pages: (m['pageCount'] as num?)?.toInt() ?? 0,
    category: BookCategory.shamela,
    sourceUrl: 'https://shamela.ws/book/${m['shamelaId']}',
    textEdition: TextEdition(
      url: 'https://shamela.ws/book/${m['shamelaId']}',
      sourceLabel: 'المكتبة الشاملة',
      sizeBytes: (m['sizeBytes'] as num?)?.toInt() ?? 0,
    ),
  );

  Future<void> add({
    required int shamelaId,
    required String titleAr,
    required String authorAr,
    required int pageCount,
    required int sizeBytes,
  }) async {
    final id = idFor(shamelaId);
    final m = {
      'id': id,
      'shamelaId': shamelaId,
      'titleAr': titleAr,
      'authorAr': authorAr,
      'pageCount': pageCount,
      'sizeBytes': sizeBytes,
      'importedAt': DateTime.now().toUtc().toIso8601String(),
    };
    _records[id] = m;
    _books[id] = _toBook(m);
    await _save();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    _records.remove(id);
    _books.remove(id);
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final f = await _file();
    await f.parent.create(recursive: true);
    await f.writeAsString(jsonEncode(_records.values.toList()));
  }
}
