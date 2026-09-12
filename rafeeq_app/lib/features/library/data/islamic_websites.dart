import 'package:flutter/material.dart';

/// The Islamic websites the «مواقع إسلامية» tab links to.
///
/// Moved out of `library_screen.dart`. A catalogue written inside a screen
/// file is how this app ended up with the channel list existing twice — one
/// copy verified and unreachable, the other reachable with three dead links
/// in it. Content lives in `data/`, where it can be read, tested and shared.

class WebsiteInfo {
  final String name;
  /// A translation KEY, not the text: the description is what a non-Arabic
  /// reader needs in order to know what the channel or site is. The `name`
  /// beside it stays Arabic because it is the real, proper name of an
  /// Arabic-language channel, and a proper noun is not translated - it is
  /// rendered with `ArabicText` so it reads in its own direction.
  final String descriptionKey;
  final String url;
  final IconData icon;
  final Color color;
  const WebsiteInfo({
    required this.name,
    required this.descriptionKey,
    required this.url,
    required this.icon,
    required this.color,
  });
}

const islamicWebsites = [
  WebsiteInfo(
    name: 'الإسلام سؤال وجواب',
    descriptionKey: 'dawah.site_islamqa',
    url: 'https://islamqa.info',
    icon: Icons.question_answer,
    color: Color(0xFF1B5E20),
  ),
  WebsiteInfo(
    name: 'الدرر السنية',
    descriptionKey: 'dawah.site_dorar',
    url: 'https://dorar.net',
    icon: Icons.diamond,
    color: Color(0xFFC9A227),
  ),
  WebsiteInfo(
    name: 'طريق الإسلام',
    descriptionKey: 'dawah.site_islamway',
    url: 'https://ar.islamway.net',
    icon: Icons.route,
    color: Color(0xFF0D47A1),
  ),
  WebsiteInfo(
    name: 'صيد الفوائد',
    descriptionKey: 'dawah.site_saaid',
    url: 'https://saaid.org',
    icon: Icons.catching_pokemon,
    color: Color(0xFF4E342E),
  ),
  WebsiteInfo(
    name: 'شبكة الألوكة',
    descriptionKey: 'dawah.site_alukah',
    url: 'https://www.alukah.net',
    icon: Icons.language,
    color: Color(0xFF311B92),
  ),
  // «زيد في المواقع الإسلامية قصة الإسلام وموقع الشاملة وموقع المشكاة».
  // Two of the three are here. Both were fetched before being written down:
  // islamstory.com answered 200 with 183 KB and its own page says it runs
  // «تحت إشراف المؤرخ الإسلامي د. راغب السرجاني»; shamela.ws answered 200
  // with 47 KB, `<title>المكتبة الشاملة</title>`, describing itself as the
  // project's official site.
  //
  // **المشكاة is deliberately absent.** `almeshkat.net` resolves — DNS gives
  // 37.48.81.163 — but nothing answers on either port: four attempts over
  // http and https, with and without `www`, all timed out at 90 s with zero
  // bytes. A card that opens a page which never loads is exactly the kind of
  // entry §1.1 forbids, so it is not added until there is an address that
  // answers.
  WebsiteInfo(
    name: 'قصة الإسلام',
    descriptionKey: 'dawah.site_islamstory',
    url: 'https://www.islamstory.com',
    icon: Icons.auto_stories,
    color: Color(0xFF6D4C41),
  ),
  WebsiteInfo(
    name: 'المكتبة الشاملة',
    descriptionKey: 'dawah.site_shamela',
    url: 'https://shamela.ws',
    icon: Icons.local_library,
    color: Color(0xFF00695C),
  ),
];
