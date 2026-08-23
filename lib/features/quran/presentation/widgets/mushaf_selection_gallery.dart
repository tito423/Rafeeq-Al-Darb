import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/models/mushaf_style.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../services/download_manager.dart';

class MushafSelectionGallery extends ConsumerStatefulWidget {
  const MushafSelectionGallery({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const MushafSelectionGallery(),
    );
  }

  @override
  ConsumerState<MushafSelectionGallery> createState() =>
      _MushafSelectionGalleryState();
}

class _MushafSelectionGalleryState extends ConsumerState<MushafSelectionGallery> {
  String _selectedCategory = 'all'; // all, hafs, riwayat, scripts

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentStyle = ref.watch(mushafStyleProvider);

    final filteredList = kMushafStyles.where((m) {
      if (_selectedCategory == 'all') return true;
      return m.category == _selectedCategory;
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFFAF7F0),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Handle bar ────────────────────────────────────────────────────
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Title & Subtitle ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accentGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    color: AppColors.accentGold,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'مكتبة المصاحف الشريفة 📖',
                        style: GoogleFonts.amiri(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.primaryBlue,
                        ),
                      ),
                      Text(
                        'اختر طبعتك المفضلة من بين 17 مصحفاً بدقة فائقة',
                        style: GoogleFonts.amiri(
                          fontSize: 13,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Category Filter Tabs ──────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip('all', 'جميع المصاحف (17)', isDark),
                const SizedBox(width: 8),
                _buildFilterChip('hafs', 'رواية حفص عن عاصم (8)', isDark),
                const SizedBox(width: 8),
                _buildFilterChip('riwayat', 'الروايات والقرّاء (5)', isDark),
                const SizedBox(width: 8),
                _buildFilterChip('scripts', 'الخطوط واللغات (4)', isDark),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Grid of Mushafs ───────────────────────────────────────────────
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.72,
              ),
              itemCount: filteredList.length,
              itemBuilder: (context, idx) {
                final item = filteredList[idx];
                final isSelected = currentStyle == item.style;

                return _buildMushafCard(item, isSelected, isDark);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String catKey, String label, bool isDark) {
    final active = _selectedCategory == catKey;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = catKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? AppColors.accentGold
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? AppColors.accentGold
                : (isDark ? Colors.white12 : Colors.black12),
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: AppColors.accentGold.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.amiri(
            fontSize: 13,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active
                ? AppColors.primaryBlue
                : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildMushafCard(MushafStyleInfo item, bool isSelected, bool isDark) {
    return GestureDetector(
      onTap: () => _showMushafDetails(item),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppColors.accentGold : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.accentGold.withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Cover Image Thumbnail
                  Expanded(
                    flex: 5,
                    child: Center(
                      child: Hero(
                        tag: 'mushaf_cover_${item.id}',
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.asset(
                              item.localThumbCover,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Container(
                                color: AppColors.primaryBlue.withValues(alpha: 0.1),
                                child: const Icon(Icons.book, color: AppColors.accentGold, size: 40),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Riwayah Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accentGold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.riwayah,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.amiri(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentGold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Title
                  Text(
                    item.nameAr,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.amiri(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),

            // Selected Checkmark Badge
            if (isSelected)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.accentGold,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: AppColors.primaryBlue,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showMushafDetails(MushafStyleInfo item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentStyle = ref.read(mushafStyleProvider);
    final isSelected = currentStyle == item.style;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              height: MediaQuery.of(ctx).size.height * 0.85,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFFAF7F0),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        // Title & Riwayah
                        Text(
                          item.nameAr,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.amiri(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppColors.primaryBlue,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.description,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.amiri(
                            fontSize: 14,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Previews Row: Cover + Page 1 + Page 2
                        SizedBox(
                          height: 220,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Page 2
                              Expanded(
                                child: _buildPreviewImage(item.localThumbPage2, 'صفحة ٢', isDark),
                              ),
                              const SizedBox(width: 8),
                              // Page 1
                              Expanded(
                                child: _buildPreviewImage(item.localThumbPage1, 'صفحة ١', isDark),
                              ),
                              const SizedBox(width: 8),
                              // Cover
                              Expanded(
                                child: _buildPreviewImage(item.localThumbCover, 'الغلاف', isDark),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Specifications Grid
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              _buildSpecRow('الرواية / الطريق', item.riwayah, isDark),
                              const Divider(height: 16),
                              _buildSpecRow('عدد الصفحات', '${item.totalPages} صفحة', isDark),
                              const Divider(height: 16),
                              _buildSpecRow('التصنيف', item.category == 'hafs' ? 'رواية حفص' : (item.category == 'riwayat' ? 'روايات وقراءات' : 'خطوط ولغات'), isDark),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom Action Buttons
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentGold,
                              foregroundColor: AppColors.primaryBlue,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 4,
                            ),
                            icon: Icon(isSelected ? Icons.check_circle_rounded : Icons.bookmark_added_rounded),
                            label: Text(
                              isSelected ? 'المصحف المفعَّل حالياً' : 'اختيار وتفعيل هذا المصحف',
                              style: GoogleFonts.amiri(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                            onPressed: () {
                              ref.read(mushafStyleProvider.notifier).setStyle(item.style);
                              
                              // Trigger full Mushaf download in background
                              ref.read(downloadManagerProvider.notifier).downloadAllMushaafPages(styleInfo: item);

                              Navigator.of(ctx).pop();
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'تم تفعيل ${item.nameAr} وجاري تحميل الصفحات في الخلفية ✨',
                                    style: GoogleFonts.amiri(fontSize: 16, fontWeight: FontWeight.w700),
                                  ),
                                  backgroundColor: AppColors.primaryBlue,
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPreviewImage(String assetPath, String label, bool isDark) {
    return Column(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                assetPath,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey.withValues(alpha: 0.2),
                  child: const Center(child: Icon(Icons.broken_image)),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.amiri(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildSpecRow(String title, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.amiri(
            fontSize: 14,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.amiri(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }
}
