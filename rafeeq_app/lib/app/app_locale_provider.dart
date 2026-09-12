import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/i18n/supported_locales.dart';

/// The app's language code, for code that has to build a *string* without a
/// `BuildContext`.
///
/// `.tr()` works context-free because `easy_localization` keeps a global
/// locale — but it keeps it *private*, with no getter, so anything that needs
/// the code itself (to shape digits, say) cannot ask for it. The prayer
/// reminders are armed from `PrayerController`, a Riverpod notifier with no
/// context, which is why this exists. It is pushed from `RafeeqApp`, the one
/// widget that already rebuilds on every locale change.
///
/// In its own file rather than beside the writer in `rafeeq_app.dart`:
/// `RafeeqApp` now reads `prayerControllerProvider`, so putting the provider
/// there would have the app and the controller importing each other.
///
/// THE DEFAULT IS NOT A GUESS ANY MORE. It used to be a hardcoded `ar`, on
/// the reasoning that it is "only ever read before the first frame's callback
/// has run" - but `PrayerController` loads in exactly that window, and it
/// hands this code to the reverse geocoder. On an English phone the very first
/// city name was therefore resolved in Arabic and then cached, which is half
/// of «الاشعار طلع مكس مابينهم». It starts from the platform's own language
/// when that is one the app ships, and `RafeeqApp` still corrects it to the
/// reader's actual choice on the first frame.
String _initialLocale() {
  final device = PlatformDispatcher.instance.locale.languageCode;
  return kSupportedLocales.any((l) => l.languageCode == device) ? device : 'ar';
}

final appLocaleProvider = StateProvider<String>((ref) => _initialLocale());
