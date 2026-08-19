// ── Tafseer book descriptor ───────────────────────────────────────────────────

class TafseerBook {
  final String id;
  final String nameAr;
  final String nameEn;
  final String author;
  final int quranComId; // quran.com tafsirs API identifier
  final String description;

  const TafseerBook({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.author,
    required this.quranComId,
    required this.description,
  });
}

// ── The 6 supported tafseers ─────────────────────────────────────────────────

const kTafseers = <TafseerBook>[
  TafseerBook(
    id: 'muyassar',
    nameAr: 'التفسير المُيَسَّر',
    nameEn: 'Al-Muyassar',
    author: 'مجمع الملك فهد',
    quranComId: 16,
    description: 'تفسير ميسر موجز معتمد من مجمع الملك فهد',
  ),
  TafseerBook(
    id: 'jalalayn',
    nameAr: 'تفسير الجلالين',
    nameEn: 'Tafsir Al-Jalalayn',
    author: 'السيوطي والمحلي',
    quranComId: 74,
    description: 'تفسير الإمامين السيوطي والمحلي',
  ),
  TafseerBook(
    id: 'ibn_kathir',
    nameAr: 'تفسير ابن كثير',
    nameEn: 'Tafsir Ibn Kathir',
    author: 'ابن كثير',
    quranComId: 169,
    description: 'تفسير القرآن العظيم للحافظ ابن كثير',
  ),
  TafseerBook(
    id: 'tabari',
    nameAr: 'تفسير الطبري',
    nameEn: 'Tafsir Al-Tabari',
    author: 'الإمام الطبري',
    quranComId: 91,
    description: 'جامع البيان في تأويل آي القرآن',
  ),
  TafseerBook(
    id: 'qurtubi',
    nameAr: 'تفسير القرطبي',
    nameEn: 'Tafsir Al-Qurtubi',
    author: 'الإمام القرطبي',
    quranComId: 90,
    description: 'الجامع لأحكام القرآن',
  ),
  TafseerBook(
    id: 'saadi',
    nameAr: 'تفسير السعدي',
    nameEn: 'Tafsir Al-Saadi',
    author: 'الشيخ السعدي',
    quranComId: 170,
    description: 'تيسير الكريم الرحمن في تفسير كلام المنان',
  ),
];
