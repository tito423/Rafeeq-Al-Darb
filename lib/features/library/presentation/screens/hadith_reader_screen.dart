import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/datasources/hadith_db_helper.dart';

// ── Arabic collection name helper ────────────────────────────────────────────

const _collectionNamesAr = {
  'bukhari': 'صحيح البخاري',
  'muslim': 'صحيح مسلم',
  'tirmidhi': 'جامع الترمذي',
  'abudawud': 'سنن أبي داود',
  'nasai': 'سنن النسائي',
  'ibnmajah': 'سنن ابن ماجه',
  'malik': 'موطأ مالك',
  'nawawi': 'الأربعون النووية',
  'qudsi': 'الأحاديث القدسية',
};

// ─────────────────────────────────────────────────────────────────────────────
// Hadith Reader Screen — opens a collection, shows chapters → hadiths
// ─────────────────────────────────────────────────────────────────────────────

class HadithReaderScreen extends ConsumerStatefulWidget {
  final String bookId;
  final String bookTitle;
  final String downloadUrl;

  const HadithReaderScreen({
    super.key,
    required this.bookId,
    required this.bookTitle,
    this.downloadUrl = '',
  });

  @override
  ConsumerState<HadithReaderScreen> createState() => _HadithReaderScreenState();
}

class _HadithReaderScreenState extends ConsumerState<HadithReaderScreen> {
  final _dbHelper = HadithDbHelper();
  List<Map<String, dynamic>> _chapters = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChapters();
  }

  Future<void> _loadChapters() async {
    try {
      final chapters = await _dbHelper.getChapters(widget.bookId);
      if (mounted) {
        setState(() {
          _chapters = chapters;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      debugPrint('Error loading chapters: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : const Color(0xFFFAF7F0);
    final cardBg = isDark ? AppColors.darkCardBackground : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _collectionNamesAr[widget.bookId] ?? widget.bookTitle,
          style: GoogleFonts.scheherazadeNew(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.accentGold : AppColors.primaryBlue,
          ),
        ),
        iconTheme: IconThemeData(color: textColor),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentGold))
          : _chapters.isEmpty
              ? _buildFlatList(cardBg, textColor, isDark)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _chapters.length,
                  itemBuilder: (context, index) {
                    final ch = _chapters[index];
                    final chapterName = ch['name'] ?? 'باب $index';
                    final chapterId = ch['chapter_id']?.toString() ?? '';
                    final hFirst = ch['hadith_first'];
                    final hLast = ch['hadith_last'];
                    final countStr = (hFirst != null && hLast != null)
                        ? '(${hLast - hFirst + 1} حديث)'
                        : '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.accentGold.withValues(alpha: 0.15),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.accentGold.withValues(alpha: 0.2),
                                AppColors.accentGold.withValues(alpha: 0.08),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              chapterId,
                              style: GoogleFonts.amiri(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.accentGold,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          chapterName,
                          style: GoogleFonts.scheherazadeNew(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                            height: 1.4,
                          ),
                        ),
                        subtitle: countStr.isNotEmpty
                            ? Text(
                                countStr,
                                style: GoogleFonts.amiri(fontSize: 13, color: subtext),
                              )
                            : null,
                        trailing: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                          color: AppColors.accentGold,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => _HadithListScreen(
                                collectionId: widget.bookId,
                                chapterId: chapterId,
                                chapterName: chapterName,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }

  /// Fallback: if no chapters, show all hadiths in a flat list.
  Widget _buildFlatList(Color cardBg, Color textColor, bool isDark) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _dbHelper.getHadithsByBook(widget.bookId, limit: 10000),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.accentGold));
        }
        final hadiths = snapshot.data ?? [];
        if (hadiths.isEmpty) {
          return Center(
            child: Text(
              'لا توجد أحاديث في هذا الكتاب',
              style: GoogleFonts.amiri(fontSize: 18, color: Colors.grey),
            ),
          );
        }
        return _HadithCards(hadiths: hadiths, cardBg: cardBg, textColor: textColor, isDark: isDark);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hadith List Screen — shows hadiths for a specific chapter
// ─────────────────────────────────────────────────────────────────────────────

class _HadithListScreen extends StatefulWidget {
  final String collectionId;
  final String chapterId;
  final String chapterName;

  const _HadithListScreen({
    required this.collectionId,
    required this.chapterId,
    required this.chapterName,
  });

  @override
  State<_HadithListScreen> createState() => _HadithListScreenState();
}

class _HadithListScreenState extends State<_HadithListScreen> {
  final _dbHelper = HadithDbHelper();
  List<Map<String, dynamic>> _hadiths = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _dbHelper.getHadithsByChapter(widget.collectionId, widget.chapterId);
      if (mounted) {
        setState(() {
          _hadiths = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : const Color(0xFFFAF7F0);
    final cardBg = isDark ? AppColors.darkCardBackground : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.chapterName,
          style: GoogleFonts.scheherazadeNew(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.accentGold : AppColors.primaryBlue,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        iconTheme: IconThemeData(color: textColor),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentGold))
          : _hadiths.isEmpty
              ? Center(
                  child: Text(
                    'لا توجد أحاديث في هذا الباب',
                    style: GoogleFonts.amiri(fontSize: 18, color: Colors.grey),
                  ),
                )
              : _HadithCards(hadiths: _hadiths, cardBg: cardBg, textColor: textColor, isDark: isDark),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared Hadith Card List
// ─────────────────────────────────────────────────────────────────────────────

class _HadithCards extends StatelessWidget {
  final List<Map<String, dynamic>> hadiths;
  final Color cardBg;
  final Color textColor;
  final bool isDark;

  const _HadithCards({
    required this.hadiths,
    required this.cardBg,
    required this.textColor,
    required this.isDark,
  });

  void _copyHadith(BuildContext context, String text, int number) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم نسخ الحديث رقم $number',
          style: GoogleFonts.amiri(fontSize: 14),
        ),
        backgroundColor: AppColors.accentGold,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: hadiths.length,
      itemBuilder: (context, index) {
        final h = hadiths[index];
        final text = (h['text_ar'] ?? h['text'] ?? '') as String;
        final number = h['hadith_number'] ?? index + 1;
        final grade = (h['grade'] ?? '') as String;

        // Clean up <br> tags from text
        final cleanText = text.replaceAll(RegExp(r'<br\s*/?>'), '\n');

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header row ───────────────────────────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.accentGold.withValues(alpha: 0.2),
                          AppColors.accentGold.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'حديث رقم $number',
                      style: GoogleFonts.amiri(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accentGold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 20),
                    color: AppColors.accentGold.withValues(alpha: 0.7),
                    tooltip: 'نسخ الحديث',
                    onPressed: () => _copyHadith(context, cleanText, number),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ── Hadith text ──────────────────────────────────────────────
              Text(
                cleanText,
                style: GoogleFonts.amiri(
                  fontSize: 20,
                  height: 1.9,
                  color: textColor,
                ),
                textAlign: TextAlign.justify,
                textDirection: TextDirection.rtl,
              ),

              // ── Grade (if available) ─────────────────────────────────────
              if (grade.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _gradeColor(grade).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    grade,
                    style: GoogleFonts.amiri(
                      fontSize: 13,
                      color: _gradeColor(grade),
                      fontWeight: FontWeight.w600,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Color _gradeColor(String grade) {
    final lower = grade.toLowerCase();
    if (lower.contains('صحيح') || lower.contains('sahih')) return Colors.green;
    if (lower.contains('حسن') || lower.contains('hasan')) return Colors.teal;
    if (lower.contains('ضعيف') || lower.contains('daif')) return Colors.orange;
    return AppColors.accentGold;
  }
}
