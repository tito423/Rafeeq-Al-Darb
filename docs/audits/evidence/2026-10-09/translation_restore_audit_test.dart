import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rafeeq_app/features/quran/data/translation_lang_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('audit: catalog translation choice is lost on notifier recreation', () async {
    final catalog = jsonDecode(File('assets/data/catalogs/quran_translations.json').readAsStringSync()) as Map;
    expect((catalog['translations'] as List).any((e) => e['lang'] == 'tr' && e['bundled'] == false), isTrue);
    SharedPreferences.setMockInitialValues({'reader_translation_locale_v1': 'en'});
    final prefs = await SharedPreferences.getInstance();
    final first = SelectedTranslationLang();
    await Future<void>.delayed(Duration.zero);
    await first.select('tr');
    expect(first.state, 'tr');
    expect(prefs.getString('reader_translation_lang_v1'), 'tr');
    first.dispose();
    final reopened = SelectedTranslationLang();
    await Future<void>.delayed(Duration.zero);
    await reopened.followAppLocale('en');
    print('AUDIT_TRANSLATION_RESTORE: disk=${prefs.getString('reader_translation_lang_v1')} reopened=${reopened.state} followedLocale=${prefs.getString('reader_translation_locale_v1')}');
    expect(reopened.state, 'en');
    expect(prefs.getString('reader_translation_lang_v1'), 'tr');
    reopened.dispose();
  });
}
