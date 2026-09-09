import 'package:easy_localization/easy_localization.dart';

/// A person's, channel's or reciter's own name, in the script the reader reads.
///
/// A name is never translated — «عبد الله رشدي» and "Abdullah Rushdy" are the
/// same name written twice, and renaming someone in French is not localisation.
/// What a reader does need is a script they can read, and the catalogues
/// already carry both forms.
///
/// The catalogues used to choose with `locale.languageCode == 'ar'`, which gave
/// the English form to Spanish, French, Portuguese and Russian — fine — and
/// also to **Urdu**, which is written in Arabic script and should have had the
/// Arabic form.
///
/// [readsArabicScript] asks the locale files rather than hard-coding the list,
/// because `.tr()` reads a global and these call sites are inside `const`
/// catalogues and list builders with no BuildContext to spare. `common.script`
/// is `arabic` in ar and ur, `latin` in the other five.
bool get readsArabicScript => 'common.script'.tr() == 'arabic';

/// [arabic] when the reader reads Arabic script, otherwise [latin] — falling
/// back to [arabic] when no Latin form was recorded, since a name in the wrong
/// script beats no name at all.
String properName(String arabic, String latin) =>
    (readsArabicScript || latin.isEmpty) ? arabic : latin;
