import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/digits.dart';
import '../../data/adhan_text.dart';

/// The whole adhan, written out at once — for a recording the app cannot
/// follow.
///
/// «في حالة إضافة أذان من الهاتف … يكون فيه الأذان النصي كامل مكتوب لأنك مش
/// هتقدر تعمل مزامنة مع أذان إنت مش عارف توقيتاته». A file the user imported
/// has never been measured, so a line-by-line display over it can only be a
/// guess — and a guess that shows «حيّ على الصلاة» while the muezzin is still
/// on the shahada is worse than no sync at all. So the text is shown whole,
/// each line with how many times it is said.
class AdhanFullText extends StatelessWidget {
  final bool isFajr;
  const AdhanFullText({super.key, required this.isFajr});

  @override
  Widget build(BuildContext context) {
    final lines = adhanLines(isFajr: isFajr);
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: l.text),
                    if (l.repeat > 1)
                      TextSpan(
                        text: '  ×${localizeDigits('${l.repeat}', uiLanguageCode)}',
                        style: const TextStyle(
                          fontSize: 18,
                          color: AppColors.goldSoft,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                  ],
                ),
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  fontFamily: 'AmiriQuran',
                  fontSize: 28,
                  height: 1.7,
                  fontWeight: FontWeight.bold,
                  color: AppColors.gold,
                  shadows: [Shadow(blurRadius: 14, color: Color(0xFF000000))],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
