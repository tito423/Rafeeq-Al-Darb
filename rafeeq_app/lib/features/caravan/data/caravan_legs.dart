/// The journey of «قافلة الدرب»: eight legs in the order of Islamic history,
/// each ending at a city gate that opens on a question from the verified
/// quiz bank.
///
/// Owner, 2026-10-08, after leg two: «اللعبة سيئة جدا … مفيش فعلا مرحلتين
/// اتنين وفي وقت اصلا بتمشي فيه … يا اما نطورها يا اما نغيرها». So the game
/// became a journey: a map, eight short legs, a new thing to meet on almost
/// every leg, stars to earn, and the next leg opened by finishing this one.
///
/// Every gate id below was read in the bank (question, answer, quote, book
/// page) and is about the city it guards; a leg draws one of its ids at
/// random so a replay does not always ask the same thing.
/// `test/caravan_legs_test.dart` holds every id to the bundled bank, with
/// its quote, page and six translations. No question is written here.
library;

class CaravanLeg {
  final int number;
  final String fromKey, toKey;

  /// Quiz bank ids about [toKey]'s city, one drawn per play.
  final List<String> gateIds;

  /// The road climbs out of Arabia into al-Sham, Iraq and Egypt: greener
  /// land, olive groves instead of an oasis, and stone walls with towers.
  final bool north;

  const CaravanLeg({
    required this.number,
    required this.fromKey,
    required this.toKey,
    required this.gateIds,
    this.north = false,
  });

  /// Odd legs run dawn into day with a sandstorm; even legs run afternoon
  /// into night, lit by the lanterns.
  bool get toNight => number.isEven;

  String get midKey => north ? 'caravan.ev_olives' : 'caravan.ev_oasis';
  String get hardKey => toNight ? 'caravan.ev_night' : 'caravan.ev_storm';

  /// What this leg adds to the road. Each one arrives on its own leg so the
  /// journey keeps teaching something new.
  bool get hasBirds => number >= 2;
  bool get hasDates => number >= 3;
  bool get hasBoulders => number >= 4;

  bool get isLast => number == all.length;
  CaravanLeg get next => all[number];

  static const first = CaravanLeg(
    number: 1,
    fromKey: 'caravan.makkah',
    toKey: 'caravan.madinah',
    // The Hijra (al-Fusul p.113); Quba before Madinah (Ibn Hisham p.100);
    // the mosque founded at Quba (al-Fusul p.118).
    gateIds: ['ef3e67153c', 'eb88aa523d', '7d973ad2b3'],
  );

  static const all = [
    first,
    CaravanLeg(
      number: 2,
      fromKey: 'caravan.madinah',
      toKey: 'caravan.badr',
      // The year of Badr (Ibn Kathir p.354); Abu Bakr in the arish (Ibn
      // Hisham p.195); al-Hubab's counsel on the wells (Ibn Hisham p.192).
      gateIds: ['02250fe5d1', '9c11009f3b', '15e5f6c117'],
    ),
    CaravanLeg(
      number: 3,
      fromKey: 'caravan.badr',
      toKey: 'caravan.khaybar',
      // Bilal bringing Safiyya after the forts (Ibn Kathir p.374); Banu
      // al-Nadir going to Khaybar (Ibn Kathir p.371).
      gateIds: ['2b86964071', '0f438b5a7d'],
    ),
    CaravanLeg(
      number: 4,
      fromKey: 'caravan.khaybar',
      toKey: 'caravan.makkah',
      // The Conquest: Bilal's adhan on the Ka'ba, its month (al-Fusul
      // p.202), its year (Ibn Kathir p.354).
      gateIds: ['29dc165f41', 'a8c311c7b3', '1eecf9f995'],
    ),
    CaravanLeg(
      number: 5,
      fromKey: 'caravan.makkah',
      toKey: 'caravan.tabuk',
      // The spring of Tabuk (Ibn Kathir p.23); 'Uthman and the army of
      // hardship (al-Fusul p.210); its month (Ibn Kathir p.3).
      gateIds: ['624c7f8b76', '00464f1600', '7b134eff7e'],
    ),
    CaravanLeg(
      number: 6,
      fromKey: 'caravan.tabuk',
      toKey: 'caravan.quds',
      // Its opening under 'Umar (al-Suyuti p.238); the Isra (al-Fusul
      // p.106); the first qibla (al-Fusul p.127).
      gateIds: ['96c6f015e7', '0a1ccded7c', '5cda8ead67'],
      north: true,
    ),
    CaravanLeg(
      number: 7,
      fromKey: 'caravan.quds',
      toKey: 'caravan.baghdad',
      // Al-Mansur built it (Ibn Kathir, al-Bidaya p.122); the Tatars took
      // it in 656 (p.200); Hulagu at their head (al-Suyuti p.716).
      gateIds: ['019c5ae9fd', '558de02df0', 'e19d818dd3'],
      north: true,
    ),
    CaravanLeg(
      number: 8,
      fromKey: 'caravan.baghdad',
      toKey: 'caravan.cairo',
      // Jawhar built Cairo (al-Bidaya p.226) and completed al-Azhar
      // (p.310).
      gateIds: ['2813c0c27c', 'faee6b0fd5'],
      north: true,
    ),
  ];
}
