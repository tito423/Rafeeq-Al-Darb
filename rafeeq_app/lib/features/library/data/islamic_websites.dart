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
    name: 'المكتبة الشاملة',
    descriptionKey: 'dawah.site_shamela',
    url: 'https://shamela.ws',
    icon: Icons.local_library,
    color: Color(0xFF00695C),
  ),
];
