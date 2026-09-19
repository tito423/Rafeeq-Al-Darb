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
///
/// «ظهور نص الأذان بالشكل ده سيئ جدًا وبدائي» (2026-09-19): it was bare gold
/// type laid straight over the mosque silhouette, the count wedged into the
/// line as «×٢». It is now a framed card of its own — a dark glass ground so
/// the words read over any scene, one row per phrase with a hairline between
/// them, the count in a small gold medallion beside its phrase — and the
/// rows arrive one after another. Deliberately NOTHING moves down the lines
/// once they are in: a travelling highlight would look like the sync this
/// screen exists precisely because it cannot do.
class AdhanFullText extends StatefulWidget {
  final bool isFajr;
  const AdhanFullText({super.key, required this.isFajr});

  @override
  State<AdhanFullText> createState() => _AdhanFullTextState();
}

class _AdhanFullTextState extends State<AdhanFullText>
    with TickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..forward();

  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _enter.dispose();
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lines = adhanLines(isFajr: widget.isFajr);
    final n = lines.length;
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: AnimatedBuilder(
          animation: _glow,
          builder: (context, child) => Container(
            width: 360,
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF0B1A2A).withValues(alpha: 0.78),
                  const Color(0xFF06101C).withValues(alpha: 0.86),
                ],
              ),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.45 + 0.25 * _glow.value),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.10 + 0.12 * _glow.value),
                  blurRadius: 26,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: child,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _Ornament(),
              const SizedBox(height: 6),
              for (var i = 0; i < n; i++) ...[
                _Stagger(
                  controller: _enter,
                  index: i,
                  count: n,
                  child: _PhraseRow(text: lines[i].text, repeat: lines[i].repeat),
                ),
                if (i < n - 1)
                  Divider(
                    height: 6,
                    thickness: 0.6,
                    indent: 24,
                    endIndent: 24,
                    color: AppColors.gold.withValues(alpha: 0.22),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// «۞ الأذان ۞», gold hairlines either side.
class _Ornament extends StatelessWidget {
  const _Ornament();

  @override
  Widget build(BuildContext context) {
    Widget line() => Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              AppColors.gold.withValues(alpha: 0),
              AppColors.gold.withValues(alpha: 0.7),
            ]),
          ),
        );
    return Row(
      children: [
        Expanded(child: line()),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text('۞',
              style: TextStyle(fontSize: 18, color: AppColors.gold, height: 1)),
        ),
        Expanded(child: Transform.flip(flipX: true, child: line())),
      ],
    );
  }
}

class _PhraseRow extends StatelessWidget {
  final String text;
  final int repeat;
  const _PhraseRow({required this.text, required this.repeat});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'AmiriQuran',
                  fontSize: 25,
                  height: 1.65,
                  fontWeight: FontWeight.bold,
                  color: AppColors.gold,
                ),
              ),
            ),
            SizedBox(
              width: 34,
              child: repeat > 1
                  ? Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.6)),
                        color: AppColors.gold.withValues(alpha: 0.10),
                      ),
                      child: Text(
                        localizeDigits('×$repeat', uiLanguageCode),
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.goldSoft,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Each row fades and rises in a little after the one above it.
class _Stagger extends StatelessWidget {
  final AnimationController controller;
  final int index;
  final int count;
  final Widget child;

  const _Stagger({
    required this.controller,
    required this.index,
    required this.count,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final start = (index / (count + 2)).clamp(0.0, 0.9);
    final anim = CurvedAnimation(
      parent: controller,
      curve: Interval(start, (start + 0.35).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: anim,
      builder: (context, c) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
            offset: Offset(0, (1 - anim.value) * 14), child: c),
      ),
      child: child,
    );
  }
}
