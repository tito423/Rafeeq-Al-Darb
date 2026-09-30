import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/hifz/data/tasmee_engine.dart';

void main() {
  const ayah = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ';

  test('live merge lights words as they are heard and never turns one off', () {
    final flags = List<bool>.filled(4, false);
    TasmeeEngine.liveMerge(ayahText: ayah, heard: 'بسم الله', flags: flags);
    expect(flags, [true, true, false, false]);
    // the window has moved on: only the tail is heard now
    TasmeeEngine.liveMerge(ayahText: ayah, heard: 'الرحمن الرحيم', flags: flags);
    expect(flags, [true, true, true, true]);
    TasmeeEngine.liveMerge(ayahText: ayah, heard: '', flags: flags);
    expect(flags, [true, true, true, true]);
  });

  test('live merge ignores another ayah', () {
    final flags = List<bool>.filled(4, false);
    TasmeeEngine.liveMerge(
        ayahText: ayah, heard: 'قل هو الله احد', flags: flags);
    expect(flags.where((f) => f).length, lessThanOrEqualTo(1));
  });
}
