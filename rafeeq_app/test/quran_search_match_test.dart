import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/utils/quran_search_match.dart';
import 'package:rafeeq_app/features/search/data/topic_tree.dart';

/// Search matching, against real Uthmani words copied out of the bundled
/// `quran_local.db` (reference beside each), not retyped ones.
///
/// Measured over the whole corpus before this shipped
/// (`scratchpad/measure_search.py`, `measure_topics2.py`): «الصلاة» found 0
/// verses under the old word-start matching and 63 under derivatives; the
/// patience topic went from its 6 curated verses to 90.
void main() {
  bool hit(String query, String word, QuranSearchMode mode,
          {bool diacritics = false}) =>
      quranWordTest(query, mode: mode, matchDiacritics: diacritics)!(
          QuranWord.of(word));

  Topic topic(String key) => topicTree
      .expand((c) => c.topics)
      .firstWhere((t) => t.labelKey == key);

  bool inTopic(String key, String word) =>
      topic(key).pattern.wordTest!(QuranWord.of(word));

  group('modes', () {
    test('«الصلاة» as anyone types it finds ٱلصَّلَوٰةَ (2:3)', () {
      // The Uthmani spelling normalises to «الصلواة»: only a pattern that
      // allows a long vowel between letters can reach it.
      expect(hit('الصلاة', 'ٱلصَّلَوٰةَ', QuranSearchMode.derivatives), isTrue);
      expect(hit('الصلاة', 'ٱلصَّلَوٰةَ', QuranSearchMode.wholeWord), isFalse);
    });

    test('all derivatives of «صبر» include ٱلصَّٰبِرِينَ (2:153)', () {
      expect(hit('الصبر', 'ٱلصَّٰبِرِينَ', QuranSearchMode.derivatives), isTrue);
    });

    test('an exact word takes its joined particles but nothing after it', () {
      expect(hit('صبر', 'بِٱلصَّبْرِ', QuranSearchMode.wholeWord), isTrue); // 2:45
      expect(hit('صبر', 'صَبَرُوا۟', QuranSearchMode.wholeWord), isFalse); // 7:137
      expect(hit('صبر', 'صَبَرُوا۟', QuranSearchMode.partial), isTrue);
    });

    test('with diacritics, the harakat must agree', () {
      expect(hit('صَبَرُوا', 'صَبَرُوا۟', QuranSearchMode.partial, diacritics: true),
          isTrue);
      expect(hit('صُبْر', 'صَبَرُوا۟', QuranSearchMode.partial, diacritics: true),
          isFalse);
    });
  });

  group('topic patterns keep their false friends out', () {
    test('Nuh, not «We reveal»', () {
      expect(inTopic('search.prophet_nuh', 'نُوحًا'), isTrue); // 7:59
      expect(inTopic('search.prophet_nuh', 'نُوحِيهَآ'), isFalse); // 11:49
    });

    test('charity, not the hypocrites (loosely «المنفقين»)', () {
      expect(inTopic('search.charity', 'ٱلزَّكَوٰةَ'), isTrue); // 2:43
      expect(inTopic('search.charity', 'ٱلصَّدَقَٰتِ'), isTrue); // 2:271
      expect(inTopic('search.charity', 'ٱلْمُنَٰفِقِينَ'), isFalse); // 4:61
    });

    test('honesty excludes alms even through the loose form «الصدقت»', () {
      // Excluding on each form separately let this back in — measured.
      expect(inTopic('search.honesty', 'ٱلصَّدَقَٰتِ'), isFalse); // 2:271
    });

    test('knowledge, not «the worlds»', () {
      expect(inTopic('search.knowledge', 'ٱلْعَٰلَمِينَ'), isFalse); // 1:2
    });

    test('parents, not «and the blood»', () {
      expect(inTopic('search.parents', 'وَٱلدَّمَ'), isFalse); // 2:173
    });

    test('paradise, not «embryos»', () {
      expect(inTopic('search.paradise', 'ٱلْجَنَّةَ'), isTrue); // 2:35
      expect(inTopic('search.paradise', 'أَجِنَّةٌۭ'), isFalse); // 53:32
    });
  });
}
