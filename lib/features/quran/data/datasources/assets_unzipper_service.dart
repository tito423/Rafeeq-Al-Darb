import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';

class AssetsUnzipperService {
  static const String baseUrl = 'https://pub-b9273af6154c4a618f813447e8a9fc09.r2.dev/quran_assets';

  static Future<String> get localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  static Future<bool> areQuranImagesReady() async {
    final path = await localPath;
    final imagesDir = Directory('$path/quran/images');
    if (!await imagesDir.exists()) return false;
    // Basic check if a few pages exist
    final page1 = File('${imagesDir.path}/page001.png');
    return await page1.exists();
  }

  static Future<void> downloadAndUnzip(String filename, Function(double) onProgress) async {
    final path = await localPath;
    final savePath = '$path/$filename';
    final url = '$baseUrl/$filename';
    
    // 1. Download Zip
    final dio = Dio();
    await dio.download(
      url, 
      savePath,
      onReceiveProgress: (received, total) {
        if (total != -1) {
          onProgress((received / total) * 0.5); // Download is first 50%
        }
      }
    );
    
    // 2. Unzip
    final bytes = File(savePath).readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);
    
    final totalFiles = archive.length;
    int extracted = 0;
    
    for (final file in archive) {
      final targetFileName = file.name;
      if (file.isFile) {
        final data = file.content as List<int>;
        final targetFile = File('$path/quran/${filename.replaceAll('.zip', '')}/$targetFileName');
        
        targetFile.createSync(recursive: true);
        targetFile.writeAsBytesSync(data);
      } else {
        Directory('$path/quran/${filename.replaceAll('.zip', '')}/$targetFileName').createSync(recursive: true);
      }
      extracted++;
      onProgress(0.5 + ((extracted / totalFiles) * 0.5)); // Extraction is 50-100%
    }
    
    // 3. Clean up
    File(savePath).deleteSync();
  }
}
