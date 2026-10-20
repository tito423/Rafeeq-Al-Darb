import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/quran/data/quran_bookmarks_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('an ayah and a page are marked, listed newest first, and kept', () async {
    final prefs = await SharedPreferences.getInstance();
    final marks = QuranBookmarksNotifier(prefs);

    expect(await marks.toggleAyah(2, 255, 42), isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 2));
    expect(await marks.togglePage(3), isTrue);

    expect(marks.state.first.isAyah, isFalse);
    expect(marks.state.first.page, 3);
    expect(marks.hasAyah(2, 255), isTrue);
    expect(marks.hasPage(3), isTrue);
    // A page bookmark is not an ayah bookmark on that page.
    expect(marks.hasPage(42), isFalse);

    // Reopened from the same preferences: nothing lost.
    final again = QuranBookmarksNotifier(prefs);
    expect(again.state.map((b) => b.key), ['p:3', 'a:2:255']);
  });

  test('marking the same place again removes it', () async {
    final prefs = await SharedPreferences.getInstance();
    final marks = QuranBookmarksNotifier(prefs);
    await marks.toggleAyah(1, 1, 1);
    expect(await marks.toggleAyah(1, 1, 1), isFalse);
    expect(marks.state, isEmpty);
    expect(QuranBookmarksNotifier(prefs).state, isEmpty);
  });

  test('a damaged entry is skipped, the rest kept', () async {
    SharedPreferences.setMockInitialValues({
      QuranBookmarksNotifier.prefsKey:
          '[{"p":5,"t":1},{"p":999,"t":2},{"s":2,"a":1,"p":2,"t":3},"x"]',
    });
    final prefs = await SharedPreferences.getInstance();
    final marks = QuranBookmarksNotifier(prefs);
    expect(marks.state.map((b) => b.key), ['a:2:1', 'p:5']);
  });
}
