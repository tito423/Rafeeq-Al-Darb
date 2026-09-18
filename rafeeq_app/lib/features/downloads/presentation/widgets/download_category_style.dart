import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/downloads_controller.dart';

/// Each storage bucket's icon and accent on the Downloads hub.

IconData categoryIcon(DownloadCategory c) => switch (c) {
  DownloadCategory.mushafs => Icons.menu_book_rounded,
  DownloadCategory.recitations => Icons.headphones_rounded,
  DownloadCategory.ayahRecitations => Icons.record_voice_over_outlined,
  DownloadCategory.hadith => Icons.format_quote_rounded,
  DownloadCategory.books => Icons.auto_stories_rounded,
  DownloadCategory.voices => Icons.graphic_eq_rounded,
};

Color categoryColor(DownloadCategory c) => switch (c) {
  DownloadCategory.mushafs => AppColors.gold,
  DownloadCategory.recitations => AppColors.primarySoft,
  DownloadCategory.ayahRecitations => AppColors.success,
  DownloadCategory.hadith => AppColors.info,
  DownloadCategory.books => AppColors.goldSoft,
  DownloadCategory.voices => AppColors.primary,
};
