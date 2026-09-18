import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/dedications/data/dedication.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The reader's dedications survive a restart, with their own words intact.
void main() {
  test('add, count, edit, remove - and it all comes back from storage', () async {
    SharedPreferences.setMockInitialValues({});
    final a = DedicationsNotifier();
    await a.loaded;
    await a.add(Dedication(
      id: 'x',
      name: 'والدي',
      kind: DedicationKind.istighfar,
      note: 'اللهم اغفر له وارحمه',
      count: 0,
      created: DateTime(2026, 9, 18),
    ));
    await a.bump('x', 1);
    await a.bump('x', 1);
    await a.bump('x', -5); // never below zero

    final b = DedicationsNotifier();
    await b.loaded;
    expect(b.state.single.name, 'والدي');
    expect(b.state.single.note, 'اللهم اغفر له وارحمه');
    expect(b.state.single.kind, DedicationKind.istighfar);
    expect(b.state.single.count, 0);

    await b.bump('x', 3);
    await b.remove('x');
    final c = DedicationsNotifier();
    await c.loaded;
    expect(c.state, isEmpty);
  });

  test('a dua has no counter; the others count pages or times', () {
    expect(DedicationKind.dua.unitKey, isNull);
    expect(DedicationKind.quran.unitKey, 'dedication.unit_pages');
    expect(DedicationKind.tasbih.unitKey, 'dedication.unit_times');
  });
}
