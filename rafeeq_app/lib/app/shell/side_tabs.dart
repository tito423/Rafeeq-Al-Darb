import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// The seven tabs standing at the start edge, for a phone on its side.
///
/// Material's `NavigationRail` was tried first and seen on the owner's Xiaomi
/// held sideways (2026-09-26): its tiles are ~61 dp, seven of them ~430 dp,
/// the screen had 351 dp - «المكتبة» was cut in half and «المزيد» sat below
/// the edge until the rail was scrolled. A tab you have to scroll to find is
/// a tab that is not there. So the height is shared out: each tab gets a
/// seventh of it, icon over name - «اكتب اسماء الايقونات دايما تحت
/// الايقونات» holds here too - and a tile too short for both scales down
/// rather than losing its name.
class SideTabs extends StatelessWidget {
  const SideTabs({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onSelect,
    required this.selectedIcon,
  });

  /// (icon, selected icon, label key), in tab order.
  final List<(IconData, IconData, String)> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  /// Builds the selected tab's icon (the shell's entrance animation).
  final Widget Function(IconData) selectedIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bar = theme.navigationBarTheme;
    final on = theme.colorScheme.onSurface;
    final label = (bar.labelTextStyle?.resolve(<WidgetState>{}) ??
            const TextStyle(fontSize: 11))
        .copyWith(color: on);
    return Material(
      color: bar.backgroundColor ?? theme.colorScheme.surface,
      child: SafeArea(
        child: SizedBox(
          width: 84,
          child: Column(
            children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  child: Semantics(
                    selected: i == selectedIndex,
                    button: true,
                    child: InkWell(
                      onTap: () => onSelect(i),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 56,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: i == selectedIndex
                                      ? bar.indicatorColor
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: IconTheme.merge(
                                  data: bar.iconTheme?.resolve({
                                        if (i == selectedIndex)
                                          WidgetState.selected,
                                      }) ??
                                      const IconThemeData(),
                                  child: i == selectedIndex
                                      ? selectedIcon(tabs[i].$2)
                                      : Icon(tabs[i].$1),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                tabs[i].$3.tr(),
                                maxLines: 1,
                                style: label,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
