/// The journey of «قافلة الدرب»: twenty legs in the order of Islamic
/// history, each ending at a place whose gate opens on a question from the
/// verified quiz bank.
///
/// Owner, 2026-10-08, after leg two: «اللعبة سيئة جدا … مفيش فعلا مرحلتين
/// اتنين وفي وقت اصلا بتمشي فيه … يا اما نطورها يا اما نغيرها», then «لو
/// تعرف خليها ٢٠ مرحلة ونوع في افكارك فيها وخليها جذابة للمستخدم صغير او
/// كبير». So: a map of twenty stations, short legs, something new to meet
/// on most legs (the sea crossing to Abyssinia by boat, birds, dates that
/// shield, rolling boulders, sandstorms, nights), stars to earn, and the
/// next leg opened by finishing this one.
///
/// Every gate id below was read in the bank (question, answer, quote, book
/// page) and is about the place it guards; a leg draws one of its ids at
/// random so a replay does not always ask the same thing.
/// `test/caravan_legs_test.dart` holds every id to the bundled bank, with
/// its quote, page and six translations. No question is written here.
library;

/// What carries the player: camels in the desert, horses on the
/// expeditions, a dhow on the sea and the rivers, a hoopoe over the
/// mountains (owner: «مش شرط يمشوا بجمال في كل حاجة»).
enum CaravanRide { camels, horses, boat, hoopoe }

class CaravanLeg {
  final int number;
  final String fromKey, toKey;

  /// Quiz bank ids about [toKey]'s place, one drawn per play.
  final List<String> gateIds;

  /// The road climbs out of Arabia into al-Sham, Iraq and Egypt: greener
  /// land, olive groves instead of an oasis, and stone walls with towers.
  final bool north;

  final CaravanRide ride;

  /// On water - the sea to Abyssinia, the Tigris, the Nile: waves to jump.
  bool get sea => ride == CaravanRide.boat;

  /// In the air: tap to beat the wings, keep off the peaks and clouds.
  bool get flying => ride == CaravanRide.hoopoe;

  const CaravanLeg({
    required this.number,
    required this.fromKey,
    required this.toKey,
    required this.gateIds,
    this.north = false,
    this.ride = CaravanRide.camels,
  });

  /// Odd legs run dawn into day with a sandstorm; even legs run afternoon
  /// into night, lit by the lanterns.
  bool get toNight => number.isEven;

  String get midKey => sea
      ? 'caravan.ev_island'
      : north
      ? 'caravan.ev_olives'
      : 'caravan.ev_oasis';
  String get hardKey => toNight ? 'caravan.ev_night' : 'caravan.ev_storm';

  /// What this leg adds to the road. Each arrives on its own leg so the
  /// journey keeps teaching something new.
  bool get hasBirds => number >= 3;
  bool get hasDates => number >= 5;
  bool get hasBoulders => number >= 6 && !sea && !flying;

  /// The first hint on the road, for what the player is riding.
  String get tapKey => switch (ride) {
    CaravanRide.camels => 'caravan.tap_to_jump',
    CaravanRide.horses => 'caravan.tap_horse',
    CaravanRide.boat => 'caravan.tap_boat',
    CaravanRide.hoopoe => 'caravan.tap_fly',
  };

  bool get isLast => number == all.length;
  CaravanLeg get next => all[number];

  static const first = CaravanLeg(
    number: 1,
    fromKey: 'caravan.makkah',
    toKey: 'caravan.hira',
    // The first revelation in Hira (al-Fusul p.96, twice; Ibn Hisham
    // p.220).
    gateIds: ['630368bbbf', '71531ed0de', '47dc5926c4'],
  );

  static const all = [
    first,
    CaravanLeg(
      number: 2,
      fromKey: 'caravan.hira',
      toKey: 'caravan.habasha',
      // The hijra to Abyssinia (al-Fusul p.100); Ja'far before the Najashi
      // (Ibn Hisham p.290); the Najashi (al-Fusul p.101).
      gateIds: ['9464f5ccf4', '2306df579b', '6fa190fa9d'],
      ride: CaravanRide.boat,
    ),
    CaravanLeg(
      number: 3,
      fromKey: 'caravan.habasha',
      toKey: 'caravan.aqaba',
      // Mus'ab sent with the 'Aqaba delegation (Ibn Hisham p.58); twelve
      // naqibs (p.64); those who pledged (al-Fusul p.112).
      gateIds: ['6337cd3d93', 'd7067b72a3', '34dbe4bb87'],
    ),
    CaravanLeg(
      number: 4,
      fromKey: 'caravan.aqaba',
      toKey: 'caravan.thawr',
      // The cave of Thawr (al-Fusul p.114); Asma' carrying food (p.115);
      // the companion of the cave (al-Suyuti p.110).
      gateIds: ['3c7dcaa720', '64da063950', '5ab67a0bb3'],
      ride: CaravanRide.hoopoe,
    ),
    CaravanLeg(
      number: 5,
      fromKey: 'caravan.thawr',
      toKey: 'caravan.madinah',
      // The Hijra (al-Fusul p.113); Quba before Madinah (Ibn Hisham
      // p.100); the mosque founded at Quba (al-Fusul p.118).
      gateIds: ['ef3e67153c', 'eb88aa523d', '7d973ad2b3'],
    ),
    CaravanLeg(
      number: 6,
      fromKey: 'caravan.madinah',
      toKey: 'caravan.badr',
      // The year of Badr (Ibn Kathir p.354); Abu Bakr in the arish (Ibn
      // Hisham p.195); al-Hubab's counsel on the wells (p.192).
      gateIds: ['02250fe5d1', '9c11009f3b', '15e5f6c117'],
      ride: CaravanRide.horses,
    ),
    CaravanLeg(
      number: 7,
      fromKey: 'caravan.badr',
      toKey: 'caravan.uhud',
      // Its month and year (Ibn Kathir p.354); the archers (al-Fusul
      // p.145); Abu 'Ubayda and the helmet rings (p.148).
      gateIds: ['c8962bbed0', '24d2f43386', '030606f137'],
      ride: CaravanRide.horses,
    ),
    CaravanLeg(
      number: 8,
      fromKey: 'caravan.uhud',
      toKey: 'caravan.khandaq',
      // Salman's counsel (al-Fusul p.166); 'Ali and 'Amr ibn 'Abd Wudd
      // (p.168); the rock in the trench (Ibn Kathir p.194).
      gateIds: ['4e34b4153a', '1394c72f0d', '9a71c9e035'],
    ),
    CaravanLeg(
      number: 9,
      fromKey: 'caravan.khandaq',
      toKey: 'caravan.hudaybiya',
      // Bay'at al-Ridwan (al-Fusul p.187); the ten-year truce (p.185);
      // Surat al-Fath on the way back (p.188).
      gateIds: ['1e977e375d', '65b2ba1ebe', 'c6b1656fcd'],
    ),
    CaravanLeg(
      number: 10,
      fromKey: 'caravan.hudaybiya',
      toKey: 'caravan.khaybar',
      // Bilal bringing Safiyya after the forts (Ibn Kathir p.374); Banu
      // al-Nadir going to Khaybar (p.371).
      gateIds: ['2b86964071', '0f438b5a7d'],
      ride: CaravanRide.horses,
    ),
    CaravanLeg(
      number: 11,
      fromKey: 'caravan.khaybar',
      toKey: 'caravan.mutah',
      // Zayd the first commander (Ibn Kathir p.623; al-Fusul p.193);
      // Khalid taking the banner (al-Fusul p.194).
      gateIds: ['69f9ba6921', '67a20d5e5b', 'c73e3bc8a2'],
      ride: CaravanRide.horses,
    ),
    CaravanLeg(
      number: 12,
      fromKey: 'caravan.mutah',
      toKey: 'caravan.makkah',
      // The Conquest: Bilal's adhan on the Ka'ba, its month (al-Fusul
      // p.202), its year (Ibn Kathir p.354).
      gateIds: ['29dc165f41', 'a8c311c7b3', '1eecf9f995'],
    ),
    CaravanLeg(
      number: 13,
      fromKey: 'caravan.makkah',
      toKey: 'caravan.hunayn',
      // «أنا النبي لا كذب» (al-Fusul p.206); Malik ibn 'Awf (p.204);
      // al-'Abbas calling the Ansar (p.206).
      gateIds: ['3b70214165', '78faa96a80', 'fdb7e6c4b0'],
      ride: CaravanRide.horses,
    ),
    CaravanLeg(
      number: 14,
      fromKey: 'caravan.hunayn',
      toKey: 'caravan.tabuk',
      // The spring of Tabuk (Ibn Kathir p.23); 'Uthman and the army of
      // hardship (al-Fusul p.210); its month (Ibn Kathir p.3).
      gateIds: ['624c7f8b76', '00464f1600', '7b134eff7e'],
    ),
    CaravanLeg(
      number: 15,
      fromKey: 'caravan.tabuk',
      toKey: 'caravan.quds',
      // Its opening under 'Umar (al-Suyuti p.238); the Isra (al-Fusul
      // p.106); the first qibla (al-Fusul p.127).
      gateIds: ['96c6f015e7', '0a1ccded7c', '5cda8ead67'],
      ride: CaravanRide.hoopoe,
      north: true,
    ),
    CaravanLeg(
      number: 16,
      fromKey: 'caravan.quds',
      toKey: 'caravan.damascus',
      // Al-Walid built its mosque (al-Suyuti p.367); Abu 'Ubayda the first
      // to pray in it (al-Bidaya p.144); Abu 'Ubayda over al-Sham (p.94).
      gateIds: ['b78e2a006b', 'd5c25ddea5', 'cc180cb885'],
      ride: CaravanRide.horses,
      north: true,
    ),
    CaravanLeg(
      number: 17,
      fromKey: 'caravan.damascus',
      toKey: 'caravan.baghdad',
      // Al-Mansur built it (al-Bidaya p.122); the Tatars took it in 656
      // (p.200); Hulagu at their head (al-Suyuti p.716).
      gateIds: ['019c5ae9fd', '558de02df0', 'e19d818dd3'],
      ride: CaravanRide.boat,
      north: true,
    ),
    CaravanLeg(
      number: 18,
      fromKey: 'caravan.baghdad',
      toKey: 'caravan.cairo',
      // Jawhar built Cairo (al-Bidaya p.226) and completed al-Azhar
      // (p.310).
      gateIds: ['2813c0c27c', 'faee6b0fd5'],
      ride: CaravanRide.boat,
      north: true,
    ),
    CaravanLeg(
      number: 19,
      fromKey: 'caravan.cairo',
      toKey: 'caravan.hittin',
      // Hattin before Bayt al-Maqdis (al-Bidaya p.320); Salah al-Din
      // (p.22); his khatib on the day (p.325).
      gateIds: ['40bcb360d5', '4b94212487', '1b187d416c'],
      ride: CaravanRide.horses,
      north: true,
    ),
    CaravanLeg(
      number: 20,
      fromKey: 'caravan.hittin',
      toKey: 'caravan.ain_jalut',
      // Qutuz breaking the Tatars (al-Bidaya p.199).
      gateIds: ['bcba91c2df'],
      ride: CaravanRide.horses,
      north: true,
    ),
  ];
}
