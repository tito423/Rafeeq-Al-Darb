import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'jazariyyah_course.dart';

/// Source coordinates identify the lesson independently of its display title
/// and list order. The generated book text and ranges remain untouched.
extension JazariyyahLessonIdentity on JazariyyahLesson {
  String get progressId =>
      '$jazariyyahBook:$fromIndex:$fromPara:$toIndex:$toPara';
}

class JazariyyahProgress extends StateNotifier<Set<String>> {
  JazariyyahProgress() : super({}) {
    ready = _load();
  }

  static const legacyKey = 'jazariyyah_done_v1';
  static const key = 'jazariyyah_done_v2';
  late final Future<void> ready;
  Future<void> _writes = Future<void>.value();

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    var saved = prefs.getStringList(key);
    if (saved == null) {
      final legacy = (prefs.getStringList(legacyKey) ?? const []).toSet();
      // An old shared title displayed both lessons as complete. Preserve that
      // visible progress, then let the reader change either lesson separately.
      saved = [
        for (final lesson in jazariyyahLessons)
          if (legacy.contains(lesson.title)) lesson.progressId,
      ];
      if (!await prefs.setStringList(key, saved)) {
        throw StateError('Could not migrate Jazariyyah progress');
      }
    }
    if (mounted) state = saved.toSet();
  }

  Future<void> toggle(String lessonId) {
    if (!jazariyyahLessons.any((lesson) => lesson.progressId == lessonId)) {
      return Future<void>.error(ArgumentError.value(lessonId, 'lessonId'));
    }
    final operation = _writes.then((_) async {
      await ready;
      if (!mounted) return;
      final next = state.toSet();
      next.contains(lessonId) ? next.remove(lessonId) : next.add(lessonId);
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setStringList(key, next.toList())) {
        throw StateError('Could not save Jazariyyah progress');
      }
      if (mounted) state = next;
      // Version 3.87 can only represent shared titles. Keep any title with at
      // least one completed lesson, and retain unknown legacy entries verbatim.
      final titles = jazariyyahLessons.map((lesson) => lesson.title).toSet();
      final legacy = {
        for (final title in prefs.getStringList(legacyKey) ?? const <String>[])
          if (!titles.contains(title)) title,
        for (final lesson in jazariyyahLessons)
          if (next.contains(lesson.progressId)) lesson.title,
      };
      if (!await prefs.setStringList(legacyKey, legacy.toList())) {
        throw StateError('Could not save legacy Jazariyyah progress');
      }
    });
    // A failed write reaches its caller without stranding subsequent changes.
    _writes = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }
}

final jazariyyahProgressProvider =
    StateNotifierProvider<JazariyyahProgress, Set<String>>(
      (ref) => JazariyyahProgress(),
    );
