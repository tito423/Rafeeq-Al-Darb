import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/models/adhan_mode.dart';
import 'package:rafeeq_app/core/models/adhan_option.dart';
import 'package:rafeeq_app/core/services/adhan_native.dart';

/// «ضيف اختيار هزاز مع الاذان الشاشة الكاملة» (owner, 2026-09-29): the
/// vibration travels to the native side only with the full-screen mode, and
/// survives the map / JSON hops the alarm pipeline makes.
void main() {
  const option = AdhanOption(
    id: 'azan1',
    name: 'test',
    isCustom: false,
    rawResource: 'azan1',
    assetPath: 'assets/audio/adhan/azan1.mp3',
  );

  AdhanSpec spec(AdhanMode mode, {required bool vibrate}) =>
      AdhanNative.specFor(
        prayerKey: 'dhuhr',
        prayerLabel: 'الظهر',
        mode: mode,
        option: option,
        vibrate: vibrate,
      );

  test('full-screen mode carries the vibration when it is on', () {
    final s = spec(AdhanMode.full, vibrate: true);
    expect(s.vibrate, isTrue);
    expect(s.toMap()['vibrate'], isTrue);
    expect(AdhanSpec.fromJson(s.toMap()).vibrate, isTrue);
  });

  test('off stays off', () {
    expect(spec(AdhanMode.full, vibrate: false).toMap()['vibrate'], isFalse);
  });

  test('the other modes never get the full-screen vibration', () {
    for (final m in [AdhanMode.audio, AdhanMode.vibrate, AdhanMode.silent]) {
      expect(spec(m, vibrate: true).vibrate, isFalse, reason: m.name);
    }
  });

  test('a stored spec without the field reads as off', () {
    final map = spec(AdhanMode.full, vibrate: true).toMap()..remove('vibrate');
    expect(AdhanSpec.fromJson(map).vibrate, isFalse);
  });
}
