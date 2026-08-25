import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AssetsExtractorService {
  static const String _kExtractedKey = 'assets_extracted_v1';

  static Future<void> extractInitialAssetsIfNeeded(Function(String) onProgress) async {
    final prefs = await SharedPreferences.getInstance();
    final bool isExtracted = prefs.getBool(_kExtractedKey) ?? false;
    
    if (isExtracted) {
      return; // Already extracted
    }
    
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final mushaafDir = Directory('${docDir.path}/mushaaf_pages/madani_1024');
      
      if (!await mushaafDir.exists()) {
        await mushaafDir.create(recursive: true);
      }
      
      onProgress('جاري تجهيز ملفات المصحف...');
      
      // Load zip from assets
      final byteData = await rootBundle.load('assets/quran/quran_images.zip');
      
      // Save to temp file to avoid OOM when extracting
      final tempZip = File('${docDir.path}/temp_quran_images.zip');
      await tempZip.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
      
      onProgress('جاري فك ضغط المصحف (قد يستغرق بعض الوقت)...');
      
      // Unzip
      final bytes = byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
      final archive = ZipDecoder().decodeBytes(bytes);
      
      for (final file in archive) {
        if (file.isFile) {
          // File names in zip are like page001.png
          // We need to rename them to page_001.png for DownloadManager
          final originalName = file.name;
          if (originalName.startsWith('page') && originalName.endsWith('.png')) {
            final numPart = originalName.replaceAll('page', '').replaceAll('.png', '');
            final newName = 'page_$numPart.png';
            
            final targetPath = '${mushaafDir.path}/$newName';
            
            final outputStream = OutputFileStream(targetPath);
            file.writeContent(outputStream);
            outputStream.close();
          }
        }
      }
      
      await tempZip.delete();
      
      // Mark as extracted
      await prefs.setBool(_kExtractedKey, true);
      onProgress('اكتمل تجهيز الموارد بنجاح!');
      
    } catch (e) {
      debugPrint('Failed to extract assets: $e');
      onProgress('حدث خطأ أثناء فك الضغط');
    }
  }
}
