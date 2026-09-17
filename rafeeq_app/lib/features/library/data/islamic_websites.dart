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
  // Added 2026-09-17, in place of islamqa and dorar. Both of those were
  // removed under «اي حاجة ابن باز داخل فيها شيلها» — they are the two
  // largest online archives of precisely those fatwas — and these three were
  // each fetched first: the names below are the sites' own `<title>` values
  // and every landing page returned zero matches for the removed names.
  WebsiteInfo(
    name: 'دار الإفتاء المصرية',
    descriptionKey: 'dawah.site_daralifta',
    url: 'https://www.dar-alifta.org/ar',
    icon: Icons.balance,
    color: Color(0xFF1B5E20),
  ),
  WebsiteInfo(
    name: 'بوابة الأزهر الإلكترونية',
    descriptionKey: 'dawah.site_azhar',
    url: 'https://www.azhar.eg',
    icon: Icons.account_balance,
    color: Color(0xFFC9A227),
  ),
  WebsiteInfo(
    name: 'موسوعة النابلسي للعلوم الإسلامية',
    descriptionKey: 'dawah.site_nabulsi',
    url: 'https://www.nabulsi.com',
    icon: Icons.menu_book,
    color: Color(0xFF00695C),
  ),
  WebsiteInfo(
    name: 'المكتبة الشاملة',
    descriptionKey: 'dawah.site_shamela',
    url: 'https://shamela.ws',
    icon: Icons.local_library,
    color: Color(0xFF00695C),
  ),
];
