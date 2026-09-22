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

    // Real rows of the bundled word_grammar: 12:2's قُرْءَٰنًا is `qrA`, and
    // the corpus writes every hamza radical as `A`. It showed «ق - ر - ا».
    test('a root\'s A is the hamza radical', () {
      expect(QuranGrammarParser.formatRootLetters('qrA'), 'ق - ر - أ');
      expect(QuranGrammarParser.formatRootLetters('Amn'), 'أ - م - ن');
      expect(QuranGrammarParser.formatRootLetters('nbA'), 'ن - ب - أ');
      expect(QuranGrammarParser.formatRootLetters('nzl'), 'ن - ز - ل');
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
      // The case as the corpus gives it — no «وعلامة جره الكسرة» added.
      expect(parsed.caseDetail, 'مجرور');
      expect(parsed.rootFormatted, 'س - م - و');
      expect(parsed.lemmaFormatted, 'ٱسْم');
      expect(parsed.englishMeaning, 'In (the) name');
      expect(parsed.transliteration, "bis'mi");
      // No segments guessed from the spelling.
      expect(parsed.segments, isEmpty);
    });

    // «ٱللَّهِ» ends in «ه», and the spelling-based splitter labelled that
    // «هاء الغائب (ضمير متصل)» — the Name shown with an attached pronoun.
    test('the Name is never split into a stem and a pronoun', () {
      const local = WordGrammar(
        pos: 2,
        token: 'ٱللَّهِ',
        posAr: 'اسم عَلَم',
        caseAr: 'مجرور',
        root: 'Alh',
        lemma: '{ll~ah',
      );
      final parsed = QuranGrammarParser.parse(local: local);
      expect(parsed.segments, isEmpty);
      expect(
        parsed.segments.map((s) => s.label).join(),
        isNot(contains('ضمير')),
      );
    });

    test('raw corpus tags read in the corpus\'s own Arabic names', () {
      String pos(String tag) => QuranGrammarParser.parse(
        local: WordGrammar(
          pos: 1,
          token: 'x',
          posAr: tag,
          caseAr: '',
          root: '',
          lemma: '',
        ),
      ).posLabel;
      expect(pos('حرف تنصيص'), 'حرف نصب');
      expect(pos('COND'), 'حرف شرط');
      expect(pos('T'), 'ظرف زمان');
      expect(pos('NUM'), 'اسم');
      expect(pos('حرف جر'), 'حرف جر');
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
      expect(parsed.caseDetail, 'مرفوع');
    });
  });
}
