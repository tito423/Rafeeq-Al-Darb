import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/db/models.dart';
import 'package:rafeeq_app/core/services/quran_api_service.dart';
import 'package:rafeeq_app/features/quran/data/quran_grammar_parser.dart';

void main() {
  group('QuranGrammarParser', () {
    test('formatRootLetters converts Buckwalter root to spaced Arabic letters', () {
      expect(QuranGrammarParser.formatRootLetters('rHm'), 'ر - ح - م');
      expect(QuranGrammarParser.formatRootLetters('smw'), 'س - م - و');
      expect(QuranGrammarParser.formatRootLetters('Hmd'), 'ح - م - د');
      expect(QuranGrammarParser.formatRootLetters(''), '');
    });

    test('formatLemma converts Buckwalter lemma to Arabic word', () {
      expect(QuranGrammarParser.formatLemma('{som'), 'ٱسْم');
      expect(QuranGrammarParser.formatLemma('Hamod'), 'حَمْد');
      expect(QuranGrammarParser.formatLemma(''), '');
    });

    test('parse decomposes word grammar correctly', () {
      const local = WordGrammar(
        pos: 1,
        token: 'بِسْمِ',
        posAr: 'اسم',
        caseAr: 'مجرور',
        root: 'smw',
        lemma: '{som',
      );

      const wbw = QuranWordWbw(
        id: 1,
        position: 1,
        textUthmani: 'بِسْمِ',
        location: '1:1:1',
        translationText: 'In (the) name',
        transliterationText: "bis'mi",
      );

      final parsed = QuranGrammarParser.parse(local: local, wbw: wbw);

      expect(parsed.position, 1);
      expect(parsed.token, 'بِسْمِ');
      expect(parsed.posLabel, 'اسم');
      expect(parsed.caseDetail, contains('مجرور (وعلامة جره الكسرة)'));
      expect(parsed.rootFormatted, 'س - م - و');
      expect(parsed.lemmaFormatted, 'ٱسْم');
      expect(parsed.englishMeaning, 'In (the) name');
      expect(parsed.transliteration, "bis'mi");
      expect(parsed.segments, isNotEmpty);
      expect(parsed.segments.first.text, 'بِـ');
      expect(parsed.segments.first.type, MorphemeType.prefix);
    });

    test('parse handles verbs and verb tenses', () {
      const local = WordGrammar(
        pos: 2,
        token: 'نَعْبُدُ',
        posAr: 'فعل',
        caseAr: 'مرفوع / فعل مضارع',
        root: 'Ebd',
        lemma: 'Eabada',
      );

      final parsed = QuranGrammarParser.parse(local: local);

      expect(parsed.posLabel, 'فعل مضارع');
      expect(parsed.rootFormatted, 'ع - ب - د');
      expect(parsed.caseDetail, contains('مرفوع (وعلامة رفعه الضمة)'));
    });
  });
}
