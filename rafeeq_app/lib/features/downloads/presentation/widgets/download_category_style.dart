import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/downloads_controller.dart';

/// Each storage bucket's icon and accent on the Downloads hub.

IconData categoryIcon(DownloadCategory c) => switch (c) {
  DownloadCategory.mushafs => Icons.menu_book_rounded,
  DownloadCategory.recitations => Icons.headphones_rounded,
  DownloadCategory.ayahRecitations => Icons.record_voice_over_outlined,
  DownloadCategory.books => Icons.auto_stories_rounded,
  DownloadCategory.voices => Icons.graphic_eq_rounded,
  DownloadCategory.quranSciences => Icons.auto_stories_outlined,
};

Color categoryColor(DownloadCategory c) => switch (c) {
  DownloadCategory.mushafs => AppColors.gold,
  DownloadCategory.recitations => AppColors.primarySoft,
  DownloadCategory.ayahRecitations => AppColors.success,
  DownloadCategory.books => AppColors.goldSoft,
  DownloadCategory.voices => AppColors.primary,
  DownloadCategory.quranSciences => AppColors.info,
};
