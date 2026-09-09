import 'package:flutter_riverpod/flutter_riverpod.dart';

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
/// The default is `ar` because that is the app's own default locale; it is
/// only ever read before the first frame's callback has run.
final appLocaleProvider = StateProvider<String>((ref) => 'ar');
