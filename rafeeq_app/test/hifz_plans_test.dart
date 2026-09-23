import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/db/models.dart';
import 'package:rafeeq_app/features/hifz/data/hifz_plans.dart';
import 'package:rafeeq_app/features/hifz/presentation/widgets/hifz_plans_section.dart';

/// «حفظي»: a range from any ayah of any surah (2026-09-23).
void main() {
  const maryam12to40 = HifzPlan(
    id: 1,
    name: '',
    from: AyahRef(19, 12),
    to: AyahRef(19, 40),
  );

  test('a plan contains its ends and nothing outside them', () {
    expect(maryam12to40.contains(19, 12), isTrue);
    expect(maryam12to40.contains(19, 40), isTrue);
    expect(maryam12to40.contains(19, 11), isFalse);
    expect(maryam12to40.contains(19, 41), isFalse);
    expect(maryam12to40.contains(20, 1), isFalse);
  });

  test('a plan may cross into the next surah', () {
    const p = HifzPlan(
      id: 2,
      name: '',
      from: AyahRef(19, 90),
      to: AyahRef(20, 5),
    );
    expect(p.contains(19, 98), isTrue);
    expect(p.contains(20, 1), isTrue);
    expect(p.contains(20, 6), isFalse);
  });

  test('a plan survives being stored', () {
    final back = HifzPlan.fromJson({
      ...maryam12to40.toJson(),
      'n': 'ورد الفجر',
    });
    expect(back.from, const AyahRef(19, 12));
    expect(back.to, const AyahRef(19, 40));
    expect(back.name, 'ورد الفجر');
  });

  test('an unnamed plan is named after its range', () {
    final surahs = {
      19: const Surah(
        id: 19,
        nameAr: 'سُورَةُ مَرۡيَمَ',
        nameEn: 'Maryam',
        revelationType: 'Meccan',
        ayahsCount: 98,
      ),
      20: const Surah(
        id: 20,
        nameAr: 'سُورَةُ طه',
        nameEn: 'Taha',
        revelationType: 'Meccan',
        ayahsCount: 135,
      ),
    };
    expect(hifzPlanTitle(maryam12to40, surahs), 'مريم ١٢–٤٠');
    const across = HifzPlan(
      id: 3,
      name: '',
      from: AyahRef(19, 90),
      to: AyahRef(20, 5),
    );
    expect(hifzPlanTitle(across, surahs), 'مريم ٩٠ – طه ٥');
    const named = HifzPlan(
      id: 4,
      name: 'ورد الفجر',
      from: AyahRef(1, 1),
      to: AyahRef(1, 7),
    );
    expect(hifzPlanTitle(named, surahs), 'ورد الفجر');
  });
}
