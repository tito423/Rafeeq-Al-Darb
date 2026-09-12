import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/utils/external_link.dart';

/// Outbound links leave the app through one door, and it only opens onto the
/// web.
///
/// `LaunchMode.externalApplication` hands Android whatever scheme the string
/// carries. Most of this app's links are literals in its own catalogues, but
/// the Library reader opens `meta.shamelaUrl` out of a downloaded book — and
/// `intent:` is a URL scheme too, one that asks Android to start another
/// app's component with extras chosen by whoever wrote the string.
void main() {
  test('anything that is not http(s) is refused, and nothing is launched', () async {
    for (final bad in const [
      'intent://scan/#Intent;scheme=zxing;end',
      'tel:+201000000000',
      'sms:+201000000000',
      'market://details?id=com.example',
      'file:///data/data/com.tito.rafeeq_aldarb/databases/hadith.db',
      'javascript:alert(1)',
      'content://com.android.contacts/data',
      'https://',        // scheme, but no host
      '',
      '   ',
      'not a url at all',
    ]) {
      // No plugin is registered in a unit test, so a real launch would throw
      // MissingPluginException. Returning false without throwing is therefore
      // also proof that `launchUrl` was never reached.
      expect(await openExternalLink(bad), isFalse, reason: 'launched: $bad');
    }
  });

  test('nothing bypasses it by calling launchUrl directly', () {
    final offenders = <String>[];
    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final path = file.path.replaceAll(r'\', '/');
      if (path.endsWith('core/utils/external_link.dart')) continue;
      final source = file.readAsStringSync();
      if (source.contains('launchUrl(')) offenders.add(path);
    }
    expect(offenders, isEmpty,
        reason: 'these open a URL without the scheme check — use '
            'openExternalLink:\n${offenders.join('\n')}');
  });
}
