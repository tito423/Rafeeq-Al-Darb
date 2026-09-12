import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every channel Dart calls on must be a channel Kotlin answers on.
///
/// A method-channel name is a string literal on both sides of the boundary and
/// nothing checks that the two agree. Get one character wrong and the call
/// does not fail — `MethodChannel.invokeMethod` on a name nobody registered
/// throws `MissingPluginException`, which several call sites here deliberately
/// swallow because a missing platform feature must not break the app. So a
/// typo becomes a feature that silently does nothing, which is the family of
/// bug this project keeps paying for (traps #27, #31).
///
/// Worth having now in particular: stage 5 of the reorganisation moved five
/// registrations out of `MainActivity.configureFlutterEngine` and replaced
/// four private vals and two inline literals with one `Channels` object. That
/// is exactly the edit that can retype a name.
void main() {
  final kotlinDir = Directory(
    'android/app/src/main/kotlin/com/tito/rafeeq_aldarb',
  );
  final kotlin = kotlinDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.kt'))
      .map((f) => f.readAsStringSync())
      .join('\n');

  final dartFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  final channel = RegExp(r'com\.tito\.rafeeq_aldarb/[a-z_]+');

  test('every channel Dart opens is registered somewhere in Kotlin', () {
    final fromDart = <String, String>{};
    for (final file in dartFiles) {
      final source = file.readAsStringSync();
      for (final m in channel.allMatches(source)) {
        fromDart[m.group(0)!] = file.path.replaceAll(r'\', '/');
      }
    }
    expect(fromDart, isNotEmpty, reason: 'the scan found no channels at all');

    final missing = <String>[];
    fromDart.forEach((name, path) {
      if (!kotlin.contains('"$name"')) missing.add('$name  (used in $path)');
    });
    expect(missing, isEmpty,
        reason: 'Dart opens these channels and no Kotlin file declares them, '
            'so every call on them throws MissingPluginException — usually '
            'into a catch that treats it as "the platform does not support '
            'this":\n${missing.join('\n')}');
  });

  test('the names Kotlin declares are the ones Dart actually uses', () {
    final names = RegExp(r'const val [A-Z_]+ = "(com\.tito\.rafeeq_aldarb/[a-z_]+)"')
        .allMatches(kotlin)
        .map((m) => m.group(1)!)
        .toSet();
    expect(names, isNotEmpty, reason: 'the Channels object was not found');

    final fromDart = <String>{};
    for (final file in dartFiles) {
      fromDart.addAll(
        channel.allMatches(file.readAsStringSync()).map((m) => m.group(0)!),
      );
    }
    final unused = names.difference(fromDart);
    expect(unused, isEmpty,
        reason: 'Kotlin declares these and nothing in Dart calls them — either '
            'a rename left the old spelling behind, or a feature was removed '
            'and its channel was not:\n${unused.join('\n')}');
  });
}
