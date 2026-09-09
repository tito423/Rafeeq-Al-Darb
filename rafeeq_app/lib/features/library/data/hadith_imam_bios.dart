/// A short, factual note on the compiler of each of the nine collections.
///
/// Keyed by `books.book_key` in `hadith.db`, and translated in all seven
/// locales under `imam_bio.<key>` — the paragraph used to live here in
/// Arabic only, so the whole «about the compiler» card was Arabic on every
/// other UI. The collection's own name, its
/// compiler's full name, and its hadith/chapter counts all come from that
/// database — only this biographical sentence lives here, because the database
/// has no column for it.
///
/// Each entry is limited to the standard, uncontested biographical facts:
/// birth and death years in Hijri, place of origin, and what the collection is
/// known for. Nothing here is an assessment or a ranking — the app deliberately
/// does not grade the compilers, the same way the hadith cards no longer show a
/// grade.
const hadithImamBioKeys = <String, String>{
  'bukhari': 'imam_bio.bukhari',
  'muslim': 'imam_bio.muslim',
  'abudawud': 'imam_bio.abudawud',
  'tirmidhi': 'imam_bio.tirmidhi',
  'nasai': 'imam_bio.nasai',
  'ibnmajah': 'imam_bio.ibnmajah',
  'ahmed': 'imam_bio.ahmed',
  'malik': 'imam_bio.malik',
  'darimi': 'imam_bio.darimi',
};
