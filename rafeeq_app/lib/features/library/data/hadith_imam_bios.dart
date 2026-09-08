/// A short, factual note on the compiler of each of the nine collections.
///
/// Keyed by `books.book_key` in `hadith.db`. The collection's own name, its
/// compiler's full name, and its hadith/chapter counts all come from that
/// database — only this biographical sentence lives here, because the database
/// has no column for it.
///
/// Each entry is limited to the standard, uncontested biographical facts:
/// birth and death years in Hijri, place of origin, and what the collection is
/// known for. Nothing here is an assessment or a ranking — the app deliberately
/// does not grade the compilers, the same way the hadith cards no longer show a
/// grade.
const hadithImamBios = <String, String>{
  'bukhari':
      'وُلد ببخارى سنة ١٩٤هـ وتوفي سنة ٢٥٦هـ. رحل في طلب الحديث إلى الحجاز '
      'والشام والعراق ومصر، وجمع «الجامع الصحيح» واشترط فيه أعلى درجات '
      'الاتصال في السند.',
  'muslim':
      'وُلد بنيسابور سنة ٢٠٤هـ وتوفي سنة ٢٦١هـ. تتلمذ على البخاري وغيره، '
      'ورتّب صحيحه على الأبواب وجمع طرق الحديث الواحد في موضع واحد.',
  'abudawud':
      'وُلد بسجستان سنة ٢٠٢هـ وتوفي بالبصرة سنة ٢٧٥هـ. عُني في سننه بأحاديث '
      'الأحكام الفقهية، وهو أحد الكتب الستة.',
  'tirmidhi':
      'وُلد بترمذ سنة ٢٠٩هـ وتوفي سنة ٢٧٩هـ. تميّز جامعه بذكر اختلاف الفقهاء '
      'ومذاهبهم عقب الأحاديث، وبالتعليق على أسانيدها.',
  'nasai':
      'وُلد بنسا من خراسان سنة ٢١٥هـ وتوفي سنة ٣٠٣هـ. اشتُهر بدقّة نظره في '
      'علل الأسانيد والرجال، وسننه أحد الكتب الستة.',
  'ibnmajah':
      'وُلد بقزوين سنة ٢٠٩هـ وتوفي سنة ٢٧٣هـ. رتّب سننه على الأبواب الفقهية، '
      'وهو سادس الكتب الستة.',
  'ahmed':
      'وُلد ببغداد سنة ١٦٤هـ وتوفي سنة ٢٤١هـ، وإليه يُنسب المذهب الحنبلي. '
      'رتّب مسنده على أسماء الصحابة لا على الأبواب.',
  'malik':
      'وُلد بالمدينة سنة ٩٣هـ وتوفي بها سنة ١٧٩هـ، وإليه يُنسب المذهب المالكي. '
      'الموطأ من أقدم ما دُوّن، ويجمع الحديث مع عمل أهل المدينة.',
  'darimi':
      'وُلد بسمرقند سنة ١٨١هـ وتوفي سنة ٢٥٥هـ. رتّب سننه على الأبواب، وصدّرها '
      'بمقدمة في العلم وآدابه وفضل النبي ﷺ.',
};
