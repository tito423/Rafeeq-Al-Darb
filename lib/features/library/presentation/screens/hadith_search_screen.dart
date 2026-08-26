import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/datasources/hadith_db_helper.dart';

const _collectionNamesAr = {
  'bukhari': 'البخاري',
  'muslim': 'مسلم',
  'tirmidhi': 'الترمذي',
  'abudawud': 'أبو داود',
  'nasai': 'النسائي',
  'ibnmajah': 'ابن ماجه',
  'malik': 'مالك',
  'nawawi': 'النووية',
  'qudsi': 'القدسية',
};

class HadithSearchScreen extends ConsumerStatefulWidget {
  const HadithSearchScreen({super.key});

  @override
  ConsumerState<HadithSearchScreen> createState() => _HadithSearchScreenState();
}

class _HadithSearchScreenState extends ConsumerState<HadithSearchScreen> {
  final _searchController = TextEditingController();
  final _dbHelper = HadithDbHelper();
  
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final results = await _dbHelper.searchHadiths(query);
      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('Search error: $e');
    }
  }

  void _copyHadith(String text, int number) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم نسخ الحديث رقم $number', style: GoogleFonts.amiri(fontSize: 14)),
        backgroundColor: AppColors.accentGold,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
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
        iconTheme: IconThemeData(color: textColor),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: GoogleFonts.amiri(fontSize: 18, color: textColor),
          textDirection: TextDirection.rtl,
          decoration: InputDecoration(
            hintText: 'ابحث في الأحاديث...',
            hintStyle: GoogleFonts.amiri(color: Colors.grey),
            border: InputBorder.none,
          ),
          onChanged: _onSearchChanged,
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                _onSearchChanged('');
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentGold))
          : _results.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _searchController.text.isEmpty ? Icons.search_rounded : Icons.search_off_rounded,
                        size: 64,
                        color: AppColors.accentGold.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchController.text.isEmpty
                            ? 'أدخل كلمة للبحث في جميع كتب الحديث'
                            : 'لا توجد نتائج مطابقة',
                        style: GoogleFonts.amiri(fontSize: 18, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Result count
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        children: [
                          const Spacer(),
                          Text(
                            'عدد النتائج: ${_results.length}',
                            style: GoogleFonts.amiri(fontSize: 14, color: AppColors.accentGold),
                          ),
                        ],
                      ),
                    ),
                    // Results list
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final h = _results[index];
                          final text = (h['text_ar'] ?? h['text'] ?? '') as String;
                          final cleanText = text.replaceAll(RegExp(r'<br\s*/?>'), '\n');
                          final collectionId = (h['collection_id'] ?? '') as String;
                          final number = h['hadith_number'] ?? '';
                          final collectionName = _collectionNamesAr[collectionId] ?? collectionId;

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
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.accentGold.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '$collectionName - حديث $number',
                                        style: GoogleFonts.amiri(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.accentGold,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(Icons.copy_rounded, size: 18),
                                      color: AppColors.accentGold.withValues(alpha: 0.7),
                                      tooltip: 'نسخ',
                                      onPressed: () => _copyHadith(cleanText, number as int),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  cleanText,
                                  style: GoogleFonts.amiri(
                                    fontSize: 18,
                                    height: 1.8,
                                    color: textColor,
                                  ),
                                  textAlign: TextAlign.justify,
                                  textDirection: TextDirection.rtl,
                                  maxLines: 6,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
