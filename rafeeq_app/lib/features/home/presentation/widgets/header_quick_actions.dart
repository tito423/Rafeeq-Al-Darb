import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/supported_locales.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_controller.dart';

/// «حط تحت التاريخ الهجري زر سريع لتغيير الثيم … وتحت التاريخ الميلادي زر
/// سريع لتغيير اللغة … وخلّي أيقوناتهم جميلة وأنيميتد». Two small round
/// buttons on the Home header, each turning a full circle when tapped.

/// Theme: one tap moves to the next theme; the icon becomes the new one's.
class ThemeQuickButton extends ConsumerWidget {
  final Color color;
  const ThemeQuickButton({super.key, required this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(themeControllerProvider);
    final all = ThemeVariant.values;
    return _QuickButton(
      color: color,
      icon: v.icon,
      label: v.labelKey.tr(),
      onTap: () => ref
          .read(themeControllerProvider.notifier)
          .set(all[(all.indexOf(v) + 1) % all.length]),
    );
  }
}

/// Language: a sheet of the seven, each in its own script.
class LanguageQuickButton extends StatelessWidget {
  final Color color;
  const LanguageQuickButton({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    final code = context.locale.languageCode;
    return _QuickButton(
      color: color,
      icon: Icons.translate_rounded,
      label: kLanguageNames[code] ?? code,
      onTap: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final e in kLanguageNames.entries)
                  ChoiceChip(
                    showCheckmark: false,
                    label: Text(e.value),
                    selected: e.key == code,
                    onSelected: (_) {
                      Navigator.of(ctx).pop();
                      if (e.key != code) context.setLocale(Locale(e.key));
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickButton extends StatefulWidget {
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickButton({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_QuickButton> createState() => _QuickButtonState();
}

class _QuickButtonState extends State<_QuickButton> {
  double _turns = 0;

  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        setState(() => _turns += 1);
        widget.onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedRotation(
            turns: _turns,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutBack,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [
                  c.withValues(alpha: 0.22),
                  AppColors.gold.withValues(alpha: 0.18),
                ]),
                border: Border.all(color: c.withValues(alpha: 0.55)),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (w, a) =>
                    ScaleTransition(scale: a, child: w),
                child: Icon(widget.icon,
                    key: ValueKey(widget.icon), size: 18, color: c),
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            widget.label,
            maxLines: 1,
            style: TextStyle(
                fontSize: 10.5, color: c, fontWeight: FontWeight.w600),
          ),
        ]),
      ),
    );
  }
}
