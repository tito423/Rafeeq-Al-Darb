/// «استمع للأذان» — the row that plays the adhan so you can hear the one you
/// picked before a prayer arrives.
///
/// Lifted out of `adhan_settings_screen.dart` for the same reason as
/// `AdhanBackgroundsCard`: that screen is over the file-length ceiling and
/// grandfathered, so it may not grow. A card that only needs a callback is the
/// easiest thing to take out of it.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class AdhanPreviewCard extends StatelessWidget {
  final VoidCallback onTap;

  const AdhanPreviewCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer,
      child: ListTile(
        leading: Icon(Icons.play_circle_fill,
            color: scheme.onPrimaryContainer, size: 32),
        title: Text(
          'prayer.preview_azan'.tr(),
          style: TextStyle(
            color: scheme.onPrimaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          'prayer.preview_azan_desc'.tr(),
          style: TextStyle(color: scheme.onPrimaryContainer),
        ),
        trailing: Icon(Icons.chevron_right, color: scheme.onPrimaryContainer),
        onTap: onTap,
      ),
    );
  }
}
