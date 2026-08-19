import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/models/mushaf_style.dart';
import '../../../../core/theme/app_colors.dart';

class MushafThemeSheet extends ConsumerWidget {
  const MushafThemeSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(mushafThemeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBackground : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: subtext.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Text(
              'مظهر المصحف',
              style: GoogleFonts.scheherazadeNew(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 8),
            Text(
              'اختر لون الخلفية المريح لعينيك أثناء القراءة',
              style: GoogleFonts.amiri(
                fontSize: 14,
                color: subtext,
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 24),

            // Theme Options
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                reverse: true, // RTL support
                itemCount: MushafBackgroundTheme.values.length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final theme = MushafBackgroundTheme.values[index];
                  final isSelected = currentTheme == theme;

                  return GestureDetector(
                    onTap: () {
                      ref.read(mushafThemeProvider.notifier).setTheme(theme);
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Color(theme.colorValue),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? AppColors.primaryBlue : Colors.grey.withValues(alpha: 0.2),
                              width: isSelected ? 3 : 1,
                            ),
                            boxShadow: [
                              if (isSelected)
                                BoxShadow(
                                  color: AppColors.primaryBlue.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                )
                            ],
                          ),
                          child: isSelected
                              ? Icon(
                                  Icons.check_rounded,
                                  color: theme == MushafBackgroundTheme.night || theme == MushafBackgroundTheme.oud
                                      ? Colors.white
                                      : AppColors.primaryBlue,
                                )
                              : null,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          theme.nameAr,
                          style: GoogleFonts.amiri(
                            fontSize: 14,
                            color: isSelected ? AppColors.primaryBlue : subtext,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
