/// Opens the real adhan screen now, with the chosen adhan, clip and
/// background - the same [AzanPlayerScreen] and native player a real firing
/// uses, in [AzanPlayerMode.preview] so closing it pops exactly one route.
///
/// Shared by «معاينة الأذان» in the adhan settings and the preview card on
/// «خلفيات شاشة الأذان» («أول ما يختار الشاشة الخلفية تقوم طالعة له اضغط
/// المعاينة ويشوفها قدامه»). The backgrounds screen is also reached from
/// Home and from «رفيق», where the catalogue may not be loaded yet, so it is
/// awaited here rather than read.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/adhan_native.dart';
import '../data/adhan_catalog_provider.dart';
import '../data/adhan_scheduler.dart';
import '../data/adhan_settings_provider.dart';
import 'screens/azan_player_screen.dart';

Future<void> openAdhanPreview(BuildContext context, WidgetRef ref) async {
  final settings = ref.read(adhanSettingsProvider);
  final catalog = await ref.read(adhanCatalogProvider.future);
  if (catalog.isEmpty || !context.mounted) return;

  // Never two adhans at once: whatever row preview was sounding stops first.
  await AdhanNative.stop();
  if (!context.mounted) return;

  final spec = previewSpec(
    settings: settings,
    catalog: catalog,
    // Dhuhr = a neutral (non-Fajr) adhan, so the synced text uses the
    // standard wording rather than the Fajr-only sunrise line.
    prayerLabel: 'prayer.dhuhr'.tr(),
  );
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          AzanPlayerScreen(spec: spec, playerMode: AzanPlayerMode.preview),
    ),
  );
  // Backing out of the preview (system back, a gesture) must not leave the
  // adhan sounding behind the screen it came from.
  await AdhanNative.stop();
}
