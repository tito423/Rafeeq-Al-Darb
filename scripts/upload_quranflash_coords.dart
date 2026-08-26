import 'dart:io';
import 'package:minio/minio.dart';

void main() async {
  final minio = Minio(
    endPoint: '33946f20ace0d8aa2aba052fa705d685.r2.cloudflarestorage.com',
    accessKey: '0ea932e392ce7b96cb81e8b4132a26d9',
    secretKey: 'a117398b232c11b17b9bebd497131bf8b0497791b20a5f02ada8558cbc1427ad',
    useSSL: true,
  );

  const bucket = 'rafeeq-aldarb-data';
  final coordsDir = Directory('C:/Users/Asus/.gemini/antigravity-ide/brain/8a34792d-e7a0-4d80-accc-81ba255a6f83/scratch/mushaf_coords');
  
  if (!await coordsDir.exists()) {
    print('Directory not found');
    return;
  }

  final files = coordsDir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList();
  print('Found ${files.length} JSON files.');

  int uploaded = 0;
  for (var file in files) {
    final filename = file.path.split(Platform.pathSeparator).last;
    final objectName = 'mushaf_coords/$filename';
    print('Uploading \$filename...');
    
    try {
      final stat = file.statSync();
      await minio.putObject(bucket, objectName, file.openRead().cast(), size: stat.size);
      print('  -> Success');
      uploaded++;
    } catch (e) {
      print('  -> Error: \$e');
    }
  }
  
  print('Uploaded \$uploaded/\${files.length} files.');
}
