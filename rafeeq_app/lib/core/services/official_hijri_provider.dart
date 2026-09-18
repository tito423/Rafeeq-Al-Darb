import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'official_hijri.dart';

/// Loads the cached declared calendar, then refreshes it from the network.
/// Widgets that print a Hijri date watch this so they redraw once the
/// declared dates arrive - until then `OfficialHijri.dateOf` answers from
/// the table, so nothing waits on it.
final officialHijriProvider = FutureProvider<int>((ref) async {
  await OfficialHijri.ensureLoaded();
  return (await OfficialHijri.refresh()).length;
});
