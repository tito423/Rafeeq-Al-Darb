import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/azkar/data/tasbeeh_catalog.dart';

void main() {
  test('the long buzz: 33, 66, 99, and every hundred - nothing else', () {
    final hits = [for (var n = 1; n <= 450; n++) if (tasbeehStrongBuzz(n)) n];
    expect(hits, [33, 66, 99, 100, 200, 300, 400]);
    expect(tasbeehStrongBuzz(0), isFalse);
  });
}
