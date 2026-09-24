import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_font.dart';

/// The fonts, each written in itself, grouped modern / traditional. A tap
/// applies the face to the whole app at once - the screen behind the list is
/// the preview.
class AppFontPicker extends ConsumerWidget {
  const AppFontPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(appFontProvider);
    final scheme = Theme.of(context).colorScheme;

    Widget group(String titleKey, bool traditional) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
              child: Text(titleKey.tr(),
                  style: TextStyle(
                      color: goldText(context), fontWeight: FontWeight.w700)),
            ),
            for (final f in appFonts)
              if (f.traditional == traditional)
                _FontTile(
                  font: f,
                  selected: f.family == current,
                  onTap: () => ref.read(appFontProvider.notifier).set(f.family),
                  scheme: scheme,
                ),
          ],
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        group('settings.font_modern', false),
        group('settings.font_traditional', true),
      ],
    );
  }
}

class _FontTile extends StatelessWidget {
  final AppFont font;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme scheme;

  const _FontTile({
    required this.font,
    required this.selected,
    required this.onTap,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: selected
                ? AppColors.gold.withValues(alpha: 0.12)
                : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            border: Border.all(
              color: selected
                  ? AppColors.gold
                  : scheme.outlineVariant.withValues(alpha: 0.5),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The sample is the same line for every face, in the
                  // reader's language, so the faces compare like for like.
                  Text(
                    'settings.font_sample'.tr(),
                    style: GoogleFonts.getFont(font.family,
                        fontSize: 17, height: 1.6, color: scheme.onSurface),
                  ),
                  Text(
                    font.family,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                        fontSize: 11, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: selected
                  ? const Icon(Icons.check_circle_rounded,
                      key: ValueKey(1), color: AppColors.gold)
                  : Icon(Icons.circle_outlined,
                      key: const ValueKey(0), color: scheme.outlineVariant),
            ),
          ]),
        ),
      ),
    );
  }
}
