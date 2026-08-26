import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../azkar/presentation/screens/azkar_screen.dart';
import '../../../sebha/presentation/screens/sebha_screen.dart';

/// Combined screen that shows Azkar and Sebha as two tabs.
class AzkarHubScreen extends StatelessWidget {
  const AzkarHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor:
            isDark ? AppColors.darkBackground : const Color(0xFFFAF7F0),
        appBar: AppBar(
          backgroundColor:
              isDark ? AppColors.darkSurface : Colors.white,
          elevation: 0,
          centerTitle: true,
          title: Text(
            'الأذكار والمسبحة',
            style: GoogleFonts.scheherazadeNew(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.accentGold : AppColors.primaryBlue,
            ),
          ),
          bottom: TabBar(
            indicatorColor: AppColors.accentGold,
            labelColor: AppColors.accentGold,
            unselectedLabelColor: isDark
                ? AppColors.darkSubtext
                : AppColors.lightSubtext,
            labelStyle: GoogleFonts.amiri(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            tabs: const [
              Tab(icon: Icon(Icons.auto_awesome_rounded), text: 'الأذكار'),
              Tab(icon: Icon(Icons.loop_rounded), text: 'المسبحة'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            // Tab 1 – Azkar (reuse existing widget without its own Scaffold)
            _AzkarTabBody(),
            // Tab 2 – Sebha
            _SebhaTabBody(),
          ],
        ),
      ),
    );
  }
}

/// Wraps AzkarScreen body without duplicating the Scaffold/AppBar.
class _AzkarTabBody extends StatelessWidget {
  const _AzkarTabBody();

  @override
  Widget build(BuildContext context) {
    // AzkarScreen has its own Scaffold; we push it as a nested route so
    // the hub AppBar/TabBar stays visible.  We embed it in a Navigator-less
    // way by returning it directly — DefaultTabController handles the rest.
    return const AzkarScreen();
  }
}

class _SebhaTabBody extends StatelessWidget {
  const _SebhaTabBody();

  @override
  Widget build(BuildContext context) {
    return const SebhaScreen();
  }
}
