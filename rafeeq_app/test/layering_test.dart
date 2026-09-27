import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The one dependency rule ARCHITECTURE.md §1 states: `core/` never imports
/// from `features/` (or `app/`). The 2026-09-27 audit found seven files
/// breaking it - reminder services that belonged to their features, a
/// service and a model importing each other, a widget reaching into the
/// «المزيد» screen - and moved or inverted each one. This keeps it that way.
void main() {
  test('core/ does not import features/ or app/', () {
    final offenders = <String>[];
    final import = RegExp(r'''^(?:import|export)\s+'([^']+)'.*''', multiLine: true);
    for (final f in Directory('lib/core')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      for (final m in import.allMatches(f.readAsStringSync())) {
        final target = m.group(1)!;
        if (target.contains('/features/') ||
            target.contains('features/') && target.startsWith('../') ||
            target.contains('/app/') ||
            target.startsWith('package:rafeeq_app/features/') ||
            target.startsWith('package:rafeeq_app/app/')) {
          offenders.add('${f.path.replaceAll(r'\', '/')} -> $target');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'core/ must not depend on a feature. Move the file to the '
            'feature it serves, move the shared piece down into core/, or '
            'invert the dependency with a hook (see RecitationSource.localFile).');
  });
}
