import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/datasources/hadith_db_helper.dart';

class HadithReaderScreen extends ConsumerStatefulWidget {
  final String bookId;
  final String bookTitle;
  final String downloadUrl;

  const HadithReaderScreen({
    super.key,
    required this.bookId,
    required this.bookTitle,
    required this.downloadUrl,
  });

  @override
  ConsumerState<HadithReaderScreen> createState() => _HadithReaderScreenState();
}

class _HadithReaderScreenState extends ConsumerState<HadithReaderScreen> {
  List<dynamic> _hadiths = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBook();
  }

  Future<void> _loadBook() async {
    try {
      
      // Fetch from DB
      final dbHelper = HadithDbHelper();
      final data = await dbHelper.getHadithsByBook(widget.bookId, limit: 10000);
      
      setState(() {
        _hadiths = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'حدث خطأ أثناء قراءة الكتاب: $e';
        _isLoading = false;
      });
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
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.bookTitle,
          style: GoogleFonts.amiri(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        iconTheme: IconThemeData(color: textColor),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _error!,
                          style: GoogleFonts.amiri(fontSize: 18, color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          label: Text('العودة', style: GoogleFonts.amiri(fontSize: 16, color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        )
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _hadiths.length,
                  itemBuilder: (context, index) {
                    final hadith = _hadiths[index];
                    final text = hadith['text'] ?? '';
                    final number = hadith['hadith_number'] ?? index + 1;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.1)),
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'حديث رقم $number',
                                  style: GoogleFonts.amiri(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryBlue,
                                  ),
                                ),
                              ),
                              const Icon(Icons.menu_book_rounded, color: AppColors.accentGold, size: 20),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            text,
                            style: GoogleFonts.amiri(
                              fontSize: 20,
                              height: 1.8,
                              color: textColor,
                            ),
                            textAlign: TextAlign.justify,
                            textDirection: TextDirection.rtl,
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
