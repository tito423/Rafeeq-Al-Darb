import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/shell/app_shell.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../splash/presentation/screens/splash_screen.dart';
import '../../../prayer/presentation/providers/prayer_settings_provider.dart';

class ThemeSelectionScreen extends ConsumerWidget {
  const ThemeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final isDark = themeState.themeMode == ThemeMode.dark;

    final bgColor = isDark ? const Color(0xFF071625) : AppColors.primaryBlue;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'مرحباً بك في رفيق الدرب',
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accentGold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'اختر مظهر التطبيق المفضل لديك\nيمكنك تغييره لاحقاً من الإعدادات',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 60),

              // Theme Options
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ThemeOption(
                    title: 'الوضع النهاري',
                    icon: Icons.light_mode_rounded,
                    isSelected: !isDark,
                    onTap: () {
                      ref.read(themeProvider.notifier).setThemeMode(ThemeMode.light);
                    },
                  ),
                  _ThemeOption(
                    title: 'الوضع الليلي',
                    icon: Icons.dark_mode_rounded,
                    isSelected: isDark,
                    onTap: () {
                      ref.read(themeProvider.notifier).setThemeMode(ThemeMode.dark);
                    },
                  ),
                ],
              ),
              
              const Spacer(),
              
              // Continue Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () async {
                    // Save first launch flag
                    final prefs = ref.read(sharedPreferencesProvider);
                    await prefs.setBool('is_first_launch', false);
                    
                    if (context.mounted) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const AppShell()),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentGold,
                    foregroundColor: AppColors.primaryBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 5,
                    shadowColor: AppColors.accentGold.withValues(alpha: 0.5),
                  ),
                  child: Text(
                    'متابعة',
                    style: GoogleFonts.amiri(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
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

class _ThemeOption extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: 140,
        height: 180,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentGold.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.accentGold : Colors.white24,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.accentGold.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 2,
                  )
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 60,
              color: isSelected ? AppColors.accentGold : Colors.white54,
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: GoogleFonts.amiri(
                fontSize: 18,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.accentGold : Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
