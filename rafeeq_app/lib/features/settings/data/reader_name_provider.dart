/// The name the reader would like to be greeted by.
///
/// «عايز لما المستخدم ينزل التطبيق أول مرة، التطبيق يسأل المستخدم عن اسمه
/// المفضّل، ويتكتب الاسم ده بزخرفة جميلة جدًا جنب أو تحت مرحبًا بك».
///
/// The Home header has said a generic «مرحبًا بك» since it was written, with a
/// comment saying not to invent a name in the meantime — §1.1. This is the
/// reader telling us one, so there is nothing to invent.
///
/// Empty is a real answer: the greeting stays exactly as it is today for
/// anyone who skips the question, and the question is never asked twice.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReaderNameNotifier extends StateNotifier<String> {
  ReaderNameNotifier() : super('') {
    _restore();
  }

  static const _nameKey = 'reader.preferred_name_v1';
  static const _askedKey = 'reader.name_asked_v1';

  bool _asked = true;

  /// Whether the first-run question is still owed. False once it has been
  /// shown, whatever the reader answered.
  bool get shouldAsk => !_asked;

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    _asked = prefs.getBool(_askedKey) ?? false;
    state = prefs.getString(_nameKey) ?? '';
  }

  Future<void> set(String name) async {
    final clean = name.trim();
    state = clean;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, clean);
  }

  /// Records that the question has been put, so it is not asked again even
  /// when the answer was "no thanks".
  Future<void> markAsked() async {
    _asked = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_askedKey, true);
  }

  /// Reads the flag without waiting for the notifier to restore — `AppShell`
  /// decides on its first frame whether to ask.
  static Future<bool> shouldAskNow() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_askedKey) ?? false);
  }
}

final readerNameProvider =
    StateNotifierProvider<ReaderNameNotifier, String>((ref) {
  return ReaderNameNotifier();
});
