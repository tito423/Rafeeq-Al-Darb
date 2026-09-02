import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/adhan_option.dart';
import '../../../core/services/adhan_catalog_service.dart';

/// The full list of selectable adhans (10 bundled + any custom imports),
/// reloaded whenever a custom adhan is added or removed.
class AdhanCatalogNotifier extends AsyncNotifier<List<AdhanOption>> {
  @override
  Future<List<AdhanOption>> build() => AdhanCatalogService.instance.loadAll();

  Future<AdhanOption> addCustom(String sourcePath, String displayName) async {
    final option =
        await AdhanCatalogService.instance.addCustom(sourcePath, displayName);
    state = AsyncData(await AdhanCatalogService.instance.loadAll());
    return option;
  }

  Future<void> removeCustom(AdhanOption option) async {
    await AdhanCatalogService.instance.removeCustom(option);
    state = AsyncData(await AdhanCatalogService.instance.loadAll());
  }
}

final adhanCatalogProvider =
    AsyncNotifierProvider<AdhanCatalogNotifier, List<AdhanOption>>(
  AdhanCatalogNotifier.new,
);
