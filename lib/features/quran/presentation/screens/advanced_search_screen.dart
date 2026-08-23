import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/datasources/quran_db_helper.dart';
import '../../domain/models/ayah.dart';
import 'surah_reading_screen.dart';

final searchResultsProvider = FutureProvider.family<List<Ayah>, String>((ref, query) {
  if (query.trim().isEmpty) return [];
  return QuranDbHelper().searchAyahs(query.trim());
});

class AdvancedSearchScreen extends ConsumerStatefulWidget {
  const AdvancedSearchScreen({super.key});

  @override
  ConsumerState<AdvancedSearchScreen> createState() => _AdvancedSearchScreenState();
}

class _AdvancedSearchScreenState extends ConsumerState<AdvancedSearchScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : const Color(0xFFFAF7F0);
    final cardBg = isDark ? AppColors.darkCardBackground : Colors.white;
    final textColor = isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'البحث المتقدم',
          style: GoogleFonts.amiri(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        iconTheme: IconThemeData(color: textColor),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchCtrl,
                textDirection: TextDirection.rtl,
                onSubmitted: (v) {
                  setState(() {
                    _query = v;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'ابحث عن آية أو جذر كلمة...',
                  filled: true,
                  fillColor: cardBg,
                  prefixIcon: IconButton(
                    icon: Icon(Icons.search_rounded, color: AppColors.primaryBlue),
                    onPressed: () {
                      setState(() {
                        _query = _searchCtrl.text;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            if (_query.isNotEmpty)
              Expanded(
                child: ref.watch(searchResultsProvider(_query)).when(
                  data: (results) {
                    if (results.isEmpty) {
                      return Center(
                        child: Text(
                          'لا توجد نتائج',
                          style: GoogleFonts.amiri(fontSize: 18, color: textColor),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: results.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (context, index) {
                        final ayah = results[index];
                        return Card(
                          color: cardBg,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SurahReadingScreen(
                                    surahId: ayah.surahId,
                                    surahNameAr: 'سورة ${ayah.surahId}', // We don't have surah name here, but the screen will fetch it or we can lookup
                                    surahNameEn: 'Surah',
                                    startPage: ayah.pageNumber,
                                  ),
                                ),
                              );
                            },
                            title: Text(
                              ayah.sanitizedText,
                              textDirection: TextDirection.rtl,
                              style: GoogleFonts.amiri(fontSize: 18, color: textColor),
                            ),
                            subtitle: Text(
                              'السورة رقم ${ayah.surahId} • الآية ${ayah.ayahNumber}',
                              textDirection: TextDirection.rtl,
                              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.primaryBlue),
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, st) => Center(child: Text('خطأ في البحث')),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
