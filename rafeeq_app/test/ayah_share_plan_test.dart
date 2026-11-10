import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/quran/presentation/widgets/ayah_share_card.dart';

/// A long tafsir is neither shrunk nor cut: it runs over several cards.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final palette = SharePalette.of(ShareStyle.night);

  test('the ayah alone is one card', () {
    final plans = planShare(
      const ShareContent(ayahText: 'قل هو الله أحد', surahName: 's', reference: '112:1'),
      palette,
    );
    expect(plans.length, 1);
    expect(plans.single.showAyah, isTrue);
    expect(plans.single.bodyText, isNull);
  });

  test('a long body is split with no word lost or repeated', () {
    final words = [for (var i = 0; i < 3000; i++) 'كلمة$i'];
    final plans = planShare(
      ShareContent(
        ayahText: 'قل هو الله أحد',
        surahName: 's',
        reference: '112:1',
        body: ShareBody(title: 't', text: words.join(' ')),
      ),
      palette,
    );
    expect(plans.length, greaterThan(1));
    expect(plans.first.showAyah, isTrue);
    expect(plans.skip(1).any((p) => p.showAyah), isFalse);
    final back = plans
        .map((p) => p.bodyText ?? '')
        .join(' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    expect(back, words);
  });
}
