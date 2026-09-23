/// The one place a recitation that played nothing is reported to the reader.
///
/// Two screens ask for the same audio through the same setting — the mushaf's
/// continuous recitation and the hifz «استمع» — and both used to fail the
/// same way: nothing played, nothing was said, and the button sat there. The
/// message names the host and the kind of refusal, because that is what can
/// be photographed and acted on.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../services/audio_failure.dart';
import '../utils/byte_formatter.dart' show ltr;

void showRecitationFailure(BuildContext context) {
  final why = AudioFailure.instance.last.value;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      // `ltr()`: a host and an http code inside an Arabic sentence reverse
      // without it (trap #16).
      content: Text(why == null
          ? 'quran.recite_failed'.tr()
          : '${'quran.recite_failed'.tr()}\n${ltr(why)}'),
      duration: const Duration(seconds: 7),
    ),
  );
}
