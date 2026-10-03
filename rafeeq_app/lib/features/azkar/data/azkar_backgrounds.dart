/// The photograph on each adhkar category card.
///
/// Owner (2026-10-03): «كل كرت يبقى له صورة حلوة هادية اسلامية جميلة».
/// One bundled photo per category, all nine from Wikimedia Commons under a
/// free licence, each looked at before it was chosen and credited on the
/// Sources screen (`sources_catalog.dart`, about.src_azkar_cards). Bundled,
/// not hotlinked: the earlier Unsplash URLs were shown at 20 % opacity and
/// two of them had already died once (2026-09-18).
library;

import 'azkar_categories.dart';

const azkarCategoryBackgrounds = <AzkarCategory, String>{
  // Faisal Mosque at sunrise (Adeelahmad93, CC BY-SA 3.0).
  AzkarCategory.morning: 'assets/azkar_cards/morning.jpg',
  // Sunset over Umm al-Fahm, minarets in silhouette (Moataz Egbaria,
  // CC BY-SA 3.0).
  AzkarCategory.evening: 'assets/azkar_cards/evening.jpg',
  // al-Muizz street, Cairo, at night under a crescent (Maro tharwat,
  // CC BY-SA 3.0).
  AzkarCategory.sleep: 'assets/azkar_cards/sleep.jpg',
  // The Blue Mosque at dawn (Nithi Ruangpisit, CC BY 3.0).
  AzkarCategory.waking: 'assets/azkar_cards/waking.jpg',
  // Süleymaniye Mosque prayer carpet (Brian Jeffery Beggerly, CC BY 2.0).
  AzkarCategory.afterPrayer: 'assets/azkar_cards/afterPrayer.jpg',
  // Meknes Grand Mosque courtyard (Robert Prazeres, CC BY-SA 4.0).
  AzkarCategory.mosque: 'assets/azkar_cards/mosque.jpg',
  // A camel caravan above the Moroccan dunes at sunset (Patricia
  // Ilizaliturri, CC BY-SA 4.0).
  AzkarCategory.travel: 'assets/azkar_cards/travel.jpg',
  // A misbaha on a dark ground (لا روسا, CC BY-SA 4.0).
  AzkarCategory.narrated: 'assets/azkar_cards/narrated.jpg',
  // A Mamluk-era mushaf, c. 1380, open on its stand (Mustafa-trit20,
  // CC BY-SA 4.0).
  AzkarCategory.ruqyah: 'assets/azkar_cards/ruqyah.jpg',
};
