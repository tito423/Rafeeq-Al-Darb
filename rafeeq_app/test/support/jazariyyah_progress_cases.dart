import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/tajweed/data/jazariyyah_course.dart';
import 'package:rafeeq_app/features/tajweed/data/jazariyyah_progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

void jazariyyahProgressCases() {
  late ProviderContainer container;
  final first = jazariyyahLessons[7];
  final second = jazariyyahLessons[9];
  final unique = jazariyyahLessons.first;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer();
  });
  tearDown(() => container.dispose());
  Future<JazariyyahProgress> load() async {
    final notifier = container.read(jazariyyahProgressProvider.notifier);
    await notifier.ready;
    return notifier;
  }

  test('A40 all real source ranges have unique stable identities', () {
    expect(first.title, second.title);
    expect(jazariyyahLessons.map((l) => l.progressId).toSet(), hasLength(18));
    final renamed = JazariyyahLesson(
      title: '${unique.title} ',
      fromIndex: unique.fromIndex,
      fromPara: unique.fromPara,
      toIndex: unique.toIndex,
      toPara: unique.toPara,
      printedFrom: unique.printedFrom,
      printedTo: unique.printedTo,
    );
    expect(renamed.progressId, unique.progressId);
  });
  test(
    'A40 old shared completion migrates both without losing legacy data',
    () async {
      final legacy = [first.title, unique.title, 'archived-unknown-title'];
      SharedPreferences.setMockInitialValues({
        JazariyyahProgress.legacyKey: legacy,
        'private-account-sentinel': 'preserved',
      });
      await load();
      expect(container.read(jazariyyahProgressProvider), {
        first.progressId,
        second.progressId,
        unique.progressId,
      });
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(JazariyyahProgress.legacyKey), legacy);
      expect(prefs.getString('private-account-sentinel'), 'preserved');
    },
  );
  test(
    'A40 removing one migrated lesson preserves the other after reopen',
    () async {
      SharedPreferences.setMockInitialValues({
        JazariyyahProgress.legacyKey: [first.title],
      });
      final notifier = await load();
      await notifier.toggle(first.progressId);
      expect(container.read(jazariyyahProgressProvider), {second.progressId});
      container.dispose();
      container = ProviderContainer();
      await load();
      expect(container.read(jazariyyahProgressProvider), {second.progressId});
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(JazariyyahProgress.legacyKey), [first.title]);
    },
  );
  test('A40 last shared completion removed clears legacy title only', () async {
    SharedPreferences.setMockInitialValues({
      JazariyyahProgress.legacyKey: [first.title, 'archived-unknown-title'],
    });
    final notifier = await load();
    await notifier.toggle(first.progressId);
    await notifier.toggle(second.progressId);
    expect(container.read(jazariyyahProgressProvider), isEmpty);
    expect(
      (await SharedPreferences.getInstance()).getStringList(
        JazariyyahProgress.legacyKey,
      ),
      ['archived-unknown-title'],
    );
  });
  test('A40 v2 wins on reopen and unknown future IDs survive writes', () async {
    SharedPreferences.setMockInitialValues({
      JazariyyahProgress.legacyKey: [first.title],
      JazariyyahProgress.key: [second.progressId, 'future-lesson-id'],
    });
    final notifier = await load();
    expect(container.read(jazariyyahProgressProvider), {
      second.progressId,
      'future-lesson-id',
    });
    await notifier.toggle(unique.progressId);
    expect(container.read(jazariyyahProgressProvider), {
      second.progressId,
      unique.progressId,
      'future-lesson-id',
    });
  });
  test('A40 empty v2 does not resurrect old shared completions', () async {
    SharedPreferences.setMockInitialValues({
      JazariyyahProgress.legacyKey: [first.title],
      JazariyyahProgress.key: <String>[],
    });
    await load();
    expect(container.read(jazariyyahProgressProvider), isEmpty);
  });
  test(
    'A40 quick changes before loading serialize without overwriting progress',
    () async {
      SharedPreferences.setMockInitialValues({
        JazariyyahProgress.legacyKey: [unique.title],
      });
      final notifier = container.read(jazariyyahProgressProvider.notifier);
      await Future.wait([
        notifier.toggle(first.progressId),
        notifier.toggle(second.progressId),
        notifier.toggle(first.progressId),
      ]);
      expect(container.read(jazariyyahProgressProvider), {
        unique.progressId,
        second.progressId,
      });
      expect(
        (await SharedPreferences.getInstance())
            .getStringList(JazariyyahProgress.key)
            ?.toSet(),
        {unique.progressId, second.progressId},
      );
    },
  );
  test('A40 unique new completion remains visible to version 3.87', () async {
    final notifier = await load();
    await notifier.toggle(unique.progressId);
    expect(
      (await SharedPreferences.getInstance()).getStringList(
        JazariyyahProgress.legacyKey,
      ),
      [unique.title],
    );
  });
}
