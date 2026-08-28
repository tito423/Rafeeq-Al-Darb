import 'package:minio/minio.dart';

void main() async {
  final minio = Minio(
    endPoint: '33946f20ace0d8aa2aba052fa705d685.r2.cloudflarestorage.com',
    accessKey: '0ea932e392ce7b96cb81e8b4132a26d9',
    secretKey: 'a117398b232c11b17b9bebd497131bf8b0497791b20a5f02ada8558cbc1427ad',
    useSSL: true,
  );
  try {
    print('Listing objects in rafeeq-aldarb-data...');
    final objects = minio.listObjectsV2('rafeeq-aldarb-data');
    await for (final obj in objects) {
      for (final item in obj.objects) {
        print(item.key);
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}
