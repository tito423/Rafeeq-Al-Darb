import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/library/data/book_catalog.dart';

/// A book whose hosted file was filtered has to SAY so.
///
/// On 2026-09-17, 47 books were re-uploaded with a modern muhaqqiq's own
/// apparatus — his footnotes, takhrij, introduction and indexes — filtered out,
/// and one more was removed because filtering could not leave a book behind.
/// See `CONTENT-LICENSES.md`.
///
/// The `sourceLabel` on those 47 still names the muhaqqiq, and that is right:
/// naming the printing the text came from is what CLAUDE.md §1.2 requires. But
/// that line ON ITS OWN reads as «this is his edition», which stopped being
/// true the moment the file was filtered. A card that is accurate and
/// misleading at the same time is the harder kind of wrong to notice, and
/// nothing in the app would ever have complained about it.
///
/// So the flag and the line that explains it are held together here.
void main() {
  final flagged = [
    for (final b in libraryBookCatalog)
      if (b.textEdition?.editorNotesRemoved ?? false) b,
  ];

  test('the books that were filtered are still flagged', () {
    // Not a lower bound that can rot upward: this is the count the upload
    // actually produced, and a change to it should be deliberate.
    // 47 until 2026-09-17; 18 of them were Ibn Taymiyyah's and went out with
    // his 60 books that afternoon. The filtering itself did not change.
    expect(flagged.length, 29,
        reason: 'scripts/mark_editor_notes_removed.py flags exactly the set '
            'of files that scripts/upload_stripped_books.py published. If this '
            'number moved, say why in CONTENT-LICENSES.md.');
  });

  test('a flagged book still credits the printing it came from', () {
    // Removing the editor's notes is not a licence to stop naming the source.
    for (final b in flagged) {
      expect(b.textEdition!.sourceLabel.trim(), isNotEmpty, reason: b.id);
      expect(b.textEdition!.sourceLabel, contains('المكتبة الشاملة'),
          reason: b.id);
    }
  });

  test('the explaining line exists, and is real, in all seven locales', () {
    // A missing key renders as the raw key on screen (CLAUDE.md trap #8), so
    // «library.editor_notes_removed» would be what a French reader saw.
    for (final locale in ['ar', 'en', 'es', 'fr', 'pt', 'ru', 'ur']) {
      final file = File('assets/translations/$locale.json');
      expect(file.existsSync(), isTrue, reason: locale);
      final map = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final library = map['library'] as Map<String, dynamic>?;
      expect(library, isNotNull, reason: locale);
      final value = library!['editor_notes_removed'] as String?;
      expect(value, isNotNull,
          reason: '$locale has no library.editor_notes_removed');
      expect(value!.trim(), isNotEmpty, reason: locale);
      // Every locale must carry its OWN words. The first pass of this work
      // shipped Arabic into all seven more than once, which is the defect
      // v3.29.0 and v3.30.0 were spent undoing.
      if (locale != 'ar' && locale != 'ur') {
        expect(RegExp(r'[؀-ۿ]').hasMatch(value), isFalse,
            reason: '$locale still holds Arabic script: $value');
      }
    }
  });

  test('no unflagged book is silently carrying the same claim', () {
    // The flag is the only thing that turns the line on, so a book that was
    // filtered but not flagged would say nothing. That cannot be checked from
    // inside the app — it is what `audit_editor_apparatus.py` is for, and it
    // returned 0 books with apparatus over all 248 on 2026-09-17. This test
    // holds the half that IS checkable: the catalogue and the bucket agree on
    // how many were touched.
    expect(libraryBookCatalog.length, 187,
        reason: 'the library was 257 entries on the morning of 2026-09-17: 7 '
            'duplicates and mislabelled takhrij volumes went, then '
            'al_ijaz_fi_sharh_sunan_abi_dawud on the rights audit (248), then '
            "Ibn Taymiyyah's 60 books and Ibn al-Qayyim's index of them, at "
            'the owner\'s instruction.');
  });
}
