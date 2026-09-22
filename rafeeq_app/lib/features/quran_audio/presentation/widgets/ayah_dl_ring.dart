import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/digits.dart';

/// A progress ring with its percentage (or a tick) inside.
///
/// The percentage is FLOORED. Rounded, 6,232 of 6,236 ayahs read «١٠٠٪» —
/// the owner's screenshot — beside a count that said four were missing.
/// Only a genuinely complete download shows the tick.
class AyahDlRing extends StatelessWidget {
  final double value;
  final double size;
  final String locale;

  const AyahDlRing({
    super.key,
    required this.value,
    required this.locale,
    this.size = 48,
  });

  /// «٤٧٪» in Arabic — the Arabic percent sign after the number — and each
  /// language's own form elsewhere. The Latin sign in an RTL run printed
  /// «%٤٧».
  static String percent(int n, String locale) =>
      trn('ayah_dl.percent', args: ['$n']);

  @override
  Widget build(BuildContext context) {
    final complete = value >= 1;
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => Stack(
          fit: StackFit.expand,
          children: [
            CircularProgressIndicator(
              value: v,
              strokeWidth: size * 0.09,
              // outlineVariant, not a surface tone: on the owner's Honor the
              // empty ring was invisible and only «٠٪» showed.
              backgroundColor: Theme.of(context).colorScheme.outlineVariant,
              valueColor: AlwaysStoppedAnimation<Color>(
                complete ? AppColors.success : AppColors.gold,
              ),
            ),
            Center(
              child: complete
                  ? Icon(
                      Icons.check_rounded,
                      color: AppColors.success,
                      size: size * 0.45,
                    )
                  : Text(
                      percent((v * 100).floor().clamp(0, 99), locale),
                      style: TextStyle(
                        fontSize: size * 0.24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
