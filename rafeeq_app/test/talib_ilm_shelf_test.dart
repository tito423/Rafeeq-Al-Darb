import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/library/data/book_catalog.dart';
import 'package:rafeeq_app/features/library/data/book_category.dart';

/// The طالب العلم shelf is a **path**, and stays one.
///
/// THE DEFECT THIS EXISTS FOR — caught before it shipped, by reading
/// `books_tab.dart` rather than by trusting the order the catalogue was
/// written in. The owner asked for «الكتب المتدرجة اللي تعلم طالب العلم
/// الشرعي المنهج الوسطي المعتدل **بتدرج**», and the entries were duly written
/// in teaching order — but the tab sorts every shelf by `sortKey`, the Arabic
/// collation handle. On screen the shelf would have opened on **الآجرومية**,
/// with **جامع بيان العلم وفضله** — the book a student reads first — sitting
/// in the middle. The catalogue would have looked right in the file and been
/// wrong on the device: §1.3 in one sentence.
///
/// `shelfOrder` is what fixes it, and it is exactly the kind of field nothing
/// else can check: every value is a valid `int`, `flutter analyze` has no
/// opinion, and a book left at the default 0 would silently jump to the front
/// of the shelf. So the stages are asserted here by name.
void main() {
  final shelf = libraryBookCatalog
      .where((b) => b.category == BookCategory.talibIlm)
      .toList();

  test('the shelf exists and is not a stub', () {
    expect(shelf.length, greaterThanOrEqualTo(10),
        reason: 'the shelf was created on 2026-09-17 with 14 books');
  });

  test('every book on it declares a stage', () {
    final unstaged = shelf.where((b) => b.shelfOrder == 0).map((b) => b.id);
    expect(unstaged, isEmpty,
        reason: 'shelfOrder defaults to 0, which sorts to the FRONT of the '
            'shelf — a book that forgot to declare its stage does not look '
            'broken, it looks like step one: $unstaged');
  });

  test('the stages are 1..4 and none of them is empty', () {
    final stages = shelf.map((b) => b.shelfOrder).toSet().toList()..sort();
    expect(stages, [1, 2, 3, 4],
        reason: 'the four stages are آداب الطلب, المتون الأولى, التوسّع and '
            'المقاصد; an empty one means books were removed without the '
            'shelf being rethought');
  });

  test('the shelf, sorted the way the tab sorts it, opens on آداب الطلب', () {
    // The same comparator as `books_tab.dart`. If that one changes and this
    // does not, the test stops describing the screen — so it is duplicated
    // deliberately and the file it mirrors is named here.
    final ordered = [...shelf]..sort((x, y) {
        final byShelf = x.shelfOrder.compareTo(y.shelfOrder);
        return byShelf != 0 ? byShelf : x.sortKey.compareTo(y.sortKey);
      });
    expect(ordered.first.shelfOrder, 1);
    expect(ordered.last.shelfOrder, 4);
    expect(ordered.map((b) => b.shelfOrder).toList(),
        [for (final b in ordered) b.shelfOrder]..sort(),
        reason: 'the stages must come out monotonically');

    // The two books the whole shelf is built around.
    expect(ordered.any((b) => b.id == 'jami_bayan_al_ilm'), isTrue);
    expect(ordered.firstWhere((b) => b.id == 'jami_bayan_al_ilm').shelfOrder, 1,
        reason: 'جامع بيان العلم وفضله is where the path starts');
    expect(ordered.firstWhere((b) => b.id == 'al_muwafaqat').shelfOrder, 4,
        reason: 'الموافقات is the مقاصد stage — the point of the shelf');
  });

  test('the comparator really is the one the tab uses', () {
    // A test that mirrors production code is worth nothing if production
    // stops doing it. This reads the tab and insists the field is consulted.
    final tab = File('lib/features/library/presentation/tabs/books_tab.dart')
        .readAsStringSync();
    expect(tab.contains('shelfOrder'), isTrue,
        reason: 'books_tab.dart no longer sorts on shelfOrder, so the shelf '
            'is alphabetical again and this whole file is describing '
            'something that is not on the screen');
  });

  test('الاعتصام is not on the shelf, and that is deliberate', () {
    // Recorded so a later session does not "complete the set". The owner
    // asked to stay far from تشدد; الموافقات is the مقاصد book and الاعتصام
    // is the polemic. See CONTENT-LICENSES.md.
    expect(libraryBookCatalog.any((b) => b.id == 'al_itisam'), isFalse);
  });
}
