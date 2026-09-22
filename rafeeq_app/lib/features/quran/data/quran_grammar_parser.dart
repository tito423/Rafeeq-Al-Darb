import '../../../../core/db/models.dart';
import '../../../../core/services/quran_api_service.dart';
import '../../../../core/utils/buckwalter.dart';

/// Segment classification in a word's morphological breakdown.
enum MorphemeType {
  prefix,
  stem,
  suffix,
}

/// A decomposed part of an Arabic word (e.g. prefix preposition + noun + suffix pronoun).
class MorphemeSegment {
  final String text;
  final String label;
  final MorphemeType type;

  const MorphemeSegment({
    required this.text,
    required this.label,
    required this.type,
  });
}

/// Rich structured grammatical syntax for one Quranic word.
class WordSyntaxData {
  final int position;
  final String token;
  final String posLabel;
  final String caseDetail;
  final String? rootFormatted;
  final String? lemmaFormatted;
  final List<MorphemeSegment> segments;
  final String? englishMeaning;
  final String? transliteration;

  const WordSyntaxData({
    required this.position,
    required this.token,
    required this.posLabel,
    required this.caseDetail,
    this.rootFormatted,
    this.lemmaFormatted,
    this.segments = const [],
    this.englishMeaning,
    this.transliteration,
  });
}

/// Advanced Parser that synthesizes morphology from SQLite and Quran.com API
/// into classical Arabic syntactic analysis.
class QuranGrammarParser {
  QuranGrammarParser._();

  /// Formats Buckwalter root string (e.g. "Hmd") to spaced Arabic letters (e.g. "ح - م - د").
  ///
  /// In a ROOT the Quranic Arabic Corpus writes the hamza radical as `A` —
  /// `qrA` قرأ, `Amn` أمن, `nbA` نبأ, `$yA` شيء: 151 distinct roots in the
  /// bundled `word_grammar`, measured 2026-09-22. A root never has a long
  /// alif as a radical (a weak radical is w or y), so plain Buckwalter's
  /// `A` → «ا» turned قرآن's root into «ق ر ا». Here `A` is the hamza, drawn
  /// «أ» as the corpus itself displays it. Lemmas are real Buckwalter and
  /// keep the standard mapping.
  static String formatRootLetters(String rawRoot) {
    if (rawRoot.isEmpty) return '';
    final hamzaRoot = rawRoot.replaceAll('A', '>');
    final arabicRoot =
        buckwalterForDisplay(hamzaRoot).replaceAll(RegExp(r'\s+'), '');
    if (arabicRoot.isEmpty) return '';
    return arabicRoot.split('').join(' - ');
  }

  /// Formats lemma (e.g. "{som") to readable Arabic script (e.g. "اسم").
  static String formatLemma(String rawLemma) {
    if (rawLemma.isEmpty) return '';
    return buckwalterForDisplay(rawLemma);
  }

  /// Synthesizes WordGrammar from local DB and optional Quran.com WBW API word.
  static WordSyntaxData parse({
    required WordGrammar local,
    QuranWordWbw? wbw,
  }) {
    final token = local.token.isNotEmpty
        ? local.token
        : (wbw?.textUthmani ?? '');

    final posLabel = _enhancePosLabel(local.posAr, local.caseAr);
    final caseDetail = _enhanceCaseDetail(local.caseAr, local.posAr);
    final rootFormatted = formatRootLetters(local.root);
    final lemmaFormatted = formatLemma(local.lemma);
    final segments = _decomposeWord(token, local);

    return WordSyntaxData(
      position: local.pos,
      token: token,
      posLabel: posLabel,
      caseDetail: caseDetail,
      rootFormatted: rootFormatted.isNotEmpty ? rootFormatted : null,
      lemmaFormatted: lemmaFormatted.isNotEmpty ? lemmaFormatted : null,
      segments: segments,
      englishMeaning: wbw?.translationText,
      transliteration: wbw?.transliterationText,
    );
  }

  /// The Quranic Arabic Corpus's own Arabic name for each part-of-speech
  /// tag, copied from its tagset page
  /// (corpus.quran.com/documentation/tagset.jsp, read 2026-09-22).
  ///
  /// The bundled `word_grammar.pos_ar` was only partly translated: 4,533
  /// words still carried a raw tag (`COND` 899, `T` 660, `RES` 634, `SUB`
  /// 631, `LOC` 602, `CERT` 402, …) and 2,223 carried «حرف تنصيص», a
  /// mistranslation of ACC, which the corpus names «حرف نصب». `NUM` is not
  /// on the tagset page; the corpus's own word pages for سَبْعَ (2:29),
  /// أَرْبَعِينَ (2:51) and عَشْرَةَ (2:60) call each one «اسم», so that is
  /// what it shows.
  static const _corpusPosNames = {
    'حرف تنصيص': 'حرف نصب',
    'COND': 'حرف شرط',
    'T': 'ظرف زمان',
    'RES': 'أداة حصر',
    'SUB': 'حرف مصدري',
    'LOC': 'ظرف مكان',
    'CERT': 'حرف تحقيق',
    'NUM': 'اسم',
    'INC': 'حرف ابتداء',
    'RET': 'حرف اضراب',
    'FUT': 'حرف استقبال',
    'AVR': 'حرف ردع',
    'ANS': 'حرف جواب',
    'EXP': 'أداة استثناء',
    'EXL': 'حرف تفصيل',
    'IMPN': 'اسم فعل أمر',
    'EXH': 'حرف تحضيض',
    'حرف (تفسير/عطف بيان)': 'حرف تفسير',
    'حرف (آيات الابتداء)': 'حروف مقطعة',
  };

  static String _enhancePosLabel(String posAr, String caseAr) {
    if (posAr.isEmpty) return 'كلمة قرآنيّة';
    if (caseAr.contains('فعل ماضٍ')) return 'فعل ماضٍ';
    if (caseAr.contains('فعل مضارع')) return 'فعل مضارع';
    if (caseAr.contains('فعل أمر')) return 'فعل أمر';
    return _corpusPosNames[posAr] ?? posAr;
  }

  /// The corpus's features, as the corpus states them.
  ///
  /// This used to add «(وعلامة نصبه الفتحة)» to every منصوب, «الكسرة» to
  /// every مجرور and so on — which is wrong wherever the sign is not the
  /// short vowel: أَرْبَعِينَ (2:51) is منصوب by its ياء. The corpus gives the
  /// case and nothing more («اسم منصوب»), and so does this now.
  static String _enhanceCaseDetail(String caseAr, String posAr) {
    if (caseAr.isEmpty) {
      if (posAr.contains('حرف')) return 'مبني لا محل له من الإعراب';
      return 'حسب موقعه في الجملة';
    }
    final parts = [
      for (final p in caseAr.split(RegExp(r'\s*[/،]\s*')))
        if (p.trim().isNotEmpty && !p.contains('فعل')) p.trim(),
    ];
    return parts.isEmpty ? caseAr : parts.join(' • ');
  }

  /// No splitting by spelling.
  ///
  /// This used to cut every word into prefix + stem + suffix by looking at
  /// its letters: anything ending in «ه» got «هاء الغائب (ضمير متصل)», so
  /// the Name «ٱللَّهِ» (1:1) was shown carrying an attached pronoun, and
  /// anything starting with «ل» got «لِـ حرف جر», so «لَعَلَّكُمْ» (12:2)
  /// was a preposition plus a word. The bundled table has one row per word
  /// and no segments, so there is nothing true to show here; the card shows
  /// the word's own part of speech, case, root and lemma instead.
  static List<MorphemeSegment> _decomposeWord(
    String token,
    WordGrammar local,
  ) => const [];
}
