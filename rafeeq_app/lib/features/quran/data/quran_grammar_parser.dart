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
  static String formatRootLetters(String rawRoot) {
    if (rawRoot.isEmpty) return '';
    final arabicRoot = buckwalterForDisplay(rawRoot).replaceAll(RegExp(r'\s+'), '');
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

  static String _enhancePosLabel(String posAr, String caseAr) {
    if (posAr.isEmpty) return 'كلمة قرآنيّة';
    if (caseAr.contains('فعل ماضٍ')) return 'فعل ماضٍ';
    if (caseAr.contains('فعل مضارع')) return 'فعل مضارع';
    if (caseAr.contains('فعل أمر')) return 'فعل أمر';
    return posAr;
  }

  static String _enhanceCaseDetail(String caseAr, String posAr) {
    if (caseAr.isEmpty) {
      if (posAr.contains('حرف')) return 'مبني لا محل له من الإعراب';
      return 'حسب موقعه في الجملة';
    }

    final parts = caseAr.split(RegExp(r'\s*[/،]\s*'));
    final enhanced = <String>[];

    for (final p in parts) {
      final trimmed = p.trim();
      if (trimmed.isEmpty) continue;
      switch (trimmed) {
        case 'مرفوع':
          enhanced.add('مرفوع (وعلامة رفعه الضمة)');
        case 'منصوب':
          enhanced.add('منصوب (وعلامة نصبه الفتحة)');
        case 'مجرور':
          enhanced.add('مجرور (وعلامة جره الكسرة)');
        case 'مجزوم':
          enhanced.add('مجزوم (وعلامة جزمه السكون)');
        case 'مبني':
          enhanced.add('مبني في محل');
        case 'مفرد':
          enhanced.add('صيغة الإفراد');
        case 'مثنى':
          enhanced.add('صيغة التثنية');
        case 'جمع':
          enhanced.add('صيغة الجمع');
        case 'مذكر':
          enhanced.add('مذكر');
        case 'مؤنث':
          enhanced.add('مؤنث');
        default:
          if (!trimmed.contains('فعل')) {
            enhanced.add(trimmed);
          }
      }
    }

    if (enhanced.isEmpty) {
      return caseAr;
    }
    return enhanced.join(' • ');
  }

  static List<MorphemeSegment> _decomposeWord(String token, WordGrammar local) {
    final segments = <MorphemeSegment>[];
    final clean = token.replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '');

    // Check common prefixes
    if (clean.startsWith('وب') || clean.startsWith('فب')) {
      segments.add(const MorphemeSegment(
        text: 'وَ / فَ',
        label: 'حرف عطف / استئناف',
        type: MorphemeType.prefix,
      ));
      segments.add(const MorphemeSegment(
        text: 'بِـ',
        label: 'حرف جر أصيل',
        type: MorphemeType.prefix,
      ));
    } else if (clean.startsWith('ب') && !clean.startsWith('بل') && clean.length > 2) {
      segments.add(const MorphemeSegment(
        text: 'بِـ',
        label: 'حرف جر',
        type: MorphemeType.prefix,
      ));
    } else if (clean.startsWith('ل') && !clean.startsWith('لا') && clean.length > 2) {
      segments.add(const MorphemeSegment(
        text: 'لِـ',
        label: 'حرف جر / لام التعليل',
        type: MorphemeType.prefix,
      ));
    } else if (clean.startsWith('ال') && clean.length > 3) {
      segments.add(const MorphemeSegment(
        text: 'الْـ',
        label: 'لام التعريف',
        type: MorphemeType.prefix,
      ));
    } else if (clean.startsWith('و') && clean.length > 2 && local.posAr.contains('حرف عطف')) {
      segments.add(const MorphemeSegment(
        text: 'وَ',
        label: 'حرف عطف',
        type: MorphemeType.prefix,
      ));
    }

    // Stem / Root representation
    final stemText = local.lemma.isNotEmpty
        ? formatLemma(local.lemma)
        : token;
    segments.add(MorphemeSegment(
      text: stemText,
      label: local.posAr.isNotEmpty ? local.posAr : 'أصل الكلمة (جذع)',
      type: MorphemeType.stem,
    ));

    // Common attached suffixes (pronouns, dual/plural markers)
    if (clean.endsWith('هم') || clean.endsWith('هن') || clean.endsWith('كم') || clean.endsWith('كن')) {
      segments.add(const MorphemeSegment(
        text: 'ـهُم / ـكُم',
        label: 'ضمير متصل في محل جر / نصب',
        type: MorphemeType.suffix,
      ));
    } else if (clean.endsWith('ه') || clean.endsWith('ها')) {
      segments.add(const MorphemeSegment(
        text: 'ـهُ / ـهَا',
        label: 'هاء الغائب (ضمير متصل)',
        type: MorphemeType.suffix,
      ));
    } else if (clean.endsWith('ك')) {
      segments.add(const MorphemeSegment(
        text: 'ـكَ',
        label: 'كاف الخطاب (ضمير متصل)',
        type: MorphemeType.suffix,
      ));
    } else if (clean.endsWith('ين') || clean.endsWith('ون')) {
      segments.add(const MorphemeSegment(
        text: 'ـونَ / ـينَ',
        label: 'علامة جمع المذكر السالم',
        type: MorphemeType.suffix,
      ));
    }

    return segments;
  }
}
