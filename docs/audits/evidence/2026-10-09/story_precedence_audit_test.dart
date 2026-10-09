import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/assistant/data/assistant_intent.dart';
import 'package:rafeeq_app/features/assistant/data/assistant_lexicon.dart';

void main() {
  test('actual parser chooses general story before named specific story', () {
    final labels = labelsFrom([
      for (final locale in ['ar', 'en', 'fr', 'es', 'pt', 'ru', 'ur'])
        jsonDecode(File('assets/translations/$locale.json').readAsStringSync())
            as Map<String, dynamic>,
    ]);
    final parser = AssistantParser(AssistantCatalog(
      surahs: (jsonDecode(File('test/fixtures/surah_names_ar.json')
          .readAsStringSync()) as List).cast<String>(),
      screenLabels: labels.screens,
      settingLabels: labels.settings,
      optionLabels: labels.options,
      settingSections: labels.sections,
    ));
    for (final pair in {
      'افتح قصة إبراهيم والطيور': 'open kidsStoryIbrahim',
      'افتح قصة سليمان والهدهد': 'open kidsStorySulayman',
    }.entries) {
      final actual = parser.parse(pair.key).toString();
      print('${pair.key} => $actual');
      expect(actual, pair.value);
    }
  });
}
