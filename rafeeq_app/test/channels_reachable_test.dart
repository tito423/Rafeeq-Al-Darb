import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The channel list has to be rendered by a screen the app can actually open.
///
/// THE DEFECT THIS EXISTS FOR, FOUND ON emulator-5554.
/// There were two channel lists. `islamic_channels.dart` held the verified one
/// — a YouTube `UC…` id read off each channel's own page and an avatar
/// mirrored onto the bucket — and fed `IslamicChannelsScreen`. The Library's
/// «قنوات دعوية» tab rendered a *private* list of its own: a name, a guessed
/// `@handle` and a Material icon.
///
/// And **nothing in the app routed to `IslamicChannelsScreen`.** So six
/// channels the owner asked for by name were added to a list no one could
/// open, and the About screen counted them into «١٣ قناة» — a figure about a
/// screen that did not exist for the reader. `flutter analyze` says nothing
/// about a widget with no route, and no test did either.
///
/// Opening the tab is what found it. This is the cheap guard that keeps it
/// found: the list the app ships must be the list the tab renders.
void main() {
  // The tab moved out of `library_screen.dart` when that 1,625-line file was
  // split one tab per file; the screen is now the shell that mounts it, so
  // both halves are checked — the tab still renders the shared list, and the
  // shell still mounts the tab.
  final tab = File(
    'lib/features/library/presentation/tabs/channels_tab.dart',
  ).readAsStringSync();
  final shell = File(
    'lib/features/library/presentation/screens/library_screen.dart',
  ).readAsStringSync();

  test('the channels tab renders the verified list, not a private copy', () {
    expect(tab.contains('islamicChannels.length'), isTrue,
        reason: 'the tab is not rendering islamic_channels.dart');
    expect(
        tab.contains(
            "import '../../../channels/data/islamic_channels.dart';"),
        isTrue);
    expect(tab.contains('const _islamicChannels'), isFalse,
        reason: 'a second, private channel list is back — that is the bug');
    expect(tab.contains('class _ChannelInfo'), isFalse);
  });

  test('and the library screen still mounts that tab', () {
    expect(shell.contains('ChannelsTab()'), isTrue,
        reason: 'the tab exists but nothing opens it — the original defect');
    expect(shell.contains("import '../tabs/channels_tab.dart';"), isTrue);
  });

  test('every channel has a description key in all seven locales', () {
    final data =
        File('lib/features/channels/data/islamic_channels.dart').readAsStringSync();
    final ids = RegExp(r"id: '([a-z0-9_]+)'")
        .allMatches(data)
        .map((m) => m.group(1)!)
        .toList();
    expect(ids.length, greaterThanOrEqualTo(20));
    for (final locale in const ['ar', 'en', 'fr', 'es', 'pt', 'ru', 'ur']) {
      final json =
          File('assets/translations/$locale.json').readAsStringSync();
      for (final id in ids) {
        expect(json.contains('"desc_$id"'), isTrue,
            reason: '$locale has no channels.desc_$id — the card would render '
                'the raw key on screen (trap #8)');
      }
    }
  });

  test('a channel with no mirrored photo says so, and none is invented', () {
    final data =
        File('lib/features/channels/data/islamic_channels.dart').readAsStringSync();
    // The five whose avatar is YouTube's generated letter tile. They must
    // stay marked, or the grid fetches a mirror that was never uploaded and
    // falls back to an error widget instead of the channel's own mark.
    for (final id in const [
      'hassan_elhusseiny',
      'amgad_samir',
      'haytham_talaat',
      'fahem',
      'ayman_abdelraheem',
    ]) {
      final from = data.indexOf("id: '$id'");
      expect(from, greaterThan(0), reason: '$id is no longer in the list');
      // To the start of the next entry — `indexOf('),')` would stop at the
      // closing paren of `Color(0x…)` and read half an entry.
      var to = data.indexOf("id: '", from + 8);
      if (to < 0) to = data.length;
      expect(data.substring(from, to).contains('hasPhoto: false'), isTrue,
          reason: '$id has no real avatar on YouTube and none on the bucket');
    }
  });
}
