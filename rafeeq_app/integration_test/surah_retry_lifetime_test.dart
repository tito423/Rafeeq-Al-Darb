import 'package:integration_test/integration_test.dart';
import '../test/support/surah_retry_lifetime.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  surahRetryLifetimeTests(native: true);
}
