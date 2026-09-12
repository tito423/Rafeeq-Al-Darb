/// The photograph behind each adhkar category's header.
///
/// Moved out of `azkar_screen.dart`: a list of hosted URLs is content,
/// and content that lives inside a screen file cannot be checked, reused
/// or audited by anything but that screen.
library;

import 'azkar_categories.dart';

/// Beautiful Islamic background image URLs per category (royalty-free from
/// Unsplash, small 640px crops to minimize bandwidth). Cached locally by
/// CachedNetworkImage so they load once and work offline after that.
const azkarCategoryBackgrounds = <AzkarCategory, String>{
  AzkarCategory.waking:
      'https://images.unsplash.com/photo-1542816417-0983c9c9ad53?w=640&q=70&fit=crop',
  // A mosque under dawn light — the morning adhkar are read at first light,
  // so the card now actually looks like when they belong.
  AzkarCategory.morning:
      'https://images.unsplash.com/photo-1519817650390-64a93db51149?w=640&q=70&fit=crop',
  AzkarCategory.mosque:
      'https://images.unsplash.com/photo-1591604129939-f1efa4d99f7e?w=640&q=70&fit=crop',
  AzkarCategory.afterPrayer:
      'https://images.unsplash.com/photo-1564769625905-50e93615e769?w=640&q=70&fit=crop',
  AzkarCategory.evening:
      'https://images.unsplash.com/photo-1519681393784-d120267933ba?w=640&q=70&fit=crop',
  AzkarCategory.sleep:
      'https://images.unsplash.com/photo-1532978379173-523e16f371f2?w=640&q=70&fit=crop',
  AzkarCategory.travel:
      'https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?w=640&q=70&fit=crop',
  AzkarCategory.narrated:
      'https://images.unsplash.com/photo-1585036156171-384164a8c956?w=640&q=70&fit=crop',
};
