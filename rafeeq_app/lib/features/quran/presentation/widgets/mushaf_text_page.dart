import 'package:flutter/material.dart';

import '../../../../core/db/models.dart';

/// Renders one mushaf page as real Uthmani text laid out per the real
/// Madani page boundaries (from the bundled database), with tap-on-ayah.
class MushafTextPage extends StatelessWidget {
  final List<Ayah> ayahs;

  /// (surahId, surahNameAr) shown as a header when a surah starts on this page.
  final (int, String)? surahHeader;
  final void Function(Ayah ayah) onAyahTap;

  const MushafTextPage({
    super.key,
    required this.ayahs,
    required this.surahHeader,
    required this.onAyahTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (ayahs.isEmpty) {
      return const Center(child: Text('—'));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final baseFont = 24.0;
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: constraints.maxWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (surahHeader != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 7),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'سُورَة ${surahHeader!.$2}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontFamily: 'AmiriQuran',
                        ),
                      ),
                    ),
                  ...ayahs.map((ayah) {
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onAyahTap(ayah),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ayah-end marker with the ayah number
                            Padding(
                              padding: const EdgeInsets.only(top: 6, left: 8),
                              child: Transform.translate(
                                offset: const Offset(0, -4),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: theme.colorScheme.primary,
                                      width: 1.2,
                                    ),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(
                                    _arabicNumber(ayah.ayahNumber),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontSize: 9,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                ayah.textUthmani,
                                textAlign: TextAlign.justify,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontFamily: 'AmiriQuran',
                                  fontSize: baseFont,
                                  height: 1.85,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                  Text(
                    '﴿ ﴾',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static String _arabicNumber(int n) {
    const digits = '٠١٢٣٤٥٦٧٨٩';
    return n.toString().split('').map((c) => digits[int.parse(c)]).join();
  }
}