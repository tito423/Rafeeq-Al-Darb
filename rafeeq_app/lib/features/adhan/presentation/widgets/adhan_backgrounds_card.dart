/// The row in adhan settings that opens «خلفيات شاشة الأذان».
///
/// Its own file because `adhan_settings_screen.dart` is on the file-length
/// guard's list: it was already over the ceiling when the ceiling went in, so
/// anything new goes beside it rather than into it.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../screens/adhan_background_screen.dart';

class AdhanBackgroundsCard extends StatelessWidget {
  const AdhanBackgroundsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.auto_awesome_mosaic_rounded,
            size: 30, color: AppColors.gold),
        title: Text('adhan.backgrounds_title'.tr()),
        subtitle: Text('adhan.backgrounds_desc'.tr()),
        // chevron_right, not chevron_left: this one must not mirror (trap #7).
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const AdhanBackgroundScreen(),
          ),
        ),
      ),
    );
  }
}
