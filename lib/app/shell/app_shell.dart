import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/quran/presentation/screens/quran_screen.dart';
import '../../features/prayer/presentation/screens/prayer_screen.dart';
import '../../features/library/presentation/screens/library_screen.dart';

// ── Tab index provider ────────────────────────────────────────────────────────
final currentTabProvider = StateProvider<int>((_) => 0);

// ── Premium tab descriptors ───────────────────────────────────────────────────
class _Tab {
  final String arabicLabel;
  final IconData icon;
  final IconData activeIcon;
  const _Tab(this.arabicLabel, this.icon, this.activeIcon);
}

const _tabs = [
  _Tab('الرئيسية',   Icons.home_outlined,            Icons.home_rounded),
  _Tab('القرآن',     Icons.menu_book_outlined,        Icons.menu_book_rounded),
  _Tab('الصلاة',     Icons.access_time_outlined,      Icons.access_time_filled),
  _Tab('الصوتيات',   Icons.headphones_outlined,       Icons.headphones_rounded),
];

// ─────────────────────────────────────────────────────────────────────────────
// App Shell
// ─────────────────────────────────────────────────────────────────────────────

/// Root [Scaffold] with a fully custom premium bottom navigation bar.
/// • [IndexedStack] keeps all screens alive.
/// • Each nav item animates its icon size & color via [AnimatedScale] / [TweenAnimationBuilder].
/// • A top gold indicator line marks the active tab.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  static const _screens = [
    HomeScreen(),
    QuranScreen(),
    PrayerScreen(),
    LibraryScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(currentTabProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(index: currentIndex, children: _screens),
      bottomNavigationBar: _PremiumNavBar(
        currentIndex: currentIndex,
        isDark: isDark,
        onTap: (i) => ref.read(currentTabProvider.notifier).state = i,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Premium Nav Bar Widget
// ─────────────────────────────────────────────────────────────────────────────

class _PremiumNavBar extends StatelessWidget {
  final int currentIndex;
  final bool isDark;
  final ValueChanged<int> onTap;

  const _PremiumNavBar({
    required this.currentIndex,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? AppColors.darkNavBar : AppColors.lightNavBar;
    final activeColor = isDark ? AppColors.accentGold : AppColors.primaryBlue;
    final idleColor = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        boxShadow: [
          // Soft multi-layer shadow for a "floating card" feel
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.10),
            blurRadius: 24,
            spreadRadius: 0,
            offset: const Offset(0, -6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(
              _tabs.length,
              (i) => Expanded(
                child: _NavItem(
                  tab: _tabs[i],
                  isActive: i == currentIndex,
                  activeColor: activeColor,
                  idleColor: idleColor,
                  onTap: () => onTap(i),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual Nav Item
// ─────────────────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final _Tab tab;
  final bool isActive;
  final Color activeColor;
  final Color idleColor;
  final VoidCallback onTap;

  const _NavItem({
    required this.tab,
    required this.isActive,
    required this.activeColor,
    required this.idleColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ── Gold top indicator ──────────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            height: 3,
            width: isActive ? 28 : 0,
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: activeColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── Icon with animated scale ────────────────────────────────────
          AnimatedScale(
            scale: isActive ? 1.18 : 1.0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutBack,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: Icon(
                isActive ? tab.activeIcon : tab.icon,
                key: ValueKey(isActive),
                color: isActive ? activeColor : idleColor,
                size: 24,
              ),
            ),
          ),

          const SizedBox(height: 4),

          // ── Arabic label (Amiri) ────────────────────────────────────────
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: GoogleFonts.amiri(
              fontSize: isActive ? 12.0 : 11.0,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              color: isActive ? activeColor : idleColor,
              height: 1,
            ),
            child: Text(tab.arabicLabel),
          ),
        ],
      ),
    );
  }
}
