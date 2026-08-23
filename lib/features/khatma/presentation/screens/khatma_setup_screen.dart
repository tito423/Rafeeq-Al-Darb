import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/khatma_plan.dart';
import '../providers/khatma_provider.dart';

class KhatmaSetupScreen extends ConsumerStatefulWidget {
  const KhatmaSetupScreen({super.key});

  @override
  ConsumerState<KhatmaSetupScreen> createState() => _KhatmaSetupScreenState();
}

class _KhatmaSetupScreenState extends ConsumerState<KhatmaSetupScreen> {
  int _targetDays = 30;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _targetDays = ref.read(khatmaProvider).targetDays;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : const Color(0xFFFAF7F0);
    final cardBg = isDark ? AppColors.darkCardBackground : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.primaryBlue;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'إعداد الختمة',
          style: GoogleFonts.amiri(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        iconTheme: IconThemeData(color: textColor),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.book_rounded,
                      size: 64,
                      color: AppColors.accentGold,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'المدة المستهدفة (بالأيام)',
                      style: GoogleFonts.amiri(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () {
                            if (_targetDays > 5) setState(() => _targetDays -= 5);
                          },
                          icon: const Icon(Icons.remove_circle_outline),
                          color: AppColors.accentGold,
                          iconSize: 32,
                        ),
                        const SizedBox(width: 24),
                        Text(
                          '$_targetDays',
                          style: GoogleFonts.outfit(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(width: 24),
                        IconButton(
                          onPressed: () {
                            if (_targetDays < 365) setState(() => _targetDays += 5);
                          },
                          icon: const Icon(Icons.add_circle_outline),
                          color: AppColors.accentGold,
                          iconSize: 32,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'معدل القراءة اليومي: ${(604 / _targetDays).ceil()} صفحات',
                      style: GoogleFonts.amiri(
                        fontSize: 16,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  final plan = KhatmaPlan(
                    id: 'khatma_${DateTime.now().millisecondsSinceEpoch}',
                    name: 'ختمتي',
                    targetDays: _targetDays,
                    currentJuz: 1,
                    currentPage: 1,
                    startDate: DateTime.now(),
                  );
                  ref.read(khatmaProvider.notifier).save(plan);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'ابدأ الختمة',
                  style: GoogleFonts.amiri(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
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
