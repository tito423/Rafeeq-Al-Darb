import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/services/source_rules.dart';

void main() {
  final r = SourceRules.instance;
  setUp(r.reset);

  test('defaults are the tested patterns and all compile', () {
    for (final k in SourceRules.defaults.keys) {
      expect(() => r.re(k), returnsNormally, reason: k);
    }
    expect(r.s('dorar.toc.start'), 'id="mtree"');
  });

  test('a newer published file replaces a rule', () {
    final ok = r.apply(jsonEncode({
      'version': SourceRules.builtInVersion + 1,
      'rules': {'dorar.toc.start': 'id="newtree"'},
    }));
    expect(ok, isTrue);
    expect(r.s('dorar.toc.start'), 'id="newtree"');
  });

  test('an older or equal version is ignored', () {
    expect(r.apply(jsonEncode({
      'version': SourceRules.builtInVersion,
      'rules': {'dorar.toc.start': 'x'},
    })), isFalse);
    expect(r.s('dorar.toc.start'), 'id="mtree"');
  });

  test('a pattern that does not compile never replaces a working one', () {
    r.apply(jsonEncode({
      'version': SourceRules.builtInVersion + 1,
      'rules': {'dorar.section.title': '(unclosed', 'unknown.key': 'x'},
    }));
    expect(r.s('dorar.section.title'), SourceRules.defaults['dorar.section.title']);
  });

  test('garbage is ignored', () {
    expect(r.apply('<html>not json'), isFalse);
  });

  test('line patterns stop at the line end', () {
    final m = r.re('shamela.card.title', dotAll: false)
        .firstMatch('الكتاب : تحفة الأطفال\nالمؤلف : الجمزوري');
    expect(m!.group(1)!.trim(), 'تحفة الأطفال');
  });
}
