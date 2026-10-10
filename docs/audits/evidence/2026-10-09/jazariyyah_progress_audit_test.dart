import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rafeeq_app/features/tajweed/data/jazariyyah_course.dart';
import 'package:rafeeq_app/features/tajweed/presentation/screens/jazariyyah_level_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('one Jazariyyah title tick completes two distinct lessons', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final progress = JazariyyahProgress();
    addTearDown(progress.dispose);
    await Future<void>.delayed(Duration.zero);
    final first = jazariyyahLessons[7];
    final second = jazariyyahLessons[9];
    expect(first.title, second.title);
    expect(first.fromIndex, isNot(second.fromIndex));
    expect(first.printedFrom, 70);
    expect(second.printedFrom, 76);
    await progress.toggle(first.title);
    expect(progress.state.length, 1);
    expect(progress.state.contains(second.title), isTrue);
    final completed = jazariyyahLessons
        .where((lesson) => progress.state.contains(lesson.title)).length;
    expect(completed, 2, reason: 'same count formula as the actual header');
    expect(prefs.getStringList('jazariyyah_done_v1'), [first.title]);
    final reopened = JazariyyahProgress();
    addTearDown(reopened.dispose);
    await Future<void>.delayed(Duration.zero);
    expect(jazariyyahLessons
        .where((lesson) => reopened.state.contains(lesson.title)).length, 2);
    await reopened.toggle(second.title);
    expect(reopened.state.contains(first.title), isFalse);
    expect(reopened.state.contains(second.title), isFalse);
    print('AUDIT_JAZARIYYAH_PROGRESS: lessons 8 (printed70-72) and10 '
        '(printed76-78) have one persisted title; one toggle completes2; '
        'reopen retains both; unticking either removes both');
  });
}
