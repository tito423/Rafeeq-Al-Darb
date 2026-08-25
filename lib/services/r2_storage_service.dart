import 'package:flutter/foundation.dart';
import 'package:minio/minio.dart';
import 'package:minio/io.dart';

class R2StorageService {
  late Minio minio;
  
  R2StorageService() {
    minio = Minio(
      endPoint: '33946f20ace0d8aa2aba052fa705d685.r2.cloudflarestorage.com',
      accessKey: '0ea932e392ce7b96cb81e8b4132a26d9',
      secretKey: 'a117398b232c11b17b9bebd497131bf8b0497791b20a5f02ada8558cbc1427ad',
      region: 'auto',
      useSSL: true,
    );
  }

  /// Uploads a file to a specific bucket
  Future<void> uploadFile(String bucket, String objectName, String filePath) async {
    try {
      await minio.fPutObject(bucket, objectName, filePath);
      debugPrint('File uploaded successfully to $bucket/$objectName');
    } catch (e) {
      debugPrint('Error uploading file to R2: $e');
      rethrow;
    }
  }

  /// Generates a presigned URL for downloading/viewing an object
  Future<String> getPresignedUrl(String bucket, String objectName, {int expiry = 3600}) async {
    try {
      return await minio.presignedGetObject(bucket, objectName, expires: expiry);
    } catch (e) {
      debugPrint('Error generating presigned URL: $e');
      rethrow;
    }
  }

  /// Downloads a file to a local path
  Future<void> downloadFile(String bucket, String objectName, String filePath) async {
    try {
      await minio.fGetObject(bucket, objectName, filePath);
      debugPrint('File downloaded successfully to $filePath');
    } catch (e) {
      debugPrint('Error downloading file from R2: $e');
      rethrow;
    }
  }

  /// Returns a stream of the file content for streaming/processing
  Future<Stream<List<int>>> getFileStream(String bucket, String objectName) async {
    try {
      return await minio.getObject(bucket, objectName);
    } catch (e) {
      debugPrint('Error streaming file from R2: $e');
      rethrow;
    }
  }
}
