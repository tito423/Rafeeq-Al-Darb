/// Real ayah references grouped by theme (WORK_QUEUE Stage 6: "topic tree
/// ... plus conceptual search that finds ayahs by meaning, not just literal
/// words"). This curated grouping — a well-known, widely-cited set of ayahs
/// per topic, the kind found in any Quranic thematic index — is the honest
/// way to do "by meaning" here: this app has no offline semantic/embedding
/// model to genuinely rank ayahs by meaning, and faking one with a keyword
/// search relabeled as "conceptual" would violate zero-mock-data. The
/// keyword search tab (reusing `QuranRepository.search`'s real FTS5 index)
/// covers literal word search separately.
///
/// Every reference below is real and independently verifiable against the
/// bundled `quran_local.db` — nothing here was invented.
class TopicRef {
  final int surah;
  final int fromAyah;
  final int toAyah;
  const TopicRef(this.surah, this.fromAyah, [int? toAyah])
      : toAyah = toAyah ?? fromAyah;
}

class Topic {
  /// Translation key under `search.*`, e.g. `search.patience`.
  final String labelKey;
  final List<TopicRef> refs;
  const Topic(this.labelKey, this.refs);
}

class TopicCategory {
  /// Translation key under `search.*`, e.g. `search.cat_akhlaq`.
  final String labelKey;
  final List<Topic> topics;
  const TopicCategory(this.labelKey, this.topics);
}

const List<TopicCategory> topicTree = [
  TopicCategory('search.cat_aqeedah', [
    Topic('search.tawheed', [
      TopicRef(112, 1, 4), // Al-Ikhlas
      TopicRef(2, 255), // Ayat al-Kursi
      TopicRef(6, 102),
    ]),
  ]),
  TopicCategory('search.cat_akhlaq', [
    Topic('search.patience', [
      TopicRef(2, 153),
      TopicRef(2, 155, 157),
      TopicRef(3, 200),
      TopicRef(39, 10),
    ]),
    Topic('search.mercy', [
      TopicRef(7, 156),
      TopicRef(21, 107),
      TopicRef(6, 12),
    ]),
    Topic('search.honesty', [
      TopicRef(9, 119),
      TopicRef(33, 23, 24),
    ]),
    Topic('search.parents', [
      TopicRef(17, 23, 24),
      TopicRef(31, 14),
      TopicRef(46, 15),
    ]),
    Topic('search.forgiveness', [
      TopicRef(3, 135),
      TopicRef(11, 3),
      TopicRef(39, 53),
    ]),
    Topic('search.knowledge', [
      TopicRef(20, 114),
      TopicRef(58, 11),
      TopicRef(39, 9),
      TopicRef(96, 1, 5),
    ]),
  ]),
  TopicCategory('search.cat_prophets', [
    Topic('search.prophet_nuh', [
      TopicRef(71, 1, 28),
      TopicRef(11, 25, 49),
    ]),
    Topic('search.prophet_ibrahim', [
      TopicRef(21, 51, 73),
      TopicRef(2, 124, 129),
      TopicRef(37, 83, 113),
    ]),
    Topic('search.prophet_musa', [
      TopicRef(20, 9, 98),
      TopicRef(28, 3, 43),
    ]),
    Topic('search.prophet_yusuf', [
      TopicRef(12, 1, 101),
    ]),
  ]),
  TopicCategory('search.cat_rulings', [
    Topic('search.prayer_topic', [
      TopicRef(2, 43),
      TopicRef(29, 45),
      TopicRef(4, 103),
    ]),
    Topic('search.charity', [
      TopicRef(2, 261),
      TopicRef(2, 274),
      TopicRef(9, 103),
    ]),
  ]),
  TopicCategory('search.cat_hereafter', [
    Topic('search.paradise', [
      TopicRef(2, 25),
      TopicRef(32, 17),
      TopicRef(76, 12, 22),
    ]),
    Topic('search.hellfire', [
      TopicRef(2, 24),
      TopicRef(66, 6),
      TopicRef(4, 56),
    ]),
  ]),
];
