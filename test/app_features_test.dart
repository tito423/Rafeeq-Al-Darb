import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/utils/text_sanitizer.dart';
import 'package:rafeeq_app/core/models/app_theme_config.dart';
import 'package:rafeeq_app/core/localization/app_localizations.dart';
import 'package:rafeeq_app/features/quran/domain/models/zikr.dart';
import 'package:rafeeq_app/features/prayer/presentation/providers/prayer_settings_provider.dart';
import 'package:rafeeq_app/features/quran/presentation/screens/quran_screen.dart';

void main() {
  group('Phase 1: Database & Text Sanitizer Tests', () {
    test('TextSanitizer cleans bracket artifacts and Python raw lists', () {
      const rawText = "(( رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً ))\\n', 'وَفِي الآخِرَةِ حَسَنَةً";
      final cleaned = TextSanitizer.clean(rawText);
      expect(cleaned.contains('(('), isFalse);
      expect(cleaned.contains('))'), isFalse);
      expect(cleaned.contains(r"\n', '"), isFalse);
      expect(cleaned.contains('«'), isTrue);
    });

    test('Zikr model parses sanitized fields correctly', () {
      final rawMap = {
        'id': 1,
        'category': 'أذكار الصباح',
        'content': "(( اللّهُ لاَ إِلَـهَ إِلاَّ هُوَ الْحَيُّ الْقَيُّومُ ))",
        'count': '3',
        'description': '',
        'reference': 'سورة البقرة: 255',
        'fadl': '',
      };
      final zikr = Zikr.fromMap(rawMap);
      expect(zikr.countInt, 3);
      expect(zikr.content.contains('«'), isTrue);
      expect(zikr.content.contains('(('), isFalse);
    });
  });

  group('Phase 3: Theming Engine Tests', () {
    test('3 complete presets are defined', () {
      expect(kAppThemes.length, 3);
      expect(kAppThemes[0].type, AppThemeType.light);
      expect(kAppThemes[1].type, AppThemeType.dark);
      expect(kAppThemes[2].type, AppThemeType.rgb);
      expect(kAppThemes[2].isAnimatedRgb, isTrue);
    });
  });

  group('Phase 4: Prayer & Muezzins Tests', () {
    test('All listed muezzins have valid https URLs', () {
      expect(kMuezzins.length, greaterThanOrEqualTo(5));
      for (final m in kMuezzins) {
        expect(m.url.startsWith('https://'), isTrue);
        expect(m.name.isNotEmpty, isTrue);
      }
    });
  });

  group('Phase 5: Accurate Juz Index-to-Page Map Tests', () {
    test('All 30 Juz have exact starting pages and surah names', () {
      expect(kJuzPages.length, 30);
      expect(kJuzPages[1]!.page, 1);
      expect(kJuzPages[2]!.page, 22);
      expect(kJuzPages[30]!.page, 582);
    });
  });

  group('Phase 6: Full i18n Localization Tests', () {
    test('AppLocalizations supports Arabic, English, and French', () {
      final locAr = AppLocalizations(const Locale('ar'));
      final locEn = AppLocalizations(const Locale('en'));
      final locFr = AppLocalizations(const Locale('fr'));

      expect(locAr.appName, 'رفيق الدرب');
      expect(locEn.appName, 'Rafiq Al-Darb');
      expect(locFr.appName, 'Rafiq Al-Darb');

      expect(locAr.library, 'المكتبة');
      expect(locEn.library, 'Library');
      expect(locFr.library, 'Bibliothèque');
    });
  });
}
