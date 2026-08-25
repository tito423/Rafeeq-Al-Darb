class AdhanPhrase {
  final String text;
  final double weight; // Proportion of time this phrase takes

  const AdhanPhrase(this.text, this.weight);
}

class AdhanSyncData {
  static const List<AdhanPhrase> standardAdhan = [
    AdhanPhrase('اللَّهُ أَكْبَرُ اللَّهُ أَكْبَرُ', 1.2), // Usually sung with elongation
    AdhanPhrase('اللَّهُ أَكْبَرُ اللَّهُ أَكْبَرُ', 1.2),
    AdhanPhrase('أَشْهَدُ أَنَّ لَا إِلَهَ إِلَّا اللَّهُ', 1.5),
    AdhanPhrase('أَشْهَدُ أَنَّ لَا إِلَهَ إِلَّا اللَّهُ', 1.5),
    AdhanPhrase('أَشْهَدُ أَنَّ مُحَمَّدًا رَسُولُ اللَّهِ', 1.5),
    AdhanPhrase('أَشْهَدُ أَنَّ مُحَمَّدًا رَسُولُ اللَّهِ', 1.5),
    AdhanPhrase('حَيَّ عَلَى الصَّلَاةِ', 1.2),
    AdhanPhrase('حَيَّ عَلَى الصَّلَاةِ', 1.2),
    AdhanPhrase('حَيَّ عَلَى الْفَلَاحِ', 1.2),
    AdhanPhrase('حَيَّ عَلَى الْفَلَاحِ', 1.2),
    AdhanPhrase('اللَّهُ أَكْبَرُ اللَّهُ أَكْبَرُ', 1.0),
    AdhanPhrase('لَا إِلَهَ إِلَّا اللَّهُ', 1.5),
  ];

  static const List<AdhanPhrase> fajrAdhan = [
    AdhanPhrase('اللَّهُ أَكْبَرُ اللَّهُ أَكْبَرُ', 1.2),
    AdhanPhrase('اللَّهُ أَكْبَرُ اللَّهُ أَكْبَرُ', 1.2),
    AdhanPhrase('أَشْهَدُ أَنَّ لَا إِلَهَ إِلَّا اللَّهُ', 1.5),
    AdhanPhrase('أَشْهَدُ أَنَّ لَا إِلَهَ إِلَّا اللَّهُ', 1.5),
    AdhanPhrase('أَشْهَدُ أَنَّ مُحَمَّدًا رَسُولُ اللَّهِ', 1.5),
    AdhanPhrase('أَشْهَدُ أَنَّ مُحَمَّدًا رَسُولُ اللَّهِ', 1.5),
    AdhanPhrase('حَيَّ عَلَى الصَّلَاةِ', 1.2),
    AdhanPhrase('حَيَّ عَلَى الصَّلَاةِ', 1.2),
    AdhanPhrase('حَيَّ عَلَى الْفَلَاحِ', 1.2),
    AdhanPhrase('حَيَّ عَلَى الْفَلَاحِ', 1.2),
    AdhanPhrase('الصَّلَاةُ خَيْرٌ مِنَ النَّوْمِ', 1.4),
    AdhanPhrase('الصَّلَاةُ خَيْرٌ مِنَ النَّوْمِ', 1.4),
    AdhanPhrase('اللَّهُ أَكْبَرُ اللَّهُ أَكْبَرُ', 1.0),
    AdhanPhrase('لَا إِلَهَ إِلَّا اللَّهُ', 1.5),
  ];

  /// Calculates the active index based on current position and total duration.
  static int getActivePhraseIndex(Duration current, Duration total, bool isFajr) {
    if (total.inMilliseconds == 0) return 0;
    
    final phrases = isFajr ? fajrAdhan : standardAdhan;
    final totalWeight = phrases.fold<double>(0, (sum, phrase) => sum + phrase.weight);
    
    // Calculate the weight equivalent of the current time
    final progress = current.inMilliseconds / total.inMilliseconds;
    final currentWeightProgress = progress * totalWeight;

    double accumulatedWeight = 0;
    for (int i = 0; i < phrases.length; i++) {
      accumulatedWeight += phrases[i].weight;
      if (currentWeightProgress <= accumulatedWeight) {
        return i;
      }
    }
    return phrases.length - 1;
  }
}
