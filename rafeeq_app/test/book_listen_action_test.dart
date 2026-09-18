import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/library/data/book_catalog.dart';
import 'package:rafeeq_app/features/library/data/book_category.dart';

/// The gate the spoken reader opens on, and where it is wired.
///
/// WHAT THIS DOES NOT DO, said plainly: it does not pump `BookListenAction`
/// in a widget tree. That widget calls `.tr()`, so it needs EasyLocalization
/// initialised with its assets loaded, and in a unit test the child is not
/// built before the assertions run — an earlier version of this file spent
/// its effort fighting that and proved nothing. The widget itself is covered
/// where it can actually be exercised: `integration_test/tts_harakat_test`
/// runs the speaker against a real device.
///
/// So this pins the two things that are true without a device: the threshold
/// is a boundary and not a range, and the control is still reachable from the
/// reader.
void main() {
  LibraryBook bookWith(int pct) => LibraryBook(
        id: 'x',
        titleAr: 'كتاب',
        titleEn: 'Book',
        authorAr: 'مؤلف',
        authorEn: 'Author',
        category: BookCategory.tazkiyah,
        diacritisedPct: pct,
        textEdition: const TextEdition(
          url: 'https://example.invalid/x.json',
          sourceLabel: 'test',
        ),
      );

  test('the threshold is exactly 80, and it is a boundary not a range', () {
    expect(bookWith(0).canBeSpoken, isFalse);
    expect(bookWith(79).canBeSpoken, isFalse);
    expect(bookWith(80).canBeSpoken, isTrue);
    expect(bookWith(87).canBeSpoken, isTrue);
  });

  test('the reader wires the control in, and does not gate it away', () {
    final src = File('lib/features/library/presentation/screens/'
            'book_text_reader_screen.dart')
        .readAsStringSync();
    expect(src, contains('BookListenAction('),
        reason: 'the reader no longer offers the spoken control at all');

    // The control is built UNCONDITIONALLY. The widget decides what tapping
    // it does — read, or say why it will not — and a screen that hid it for
    // unvowelled books would turn a stated decision back into a missing
    // button.
    final widget = File('lib/features/library/presentation/widgets/'
            'book_listen_action.dart')
        .readAsStringSync();
    expect(widget, contains('canBeSpoken'),
        reason: 'the widget stopped consulting the gate');
    expect(widget, contains('_explain'),
        reason: 'the widget stopped explaining itself');
  });
}
