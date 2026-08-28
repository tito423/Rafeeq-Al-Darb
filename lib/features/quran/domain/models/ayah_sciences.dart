import 'dart:convert';

class WordMeaningItem {
  final String word;
  final String meaning;
  final String? root;

  WordMeaningItem({
    required this.word,
    required this.meaning,
    this.root,
  });

  factory WordMeaningItem.fromJson(Map<String, dynamic> json) {
    return WordMeaningItem(
      word: json['word'] as String,
      meaning: json['meaning'] as String,
      root: json['root'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'word': word,
        'meaning': meaning,
        if (root != null) 'root': root,
      };
}

class AyahSciencesData {
  final int surahNumber;
  final int ayahNumber;
  final String ayahText;
  final String tafseerSaadi;
  final String tafseerMoyassar;
  final String irab;
  final String asbabNuzul;
  final List<WordMeaningItem> wordMeanings;

  AyahSciencesData({
    required this.surahNumber,
    required this.ayahNumber,
    required this.ayahText,
    required this.tafseerSaadi,
    required this.tafseerMoyassar,
    required this.irab,
    required this.asbabNuzul,
    required this.wordMeanings,
  });

  factory AyahSciencesData.fromMap(Map<String, dynamic> map) {
    final wordMeaningsJson = map['word_meanings_json'] as String? ?? '[]';
    List<WordMeaningItem> wordMeanings = [];
    try {
      final list = jsonDecode(wordMeaningsJson) as List<dynamic>;
      wordMeanings = list.map((e) => WordMeaningItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      // fallback: empty list
    }
    return AyahSciencesData(
      surahNumber: map['surah_number'] as int,
      ayahNumber: map['ayah_number'] as int,
      ayahText: map['ayah_text'] as String? ?? '',
      tafseerSaadi: map['tafseer_saadi'] as String? ?? '',
      tafseerMoyassar: map['tafseer_moyassar'] as String? ?? '',
      irab: map['irab'] as String? ?? '',
      asbabNuzul: map['asbab_nuzul'] as String? ?? '',
      wordMeanings: wordMeanings,
    );
  }

  Map<String, dynamic> toMap() => {
        'surah_number': surahNumber,
        'ayah_number': ayahNumber,
        'ayah_text': ayahText,
        'tafseer_saadi': tafseerSaadi,
        'tafseer_moyassar': tafseerMoyassar,
        'irab': irab,
        'asbab_nuzul': asbabNuzul,
        'word_meanings_json': jsonEncode(wordMeanings.map((e) => e.toJson()).toList()),
      };
}