import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/services/continuous_recitation.dart';
import 'package:rafeeq_app/core/utils/http_status_probe.dart';

/// The pieces of «never skip, hold and resume» that can be held without a
/// device (the rest was seen on emulator-5554 with the network cut).
void main() {
  group('ContinuousRecitation.waiting', () {
    const held = ContinuousRecitation(
      active: true,
      surahId: 2,
      ayahNumber: 148,
      waiting: true,
    );

    test('a hold keeps its verse — that verse is where it resumes', () {
      expect(held.isAyah(2, 148), isTrue);
    });

    test('copyWith keeps the hold unless told otherwise', () {
      // The retry marks the run `buffering` while it loads; the hold must
      // survive that, or a failed retry would lose "waiting" and the bar
      // would stop saying why nothing is sounding.
      expect(held.copyWith(buffering: true).waiting, isTrue);
      expect(held.copyWith(stalled: true).waiting, isTrue);
      expect(held.copyWith(waiting: false).waiting, isFalse);
    });

    test('a fresh run is not waiting', () {
      expect(const ContinuousRecitation(active: true).waiting, isFalse);
      expect(ContinuousRecitation.stopped.waiting, isFalse);
    });
  });

  group('httpStatusOf', () {
    // Only the offline answers are testable here; the live ones (404 for
    // al-Burimi's An-Nas, 200 for a mirror) were measured against the hosts.
    test('a local or malformed URL is "no answer", never a crash', () async {
      expect(await httpStatusOf('file:///sdcard/x.mp3'), isNull);
      expect(await httpStatusOf('content://media/1'), isNull);
      expect(await httpStatusOf('not a url'), isNull);
      expect(await httpStatusOf(''), isNull);
    });
  });
}
