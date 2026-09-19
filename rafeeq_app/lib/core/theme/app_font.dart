import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One typeface the reader can give the app's interface.
class AppFont {
  /// The Google Fonts family name; the files are bundled under
  /// `assets/fonts/google_fonts/` (`scripts/fetch_app_fonts.py`).
  final String family;

  /// True for the naskh, kufi and ruq'a faces - «خطوط إسلامية» - as against
  /// the modern sans ones.
  final bool traditional;

  const AppFont(this.family, {this.traditional = false});
}

/// «ضيفلي كارت في إعدادات التطبيق بتغيير نوع الخط … وإديني خيارات كتير …
/// ولو ينفع ينضاف خطوط إسلامية» (2026-09-19). Cairo is the app's own face
/// and stays the default. All are SIL Open Font License 1.1.
const appFonts = <AppFont>[
  AppFont('Cairo'),
  AppFont('Tajawal'),
  AppFont('Almarai'),
  AppFont('IBM Plex Sans Arabic'),
  AppFont('Noto Kufi Arabic'),
  AppFont('Changa'),
  AppFont('Alexandria'),
  AppFont('Amiri', traditional: true),
  AppFont('Scheherazade New', traditional: true),
  AppFont('Noto Naskh Arabic', traditional: true),
  AppFont('Lateef', traditional: true),
  AppFont('Markazi Text', traditional: true),
  AppFont('Reem Kufi', traditional: true),
  AppFont('El Messiri', traditional: true),
  AppFont('Aref Ruqaa', traditional: true),
];

const defaultAppFont = 'Cairo';

/// The interface font, kept between launches. The Qur'an keeps its own face
/// whatever is chosen here.
class AppFontController extends StateNotifier<String> {
  AppFontController() : super(defaultAppFont) {
    SharedPreferences.getInstance().then((p) {
      final v = p.getString(_key);
      if (v != null && mounted && appFonts.any((f) => f.family == v)) {
        state = v;
      }
    });
  }

  static const _key = 'app_font_family_v1';

  Future<void> set(String family) async {
    state = family;
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, family);
  }
}

final appFontProvider =
    StateNotifierProvider<AppFontController, String>((ref) => AppFontController());
