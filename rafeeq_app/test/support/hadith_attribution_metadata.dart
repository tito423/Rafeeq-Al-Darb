import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/i18n/hadith_grade_i18n.dart';
import 'package:rafeeq_app/features/settings/data/sources_catalog.dart';

void hadithAttributionMetadataTests() {
  const languages = ['ar', 'en', 'fr', 'es', 'pt', 'ru', 'ur'];
  final documents = <String, Map<String, dynamic>>{};
  // Finish actual asset I/O before timed cases. A cold native engine can
  // otherwise return a late asset reply inside the following widget test.
  setUpAll(() async {
    for (final language in languages) {
      documents[language] =
          jsonDecode(
                await rootBundle.loadString(
                  'assets/translations/$language.json',
                ),
              )
              as Map<String, dynamic>;
    }
  });
  const editions = {
    'tirmidhi': '9789960996738',
    'nasai': '9789960587608',
    'ibnmajah': '9789960988139',
  };
  test('A44 Darussalam editions match the original printed identifiers', () {
    for (final entry in editions.entries) {
      expect(darussalamGradingIsbn('Darussalam', entry.key), entry.value);
    }
  });
  test(
    'A44 unknown collections and other scholars keep their source identity',
    () {
      for (final book in ['bukhari', 'muslim', 'abudawud', 'future-book', '']) {
        expect(darussalamGradingIsbn('Darussalam', book), isNull);
      }
      for (final grader in [
        null,
        '',
        'Al-Albani',
        'شعيب الأرناؤوط',
        'darussalam',
      ]) {
        expect(darussalamGradingIsbn(grader, 'tirmidhi'), isNull);
      }
      expect(localizedHadithGrader('Al-Albani', 'ar'), 'الألباني');
      expect(localizedHadithGrade('Hasan Sahih', 'en'), 'Hasan Sahih');
    },
  );
  test('A44 source credits link grading authorship and all three editions', () {
    final sources = sourceGroups.expand((group) => group.$2).toList();
    expect(
      sources.where((s) => s.url == 'https://sunnah.com/about'),
      hasLength(1),
    );
    for (final key in editions.keys) {
      final source = sources.singleWhere(
        (s) => s.roleKey == 'about.src_darussalam_$key',
      );
      expect(source.host, contains(editions[key]!));
      expect(Uri.parse(source.url).host, 'dar-us-salam.com');
    }
  });
  test(
    'A44 attribution and edition references exist in all seven actual assets',
    () {
      for (final language in languages) {
        final document = documents[language]!;
        final label =
            (document['library'] as Map)['takhrij_darussalam'] as String;
        expect(label, contains('{}'));
        expect(label, contains(language == 'ar' ? '٢٠٠٧' : '2007'));
        final about = document['about'] as Map;
        expect(about['src_darussalam_grading'], isNotEmpty);
        for (final entry in editions.entries) {
          expect(about['src_darussalam_${entry.key}'], contains(entry.value));
        }
      }
    },
  );
}
