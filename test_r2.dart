import 'dart:io';
import 'package:minio/minio.dart';

void main() async {
  final minio = Minio(
    endPoint: '33946f20ace0d8aa2aba052fa705d685.r2.cloudflarestorage.com',
    accessKey: '0ea932e392ce7b96cb81e8b4132a26d9',
    secretKey: 'a117398b232c11b17b9bebd497131bf8b0497791b20a5f02ada8558cbc1427ad',
    region: 'auto',
    useSSL: true,
  );

  try {
    final url = await minio.presignedGetObject('rafeeq-aldarb-data', 'quran_assets/tafseers/saadi.zip');
    print('Presigned URL: $url');
    final response = await HttpClient().getUrl(Uri.parse(url)).then((req) => req.close());
    print('Status code: ${response.statusCode}');
  } catch (e) {
    print('Error: $e');
  }
}
